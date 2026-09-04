#!/usr/bin/env bash
# 头像上传必须走对象存储适配器，不能落本机磁盘
#
# 用户报「选的微信头像一直打不开」。根因不是前端，是后端三个上传入口漏改：
#   CommonController.uploadFile   → uploadByStorage（走 OSS）✅ 早就对了
#   ApiMemberController.uploadAvatar  → FileUploadUtils.upload（本机磁盘）❌
#   SysProfileController.avatar       → 同上 ❌
#   CommonController.uploadFiles      → 同上 ❌
#
# 落本机磁盘为什么打不开：生产 nginx 只有
#   location / { try_files $uri $uri/ /index.html; }
# 没有 /profile/ 的 alias，于是 GET /profile/avatar/xxx.jpg 被兜底成首页。
# 实测 https://daodian.lanaoboxiang.com/profile/avatar/2026/08/22/tmp_...jpg
# 返回 200 + Content-Type: text/html + 6897 字节 <!DOCTYPE html>。
# <image> 拿到 HTML 什么都画不出来，而且因为是 200 不是 404，看响应码发现不了。
#
# 本脚本对 local 与 oss 两种 storage.type 都要成立，所以断言分两层：
#   A. 不论哪种模式，入库值必须是「适配器返回的 URL」形态（/profile/ 或 https://）
#      且不能是 serverConfig.getUrl() 拼的 http://127.0.0.1:8080/...（换环境即废）
#   B. local 模式下文件必须真的在 profile/avatar/ 目录里（证明 keyPrefix 生效，
#      与历史入库数据同形，不产生第二种路径形态）
#   C. 源码层守卫：三个入口都不许再出现 FileUploadUtils.upload(...AvatarPath...)
#      —— 这条是防回退的硬约束，因为 A/B 只能在当前 storage.type 下跑
set -u
BASE_URL="${BASE_URL:-http://localhost:8080}"
APPID="${MP_APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DB="${MYSQL_DB:-ry-vue}"
MA="-uroot -p${MYSQL_PASS:-133301} $DB --default-character-set=utf8mb4 -N -B"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OPENID="mock_smokeavatar"

PASSN=0; FAILN=0
ok(){ echo "  ✅ $1"; PASSN=$((PASSN+1)); }
ng(){ echo "  ❌ $1"; FAILN=$((FAILN+1)); }
q(){ $MYSQL $MA -e "$1" 2>/dev/null | grep -v Warning; }
# 剥掉 java 行注释（// …）与块注释行（* …），只留真实代码
nocomment(){ sed -E 's#//.*$##' "$1" | grep -vE '^[[:space:]]*\*'; }

MID=""; UPLOADED=""
cleanup(){
  [ -n "$MID" ] && q "delete from biz_member where member_id=$MID;"
  q "delete from biz_member where openid='$OPENID';"
  [ -n "$UPLOADED" ] && [ -f "$UPLOADED" ] && python3 - "$UPLOADED" <<'PY'
import os,sys
try: os.remove(sys.argv[1])
except Exception: pass
PY
  return 0
}
trap cleanup EXIT

echo "== A. 会员头像上传（/api/member/avatar） =="

TOKEN=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
  -d "{\"code\":\"${OPENID#mock_}\",\"appid\":\"$APPID\"}" \
  "$BASE_URL/api/auth/login" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('token') or (d.get('data') or {}).get('token') or '')" 2>/dev/null)
[ -n "$TOKEN" ] || { echo "FAIL: 会员登录拿不到 token"; exit 1; }
MID=$(q "select member_id from biz_member where openid='$OPENID' limit 1;")
[ -n "$MID" ] || { echo "FAIL: mock 会员没落库"; exit 1; }

# 造一张真 PNG（1x1），不能用随机字节：assertAllowed 按扩展名过，
# 但 OSS/本地写盘后如果内容不是图片，「打得开」这件事就没被真正验证
TMPIMG="/tmp/smoke_avatar_$$.png"
python3 - "$TMPIMG" <<'PY'
import base64,sys
# 1x1 红色 PNG
png = base64.b64decode(
 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==')
open(sys.argv[1],'wb').write(png)
PY

RESP=$(curl -s -m 20 -X POST -H "Authorization: Bearer $TOKEN" -H "X-App-Id: $APPID" \
  -F "avatarfile=@$TMPIMG;type=image/png" "$BASE_URL/api/member/avatar")
CODE=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))" 2>/dev/null || echo x)
if [ "$CODE" = "200" ]; then ok "上传返回 200"; else ng "上传失败：$RESP"; fi

