#!/usr/bin/env bash
# 商家端商品创建/编辑 端到端烟测
#
# 按小程序页面的真实交互顺序跑：
#   列表页「创建商品」→ 建品页第1步选品类/类型 → 第2步填表 → 保存草稿
#   → 回列表页（切「未上架」tab）→ 点「上架」被拦 → 点「编辑」回填 → 补齐 → 上架成功
#
# 覆盖的真实缺陷（都是本轮修的，脚本用来防回归）：
#   1. saveExtByTypeCode 丢弃小程序提交的 ext（渠道/券码类型存不进去）
#   2. add 无条件完整校验 → 草稿一条都存不下
#   3. edit 无任何校验 → 已上架商品能被改成 stock=0
#   4. /status 上架不校验 → 残缺草稿能直接上架
#   5. 编辑页 productId 回填（后端要能按 id 返回完整字段供回填）
#
# 用法：bash .github/scripts/smoke-merchant-product.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# 断言 code 等于期望值
chk_code() { # $1 desc $2 want $3 body
  local got
  got=$(echo "$3" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))' 2>/dev/null)
  [ "$got" = "$2" ] && ok "$1 (code=$got)" || bad "$1 期望 code=$2 实得 $got: $3"
}
# 断言错误信息里含某关键词（验报错是否指明了缺哪个字段）
chk_msg() { # $1 desc $2 keyword $3 body
  echo "$3" | grep -q "$2" && ok "$1" || bad "$1 未含「$2」: $3"
}

echo "=== 商家端商品创建/编辑 端到端 ($H) ==="

# ---------- 0) 店长登录 ----------
echo "[0] 店长登录"
LOGIN=$(curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
  -d '{"username":"owner_c43","password":"admin123"}')
STK=$(echo "$LOGIN" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
MID=$(echo "$LOGIN" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("merchantId",""))')
SID=$(echo "$LOGIN" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("storeId",""))')
if [ -z "$STK" ]; then echo "  ❌ 登录失败，后续跳过: $LOGIN"; exit 1; fi
ok "登录成功 merchantId=$MID storeId=$SID"
AUTH="Authorization: Bearer $STK"
JSON='Content-Type: application/json'
APPID="wx9e147c4e2151b123"   # 本地 appid → 商户 1，用于顾客态租户解析

# 收尾清理：不管中途哪步失败都把测试商品删掉
CREATED=""
cleanup() {
  [ -z "$CREATED" ] && return
  for pid in $CREATED; do
    /usr/local/mysql/bin/mysql -uroot -p133301 ry-vue -e \
      "delete from biz_product_ext where product_id=$pid; delete from biz_product where product_id=$pid;" 2>/dev/null
    echo "  [cleanup] 删除测试商品 $pid"
  done
}
trap cleanup EXIT

# ---------- 1) 建品页要读的两个字典 ----------
echo "[1] 建品页初始化：品类 + 渠道字典"
CAT=$(curl -s -H "$AUTH" "$H/api/product/category/list")
chk_code "品类列表可读" 200 "$CAT"

CH=$(curl -s "$H/biz/saleChannel/enabled")
CH_N=$(echo "$CH" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("data",[])))')
[ "$CH_N" -ge 1 ] && ok "渠道字典返 $CH_N 条" || bad "渠道字典为空（建品页投放渠道会是空弹窗）: $CH"
DEF=$(echo "$CH" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("defaultCodes",""))')
[ -n "$DEF" ] && ok "默认勾选渠道=$DEF" || bad "defaultCodes 为空（新建商品不会自动带渠道）"
# 渠道必须带 channelGroup，否则前端分组渲染会全塞进 OTHER 组
echo "$CH" | grep -q '"channelGroup"' && ok "渠道含 channelGroup（前端可分组渲染）" \
  || bad "渠道缺 channelGroup"
# 也必须带 channelDesc，这是每条渠道下方的灰字投放说明
echo "$CH" | grep -q '"channelDesc"' && ok "渠道含 channelDesc（投放规则灰字）" \
  || bad "渠道缺 channelDesc"

