#!/usr/bin/env bash
# 微信支付「商品订单详情path」smoke test
#
# 锁住的行为：订单详情必须能按 **商户订单号** 打开，不只是数据库主键。
#
# 为什么要这个 smoke：
#   微信支付商户平台的「商品订单详情path」要求填成
#     pages/order/detail/index?id=${商品订单号}
#   那个 ${商品订单号} 占位符是字面写进配置的，微信在用户点「查看订单」时
#   替换成下单接口传的 out_trade_no —— 也就是 biz_order.order_no
#   （形如 D1787398679265359），不是主键 order_id。
#   而 /api/order/{orderId} 是 @PathVariable Long，拿订单号去请求会直接
#   报「参数类型不匹配，要求 java.lang.Long」→ 用户从微信账单点进来看到报错页。
#   所以加了 /api/order/no/{orderNo}。谁把它删了，这个 smoke 就红。
#
# 验证：
#   A) 主键入口照常可用（站内跳转走这条）
#   B) 订单号入口可用，且返回同一笔订单
#   C) 订单号打主键入口必然失败 —— 证明 A 顶不了 B 的位
#   D) 越权：查别人的订单号被拒（归属校验不能只写在主键入口上）
#   E) 不存在的订单号 → 订单不存在
#   F) 未登录 → 401
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-wxpay-orderpath.sh
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
DB="${DB:-ry-vue}"
DBUSER="${DBUSER:-root}"
DBPASS="${DBPASS:-133301}"

q() { "$MYSQL" -u"$DBUSER" -p"$DBPASS" --default-character-set=utf8mb4 -N -B "$DB" -e "$1" 2>/dev/null; }
jget() { python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('data') or {}).get('$1',''))" 2>/dev/null; }
jtop() { python3 -c "import sys,json;print(json.load(sys.stdin).get('$1',''))" 2>/dev/null; }

PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokewxpath\",\"appid\":\"$APPID\"}" | jtop token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
MID=$(q "select member_id from biz_member where openid='mock_smokewxpath'")
[ -n "$MID" ] || { echo "FAIL: 找不到测试会员"; exit 1; }

# 借一笔已有的待支付订单，测完还原归属
ORDER_ID=$(q "select order_id from biz_order where status='0' order by order_id desc limit 1")
[ -n "$ORDER_ID" ] || { echo "SKIP: 库里没有待支付订单"; exit 0; }
ORDER_NO=$(q "select order_no from biz_order where order_id=$ORDER_ID")
OWNER=$(q "select member_id from biz_order where order_id=$ORDER_ID")

cleanup() {
  q "update biz_order set member_id=$OWNER, status='0', pay_time=null, verify_code=null where order_id=$ORDER_ID"
  q "delete from biz_member where member_id=$MID and openid='mock_smokewxpath'"
}
trap cleanup EXIT

q "update biz_order set member_id=$MID where order_id=$ORDER_ID"
echo "测试订单 order_id=$ORDER_ID order_no=$ORDER_NO"

AUTH=(-H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")

echo "A) 主键入口"
A=$(curl -s "${AUTH[@]}" "$BASE_URL/api/order/$ORDER_ID" | jget orderNo)
[ "$A" = "$ORDER_NO" ] && ok "orderId 查到 $A" || bad "orderId 入口异常，得到 '$A'"

echo "B) 订单号入口（微信回跳走这条）"
B=$(curl -s "${AUTH[@]}" "$BASE_URL/api/order/no/$ORDER_NO" | jget orderId)
[ "$B" = "$ORDER_ID" ] && ok "orderNo 查到同一笔 orderId=$B" || bad "orderNo 入口异常，得到 '$B'"

echo "C) 订单号打主键入口必须失败（证明 A 顶不了 B）"
C=$(curl -s "${AUTH[@]}" "$BASE_URL/api/order/$ORDER_NO" | jtop code)
[ "$C" = "500" ] && ok "如预期报错 code=500（类型不匹配）" || bad "预期 500，得到 '$C'"

echo "D) 越权：别人的订单号"
OTHER=$(q "select order_no from biz_order where member_id<>$MID and member_id is not null order by order_id desc limit 1")
if [ -n "$OTHER" ]; then
  D=$(curl -s "${AUTH[@]}" "$BASE_URL/api/order/no/$OTHER" | jtop msg)
  [ "$D" = "无权查看他人订单" ] && ok "越权被拒" || bad "越权未拦住，msg='$D'"
else
  ok "库里没有他人订单，跳过"
fi

echo "E) 不存在的订单号"
E=$(curl -s "${AUTH[@]}" "$BASE_URL/api/order/no/D0000000000000000" | jtop msg)
[ "$E" = "订单不存在" ] && ok "返回订单不存在" || bad "预期订单不存在，得到 '$E'"

echo "F) 未登录"
F=$(curl -s -H "X-App-Id: $APPID" "$BASE_URL/api/order/no/$ORDER_NO" | jtop code)
[ "$F" = "401" ] && ok "401" || bad "预期 401，得到 '$F'"

echo
echo "smoke-wxpay-orderpath: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