DBAVATAR=$(q "select ifnull(avatar,'') from biz_member where member_id=$MID;")
echo "     入库 avatar = $DBAVATAR"

# A1 必须落库
if [ -n "$DBAVATAR" ]; then ok "avatar 已落库"; else ng "avatar 没落库"; fi

# A2 绝不能是 serverConfig.getUrl() 拼出来的 host（换环境/换设备即废，且 <image> 不支持 http）
case "$DBAVATAR" in
  http://127.0.0.1*|http://localhost*|http://10.*|http://172.*|http://192.168.*)
    ng "入库了当前请求 host 的绝对地址（换环境必失效）：$DBAVATAR" ;;
  *) ok "未入库请求 host 绝对地址" ;;
esac

# A3 形态必须是适配器返回值：local=/profile/... 或 s3=https://...
case "$DBAVATAR" in
  /profile/*) ok "local 适配器形态 /profile/…"; MODE=local ;;
  https://*)  ok "对象存储形态 https://…";      MODE=s3 ;;
  *)          ng "既不是 /profile/ 也不是 https://：$DBAVATAR"; MODE=unknown ;;
esac

echo "== B. keyPrefix=avatar 生效（与历史入库同形，不产生第二种路径） =="
case "$DBAVATAR" in
  /profile/avatar/*|https://*/avatar/*) ok "key 带 avatar/ 前缀" ;;
  *) ng "key 缺 avatar/ 前缀（会和历史 /profile/avatar/… 数据分叉）：$DBAVATAR" ;;
esac

if [ "${MODE:-}" = "local" ]; then
  echo "== B2. local 模式：文件必须真的写到 profile/ 下（证明不是空跑） =="
  # yml 里写的是 profile: ${RUOYI_PROFILE_PATH:/Users/mac/ruoyi/uploadPath}，
  # 得还原 Spring 占位符语义：env 有值取 env，否则取冒号后的默认值。
  # 第一版脚本直接把整个 ${...} 当路径用，于是「文件不在磁盘上」是假失败。
  RAW=$(grep -E "^[[:space:]]+profile:" "$ROOT/ruoyi-admin/src/main/resources/application.yml" \
    | head -1 | sed -E 's/.*profile:[[:space:]]*//' | tr -d '\r')
  if [[ "$RAW" == \$\{*\} ]]; then
    INNER="${RAW#\$\{}"; INNER="${INNER%\}}"
    PVAR="${INNER%%:*}"; PDEF="${INNER#*:}"
    RAW="$(eval echo "\${$PVAR:-$PDEF}")"
  fi
  PROFILE_DIR="$RAW"
  REL="${DBAVATAR#/profile/}"
  UPLOADED="$PROFILE_DIR/$REL"
  if [ -f "$UPLOADED" ]; then
    SZ=$(python3 -c "import os,sys;print(os.path.getsize(sys.argv[1]))" "$UPLOADED")
    if [ "$SZ" -gt 0 ]; then ok "文件已落盘 ($SZ bytes)"; else ng "文件是 0 字节"; fi
  else
    ng "文件不在磁盘上：$UPLOADED"
  fi
elif [ "${MODE:-}" = "s3" ]; then
  ok "s3 模式跳过本地落盘检查（对象在 bucket 里，本机无文件）"
else
  ng "storage 形态无法识别，落盘检查无从谈起"
fi

