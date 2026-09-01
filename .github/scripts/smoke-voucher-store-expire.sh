#!/usr/bin/env bash
# 代金券「门店限制 / 过期 / 生效期」smoke test
#
# 为什么要这个 smoke：三条校验都是「字段建了但从来没人读」型缺口，
# 后端不报错、前端看不出来，只能从接口这层锁住。全部实测复现过：
#
#   1) 过期券仍能抵扣：原判断只看 status='0'，而 status 要靠定时任务刷新，
#      sys_job 里压根没有这个任务（只有 4 条，无一是券过期）。于是
#      expire_time 是 5 天前的券 status 永远停在 '0' —— 实测 ¥200 的单
#      被这种券抵掉 ¥20 并成功落库。
#   2) 券跨门店抵扣：biz_voucher.store_id 限定券属于哪个门店，下单和买单
#      都没读过它。实测领门店 201 的「满 150 减 30」，去买门店 200 的
#      ¥200 商品照样抵扣成功 —— A 店发的券扣了 B 店的营业额。
#   3) 领券中心漏掉全门店通用券：小程序带 storeId 进来，mapper 复用了
#      admin 的精确匹配，store_id=0 的通用券一张都领不到。
#
# 验证：
#   A) 过期券（expire_time 已过、status 仍 0）→ 拒，msg=代金券已过期
#   B) 他店专属券买本店商品 → 拒，msg 含「仅限」
#   C) 本店专属券买本店商品 → 正常抵扣
#   D) 通用券（store_id=0）→ 任意门店都能用
#   E) 领券中心带 storeId → 必须同时含本店券与通用券
#   F) 活动已结束的模板（valid_to 已过）→ 不许领取
#   G) 买单路径同样受门店限制约束（与下单共用 VoucherUsageService）
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-voucher-store-expire.sh
set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
FAIL=0

# 商品：店 200 的 ¥200 商品（门槛 150 的券刚好够用），店 100 的 ¥99 商品
P_STORE200=999829   # C36_398623 ¥200.00 store_id=200
P_STORE100=999846   # 99元任选3件 ¥99.00 store_id=100

ck() { if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=1; fi; }
ckhas() { case "$2" in *"$3"*) echo "  OK: $1 (含「$3」)";; *) echo "  FAIL: $1 期望含「$3」实际 $2"; FAIL=1;; esac; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 -e "use \`ry-vue\`; $1" 2>/dev/null; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null; }

