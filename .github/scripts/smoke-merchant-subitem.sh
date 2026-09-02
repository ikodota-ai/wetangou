#!/usr/bin/env bash
# 商家端「商品搭配」（子品分组 + 几选几）端到端烟测
#
# 为什么需要这个脚本：
#   pages/merchant/product/combo 是手机上唯一能配团购套餐内容的页面，
#   它原来调的是 PC 后台的 /biz/productSubitem/**。那套挂 Spring Security +
#   @PreAuthorize，判的是后台 sys_user 的 perms；小程序员工 token 走的是
#   MemberAuthInterceptor 这条完全独立的链路 —— 拿员工 token 打 /biz/** 一律 401。
#   于是新开了 /api/product/subitem/** 6 个端点，这个脚本锁住它们的行为，
#   尤其是三条只能在服务端保证的约束：
#     1) 商品必须属于当前登录员工的商户（改 productId 编不了别家的套餐）
#     2) 组/子品必须属于该商品（防拿别家 groupId 往自己商品上挂）
#     3) 只有 OWNER/MANAGER 能改（店员只核销，不该动商品结构）
#   另外锁「几选几」的两条口径（与 PC 端 checkPickRule / shrinkPickRule 一致）：
#     N > 本组单品数 → 拒；N == 单品数 → 归一成 ALL；删单品后规则自动收敛
#
# 用法：bash .github/scripts/smoke-merchant-subitem.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

chk_code() { # $1 desc $2 want $3 body
  local got
  got=$(echo "$3" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))' 2>/dev/null)
  [ "$got" = "$2" ] && ok "$1 (code=$got)" || bad "$1 期望 code=$2 实得 $got: $3"
}
chk_msg() { # $1 desc $2 keyword $3 body
  echo "$3" | grep -q "$2" && ok "$1" || bad "$1 未含「$2」: $3"
}
chk_eq() { # $1 desc $2 want $3 got
  [ "$3" = "$2" ] && ok "$1 ($3)" || bad "$1 期望「$2」实得「$3」"
}

MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 ry-vue"

echo "=== 商家端商品搭配（子品分组/几选几） 端到端 ($H) ==="

# ---------- 0) 三个角色登录 ----------
echo "[0] 登录：店长 owner / 店员 staff"
LO=$(curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
  -d '{"username":"owner_c43","password":"admin123"}')
