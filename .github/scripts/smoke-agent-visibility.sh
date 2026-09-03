#!/usr/bin/env bash
# 商户不该看到自己的代理商 + 门店选择器必须跟随商户
#
# 背景（用户报的两件事，排查时挖出第三件更严重的）：
#
# 1) 商户能看到自己挂在哪个代理商名下。代理商是平台的渠道关系，属于商户不该
#    知道的上游信息。前端 merchant/merchantfee 两个页面的代理商列没有任何身份
#    判断；更要命的是 /biz/merchantfee/list 接口对商户账号照样吐 agentId/
#    agentName —— UI 隐藏从来不是数据权限，开个 F12 就看见了，必须服务端抹。
#
# 2) 后台「先选商家再选门店」的联动缺失。BizSelect 组件本来就支持 merchantId
#    prop，但 12 个业务页面里只有 commission 的表单真传了，其余全是各选各的；
#    staffInvite 更是把 prop 名写成了不存在的 :params，等于没传。平台账号能在
#    「全部门店」里挑一个别家的，一路填到提交才被后端以「门店不属于该商家」打回。
#
# 3) 排查时发现的真 500：biz_agent 被误登记进 TenantTableRegistry.ISOLATED_TABLES，
#    可这张表压根没有 merchant_id 列（主键 agent_id）。于是 MerchantFeeMapper 里
#    `left join biz_agent a` 被租户重写器追加 `a.merchant_id = ?`，商户账号打开
#    「商户收费」页面直接 Unknown column 'a.merchant_id' in 'on clause'。
set -u
BASE="${BASE:-http://localhost:8080}"
UI="ruoyi-ui/src"

PASS=0; FAIL=0
ck() {
  local name="$1" got="$2" exp="$3"
  if [ "$got" = "$exp" ]; then echo "PASS | $name"; PASS=$((PASS+1));
  else echo "FAIL | $name | got=[$got] exp=[$exp]"; FAIL=$((FAIL+1)); fi
}

login() {
  curl -s -X POST "$BASE/login" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$1\",\"password\":\"admin123\"}" \
  | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('token',''))
except Exception: print('')"
}

MT=$(login manager_c43)   # userType=2 商户，merchantId=1
AT=$(login admin)         # userType=0 平台
ck "商户账号登录成功"       "$([ -n "$MT" ] && echo yes || echo no)" "yes"
ck "平台账号登录成功"       "$([ -n "$AT" ] && echo yes || echo no)" "yes"

jget() { curl -s "$BASE$2" -H "Authorization: Bearer $1"; }

# --- 1. 商户收费不再 500（biz_agent 误登记为租户表的回归保护）---
FEE_M=$(jget "$MT" /biz/merchantfee/list)
ck "商户打开商户收费不 500"  "$(echo "$FEE_M" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('code',''))
except Exception: print('ERR')")" "200"

# --- 2. 接口层：商户拿不到代理商字段 ---
ck "商户看不到 agentId"      "$(echo "$FEE_M" | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    print('leaked' if any(r.get('agentId') is not None for r in rows) else 'clean')
except Exception: print('ERR')")" "clean"
ck "商户看不到 agentName"    "$(echo "$FEE_M" | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    print('leaked' if any(r.get('agentName') for r in rows) else 'clean')
except Exception: print('ERR')")" "clean"
ck "商户收费仍有数据"        "$(echo "$FEE_M" | python3 -c "import sys,json
try: print('yes' if (json.load(sys.stdin).get('rows') or []) else 'no')
except Exception: print('ERR')")" "yes"

# 平台不受影响：该看见的还得看见，否则就是把功能改没了
FEE_A=$(jget "$AT" /biz/merchantfee/list)
ck "平台仍看得到 agentName"  "$(echo "$FEE_A" | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    print('yes' if any(r.get('agentName') for r in rows) else 'no')
except Exception: print('ERR')")" "yes"

# --- 3. 门店按商户过滤：后端能力（前端联动依赖它）---
ck "平台按商户1筛门店"       "$(jget "$AT" '/biz/store/list?merchantId=1&pageSize=50' | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    mids={r.get('merchantId') for r in rows}
    print('clean' if mids=={1} else 'dirty:'+str(sorted(mids)))
except Exception: print('ERR')")" "clean"
ck "平台按商户200筛门店"     "$(jget "$AT" '/biz/store/list?merchantId=200&pageSize=50' | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    mids={r.get('merchantId') for r in rows}
    print('clean' if mids=={200} else 'dirty:'+str(sorted(mids)))
except Exception: print('ERR')")" "clean"

# 商户账号不传 merchantId 也只看得到自己的（所以不需要先选商户）
ck "商户不选商户也只见自家"  "$(jget "$MT" '/biz/store/list?pageSize=50' | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('rows') or []
    mids={r.get('merchantId') for r in rows}
    print('clean' if mids=={1} else 'dirty:'+str(sorted(mids)))
except Exception: print('ERR')")" "clean"
ck "商户越权传别家被拒"      "$(jget "$MT" '/biz/store/list?merchantId=200' | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('code',''))
except Exception: print('ERR')")" "500"

# --- 4. 源码约束：biz_agent 不得再被登记为租户表 ---
TTR="ruoyi-framework/src/main/java/com/ruoyi/framework/tenant/TenantTableRegistry.java"
ck "biz_agent 不在隔离表"    "$(python3 - "$TTR" <<'PY'
import io,sys,re
s=io.open(sys.argv[1],encoding='utf-8').read()
m=re.search(r'ISOLATED_TABLES\s*=.*?\)\)\);', s, re.S)
print('bad' if m and 'biz_agent' in m.group(0) else 'ok')
PY
)" "ok"

# --- 5. 源码约束：门店选择器必须联动商户 ---
# 按 biz-select 标签整体匹配：product/create.vue 的属性分多行写，逐行 grep 会误判
BAD=$(python3 .github/scripts/lib/check-store-select.py "$UI/views/biz" 2>/dev/null)
ck "无脱离商户的门店选择器"  "$BAD" "0"
ck "staffInvite 不再用错 prop" "$(grep -q ':params="{ merchantId' "$UI/views/biz/staffInvite/index.vue" && echo bad || echo ok)" "ok"
ck "BizSelect 支持 requireMerchant" "$(grep -q 'requireMerchant' "$UI/components/BizSelect/index.vue" && echo yes || echo no)" "yes"

# --- 6. 源码约束：商户身份不该被「先选商户」卡住 ---
# 表单里的商户项一律 v-if="showMerchantFilter"，商户账号看不到也就不用选，
# merchantId 由 currentMerchantId() 直接钉成自己的。
for f in bill category agreement user voucher album rule booking staffInvite; do
  P="$UI/views/biz/$f/index.vue"
  ck "$f 表单商户项对商户隐藏" "$(grep -cE 'label="(所属商户|商户)" prop="merchantId" v-if="showMerchantFilter"' "$P" | awk '{print ($1>0)?"yes":"no"}')" "yes"
  ck "$f 钉住自身商户"         "$(grep -q 'identityMerchantId()' "$P" && echo yes || echo no)" "yes"
done

# 读错的 vuex 路径必须绝迹（state.user 下没有嵌套 user 对象，恒为 undefined）
ck "无 state.user.user.merchantId" "$(grep -rn 'state.user.user.merchantId' "$UI" --include='*.vue' | wc -l | tr -d ' ')" "0"

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
