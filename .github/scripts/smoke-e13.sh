#!/usr/bin/env bash
# E13 smoke: OrderController 越权显式 guard
#   1) agent001 -> 999001 (merchantId=2, 别人) -> 500 没有权限
#   2) agent001 -> 999002 (merchantId=1, 自己) -> 200 + data
#   3) agent001 -> 999999 (不存在)           -> 200 + null
#   4) admin    -> 999001 (平台放行)         -> 200 + data
#   5) no auth  -> 401
set -e
H=http://127.0.0.1:8080
J() { python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"; }
T1=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"agent001","password":"admin123"}' $H/login | J)
T2=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'    $H/login | J)
[ ${#T1} -gt 50 ] && [ ${#T2} -gt 50 ] || { echo "login fail"; exit 1; }
PASS=0; FAIL=0
chk() {
  local name="$1" expect_code="$2" expect_msg="$3" got_code="$4" got_msg="$5"
  if [ "$got_code" = "$expect_code" ] && [[ "$got_msg" == *"$expect_msg"* ]]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (want code=$expect_code msg~$expect_msg, got code=$got_code msg=$got_msg)"
    FAIL=$((FAIL+1))
  fi
}
P() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code',''), d.get('msg',''))"; }
R1=$(curl -s -H "Authorization: Bearer $T1" $H/biz/order/999001 | P)
R2=$(curl -s -H "Authorization: Bearer $T1" $H/biz/order/999002 | P)
R3=$(curl -s -H "Authorization: Bearer $T1" $H/biz/order/999999 | P)
R4=$(curl -s -H "Authorization: Bearer $T2" $H/biz/order/999001 | P)
R5=$(curl -s -o /dev/null -w "%{http_code}" $H/biz/order/999001)
echo "E13 OrderController 越权显式 guard:"
chk "1) agent001 -> 别人 999001 拒访"   500  "没有权限"  $R1
chk "2) agent001 -> 自己 999002 放行"   200  "操作成功"  $R2
chk "3) agent001 -> 不存在 999999 200"  200  "操作成功"  $R3
chk "4) admin    -> 任何 order 放行"    200  "操作成功"  $R4
[ "$R5" = "401" ] && { echo "  ✅ 5) no auth -> 401"; PASS=$((PASS+1)); } || { echo "  ❌ 5) no auth want 401 got $R5"; FAIL=$((FAIL+1)); }
echo "E13 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