OTK=$(echo "$LO" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
MID=$(echo "$LO" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("merchantId",""))')
SID=$(echo "$LO" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("storeId",""))')
if [ -z "$OTK" ]; then echo "  ❌ 店长登录失败，后续跳过: $LO"; exit 1; fi
ok "店长登录成功 merchantId=$MID storeId=$SID"

LS=$(curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
  -d '{"username":"staff_c43","password":"admin123"}')
STK=$(echo "$LS" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
[ -n "$STK" ] && ok "店员登录成功" || bad "店员登录失败: $LS"

AUTH="Authorization: Bearer $OTK"
SAUTH="Authorization: Bearer $STK"
JSON='Content-Type: application/json'

# 收尾清理
CREATED=""
cleanup() {
  $MYSQL -e "
    delete from biz_product_subitem where product_id in (select product_id from biz_product where product_name like 'ZZSUB_%');
    delete from biz_product_subitem_group where product_id in (select product_id from biz_product where product_name like 'ZZSUB_%');
    delete from biz_product_store where product_id in (select product_id from biz_product where product_name like 'ZZSUB_%');
    delete from biz_product_ext where product_id in (select product_id from biz_product where product_name like 'ZZSUB_%');
    delete from biz_product where product_name like 'ZZSUB_%';" 2>/dev/null
  local left
  left=$($MYSQL -N -B -e "select count(*) from biz_product where product_name like 'ZZSUB_%';" 2>/dev/null)
  echo "  [cleanup] 残留测试商品 left=$left"
}
trap cleanup EXIT

# ---------- 1) 建一个 GROUPON 草稿当载体 ----------
echo "[1] 建 GROUPON 商品（草稿）"
ADD=$(curl -s -X POST "$H/api/product/add" -H "$AUTH" -H "$JSON" \
  -d "{\"productName\":\"ZZSUB_团购套餐\",\"typeCode\":\"GROUPON\",\"industryCode\":\"FOOD\",\"price\":99,\"originalPrice\":199,\"stock\":100,\"maxPerOrder\":1,\"storeIds\":\"$SID\"}")
chk_code "建品成功" 200 "$ADD"
PID=$(echo "$ADD" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("productId") or (d.get("data") or {}).get("productId") or "")')
[ -n "$PID" ] && ok "productId=$PID" || { bad "未拿到 productId: $ADD"; exit 1; }

# ---------- 2) 无 token / 店员 → 拒 ----------
echo "[2] 权限：无 token 401，店员 403"
NOAUTH=$(curl -s "$H/api/product/subitem/groups?productId=$PID")
chk_code "无 token 读分组 → 401" 401 "$NOAUTH"

SGET=$(curl -s -H "$SAUTH" "$H/api/product/subitem/groups?productId=$PID")
chk_code "店员读分组 → 403（只核销，不该动商品结构）" 403 "$SGET"

SADD=$(curl -s -X POST "$H/api/product/subitem/group" -H "$SAUTH" -H "$JSON" \
  -d "{\"productId\":$PID,\"groupName\":\"店员越权组\",\"pickRule\":\"ALL\"}")
chk_code "店员建分组 → 403" 403 "$SADD"

# ---------- 3) 跨商户：拿别家 productId → 拒 ----------
echo "[3] 跨商户：改 productId 编别家套餐 → 拒"
OTHER=$($MYSQL -N -B -e "select product_id from biz_product where merchant_id<>$MID limit 1;" 2>/dev/null)
if [ -n "$OTHER" ]; then
  X=$(curl -s -X POST "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
    -d "{\"productId\":$OTHER,\"groupName\":\"越权组\",\"pickRule\":\"ALL\"}")
  chk_code "往别家商品($OTHER)挂分组 → 500 拒" 500 "$X"
  chk_msg "拒绝文案指明无权" "无权" "$X"
else
  ok "库里没有别家商户商品，跳过跨商户用例"
fi

# ---------- 4) 建分组 + 加 3 个单品 ----------
echo "[4] 建分组 + 加 3 单品"
G=$(curl -s -X POST "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"productId\":$PID,\"groupName\":\"主菜\",\"pickRule\":\"ALL\",\"sort\":0}")
chk_code "建分组成功" 200 "$G"
GRP=$(echo "$G" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("groupId") or "")')
[ -n "$GRP" ] && ok "groupId=$GRP" || { bad "未拿到 groupId: $G"; exit 1; }

for n in 牛肉 羊肉 时蔬; do
  S=$(curl -s -X POST "$H/api/product/subitem" -H "$AUTH" -H "$JSON" \
    -d "{\"groupId\":$GRP,\"subitemName\":\"$n\",\"quantity\":1,\"price\":30}")
  chk_code "加单品 $n" 200 "$S"
done

# 名称缺失必须给人话，不能把 SQL 异常糊到用户脸上。
# biz_product_subitem.subitem_name 是 NOT NULL 且无默认值，端点原先不校验就直接
# insert，MySQL 抛 "Field 'subitem_name' doesn't have a default value"，RuoYi 的
# 全局异常处理把整段 SQL 异常原文塞进 msg 返给端上 —— 商家在手机上看到的是一屏
# "### Error updating database ... ProductSubitemMapper.xml"，完全不知道是名称没填。
# 字段名写错（比如传 itemName）也是同一个下场，排查成本极高。
for BAD in '{"groupId":GRPID,"itemName":"字段名写错","num":1}' \
           '{"groupId":GRPID,"subitemName":"","quantity":1}' \
           '{"groupId":GRPID,"subitemName":"   ","quantity":1}' \
           '{"groupId":GRPID,"quantity":1}'; do
  BODY=$(echo "$BAD" | sed "s/GRPID/$GRP/")
  BR=$(curl -s -X POST "$H/api/product/subitem" -H "$AUTH" -H "$JSON" -d "$BODY")
  chk_msg "缺名称给人话提示: $BODY" "请填写单品名称" "$BR"
  # 反面：绝不能把 SQL 细节漏出去
  case "$BR" in
    *"Error updating database"*|*"doesn't have a default value"*|*Mapper.xml*)
      bad "缺名称时把 SQL 异常返给了端上: $BR";;
    *) ok "  → 未泄漏 SQL 异常";;
  esac