echo "== B3. 入库地址必须真能取到图片（不是 HTML 兜底页） =="
# 这是用户报的现象本身：生产返回 200 但 Content-Type: text/html（首页 6897 字节），
# <image> 拿到 HTML 什么都画不出来。光看 200 发现不了，必须断言 content-type。
#
# 后端 ResourcesConfig 注册了 /profile/** → file:${ruoyi.profile}/，
# SecurityConfig 对 GET /profile/** permitAll，所以本地这条路是通的 ——
# 生产打不开纯粹是 nginx 没把 /profile/ 转发给后端（被 location / 的 try_files 吃掉）。
case "$DBAVATAR" in
  /*)  PROBE="$BASE_URL$DBAVATAR" ;;
  *)   PROBE="$DBAVATAR" ;;
esac
HDR=$(curl -s -o /dev/null -m 15 -w "%{http_code} %{content_type} %{size_download}" "$PROBE")
echo "     GET $PROBE → $HDR"
PCODE=$(echo "$HDR" | awk '{print $1}')
PTYPE=$(echo "$HDR" | awk '{print $2}')
PLEN=$(echo  "$HDR" | awk '{print $3}')
if [ "$PCODE" = "200" ]; then ok "可访问返 200"; else ng "返 $PCODE（期望 200）"; fi
case "$PTYPE" in
  image/*) ok "Content-Type 是 image/*（$PTYPE）" ;;
  text/html*) ng "拿到的是 HTML 兜底页而不是图片（这正是用户报的现象）" ;;
  *) ng "Content-Type 异常：$PTYPE" ;;
esac
if [ "${PLEN:-0}" -gt 0 ]; then ok "响应体非空（$PLEN bytes）"; else ng "响应体是 0 字节"; fi

echo "== C. 源码守卫：三个上传入口都不许再落本机磁盘 =="
guard(){ # $1=文件 $2=说明
  local f="$ROOT/$1"
  if [ ! -f "$f" ]; then ng "$2 文件不存在：$1"; return; fi
  # 必须剥掉注释再判：改动本身在注释里写了「原先是 FileUploadUtils.upload」做根因说明，
  # 直接 grep 会把注释当成真调用（第一版脚本就这么误报了）
  if nocomment "$f" | grep -qE 'FileUploadUtils\.upload\('; then
    ng "$2 仍在用 FileUploadUtils.upload（本机磁盘）"
  else
    ok "$2 未用 FileUploadUtils.upload"
  fi
  if grep -q 'uploadByStorage' "$f"; then
    ok "$2 已走 uploadByStorage"
  else
    ng "$2 没有 uploadByStorage 调用"
  fi
}
guard "ruoyi-admin/src/main/java/com/ruoyi/web/api/ApiMemberController.java"           "会员头像"
guard "ruoyi-admin/src/main/java/com/ruoyi/web/controller/system/SysProfileController.java" "PC 用户头像"
guard "ruoyi-admin/src/main/java/com/ruoyi/web/controller/common/CommonController.java"     "通用上传"

echo "== D. 旧头像清理不能再删本机磁盘路径 =="
SPC="$ROOT/ruoyi-admin/src/main/java/com/ruoyi/web/controller/system/SysProfileController.java"
if nocomment "$SPC" | grep -qE 'FileUtils\.deleteFile\(RuoYiConfig\.getProfile\(\)'; then
  ng "SysProfileController 仍在删本机磁盘路径（切 OSS 后必然删不到，旧对象永久残留）"
else
  ok "SysProfileController 不再删本机磁盘路径"
fi
if grep -q 'FileUploadUtils.deleteByStorage' "$SPC"; then
  ok "改走 deleteByStorage 按 URL 反查 key"
else
  ng "缺 deleteByStorage 调用"
fi

echo "== E. admin 前端不能对 OSS 绝对地址二次拼 baseApi =="
UAV="$ROOT/ruoyi-ui/src/views/system/user/profile/userAvatar.vue"
if grep -qE 'options\.img = process\.env\.VUE_APP_BASE_API \+ response\.imgUrl' "$UAV"; then
  ng "userAvatar.vue 无条件拼 VUE_APP_BASE_API（OSS 地址会变成 /prod-api/https://…）"
else
  ok "userAvatar.vue 已按 isHttp 分支处理"
fi

echo "== F. 无 token 必须 401 =="
NOAUTH=$(curl -s -m 12 -X POST -H "X-App-Id: $APPID" -F "avatarfile=@$TMPIMG;type=image/png" \
  "$BASE_URL/api/member/avatar" | python3 -c "import sys,json;print(json.load(sys.stdin).get('code'))" 2>/dev/null || echo x)
if [ "$NOAUTH" = "401" ]; then ok "未登录返 401"; else ng "未登录返 $NOAUTH（期望 401）"; fi

python3 - "$TMPIMG" <<'PY'
import os,sys
try: os.remove(sys.argv[1])
except Exception: pass
PY

echo
echo "PASS=$PASSN FAIL=$FAILN"
[ "$FAILN" -eq 0 ] || exit 1
