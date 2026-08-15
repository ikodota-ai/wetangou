#!/usr/bin/env bash
# V5-11 推客身份校验 smoke（v2.5 P2 · 3 层身份模型）
# 第一身份: 会员 (openid 存在)
# 第二身份: 推客 (biz_distributor 命中)
# 第三身份: 员工 (sys_user + biz_merchant_staff)
# 期望:
#   - 员工没绑 openid: /center 403 "仅会员可访问"
#   - 员工绑 openid + 有推客: /center 200
#   - 平台/代理商: 403 "仅会员可访问"（推客是 C 端场景）
#   - 未登录: 401
#   - /join: @Anonymous 放行（即使不是会员也能申请加入）
set -u
H=http://127.0.0.1:8080
PASS=0; FAIL=0

login() {
    curl -s -X POST $H/api/merchant/staff/login \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

check() {
    local label="$1" expected_code="$2" body="$3"
    local got
    got=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code'))" 2>/dev/null)
    if [ "$got" = "$expected_code" ]; then
        echo "  ✅ $label  (body.code=$got)"
        PASS=$((PASS+1))
    else
        echo "  ❌ $label  expect=$expected_code got=$got body=$body"
        FAIL=$((FAIL+1))
    fi
}

TK_STAFF=$(login staff_c43)
TK_OWNER=$(login owner_c43)
TK_PLATFORM=$(login platform_c43)
TK_AGENT=$(login agent_c43)
echo "tokens: staff=${#TK_STAFF} owner=${#TK_OWNER} platform=${#TK_PLATFORM} agent=${#TK_AGENT}"

# 看 staff_c43 openid 是否已绑（依赖前置 SQL 注入）
echo ""
echo "--- 第一身份校验（openid 必须有）---"
# staff_c43 已通过 smoke 前置 SQL 绑了 openid=oTest_distributor_001 + 推客 999901
# 如果 openid 没绑，期望 403
OPENID=$(curl -s $H/api/merchant/staff/me -H "Authorization: Bearer $TK_STAFF" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('openid') or '')")
echo "  staff_c43 openid='$OPENID'"
if [ -n "$OPENID" ] && [ "$OPENID" != "None" ]; then
    # 已绑 → 第二身份命中
    check "[staff_c43] 已绑 openid /center 200" 200 "$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_STAFF")"
else
    # 未绑 → 拦截
    check "[staff_c43] 未绑 openid /center 403" 403 "$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_STAFF")"
fi

echo ""
echo "--- 第二身份校验（推客记录）---"
# staff_c43 通过 openid 反查命中推客 → /center 200
# 如果 SQL 没注入推客，期望 403
CENTER=$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_STAFF")
CENTER_DID=$(echo "$CENTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('distributorId',''))" 2>/dev/null)
if [ -n "$CENTER_DID" ] && [ "$CENTER_DID" != "None" ]; then
    echo "  ✅ [staff_c43] 推客记录命中 distributorId=$CENTER_DID"
    PASS=$((PASS+1))
else
    echo "  ⚠️  [staff_c43] 推客记录未命中（请先执行 SQL 注入脚本注入推客身份）"
    echo "  body=$CENTER"
fi

echo ""
echo "--- 平台/代理商 token → /center (应 403 仅会员) ---"
check "[platform_c43] /center 403" 403 "$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_PLATFORM")"
check "[agent_c43] /center 403"    403 "$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_AGENT")"

echo ""
echo "--- owner_c43 没绑 openid → /center 403 ---"
check "[owner_c43] /center 403" 403 "$(curl -s $H/api/distributor/center -H "Authorization: Bearer $TK_OWNER")"

echo ""
echo "--- /join @Anonymous 放行 ---"
check "[staff_c43] /join 200 (申请加入推客)" 200 "$(curl -s -X POST $H/api/distributor/join -H "Authorization: Bearer $TK_STAFF" -H "Content-Type: application/json" -d '{}')"
check "[未登录] /join 401" 401 "$(curl -s -X POST $H/api/distributor/join -H "Content-Type: application/json" -d '{}')"

echo ""
echo "--- 未登录 → /center 401 ---"
check "[未登录] /center 401" 401 "$(curl -s $H/api/distributor/center)"

echo ""
echo "C49 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "💥 HAS FAIL"
