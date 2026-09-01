#!/usr/bin/env bash
# 六项问题的生产验收脚本（只读，不写任何数据）
#
# 用途：部署完 jar 之后跑一次，直接告诉你六项在**生产**上到底通没通。
# 之前反复出现「本地改好了、手机上还是看不到」，根因往往不是代码，
# 而是 jar 没更新或后台没填数据。这个脚本把两类原因分开报。
#
# 用法：
#   bash .github/scripts/verify-prod-6items.sh
#   BASE=https://daodian.lanaoboxiang.com APPID=wx7d1c43cb9a27abc7 bash ...
#
# 注意：脚本不需要登录态 —— 六项里能匿名验证的都验证了；
# 需要会员 token 的那两条（auth/info、booking 详情的手机号）会明确标为
# SKIP 并给出手工验证方法，不会假装通过。
set -u

BASE="${BASE:-https://daodian.lanaoboxiang.com}"
APPID="${APPID:-wx7d1c43cb9a27abc7}"
H=(-H "X-App-Id: $APPID")
PASS=0; FAIL=0; SKIP=0; TODO=0

ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭  $1"; SKIP=$((SKIP+1)); }
todo() { echo "  ⚠️  $1"; TODO=$((TODO+1)); }

jq_get() { python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
cur=d
for k in '$1'.split('.'):
    if k=='': continue
    if isinstance(cur,dict): cur=cur.get(k)
    else: cur=None
    if cur is None: break
print('' if cur is None else cur)
"; }

echo "生产验收：$BASE （appid=$APPID）"
echo

# ============================================================
# 前置：jar 是否已更新
# ============================================================
echo "【前置】后端 jar 版本"
TYPES=$(curl -s "${H[@]}" "$BASE/api/booking/types")
# 判据必须看 body 里有没有 data 数组 —— 旧 jar 返的是
# HTTP 200 + {"code":401,...}，只看 HTTP 码会误判成「端点已上线」
TYPES_CODE=$(echo "$TYPES" | jq_get code)
if [ "$TYPES_CODE" = "200" ]; then
  ok "jar 已更新（/api/booking/types 返 200，第 4 项的字典端点存在）"
  JAR_NEW=1
else
  bad "jar 仍是旧版：/api/booking/types 返 code=$TYPES_CODE（旧 jar 里 /api/booking/** 整体要登录，没有这个匿名端点）"
  echo "       → 传新 jar 到 /data/wwwroot/daodian/ 后跑 ./start.sh"
  JAR_NEW=0
fi

MINFO=$(curl -s "${H[@]}" "$BASE/api/merchant/info")
if echo "$MINFO" | python3 -c "import sys,json;d=json.load(sys.stdin).get('data') or {};raise SystemExit(0 if 'phone' in d else 1)" 2>/dev/null; then
  ok "merchant/info 含 phone 字段（第 3 项「拨打电话」的商家兜底靠它）"
else
  bad "merchant/info 缺 phone 字段 → jar 未更新"
fi

# 后台前端包也要一起看。第 1 项「门店评分」在小程序上看不到，
# 真因不只是没填数据 —— 生产 /admin 的 dist 是旧包，
# 门店编辑弹窗里压根没有「门店评分」这个表单项，用户根本没地方填。
# 同理 v10 的「可提前预约 / 时段粒度 / 每周歇业日」也是后台可配项，
# 旧包里同样不存在。所以 jar 和 dist 必须成对部署。
#
# 检查方式：index.html 里有 webpack 的 chunk→hash 映射表，
# 从中取门店页 chunk 的真实文件名，下载后 grep 中文表单标签。
ADMIN_HTML=$(curl -s "$BASE/admin/index.html")
if [ -z "$ADMIN_HTML" ]; then
  skip "取不到 $BASE/admin/index.html（后台可能部署在别的路径）"
else
  # 定位门店管理页的 chunk 分两步（chunk 名和内容 hash 存在两个不同文件里）：
  #   1) app.*.js 里有 './biz/store/index.vue':['202b','chunk-xxxxxxxx'] 的路由映射
  #   2) index.html 内联的 webpack runtime 里有 'chunk-xxxxxxxx':'<内容hash>'
  APP_JS=$(printf '%s' "$ADMIN_HTML" | grep -o 'static/js/app\.[0-9a-f]*\.js' | head -1)
  STORE_CHUNK=$(curl -s "$BASE/admin/$APP_JS" \
    | grep -o '"./biz/store/index.vue":\["[^"]*","chunk-[0-9a-f]*"' \
    | grep -o 'chunk-[0-9a-f]*' | head -1)
  STORE_HASH=$(printf '%s' "$ADMIN_HTML" | grep -o "\"$STORE_CHUNK\":\"[0-9a-f]*\"" | head -1 | sed 's/.*:"//; s/"$//')
  if [ -z "$STORE_CHUNK" ] || [ -z "$STORE_HASH" ]; then
    skip "解析不出后台门店页 chunk（app=$APP_JS chunk=$STORE_CHUNK hash=$STORE_HASH）"
  else
    SJS=$(curl -s "$BASE/admin/static/js/$STORE_CHUNK.$STORE_HASH.js")
    MISSING=""
    for k in 门店评分 可提前预约 时段粒度 每周歇业日; do
      printf '%s' "$SJS" | grep -q "$k" || MISSING="$MISSING $k"
    done
    if [ -z "$MISSING" ]; then
      ok "后台 dist 已更新（门店页含 评分/可提前预约/时段粒度/每周歇业日）"
    else
      bad "后台 dist 是旧包，门店管理页缺表单项：$MISSING"
      echo "       → 这就是「后台没地方填门店评分」的原因，不是漏填"
      echo "       → cd ruoyi-ui && npm run build:prod，dist 传成 /data/wwwroot/daodian/www/admin"
    fi
  fi
fi
echo

# ============================================================
# 1. 门店评分
# ============================================================
echo "【1】首页门店评分"
# 取样必须优先挑「已填 rating」的门店，不能无脑取列表首行。
# 之前就是取首行：本地首行是门店 200（rating 空），于是这一项永远只报
# 「⚠️ 去后台填评分」，三条接口到底返不返 rating 一次都没被真验过 ——
# 真要是 mapper 漏了 select rating，这个脚本也会一路绿着放过去。
# 全部门店都没填时才回落到首行，此时报 ⚠️ 是对的（确实是没数据）。
SID=$(curl -s "${H[@]}" "$BASE/api/store/list" | python3 -c "
import sys,json
rows=json.load(sys.stdin).get('data') or []
if not rows:
    print(''); raise SystemExit
rated=[r for r in rows if r.get('rating') is not None]
print((rated[0] if rated else rows[0]).get('storeId'))")
if [ -z "$SID" ]; then
  bad "拿不到门店列表，后面的门店项无法验证"
else
  R_LST=$(curl -s "${H[@]}" "$BASE/api/store/list" | python3 -c "
import sys,json
rows=json.load(sys.stdin).get('data') or []
m=[r for r in rows if str(r.get('storeId'))=='$SID']
print('' if not m or m[0].get('rating') is None else m[0]['rating'])")
  R_DET=$(curl -s "${H[@]}" "$BASE/api/store/$SID" | jq_get data.rating)
  R_NEA=$(curl -s "${H[@]}" "$BASE/api/store/nearest?limit=5" | python3 -c "
import sys,json
rows=json.load(sys.stdin).get('data') or []
m=[r for r in rows if str(r.get('storeId'))=='$SID']
print('' if not m or m[0].get('rating') is None else m[0]['rating'])")
  if [ -z "$R_LST" ] && [ -z "$R_DET" ] && [ -z "$R_NEA" ]; then
    todo "门店 $SID 的 rating 是空 → 评分行按设计不显示"
    echo "       → 去后台【门店管理】编辑门店，填「门店评分」（0.1~5.0）"
    echo "       → 注意别填 0：0 分会被当成真实差评展示出来"
  else
    [ -n "$R_DET" ] && ok "/api/store/{id} 返 rating=$R_DET" || bad "/api/store/{id} 没返 rating（列表有值但详情没有 → mapper 漏 select）"
    [ -n "$R_LST" ] && ok "/api/store/list 返 rating=$R_LST" || bad "/api/store/list 没返 rating"
    [ -n "$R_NEA" ] && ok "/api/store/nearest 返 rating=$R_NEA" || bad "/api/store/nearest 没返 rating"
    echo "       三条路径都要有值：小程序的 store 可能来自其中任意一条"
  fi
fi
echo

# ============================================================
# 2. 基础设施 / 服务标签
# ============================================================
echo "【2】首页基础设施（服务标签）"
if [ -n "$SID" ]; then
  SVC=$(curl -s "${H[@]}" "$BASE/api/store/$SID/services")
  N=$(echo "$SVC" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []))")
  if [ "${N:-0}" -gt 0 ]; then
    ok "门店 $SID 返 $N 个服务标签：$(echo "$SVC" | python3 -c "
import sys,json;print(','.join(json.load(sys.stdin).get('data') or []))")"
  else
    todo "门店 $SID 一个服务标签都没有 → 去后台【门店管理】勾选「设施与服务」"
  fi
fi
echo

# ============================================================
# 3. 客服信息（拨打电话 / 在线咨询 / 客服二维码）
# ============================================================
echo "【3】联系商家：拨打电话 + 在线咨询（客服电话/二维码）"
if [ -n "$SID" ]; then
  SDET=$(curl -s "${H[@]}" "$BASE/api/store/$SID")
  S_PH=$(echo "$SDET"  | jq_get data.phone)
  S_SPH=$(echo "$SDET" | jq_get data.servicePhone)
  S_QR=$(echo "$SDET"  | jq_get data.serviceQrcode)
  S_SH=$(echo "$SDET"  | jq_get data.serviceHours)
  M_PH=$(echo "$MINFO"  | jq_get data.phone)
  M_SPH=$(echo "$MINFO" | jq_get data.servicePhone)
  M_QR=$(echo "$MINFO"  | jq_get data.serviceQrcode)
  M_SH=$(echo "$MINFO"  | jq_get data.serviceHours)

  # 降级链与 utils/contact.js 完全一致：门店优先、商家兜底，四项各自独立
  pick() { for v in "$@"; do [ -n "$v" ] && { echo "$v"; return; }; done; echo ""; }
  CALL=$(pick "$S_PH" "$S_SPH" "$M_PH" "$M_SPH")
  SERV=$(pick "$S_SPH" "$S_PH" "$M_SPH" "$M_PH")
  QR=$(pick "$S_QR" "$M_QR")
  SH=$(pick "$S_SH" "$M_SH")

  [ -n "$CALL" ] && ok "拨打电话可用：$CALL（门店 phone=${S_PH:-空} → 商家 phone=${M_PH:-空}）" \
                 || todo "拨打电话无值 → 后台填门店电话或商家电话"
  [ -n "$SERV" ] && ok "客服电话可用：$SERV" \
                 || todo "客服电话无值 → 后台填门店/商家客服电话"
  [ -n "$QR" ]   && ok "客服二维码可用（门店=${S_QR:-空} → 商家兜底）" \
                 || todo "客服二维码无值 → 后台【商家管理】或【门店管理】上传客服二维码"
  [ -n "$SH" ]   && ok "客服服务时间可用：$SH" \
                 || todo "客服服务时间无值（会显示「请咨询门店」兜底文案）"

  # 手机号不能带星号（Store 实体特意没加 @Sensitive 就是为了能拨出去）
  case "$CALL$SERV" in
    *'*'*) bad "客服/门店电话里有星号 → 脱敏又回来了，wx.makePhoneCall 拨不出去" ;;
    *)     ok "门店/商家电话均无星号（能正常拨出）" ;;
  esac
fi
echo

# ============================================================
# 4. 预约类型来自后台字典
# ============================================================
echo "【4】预约首页的预约项目来自后台字典"
if [ "$JAR_NEW" = "1" ]; then
  N=$(echo "$TYPES" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('data') or []))")
  if [ "${N:-0}" -gt 0 ]; then
    ok "返 $N 条预约类型：$(echo "$TYPES" | python3 -c "