done
# 上面 4 次失败请求都不该落库，仍应只有 3 个单品
LEFT=$($MYSQL -N -B -e "select count(*) from biz_product_subitem where group_id=$GRP;" 2>/dev/null)
chk_eq "失败请求没污染数据（仍 3 个单品）" 3 "$LEFT"

READ=$(curl -s -H "$AUTH" "$H/api/product/subitem/groups?productId=$PID")
CNT=$(echo "$READ" | python3 -c '
import sys,json
d=json.load(sys.stdin); l=d.get("data") or []
print(len((l[0].get("subitems") or [])) if l else 0)')
chk_eq "读回 3 个单品" 3 "$CNT"

# ---------- 5) 几选几：合法 / 超范围拒 / 等于总数归一 ----------
echo "[5] 几选几校验（与 PC 端 checkPickRule 同口径）"
R2=$(curl -s -X PUT "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"groupId\":$GRP,\"pickRule\":\"PICK_2\"}")
chk_code "3 单品设 3选2 → 通过" 200 "$R2"
DB=$($MYSQL -N -B -e "select pick_rule from biz_product_subitem_group where group_id=$GRP;" 2>/dev/null)
chk_eq "库里存 PICK_2" "PICK_2" "$DB"

R5=$(curl -s -X PUT "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"groupId\":$GRP,\"pickRule\":\"PICK_5\"}")
chk_code "3 单品设 选5 → 拒（顾客永远满足不了）" 500 "$R5"
chk_msg "拒绝文案说明只有几个单品" "只有 3 个单品" "$R5"

R3=$(curl -s -X PUT "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"groupId\":$GRP,\"pickRule\":\"PICK_3\"}")
chk_code "3 单品设 3选3 → 通过" 200 "$R3"
DB3=$($MYSQL -N -B -e "select pick_rule from biz_product_subitem_group where group_id=$GRP;" 2>/dev/null)
chk_eq "3选3 归一成 ALL（同一语义不存两种值）" "ALL" "$DB3"

RBAD=$(curl -s -X PUT "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"groupId\":$GRP,\"pickRule\":\"3选2\"}")
chk_code "中文格式 3选2 → 拒（全系统统一 ALL/PICK_N）" 500 "$RBAD"

# ---------- 6) 删单品后 pickRule 自动收敛 ----------
echo "[6] 删单品后「几选几」自动收敛"
curl -s -X PUT "$H/api/product/subitem/group" -H "$AUTH" -H "$JSON" \
  -d "{\"groupId\":$GRP,\"pickRule\":\"PICK_2\"}" > /dev/null
SUBID=$($MYSQL -N -B -e "select subitem_id from biz_product_subitem where group_id=$GRP order by subitem_id desc limit 1;" 2>/dev/null)
DEL=$(curl -s -X DELETE "$H/api/product/subitem/$SUBID" -H "$AUTH")
chk_code "删单品成功" 200 "$DEL"
AFTER=$($MYSQL -N -B -e "select pick_rule from biz_product_subitem_group where group_id=$GRP;" 2>/dev/null)
chk_eq "剩 2 单品，PICK_2 收敛成 ALL" "ALL" "$AFTER"
LEFT=$($MYSQL -N -B -e "select count(*) from biz_product_subitem where group_id=$GRP;" 2>/dev/null)
chk_eq "剩余单品数" 2 "$LEFT"

# ---------- 7) 详情端点带出 subitemGroups（顾客端下单页要用） ----------
echo "[7] 商品详情带出 subitemGroups"
DET=$(curl -s -H "$AUTH" "$H/api/product/$PID")
DG=$(echo "$DET" | python3 -c '
import sys,json
d=json.load(sys.stdin); print(len(d.get("subitemGroups") or []))')
chk_eq "详情返 1 个分组" 1 "$DG"

# ---------- 8) 子品列表端点 + DELETE 幂等 ----------
echo "[8] 子品列表 + DELETE 幂等"
LST=$(curl -s -H "$AUTH" "$H/api/product/subitem/list?groupId=$GRP")
chk_code "按 groupId 读子品" 200 "$LST"

D1=$(curl -s -X DELETE "$H/api/product/subitem/group/$GRP" -H "$AUTH")
chk_code "删分组" 200 "$D1"
D2=$(curl -s -X DELETE "$H/api/product/subitem/group/$GRP" -H "$AUTH")
chk_code "重复删分组仍 200（DELETE 必须幂等）" 200 "$D2"

echo ""
echo "=== 结果：PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