jmsg()  { python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("msg",""))'; }
jcode() { python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))'; }
jamt()  { python3 -c "
import sys,json
from decimal import Decimal
d=json.load(sys.stdin,parse_float=Decimal); b=d.get('data') or {}
v=(b or {}).get('$1')
print('' if v is None else '{:.2f}'.format(Decimal(str(v))))
"; }

# 券模板 id 段用 9993xx，与既有测试数据（9996xx/9995xx）不撞
T_S200=999311   # 门店 200 专属
T_S201=999312   # 门店 201 专属
T_ANY=999313    # 全门店通用 store_id=0
T_ENDED=999314  # 活动已结束 valid_to 昨天

cleanup() {
  sql "delete from biz_order where member_id in (select member_id from biz_member where openid='mock_smokevs');"
  sql "delete from biz_pay_bill where member_id in (select member_id from biz_member where openid='mock_smokevs');" >/dev/null 2>&1
  sql "delete from biz_member_voucher where member_id in (select member_id from biz_member where openid='mock_smokevs');"
  sql "delete from biz_member where openid='mock_smokevs';"
  sql "delete from biz_voucher where voucher_id in ($T_S200,$T_S201,$T_ANY,$T_ENDED);"
}
trap cleanup EXIT
cleanup   # 上次异常中断可能有残留

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokevs\",\"appid\":\"$APPID\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
MID=$(sql1 "select member_id from biz_member where openid='mock_smokevs';")
echo "[0] member=$MID"

sql "insert into biz_voucher(voucher_id,merchant_id,store_id,voucher_name,face_value,threshold,total,received,valid_days,status)
     values($T_S200,1,200,'SMOKE_VS_S200',30.00,150.00,100,0,30,'0'),
           ($T_S201,1,201,'SMOKE_VS_S201',30.00,150.00,100,0,30,'0'),
           ($T_ANY, 1,0,  'SMOKE_VS_ANY', 30.00,150.00,100,0,30,'0');"
sql "insert into biz_voucher(voucher_id,merchant_id,store_id,voucher_name,face_value,threshold,total,received,valid_days,status,valid_to)
     values($T_ENDED,1,200,'SMOKE_VS_ENDED',30.00,0.00,100,0,30,'0',date_sub(now(), interval 1 day));"

# mkv <模板id> <过期偏移天数，负数=已过期> → 新会员券 id
mkv() {
  sql "insert into biz_member_voucher(merchant_id,voucher_id,member_id,face_value,threshold,status,get_time,expire_time)
       select 1,voucher_id,$MID,face_value,threshold,'0',now(),date_add(now(), interval $2 day)
       from biz_voucher where voucher_id=$1;"
  sql1 "select max(id) from biz_member_voucher where member_id=$MID;"
}
order() {  # order <会员券id> <商品id>
  curl -s -X POST "$BASE_URL/api/order" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
    -d "{\"productId\":$2,\"num\":1,\"memberVoucherId\":$1}"
}

# A) 过期券：status 仍是 '0'，但 expire_time 已过 5 天
V_EXP=$(mkv $T_S200 -5)
RESP=$(order "$V_EXP" $P_STORE200)
echo "[A] 过期券(券$V_EXP expire=5天前 status=0): $(echo "$RESP" | head -c 160)"
ck    "过期券被拒 code" "$(echo "$RESP" | jcode)" "500"
ckhas "过期券提示"      "$(echo "$RESP" | jmsg)"  "已过期"

# B) 门店 201 的券去买门店 200 的商品（金额满门槛，只差门店不符）
V_S201=$(mkv $T_S201 30)
RESP=$(order "$V_S201" $P_STORE200)
echo "[B] 他店券跨店用(券$V_S201 属店201 商品属店200): $(echo "$RESP" | head -c 160)"
ck    "跨店用券被拒 code" "$(echo "$RESP" | jcode)" "500"
ckhas "跨店提示带门店名"  "$(echo "$RESP" | jmsg)"  "仅限"

# C) 本店券买本店商品 → 正常抵扣，证明 B 不是把所有券都拦死了
V_S200=$(mkv $T_S200 30)
RESP=$(order "$V_S200" $P_STORE200)
echo "[C] 本店券正常用(券$V_S200): $(echo "$RESP" | head -c 160)"
ck "本店券下单成功" "$(echo "$RESP" | jcode)"        "200"
ck "抵扣 30"        "$(echo "$RESP" | jamt discountAmount)" "30.00"
ck "实付 170"       "$(echo "$RESP" | jamt payAmount)"      "170.00"

# D) 通用券 store_id=0 → 不受门店限制
V_ANY=$(mkv $T_ANY 30)
RESP=$(order "$V_ANY" $P_STORE200)
echo "[D] 通用券(券$V_ANY store_id=0): $(echo "$RESP" | head -c 160)"
ck "通用券可用"  "$(echo "$RESP" | jcode)"               "200"
ck "通用券抵 30" "$(echo "$RESP" | jamt discountAmount)" "30.00"

# E) 领券中心带 storeId=200：本店券 + 通用券都要列出来，他店券不能出现
LIST=$(curl -s "$BASE_URL/api/voucher/list?storeId=200" -H "X-App-Id: $APPID")
PICK=$(echo "$LIST" | python3 -c "
import sys,json
ids={str(v.get('voucherId')) for v in (json.load(sys.stdin).get('data') or [])}
print(('本店' if '$T_S200' in ids else '-') + '/' + ('通用' if '$T_ANY' in ids else '-') + '/' + ('他店' if '$T_S201' in ids else '-'))
")
echo "[E] 领券中心 storeId=200 命中: $PICK"
ck "本店券+通用券都在、他店券不在" "$PICK" "本店/通用/-"

# F) 活动已结束的模板不许领
RESP=$(curl -s -X POST "$BASE_URL/api/voucher/receive/$T_ENDED" \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID")
echo "[F] 领已结束活动的券(模板$T_ENDED valid_to=昨天): $(echo "$RESP" | head -c 160)"
ck    "已结束不许领 code" "$(echo "$RESP" | jcode)" "500"
ckhas "已结束提示"        "$(echo "$RESP" | jmsg)"  "已结束"

# G) 买单路径：门店 100 的账单用门店 201 的券 → 同样要拒
V_S201B=$(mkv $T_S201 30)
RESP=$(curl -s -X POST "$BASE_URL/api/bill" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"storeId\":100,\"amount\":200.00,\"memberVoucherId\":$V_S201B}")
echo "[G] 买单跨店用券(券$V_S201B 属店201 账单店100): $(echo "$RESP" | head -c 160)"
ck    "买单跨店被拒 code" "$(echo "$RESP" | jcode)" "500"
ckhas "买单跨店提示"      "$(echo "$RESP" | jmsg)"  "仅限"

echo
if [ "$FAIL" = "0" ]; then echo "voucher store/expire smoke PASSED"; else echo "voucher store/expire smoke FAILED"; exit 1; fi