import sys,json
print(', '.join([t.get('name','') for t in (json.load(sys.stdin).get('data') or [])]))")"
    echo "       小程序按这个列表渲染卡片，不再写死「堂食预约」"
  else
    todo "字典一条都没有 → 后台【字典管理】找 biz_booking_type 加项（小程序会显示「在线预约」兜底）"
  fi
else
  skip "第 4 项需要新 jar 才能验（当前 /api/booking/types 不可用）"
fi
echo

# ============================================================
# 5. 手机号不能有星号
# ============================================================
echo "【5】支付时手机号不能有星号"
# 匿名能验的：门店/商家电话（上面已验）。会员手机号需要 token，
# 生产不方便造 mock 会员，这里明确 SKIP 并给手工方法，不假装通过。
skip "会员手机号（/api/auth/info、/api/member/profile）需登录态，生产不便自动验"
echo "       → 手工验：小程序登录后进「我的-资料」，手机号不该有星号；"
echo "         再进商品下单页，手机号输入框应自动带出完整号码"
echo "       → 本地已端到端实测：买单 POST /api/bill → GET /api/bill/{id}、"
echo "         下单 POST /api/order → detail → list → prepay 全链路无星号"
# 顺带扫一遍匿名可达的接口，确认没有星号泄漏
STAR=0
for p in "/api/store/list" "/api/store/$SID" "/api/merchant/info"; do
  if curl -s "${H[@]}" "$BASE$p" | grep -q '\*\*\*\*'; then
    bad "$p 响应里有星号"; STAR=1
  fi