# ---------- 2) 保存为草稿：只填名称+价格 ----------
# 这是本轮的关键修复点。原先 add 无条件跑完整校验，商家点「保存为草稿」
# 会被「GROUPON 需填库存 stock」顶回来，草稿一条都存不下。
echo "[2] 第2步填表 → 保存为草稿（只填名称+价格，故意不填库存）"
D_BODY=$(python3 -c "import json;print(json.dumps({
  'storeIds':'$SID','typeCode':'GROUPON','productName':'SMOKE_商家端草稿',
  'price':88.00,'status':'1','delFlag':'0','productType':'0',
  'refundPolicy':'BEFORE_EXPIRE','collectMethod':'PLATFORM',
  'mutexWithStorePromotion':0,'extraFeeDesc':'包间费另算',
  'ext':{'saleChannels':'MINI_HOME,GROUP_SHARE','staffPromote':1,'codeType':'MERCHANT'}
}))")
DRAFT=$(curl -s -X POST "$H/api/product/add" -H "$AUTH" -H "$JSON" -d "$D_BODY")
chk_code "残缺草稿能存下" 200 "$DRAFT"
PID=$(echo "$DRAFT" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("productId") or 0)')
[ "$PID" -gt 0 ] && { CREATED="$CREATED $PID"; ok "拿到 productId=$PID"; } || bad "未返回 productId"
[ "$PID" -gt 0 ] || exit 1

# ---------- 3) 小程序提交的 ext 必须真落库 ----------
# 原先 saveExtByTypeCode 用 new ProductExt() 从零构造，把 body.ext 整个丢掉。
echo "[3] 小程序提交的 ext 是否落库"
# 必须带员工 token：详情端点对顾客态只放行上架商品，草稿要靠商家态才看得到。
# 不带 token 拿这条草稿会被判「商品不存在或已下架」，下面所有回填断言会连环失败。
DET=$(curl -s "$H/api/product/$PID" -H "$AUTH" -H "X-App-Id: $APPID")
# 反过来锁死顾客侧：同一条草稿顾客态必须读不到，否则未上架的定价/库存就漏出去了
CDET=$(curl -s "$H/api/product/$PID" -H "X-App-Id: $APPID")
chk_msg "顾客态读不到自家草稿" "商品不存在或已下架" "$CDET"
chk_code "商家态能读自家草稿(编辑回填)" 200 "$DET"
for kv in "saleChannels:MINI_HOME,GROUP_SHARE" "staffPromote:1" "codeType:MERCHANT"; do
  k="${kv%%:*}"; want="${kv#*:}"
  got=$(echo "$DET" | python3 -c "import sys,json;print((json.load(sys.stdin)['data'].get('ext') or {}).get('$k'))")
  [ "$got" = "$want" ] && ok "ext.$k=$got" || bad "ext.$k 期望 $want 实得 $got"
done
# 主表上的 3 个同类字段（原先也没人写）
for kv in "refundPolicy:BEFORE_EXPIRE" "mutexWithStorePromotion:0" "extraFeeDesc:包间费另算"; do
  k="${kv%%:*}"; want="${kv#*:}"
  got=$(echo "$DET" | python3 -c "import sys,json;print(json.load(sys.stdin)['data'].get('$k'))")
  [ "$got" = "$want" ] && ok "$k=$got" || bad "$k 期望 $want 实得 $got"
done

