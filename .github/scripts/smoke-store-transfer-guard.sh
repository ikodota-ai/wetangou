#!/usr/bin/env bash
# 门店换商户后产生的跨商户脏数据，以及它如何伪装成「老板建不了商品」
#
# 真实事故：运营在后台把某门店的「所属商户」从 A 改到 B。biz_store.merchant_id 变了，
# 但指向这家门店的 biz_merchant_staff（员工在职关联）里那份 merchant_id 没跟着动 ——
# 两张表之间既没有外键也没有联动。于是员工关联变成「声明属于商户 A，指向的门店却已属于
# 商户 B」的脏数据。
#
# 关键在于**报错指错方向**：登录时只按 user_id 取 store_id、从不回查门店真实归属，
# 脏 storeId 被原封不动写进 token；商家端「适用门店」照常把它列出来；商家勾上保存，
# 才在 ProductServiceImpl.assertStoresBelongToMerchant 抛
# 「门店 X 不属于该商家，不能作为本商品的适用门店」。
# 现象是「连老板账号都建不了商品」，而病根在几天前那次门店换商户，中间零提示。
#
# 本脚本守住三件事：
#   A. 登录时脏门店必须被剔出 storeIds，且留下能指向根因的 error 日志
#   B. 门店身上还挂着在职员工/商品时，禁止转移归属（转移前先清理关联）
#   C. biz_store.merchant_id 必须真的可更新 —— 原先 updateStore 的 set 里没这一列，
#      后台改「所属商户」返回「操作成功」而库里纹丝不动（哑操作），
#      导致 StoreController.edit 里那两道 assertDataScope 一直在空转
set -u
BASE="${BASE:-http://localhost:8080}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
DB="${DB:-ry-vue}"
MYSQL_ARGS="-uroot -p133301 --default-character-set=utf8mb4 -N -B $DB"

APP_M1="wx9e147c4e2151b123"
OWNER_USER="owner_c43"                # user_id=59，biz_merchant_staff 声明 merchant_id=1 / store_id=100
OWNER_PWD="admin123"
STORE_DIRTY=100                       # 属商户 1，且挂着在职员工 + 商品
MERCHANT_OTHER=200
TMP_STORE=999911                      # 本脚本自建的干净门店（无员工无商品）

