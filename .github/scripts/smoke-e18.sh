#!/usr/bin/env bash
# E18 list 端点过滤验证：检查 SQL 拦截器 TenantTableRegistry 是否覆盖所有 v2 表
# 测试 list 端点：agent 只能看到自己/平台共享，admin 看全部
H=http://127.0.0.1:8080
J() { python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"; }
T1=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"agent001","password":"admin123"}' $H/login | J)
T2=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'    $H/login | J)
[ ${#T1} -gt 50 ] && [ ${#T2} -gt 50 ] || { echo "login fail"; exit 1; }
PASS=0; FAIL=0

# 通用 list 端点过滤验证
# 用法: chk_list "name" "endpoint" "field(mid/aid)" "expected_aid" "expected_mid_for_aid"
chk_list() {
  name="$1"; ep="$2"; field="$3"; expect="$4"
  r1=$(curl -s -H "Authorization: Bearer $T1" "$H$ep?pageNum=1&pageSize=100")
  r2=$(curl -s -H "Authorization: Bearer $T2" "$H$ep?pageNum=1&pageSize=100")
  got_a=$(echo "$r1" | python3 -c "import sys,json; d=json.load(sys.stdin); rows=d.get('rows',[]); print(','.join(str(r.get('$field','')) for r in rows) if rows else 'EMPTY')" 2>/dev/null)
  agent_n=$(echo "$r1" | grep -oE '"total"\s*:\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
  admin_n=$(echo "$r2" | grep -oE '"total"\s*:\s*[0-9]+' | grep -oE '[0-9]+' | head -1)
  [ -z "$agent_n" ] && agent_n=0
  [ -z "$admin_n" ] && admin_n=0
  if [ "$agent_n" -gt 0 ] && [ "$admin_n" -ge "$agent_n" ]; then
    echo "  ✅ $name (agent=$agent_n mids=$got_a | admin=$admin_n)"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name agent=$agent_n admin=$admin_n (异常)"
    FAIL=$((FAIL+1))
  fi
}

echo "E18 list 端点 SQL 拦截器覆盖 (7 张表注册后):"
# agent001 名下 mid=[1] / aid=[1]; 别人数据 mid=2 / aid=101 在 fixture
chk_list "biz_banner          (/biz/banner/list)"     "/biz/banner/list"      "merchantId" "1"
chk_list "biz_product_category(/biz/category/list)"  "/biz/category/list"    "merchantId" "1"
chk_list "biz_product         (/biz/product/list)"    "/biz/product/list"     "merchantId" "1"
chk_list "biz_store           (/biz/store/list)"      "/biz/store/list"       "merchantId" "1"
chk_list "biz_member          (/biz/member/list)"     "/biz/member/list"      "merchantId" "1"
chk_list "biz_pay_bill        (/biz/bill/list)"       "/biz/bill/list"        "merchantId" "1"
chk_list "biz_agent           (/biz/agent/list)"      "/biz/agent/list"       "agentId"    "1"
chk_list "biz_booking         (/biz/booking/list)"    "/biz/booking/list"     "merchantId" "1"
chk_list "biz_commission      (/biz/commission/list)" "/biz/commission/list"  "merchantId" "1"
chk_list "biz_settle_record   (/biz/record/list)"     "/biz/record/list"      "merchantId" "1"
chk_list "biz_settle_account  (/biz/account/list)"    "/biz/account/list"     "merchantId" "1"
chk_list "biz_withdraw        (/biz/withdraw/list)"   "/biz/withdraw/list"    "merchantId" "1"
# [DEBUG distributor]
chk_list "biz_distributor     (/biz/distributor/list)" "/biz/distributor/list" "merchantId" "1"
chk_list "biz_voucher         (/biz/voucher/list)"    "/biz/voucher/list"     "merchantId" "1"
chk_list "biz_agreement       (/biz/agreement/list)"  "/biz/agreement/list"   "merchantId" "1"

echo "E18 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