# ---------- 3b) 商家端新补的 5 组 ext 字段必须真落库 ----------
# 背景：商家端建品页原先只传 saleChannels/staffPromote/codeType 三个 ext，
# 而 PC 建品页能填的可消费日期 / 不可消费日期 / 每日时段 /
# 适用规则 / 适用范围 一个也没传 —— 商家在手机上建的券因此永远没有使用期限
# 和可用时段，顾客详情页那几行恒空。
#
# 两个格式坑必须锁住（否则 500 / 解不出来）：
#   consumeStartDate/EndDate 是 java.util.Date 且未加 @JsonFormat，只认
#     yyyy-MM-dd HH:mm:ss；小程序 <picker mode="date"> 只给 yyyy-MM-dd，必须补时分秒。
#   excludeDates 存 JSON 二级数组 [[起,止]]，顾客端 excludeDatesText 按段展，
#     平铺成 "起,止" 会直接解不出来。
echo "[3b] 5 组日期/时段/适用规则 ext 落库"
E_BODY=$(python3 -c "import json;print(json.dumps({
  'productId':$PID,
  'ext':{
    'consumeStartDate':'2026-09-10 00:00:00','consumeEndDate':'2026-12-31 23:59:59',
    'excludeDates':json.dumps([['2026-10-01','2026-10-07'],['2026-02-14','2026-02-14']]),
    'dailyTimeStart':'11:00:00','dailyTimeEnd':'14:30:00',
    'voucherRules':'ALL_CATEGORY,ALL_BRAND','voucherScopeType':'STORE'
  }
}))")
EE=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" -d "$E_BODY")
chk_code "5 组 ext 保存成功" 200 "$EE"
DET2=$(curl -s "$H/api/product/$PID" -H "$AUTH" -H "X-App-Id: $APPID")
ext(){ echo "$DET2" | python3 -c "import sys,json;v=(json.load(sys.stdin)['data'].get('ext') or {}).get('$1');print('' if v is None else v)"; }
# 日期回流带 .0 结尾（Jackson 序列化 Date），只看前 10 位日期部分
case "$(ext consumeStartDate)" in 2026-09-10*) ok "ext.consumeStartDate 落库 ($(ext consumeStartDate))";; *) bad "ext.consumeStartDate 实得 [$(ext consumeStartDate)]";; esac
case "$(ext consumeEndDate)"   in 2026-12-31*) ok "ext.consumeEndDate 落库 ($(ext consumeEndDate))";;   *) bad "ext.consumeEndDate 实得 [$(ext consumeEndDate)]";; esac
case "$(ext dailyTimeStart)"   in 11:00*)      ok "ext.dailyTimeStart 落库 ($(ext dailyTimeStart))";;    *) bad "ext.dailyTimeStart 实得 [$(ext dailyTimeStart)]";; esac
case "$(ext dailyTimeEnd)"     in 14:30*)      ok "ext.dailyTimeEnd 落库 ($(ext dailyTimeEnd))";;      *) bad "ext.dailyTimeEnd 实得 [$(ext dailyTimeEnd)]";; esac
[ "$(ext voucherRules)" = "ALL_CATEGORY,ALL_BRAND" ] && ok "ext.voucherRules 落库" || bad "ext.voucherRules 实得 [$(ext voucherRules)]"
[ "$(ext voucherScopeType)" = "STORE" ] && ok "ext.voucherScopeType 落库" || bad "ext.voucherScopeType 实得 [$(ext voucherScopeType)]"
# 二级数组的第二段不能被吞（顾客端逐段展，吞了就少一个排除区间）
case "$(ext excludeDates)" in *2026-02-14*) ok "ext.excludeDates 保留第二段";; *) bad "ext.excludeDates 实得 [$(ext excludeDates)]";; esac
# 上一次存的三个 ext 不能被这次局部更新抹掉 ——
# saveExtByTypeCode 如果又回到 new ProductExt() 从零构造，渠道就丢了。
[ "$(ext saleChannels)" = "MINI_HOME,GROUP_SHARE" ] && ok "局部更新不抹掉已有 ext.saleChannels" || bad "ext.saleChannels 被抹成 [$(ext saleChannels)]"

# ---------- 4) 草稿必须是下架态 ----------
# 商家端原先写死 status:'0' 直接上架，字段没齐就对顾客可见了。
echo "[4] 草稿状态"
ST=$(echo "$DET" | python3 -c "import sys,json;print(json.load(sys.stdin)['data'].get('status'))")
[ "$ST" = "1" ] && ok "草稿是下架态（顾客看不到）" || bad "草稿 status=$ST，应为 1"

# ---------- 5) 编辑页回填：后端要能返回全部字段 ----------
echo "[5] 点「编辑」→ 详情要能回填门店和渠道"
SIDS=$(echo "$DET" | python3 -c "import sys,json;print(json.load(sys.stdin)['data'].get('storeIds'))")
[ -n "$SIDS" ] && [ "$SIDS" != "None" ] && ok "storeIds=$SIDS（适用门店可回填）" \
  || bad "storeIds 为空，编辑页门店勾选会丢"
TC=$(echo "$DET" | python3 -c "import sys,json;print(json.load(sys.stdin)['data'].get('typeCode'))")
[ "$TC" = "GROUPON" ] && ok "typeCode 可回填" || bad "typeCode=$TC"

# ---------- 6) 残缺草稿上架必须被拦，且要说清缺什么 ----------
# 原先 /api/product/status 只查 status 取值和商户归属，残缺草稿直接就上架了。
echo "[6] 列表页点「上架」（库存还没填）"
UP1=$(curl -s -X PUT "$H/api/product/status" -H "$AUTH" -H "$JSON" -d "{\"productId\":$PID,\"status\":\"0\"}")
chk_code "残缺草稿上架被拦" 500 "$UP1"
chk_msg "报错指明缺库存（而不是笼统的操作失败）" "stock" "$UP1"

# ---------- 7) 局部编辑补齐 ----------
echo "[7] 编辑页补齐库存/有效期"
ED=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" \
  -d "{\"productId\":$PID,\"stock\":20,\"validityDays\":30,\"maxPerOrder\":2}")