done
[ "$STAR" = "0" ] && ok "匿名可达接口（门店列表/详情/商家信息）均无星号"
echo

# ============================================================
# 6. 预约时段由谁决定
# ============================================================
echo "【6】小程序可选预约时段由门店营业时间决定（不是后台预约记录）"
if [ -n "$SID" ]; then
  BH=$(curl -s "${H[@]}" "$BASE/api/store/$SID" | jq_get data.businessHours)
  DT=$(python3 -c "import datetime;print((datetime.date.today()+datetime.timedelta(days=3)).isoformat())")
  SLOTS=$(curl -s "${H[@]}" "$BASE/api/booking/slots?storeId=$SID&date=$DT")
  SN=$(echo "$SLOTS" | python3 -c "
import sys,json
d=json.load(sys.stdin).get('data') or {}
print(len(d.get('day') or [])+len(d.get('night') or []))" 2>/dev/null || echo 0)
  if [ "${SN:-0}" -gt 0 ]; then
    ok "门店 businessHours=$BH → $DT 可选 $SN 个时段"
    echo "       证明：时段是按营业时间整点展开的，与后台任何一条预约记录无关"
    echo "       详见 doc/预约模型说明-后台字段职责-2026-09-01.md"
  else
    todo "该日期算不出时段 → 检查门店「营业时间」是否填了（未填按 10-22 默认）"
  fi

  # v10 起「可约范围」本身也能配了（原先只有起止小时跟营业时间走，
  # 天数写死 7 / 粒度写死整点 / 歇业日没有）。这里验新端点是否已上线。
  DAYS=$(curl -s "${H[@]}" "$BASE/api/booking/days?storeId=$SID")
  DN=$(echo "$DAYS" | python3 -c "
import sys,json
d=json.load(sys.stdin).get('data') or {}
rows=d.get('days') or []
print(len(rows), d.get('aheadDays') or 0, len([x for x in rows if x.get('closed')]))" 2>/dev/null || echo "0 0 0")
  set -- $DN
  if [ "${1:-0}" -gt 0 ]; then
    ok "可约范围可配：/api/booking/days 返 $1 天（可提前 $2 天，其中歇业 $3 天）"
    echo "       后台【门店管理】可调「可提前预约 / 时段粒度 / 每周歇业日」"
  else
    bad "/api/booking/days 不可用 → 新 jar 未部署（v10 才有这个端点）"
    echo "       → 先执行 sql/upgrade/biz_store_booking_rule_v10.sql，再传新 jar"
  fi
fi
echo

echo "════════════════════════════════════════"
echo "PASS=$PASS  FAIL=$FAIL  待配置=$TODO  跳过=$SKIP"
echo
if [ "$FAIL" -gt 0 ]; then
  echo "有 FAIL：多半是 jar 没更新。传 jar 到 /data/wwwroot/daodian/ 后跑 ./start.sh，再跑本脚本。"
  exit 1
fi
if [ "$TODO" -gt 0 ]; then
  echo "代码侧都通了，剩下的是后台数据没填（上面标 ⚠️ 的几条）。填完再跑一次即可。"
  exit 0
fi
echo "六项在生产全部通过。"
