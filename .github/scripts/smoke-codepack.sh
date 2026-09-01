#!/usr/bin/env bash
# 后台「一键打包小程序代码包」端到端
#
# 为什么要有这个 smoke：这个接口两个缺陷都是「返回 200 但产物是错的」型，
# 光看 HTTP 状态码永远发现不了，必须解包断言内容。
#   1) 模板是 8-06 的手工副本，漂了 59 个 commit —— 商家下载到旧代码，
#      表现为「下单页没有优惠券入口」「首页没有门店评分」等改好了却看不到。
#   2) rewriteConfigJs 的正则在 config.js 重构后失效，replaceAll 匹配不到不报错，
#      于是后台让运营填的「API 地址」完全没写进包里（实测传内网 IP 打出来的包没变）。
#
# 断言：解包后必须能看到新代码的特征，且 appid / baseUrl 真的被改写成入参。
set -u
BASE_URL="${BASE_URL:-http://localhost:8080}"
USER="${ADMIN_USER:-admin}"
PASS="${ADMIN_PASS:-admin123}"
MID="${CODEPACK_MERCHANT_ID:-1}"
TEST_BASE="http://10.77.88.99:8080"   # 刻意用一个模板里绝不会出现的地址

PASSN=0; FAILN=0
ok(){ echo "  ✅ $1"; PASSN=$((PASSN+1)); }
ng(){ echo "  ❌ $1"; FAILN=$((FAILN+1)); }

TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" \
  "$BASE_URL/login" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
[ -n "$TOKEN" ] || { echo "FAIL: login no token"; exit 1; }

WORK=$(mktemp -d)
trap 'python3 -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$WORK"' EXIT

echo "== A) preview 能带出 appid =="
APPID=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/biz/codepack/preview/$MID" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('data') or {}).get('appid') or '')" 2>/dev/null)
if [ -n "$APPID" ]; then ok "preview appid=$APPID"; else ng "preview 没返 appid（商户 $MID 未配 appid？）"; fi

echo "== B) 下载 zip =="
HTTP=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/biz/codepack/$MID?baseUrl=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$TEST_BASE")" \
  -o "$WORK/p.zip" -w "%{http_code}")
if [ "$HTTP" = "200" ] && [ -s "$WORK/p.zip" ]; then ok "下载成功 http=200"; else ng "下载失败 http=$HTTP"; echo "结果: PASS=$PASSN FAIL=$FAILN"; exit 1; fi

cd "$WORK" && unzip -qo p.zip -d pk 2>/dev/null

echo "== C) 模板是最新代码，不是 8-06 快照 =="
# 下单页的选券入口（faf77514 之后才有）
if [ -f pk/pages/order/submit/index.js ] && grep -q "memberVoucherId" pk/pages/order/submit/index.js; then
  ok "下单页含 memberVoucherId（券入口在包里）"
else
  ng "下单页没有 memberVoucherId —— 模板又漂回旧快照了"
fi
for f in utils/voucher.js utils/rating.js utils/contact.js utils/broadcast.js utils/storePick.js; do
  if [ -f "pk/$f" ]; then ok "含 $f"; else ng "缺 $f —— 模板漂移"; fi
done
# 提审必需（43b8d8aa/d8ca3d4f）
if grep -q "requiredPrivateInfos" pk/app.json 2>/dev/null; then
  ok "app.json 含 requiredPrivateInfos"
else
  ng "app.json 缺 requiredPrivateInfos —— 商家提审会被驳回"
fi

echo "== D) appid 真的改写成入参 =="
if grep -q "\"appid\": \"$APPID\"" pk/project.config.json 2>/dev/null; then
  ok "project.config.json appid=$APPID"
else
  ng "appid 未改写"
fi

echo "== E) baseUrl 真的改写成入参（这条原先是假的）=="
if grep -q "10.77.88.99" pk/utils/config.js 2>/dev/null; then
  ok "config.js 写入了 $TEST_BASE"
else
  ng "config.js 没有 $TEST_BASE —— rewriteConfigJs 正则又失配了"
fi
# 探测列表也必须改，否则真机会切回模板里的线上域名
if grep -A3 "BASE_URL_FALLBACKS" pk/utils/config.js 2>/dev/null | grep -q "10.77.88.99"; then
  ok "BASE_URL_FALLBACKS 同步改写"
else
  ng "BASE_URL_FALLBACKS 未改写 —— 真机探测会切回模板域名"
fi

echo "== F) 开发产物没混进代码包 =="
if [ -d pk/node_modules ]; then ng "含 node_modules"; else ok "无 node_modules"; fi
if [ -d pk/tests ]; then ng "含 tests"; else ok "无 tests"; fi
if [ -f pk/package.json ]; then ng "含 package.json"; else ok "无 package.json"; fi

echo "结果: PASS=$PASSN FAIL=$FAILN"
[ "$FAILN" -eq 0 ] || exit 1