chk_code "补齐字段保存成功" 200 "$ED"

# ---------- 8) 上架成功 ----------
echo "[8] 再点「上架」"
UP2=$(curl -s -X PUT "$H/api/product/status" -H "$AUTH" -H "$JSON" -d "{\"productId\":$PID,\"status\":\"0\"}")
chk_code "补齐后可上架" 200 "$UP2"

# ---------- 9) 已上架商品不能被改成非法值 ----------
# 原先商家端 edit 一个校验都没有，能把已上架商品的库存/售价改成 0，
# 商品仍对顾客可见但点进详情下单必然失败。
echo "[9] 已上架商品的编辑防护"
B1=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" -d "{\"productId\":$PID,\"stock\":0}")
chk_code "把库存改成 0 被拦" 500 "$B1"
B2=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" -d "{\"productId\":$PID,\"price\":-1}")
chk_code "把售价改成负数被拦" 500 "$B2"
# 反方向：合法的局部改必须放过。校验对象是「合并后的那一行」而不是请求体，
# 否则只改 notice 的请求会因为没带 typeCode 被误判成「类型不能为空」。
B3=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" -d "{\"productId\":$PID,\"notice\":\"节假日通用\"}")
chk_code "只改备注的局部 PUT 放过" 200 "$B3"

# ---------- 10) 列表页 tab 与角标 ----------
# 角标原先是拿当前页 20 条自己 filter 算的：站在「已上架」tab 时请求带
# status=0，返回全是上架品，所以「未上架」角标恒为 0。
echo "[10] 列表页 tab 计数（走商家端专属端点）"
# 上一步已经把唯一的测试草稿上架了，而库里存量商品可能全是上架态，
# 那样「未上架 total」会是 0，验不出「草稿能否被查到」这个关键点 ——
# 而这正是顾客端端点（写死 status=0）做不到的事。所以这里再建一个草稿。
D2=$(curl -s -X POST "$H/api/product/add" -H "$AUTH" -H "$JSON" \
  -d "{\"storeIds\":\"$SID\",\"typeCode\":\"GROUPON\",\"productName\":\"SMOKE_角标用草稿\",\"price\":9.9,\"status\":\"1\",\"delFlag\":\"0\"}")
PID2=$(echo "$D2" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("productId") or 0)')
[ "$PID2" -gt 0 ] && CREATED="$CREATED $PID2"

tot() { curl -s -H "$AUTH" "$H/api/product/merchant/list?pageNum=1&pageSize=1$1" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("total",-1))'; }
L_ON=$(tot "&status=0"); L_OFF=$(tot "&status=1"); L_ALL=$(tot "")
[ "$L_ON" -ge 1 ] && ok "已上架 total=$L_ON" || bad "已上架 total=$L_ON"
[ "$L_OFF" -ge 1 ] && ok "未上架 total=$L_OFF（顾客端端点查不到草稿，这里能）" \
  || bad "未上架 total=$L_OFF（草稿查不出来，tab 角标会是 0）"
[ "$L_ALL" -eq $((L_ON + L_OFF)) ] && ok "全部 total=$L_ALL = 上架$L_ON + 未上架$L_OFF" \
  || bad "全部 $L_ALL != $L_ON + $L_OFF"
# 分页必须真生效：pageSize=1 只能返 1 行，但 total 是全量
ROWN=$(curl -s -H "$AUTH" "$H/api/product/merchant/list?pageNum=1&pageSize=1" \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("rows",[])))')
[ "$ROWN" -eq 1 ] && ok "分页生效（pageSize=1 返 1 行，total=$L_ALL）" \
  || bad "分页未生效：pageSize=1 返了 $ROWN 行"
# typeCode 过滤必须生效（mapper 原先漏了这个条件，传了也不筛）
T_G=$(tot "&typeCode=GROUPON"); T_V=$(tot "&typeCode=VOUCHER")
[ "$T_G" -lt "$L_ALL" ] || [ "$T_V" -lt "$L_ALL" ] \
  && ok "typeCode 过滤生效（GROUPON=$T_G VOUCHER=$T_V 全部=$L_ALL）" \
  || bad "typeCode 未生效：GROUPON=$T_G VOUCHER=$T_V 都等于全部 $L_ALL"
# 商家端列表不能返回别家商户的商品
LEAK=$(curl -s -H "$AUTH" "$H/api/product/merchant/list?pageNum=1&pageSize=100" \
  | python3 -c "import sys,json;rs=json.load(sys.stdin).get('rows',[]);print(sum(1 for r in rs if str(r.get('merchantId'))!='$MID'))")
