#!/usr/bin/env bash
# E17 P3 smoke: 3 controller 越权 guard
#   - Agreement / MpRelease → assertDataScope (merchantId) OK
#   - MpAuth: agent 缺 biz:mpauth:query perms (pre-existing 403), 只测 admin bypass

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
echo "E17 P3 batch (2 verified + 1 pre-existing perms bug):"
# 2 个 assertDataScope + admin bypass
for spec in "Agreement|agreement" "MpRelease|mprelease"; do
  IFS='|' read -r c p <<< "$spec"
  chk "$c agent001 -> 别人 999401" 500 "没有权限" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/999401 | P)"
  chk "$c agent001 -> 自己 999402" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/999402 | P)"
  chk "$c admin    -> 别人 999401" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T2" $H/biz/$p/999401 | P)"
done
# MpAuth: agent 已有 biz:mpauth:query perms (F2 grant), 完整 agent 测
c="MpAuth"; p="mpauth"
chk "$c agent001 -> 别人 999401" 500 "没有权限" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/999401 | P)"
chk "$c agent001 -> 自己 999402" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T1" $H/biz/$p/999402 | P)"
chk "$c admin    -> 别人 999401" 200 "操作成功" "$(curl -s -H "Authorization: Bearer $T2" $H/biz/$p/999401 | P)"
echo "E17 result: PASS=$PASS FAIL=$FAIL (3 controller 全 verified)"
[ $FAIL -eq 0 ] || exit 1
