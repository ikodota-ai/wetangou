#!/usr/bin/env bash
# E15 P1 smoke: 6 controller 越权 guard
#   - Member / Distributor / MerchantFee / Commission / CommissionRule → assertDataScope (merchantId)
#   - AgentFee → assertAgentDataScope (agentId)

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_load_e13_e17_fixture

set -e
H=http://127.0.0.1:8080
J() { python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"; }
T1=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"agent001","password":"admin123"}' $H/login | J)
T2=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'    $H/login | J)
[ ${#T1} -gt 50 ] && [ ${#T2} -gt 50 ] || { echo "login fail"; exit 1; }
PASS=0; FAIL=0
chk() {
  local name="$1" expect_code="$2" expect_msg="$3" got="$4"
  local gc gm
  gc=$(echo "$got" | awk '{print $1}')
  gm=$(echo "$got" | cut -d' ' -f2-)
  if [ "$gc" = "$expect_code" ] && [[ "$gm" == *"$expect_msg"* ]]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (want code=$expect_code msg~$expect_msg, got code=$gc msg=$gm)"
    FAIL=$((FAIL+1))
  fi
}
P() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code',''), d.get('msg',''))"; }
echo "E15 P1 batch (6 controllers: Member/Distributor/MerchantFee/Commission/CommissionRule/AgentFee):"
# 5 个用 assertDataScope (mid)
for spec in "Member|member|999201|999202" "Distributor|distributor|999201|999202" "MerchantFee|merchantfee|999201|999202" "Commission|commission|999201|999202" "CommissionRule|rule|999201|999202"; do
  IFS='|' read -r c p other self <<< "$spec"
  chk "$c agent001 -> 别人 $other" 500 "没有权限" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/$other | P)"
  chk "$c agent001 -> 自己 $self" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/$self  | P)"
  chk "$c admin    -> 别人 $other" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T2" $H/biz/$p/$other | P)"
done
# 1 个用 assertAgentDataScope (aid)
c="AgentFee"; p="agentfee"; other=999201; self=999202
chk "$c agent001 -> 别人 $other (aid=101)" 500 "没有权限" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/$other | P)"
chk "$c agent001 -> 自己 $self (aid=1)"   200 "操作成功" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/$self  | P)"
chk "$c admin    -> 别人 $other"          200 "操作成功" "$(curl -s -H "Authorization: Bearer $T2" $H/biz/$p/$other | P)"
echo "E15 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
