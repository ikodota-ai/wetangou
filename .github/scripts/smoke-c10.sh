#!/usr/bin/env bash
# C10 voucher 列表 / 搜索 / 我的券 smoke
# 验证:
#   A) admin GET /biz/voucher/list 分页
#   B) admin GET /biz/voucher/list?voucherName=... 模糊搜索
#   C) admin GET /biz/voucher/list?storeId=... 按门店过滤
#   D) 小程序 GET /api/voucher/list 仅 status=0
#   E) 小程序按 voucherName 模糊（新加参数）
#   F) 小程序 GET /api/voucher/my?status=0 仅看自己的
#   G) 跨会员隔离：A 领的券不应出现在 B 的 my
#   H) 按 status 过滤：status=1 已使用 / status=2 过期
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# admin
ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#ADMIN_TOK} -gt 50 ] || { echo "FAIL: admin login"; exit 1; }

# 两个会员
JS_A="c10a_$(date +%s)_$$"
JS_B="c10b_$(date +%s)_$$"
LOGIN_A=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"code\":\"$JS_A\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c10a\"}" $H/api/auth/login)
TOK_A=$(echo "$LOGIN_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEM_A=$(echo "$LOGIN_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
LOGIN_B=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"code\":\"$JS_B\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c10b\"}" $H/api/auth/login)
TOK_B=$(echo "$LOGIN_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEM_B=$(echo "$LOGIN_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ "$MEM_A" -gt 0 ] && [ "$MEM_B" -gt 0 ] || { echo "FAIL: members login"; exit 1; }
echo "[init] A=$MEM_A B=$MEM_B"