[ "$LEAK" = "0" ] && ok "列表无跨商户数据" || bad "列表混入 $LEAK 条别家商户商品"
# 前端传 merchantId 想翻别家：必须被忽略
SPOOF=$(curl -s -H "$AUTH" "$H/api/product/merchant/list?merchantId=999&pageNum=1&pageSize=1" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("total",-1))')
[ "$SPOOF" = "$L_ALL" ] && ok "前端伪造 merchantId 被忽略（仍返本商户 $SPOOF 条）" \
  || bad "伪造 merchantId 生效了：total=$SPOOF 应为 $L_ALL"
# 未登录不能读商家端列表
NL=$(curl -s "$H/api/product/merchant/list?pageNum=1&pageSize=1")
echo "$NL" | grep -q "401\|未登录\|登录" && ok "未登录读商家端列表被拒" \
  || bad "未登录能读商家端列表: $NL"
# 对照：顾客端端点确实看不到草稿（证明商家端必须走自己的端点，不是多余的）
CUST=$(curl -s "$H/api/product/list?merchantId=$MID" \
  | python3 -c "import sys,json;rs=json.load(sys.stdin).get('data') or [];print(sum(1 for r in rs if r.get('status')=='1'))")
[ "$CUST" = "0" ] && ok "顾客端端点不返草稿（商家端专属端点非冗余）" \
  || bad "顾客端端点漏出了 $CUST 条草稿给顾客"

# ---------- 11) 租户隔离 ----------
echo "[11] 越权防护"
OTHER=$(/usr/local/mysql/bin/mysql -uroot -p133301 ry-vue -N -e \
  "select product_id from biz_product where merchant_id<>$MID limit 1;" 2>/dev/null)
if [ -n "$OTHER" ]; then
  X1=$(curl -s -X PUT "$H/api/product" -H "$AUTH" -H "$JSON" -d "{\"productId\":$OTHER,\"notice\":\"x\"}")
  chk_msg "改别家商品被拒" "无权编辑" "$X1"
  X2=$(curl -s -X PUT "$H/api/product/status" -H "$AUTH" -H "$JSON" -d "{\"productId\":$OTHER,\"status\":\"0\"}")
  chk_msg "上架别家商品被拒" "无权操作" "$X2"
  # 详情端点也必须挡住：商品 id 自增连号，URL 里 id 加一就能翻别家商户的定价/库存/门店。
  # 编辑和上架早就判了归属，只有 GET 详情这条一直裸奔。
  X3=$(curl -s "$H/api/product/$OTHER" -H "X-App-Id: $APPID")
  chk_msg "顾客态读别家商品被拒" "商品不存在或已下架" "$X3"
  X4=$(curl -s "$H/api/product/$OTHER" -H "$AUTH" -H "X-App-Id: $APPID")
  chk_msg "商家态读别家商品被拒" "商品不存在或已下架" "$X4"
  # 不能靠不带 header 绕过（缺 appid 时拦截器会 fallback 到默认商户）
  X5=$(curl -s "$H/api/product/$OTHER")
  chk_msg "不带 X-App-Id 也读不到别家商品" "商品不存在或已下架" "$X5"
else
  echo "  ⚠️  跳过：库里没有别家商户的商品可用于越权测试"
fi
# 带别家门店建品：商品会挂在 A 名下却在 B 的门店可核销
BADS=$(/usr/local/mysql/bin/mysql -uroot -p133301 ry-vue -N -e \
  "select store_id from biz_store where merchant_id<>$MID limit 1;" 2>/dev/null)
if [ -n "$BADS" ]; then
  XS=$(curl -s -X POST "$H/api/product/add" -H "$AUTH" -H "$JSON" \
    -d "{\"storeIds\":\"$SID,$BADS\",\"typeCode\":\"GROUPON\",\"productName\":\"SMOKE_跨店\",\"price\":10,\"status\":\"1\"}")
  chk_msg "建品带别家门店被拒" "不属于该商家" "$XS"
fi

# ---------- 12) 未登录 ----------
echo "[12] 未登录访问"
NA=$(curl -s -X POST "$H/api/product/add" -H "$JSON" -d '{"productName":"x"}')
chk_msg "未登录建品被拒" "401\|未登录\|登录" "$NA"

echo
echo "商家端商品 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "ALL PASS 🎉" || echo "有失败用例"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