PASS=0; FAIL=0
ck() {
  local name="$1" got="$2" exp="$3"
  if [ "$got" = "$exp" ]; then echo "PASS | $name"; PASS=$((PASS+1));
  else echo "FAIL | $name | got=[$got] exp=[$exp]"; FAIL=$((FAIL+1)); fi
}
ckc() {  # 包含匹配
  local name="$1" got="$2" needle="$3"
  case "$got" in
    *"$needle"*) echo "PASS | $name"; PASS=$((PASS+1));;
    *) echo "FAIL | $name | got=[$got] want-contains=[$needle]"; FAIL=$((FAIL+1));;
  esac
}
q() { $MYSQL $MYSQL_ARGS -e "$1" 2>/dev/null | grep -v Warning; }
jget() { python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit()
for k in '$1'.split('.'):
    if isinstance(d,dict): d=d.get(k)
    else: d=None
if isinstance(d,bool): d=str(d).lower()
print('' if d is None else d)"; }

cleanup() {
  # 门店归属复原（脏数据是本脚本造的，绝不能留）
  q "update biz_store set merchant_id=1 where store_id=$STORE_DIRTY;" >/dev/null
  q "delete from biz_product_ext where product_id in (select product_id from biz_product where product_name like 'SMOKE_TRANSFER_%');" >/dev/null
  q "delete from biz_product where product_name like 'SMOKE_TRANSFER_%';" >/dev/null
  q "delete from biz_store where store_id=$TMP_STORE;" >/dev/null
  redis-cli DEL "merchant:appid:$APP_M1" merchant:id:1 merchant:id:$MERCHANT_OTHER >/dev/null 2>&1
  echo "--- cleanup done"
}
trap cleanup EXIT

login_owner() {  # 回显 token；副作用：把登录响应存到 /tmp/_st_login.json
  curl -s -X POST "$BASE/api/merchant/staff/login" \
    -H 'Content-Type: application/json' -H "X-App-Id: $APP_M1" \
    -d "{\"username\":\"$OWNER_USER\",\"password\":\"$OWNER_PWD\",\"appid\":\"$APP_M1\"}" \
    > /tmp/_st_login.json
  jget token < /tmp/_st_login.json
}

echo "=== 门店转移守护 ($BASE) ==="

# ---------- 前置：确认基线是干净的 ----------
ck "前置：门店 $STORE_DIRTY 属于商户 1" "$(q "select merchant_id from biz_store where store_id=$STORE_DIRTY")" "1"

# ---------- A. 登录侧：脏门店必须被剔除 ----------
TK="$(login_owner)"
ck "A1 正常态老板登录成功"          "$(jget code < /tmp/_st_login.json)"       "200"
ck "A2 正常态 storeIds 含门店"      "$(jget storeId < /tmp/_st_login.json)"    "$STORE_DIRTY"

# 直接改库制造脏数据（模拟历史遗留：绕过 controller 或在拦截上线前就已改坏）
q "update biz_store set merchant_id=$MERCHANT_OTHER where store_id=$STORE_DIRTY;" >/dev/null
redis-cli DEL "merchant:appid:$APP_M1" merchant:id:1 merchant:id:$MERCHANT_OTHER >/dev/null 2>&1
ck "A3 已制造脏数据（门店转到 $MERCHANT_OTHER）" "$(q "select merchant_id from biz_store where store_id=$STORE_DIRTY")" "$MERCHANT_OTHER"

TK_DIRTY="$(login_owner)"
ck "A4 脏数据下登录仍成功（不阻断登录）" "$(jget code < /tmp/_st_login.json)" "200"
# 关键断言：脏门店不能出现在 storeIds 里。断言的是「具体那个门店 id 没了」，
# 不是「数组长度变了」—— 后者在多店场景下会被别的门店顶掉而假绿。
DIRTY_IN=$(python3 -c "
import json
d=json.load(open('/tmp/_st_login.json'))
print('yes' if $STORE_DIRTY in (d.get('storeIds') or []) else 'no')")
ck "A5 脏门店已被剔出 storeIds"     "$DIRTY_IN" "no"
ck "A6 剔除后 storeId 不再指向脏门店" "$(jget storeId < /tmp/_st_login.json)" ""

# 建品必须给出「未绑定门店」这类真实状态，而不是让商家勾一个注定失败的门店
ADD_DIRTY=$(curl -s -X POST "$BASE/api/product/add" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TK_DIRTY" -H "X-App-Id: $APP_M1" \
  -d "{\"storeIds\":\"$STORE_DIRTY\",\"typeCode\":\"GROUPON\",\"productName\":\"SMOKE_TRANSFER_脏门店\",\"price\":1,\"stock\":5,\"maxPerOrder\":1,\"validityDays\":30,\"status\":\"1\",\"delFlag\":\"0\"}")
# 前端已拿不到这个门店；就算手搓请求也必须被 service 层门店归属校验拦住
ckc "A7 手搓脏门店建品仍被拦" "$(echo "$ADD_DIRTY" | jget msg)" "不属于该商家"

# 复原
q "update biz_store set merchant_id=1 where store_id=$STORE_DIRTY;" >/dev/null
redis-cli DEL "merchant:appid:$APP_M1" merchant:id:1 merchant:id:$MERCHANT_OTHER >/dev/null 2>&1
TK_OK="$(login_owner)"
ck "A8 数据修正后 storeIds 恢复"    "$(jget storeId < /tmp/_st_login.json)"    "$STORE_DIRTY"
ADD_OK=$(curl -s -X POST "$BASE/api/product/add" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TK_OK" -H "X-App-Id: $APP_M1" \
  -d "{\"storeIds\":\"$STORE_DIRTY\",\"typeCode\":\"GROUPON\",\"productName\":\"SMOKE_TRANSFER_正常\",\"price\":1,\"stock\":5,\"maxPerOrder\":1,\"validityDays\":30,\"status\":\"1\",\"delFlag\":\"0\"}")
ck "A9 修正后老板建品成功"          "$(echo "$ADD_OK" | jget code)"            "200"

# ---------- B/C. 后台门店转移 ----------
PT=$(curl -s -X POST "$BASE/login" -H 'Content-Type: application/json' \
     -d '{"username":"admin","password":"admin123"}' | jget token)
if [ -z "$PT" ]; then echo "FAIL | 平台账号登录失败，B/C 段跳过"; FAIL=$((FAIL+1));
else
  # B. 挂着在职员工/商品的门店禁止转移
  EDIT_DIRTY=$(curl -s -X PUT "$BASE/biz/store" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $PT" \
    -d "{\"storeId\":$STORE_DIRTY,\"merchantId\":$MERCHANT_OTHER,\"storeName\":\"洞天团购·旗舰店\"}")
  ckc "B1 有员工/商品的门店禁止转移" "$(echo "$EDIT_DIRTY" | jget msg)" "不能转到其他商户"
  ckc "B2 拦截提示点明在职员工"      "$(echo "$EDIT_DIRTY" | jget msg)" "在职员工"
  ckc "B3 拦截提示点明商品"          "$(echo "$EDIT_DIRTY" | jget msg)" "适用门店"
  ck  "B4 被拦后库里归属未变"        "$(q "select merchant_id from biz_store where store_id=$STORE_DIRTY")" "1"

  # 普通编辑（不改归属）不能被误伤
  EDIT_PLAIN=$(curl -s -X PUT "$BASE/biz/store" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $PT" \
    -d "{\"storeId\":$STORE_DIRTY,\"merchantId\":1,\"storeName\":\"洞天团购·旗舰店\",\"intro\":\"SMOKE_TRANSFER_plain\"}")
  ck "B5 不改归属的普通编辑放行"     "$(echo "$EDIT_PLAIN" | jget code)" "200"

  # C. 干净门店可以转移，且必须真的落库（防 updateStore 漏 merchant_id 的哑操作复发）
  q "insert into biz_store(store_id,merchant_id,store_name,status,del_flag,create_time) values ($TMP_STORE,1,'SMOKE_TRANSFER_干净门店','0','0',now());" >/dev/null
  EDIT_CLEAN=$(curl -s -X PUT "$BASE/biz/store" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $PT" \
    -d "{\"storeId\":$TMP_STORE,\"merchantId\":$MERCHANT_OTHER,\"storeName\":\"SMOKE_TRANSFER_干净门店\"}")
  ck "C1 干净门店转移接口返成功"     "$(echo "$EDIT_CLEAN" | jget code)" "200"
  ck "C2 干净门店转移真的落库"       "$(q "select merchant_id from biz_store where store_id=$TMP_STORE")" "$MERCHANT_OTHER"
fi

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