# 3 张模板券：coupon_AAA / coupon_BBB / coupon_CCC
VA=$($DB_CMD -N -e "INSERT INTO biz_voucher (merchant_id, store_id, voucher_name, face_value, threshold, total, received, valid_days, status, create_time) VALUES (1, 200, 'coupon_AAA_c10', 20.00, 100.00, 100, 0, 30, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
VB=$($DB_CMD -N -e "INSERT INTO biz_voucher (merchant_id, store_id, voucher_name, face_value, threshold, total, received, valid_days, status, create_time) VALUES (1, 200, 'coupon_BBB_c10', 50.00, 200.00, 100, 0, 30, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
VC=$($DB_CMD -N -e "INSERT INTO biz_voucher (merchant_id, store_id, voucher_name, face_value, threshold, total, received, valid_days, status, create_time) VALUES (1, 201, 'coupon_CCC_c10', 30.00, 150.00, 100, 0, 30, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
# 一张已停用的，不应被小程序列出
VD=$($DB_CMD -N -e "INSERT INTO biz_voucher (merchant_id, store_id, voucher_name, face_value, threshold, total, received, valid_days, status, create_time) VALUES (1, 200, 'coupon_DISABLED_c10', 10.00, 50.00, 100, 0, 30, '1', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "[init] VA=$VA VB=$VB VC=$VC VD=$VD(disabled)"

MVA=0; MVB=0; MVC=0
cleanup() {
  [ "$MVA" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member_voucher WHERE id=$MVA;" 2>/dev/null || true
  [ "$MVB" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member_voucher WHERE id=$MVB;" 2>/dev/null || true
  [ "$MVC" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member_voucher WHERE id=$MVC;" 2>/dev/null || true
  [ "$VA" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_voucher WHERE voucher_id=$VA;" 2>/dev/null || true
  [ "$VB" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_voucher WHERE voucher_id=$VB;" 2>/dev/null || true
  [ "$VC" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_voucher WHERE voucher_id=$VC;" 2>/dev/null || true
  [ "$VD" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_voucher WHERE voucher_id=$VD;" 2>/dev/null || true
  $DB_CMD -e "DELETE FROM biz_member WHERE member_id IN ($MEM_A, $MEM_B);" 2>/dev/null || true
}
trap cleanup EXIT

echo "C10 voucher 列表/搜索/我的券 smoke:"

# A) admin 全量分页
LIST_A=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/voucher/list?pageNum=1&pageSize=100")
chk "A admin 全量列表 (rows 包含 coupon_AAA_c10)" "coupon_AAA_c10" "$LIST_A"
chk "A admin 全量列表 (rows 包含 coupon_BBB_c10)" "coupon_BBB_c10" "$LIST_A"
chk "A admin 全量列表 (rows 包含 coupon_CCC_c10)" "coupon_CCC_c10" "$LIST_A"

# B) admin 按 voucherName 模糊搜索
LIST_B=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/voucher/list?voucherName=coupon_BBB&pageNum=1&pageSize=100")
chk "B 搜索 coupon_BBB 命中" "coupon_BBB_c10" "$LIST_B"
echo "$LIST_B" | grep -q "coupon_AAA_c10" && { echo "  ❌ B 搜索 coupon_BBB 不应命中 coupon_AAA_c10"; FAIL=$((FAIL+1)); } || { echo "  ✅ B 搜索 coupon_BBB 排除其他"; PASS=$((PASS+1)); }

# C) admin 按 storeId 过滤
LIST_C=$(curl -s -H "Authorization: Bearer $ADMIN_TOK" "$H/biz/voucher/list?storeId=201&pageNum=1&pageSize=100")
chk "C storeId=201 命中 coupon_CCC_c10" "coupon_CCC_c10" "$LIST_C"
echo "$LIST_C" | grep -q "coupon_AAA_c10" && { echo "  ❌ C storeId=201 不应命中 coupon_AAA_c10 (store=200)"; FAIL=$((FAIL+1)); } || { echo "  ✅ C storeId=201 隔离"; PASS=$((PASS+1)); }

# D) 小程序可领列表：仅 status=0
LIST_D=$(curl -s "$H/api/voucher/list?storeId=200")
chk "D 小程序 storeId=200 命中 coupon_AAA_c10" "coupon_AAA_c10" "$LIST_D"
echo "$LIST_D" | grep -q "coupon_DISABLED_c10" && { echo "  ❌ D 已停用券不应被小程序列出"; FAIL=$((FAIL+1)); } || { echo "  ✅ D 排除已停用券"; PASS=$((PASS+1)); }

# E) 小程序按 voucherName 搜索
LIST_E=$(curl -s "$H/api/voucher/list?storeId=200&voucherName=coupon_BBB")
chk "E 小程序搜索 coupon_BBB 命中" "coupon_BBB_c10" "$LIST_E"
echo "$LIST_E" | grep -q "coupon_AAA_c10" && { echo "  ❌ E 搜索不应命中 coupon_AAA_c10"; FAIL=$((FAIL+1)); } || { echo "  ✅ E 小程序搜索隔离"; PASS=$((PASS+1)); }

# F) 领取：A 领 AAA，B 领 BBB
RCV_A=$(curl -s -X POST -H "Authorization: Bearer $TOK_A" "$H/api/voucher/receive/$VA")
MVA=$(echo "$RCV_A" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('id',0))" 2>/dev/null)
[ "$MVA" -gt 0 ] && echo "  ✅ F A 领取 AAA (id=$MVA)" && PASS=$((PASS+1)) || { echo "  ❌ F A 领取失败: $RCV_A"; FAIL=$((FAIL+1)); }

RCV_B=$(curl -s -X POST -H "Authorization: Bearer $TOK_B" "$H/api/voucher/receive/$VB")
MVB=$(echo "$RCV_B" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('id',0))" 2>/dev/null)
[ "$MVB" -gt 0 ] && echo "  ✅ F B 领取 BBB (id=$MVB)" && PASS=$((PASS+1)) || { echo "  ❌ F B 领取失败: $RCV_B"; FAIL=$((FAIL+1)); }

# G) 我的券：A 只能看到自己领的 AAA，不应看到 B 领的 BBB
MY_A=$(curl -s -H "Authorization: Bearer $TOK_A" "$H/api/voucher/my?status=0")
chk "G A my 看到 coupon_AAA_c10" "coupon_AAA_c10" "$MY_A"
echo "$MY_A" | grep -q "coupon_BBB_c10" && { echo "  ❌ G A my 不应看到 B 领的 coupon_BBB_c10"; FAIL=$((FAIL+1)); } || { echo "  ✅ G A my 隔离 B 的券"; PASS=$((PASS+1)); }

MY_B=$(curl -s -H "Authorization: Bearer $TOK_B" "$H/api/voucher/my?status=0")
chk "G B my 看到 coupon_BBB_c10" "coupon_BBB_c10" "$MY_B"
echo "$MY_B" | grep -q "coupon_AAA_c10" && { echo "  ❌ G B my 不应看到 A 领的 coupon_AAA_c10"; FAIL=$((FAIL+1)); } || { echo "  ✅ G B my 隔离 A 的券"; PASS=$((PASS+1)); }

# H) 按 status 过滤：A 把 MVA 标为 status=1（已使用），再查 my?status=0 应看不到
$DB_CMD -e "UPDATE biz_member_voucher SET status='1', use_time=NOW() WHERE id=$MVA;" 2>/dev/null
MY_A_USED=$(curl -s -H "Authorization: Bearer $TOK_A" "$H/api/voucher/my?status=0")
echo "$MY_A_USED" | grep -q "coupon_AAA_c10" && { echo "  ❌ H status=0 不应看到已使用券"; FAIL=$((FAIL+1)); } || { echo "  ✅ H status=0 排除已使用"; PASS=$((PASS+1)); }
MY_A_USED_VIEW=$(curl -s -H "Authorization: Bearer $TOK_A" "$H/api/voucher/my?status=1")
chk "H status=1 看到已使用券" "coupon_AAA_c10" "$MY_A_USED_VIEW"

echo ""
echo "C10 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
