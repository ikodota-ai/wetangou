#!/usr/bin/env bash
# E10 推客太阳码缓存 smoke
# 验证:
#   A) 首次调 /api/distributor/qrcode 返 cached=false 并落盘 1 个 qr_<memberId>_*.png
#   B) 二次调同接口返 cached=true 且不新增文件
#   C) 二次调返的 url 与首次一致（命中文件复用）
#   D) no auth → 401
#
# 前置: 后端在 8080 运行, MySQL 可直连
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-133301}"
DB_NAME="${DB_NAME:-ry-vue}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
PROFILE_DIR="${PROFILE_DIR:-/Users/mac/ruoyi/uploadPath/distributor}"
JSCODE="e10smoke_$(date +%s)_$$"

cleanup() {
  if [ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ]; then
    $MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID" 2>/dev/null
    echo "  [cleanup] deleted biz_distributor distributor_id=$DIST_ID"
  fi
  if [ -n "$MEMBER_ID" ] && [ "$MEMBER_ID" -gt 0 ]; then
    ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | while read f; do
      DEST=$(mktemp -t e10rm)
      mv "$f" "$DEST"
      echo "  [cleanup] moved $f -> $DEST"
    done
  fi
}
trap cleanup EXIT

# 1) 拿 token（mock 模式，code 直接作 openid 后缀）
LOGIN_RESP=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"$JSCODE\",\"appid\":\"$APPID\",\"nickName\":\"e10smoke\"}" \
  "$BASE_URL/api/auth/login")
TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
MEMBER_ID=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memberId',0))")
[ -n "$TOKEN" ] || { echo "FAIL: no token"; echo "$LOGIN_RESP"; exit 1; }
[ "$MEMBER_ID" -gt 0 ] || { echo "FAIL: no memberId"; exit 1; }
echo "[login] memberId=$MEMBER_ID"

# 2) 把这个 member 升级为 distributor（smoke 退出时清理）
DIST_ID=$($MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e \
  "INSERT INTO biz_distributor (member_id, merchant_id, level, status, join_time, create_time) VALUES ($MEMBER_ID, 1, 1, '0', NOW(), NOW());
   SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
[ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ] || { echo "FAIL: insert distributor"; exit 1; }
echo "[setup] distributor_id=$DIST_ID for member $MEMBER_ID"

# 3) 准备：清空历史 qr_<MEMBER_ID>_*.png
PRE_EXISTING=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$PRE_EXISTING" -gt 0 ] && echo "  [prep] moving $PRE_EXISTING pre-existing png file(s) aside"
ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | while read f; do
  DEST=$(mktemp -t e10rm)
  mv "$f" "$DEST"
  echo "  [prep] moved $f -> $DEST"
done

# 4) 首次调：期望 cached=false
RESP1=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/distributor/qrcode")
echo "[B] first: $RESP1"
CACHED1=$(echo "$RESP1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cached', 'missing'))")
URL1=$(echo "$RESP1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))")
[ "$CACHED1" = "False" ] || { echo "FAIL: first call cached=$CACHED1 (expect False)"; exit 1; }
[ -n "$URL1" ] || { echo "FAIL: no url"; exit 1; }
echo "  [B] OK: cached=false url=$URL1"

sleep 0.3
COUNT_AFTER_1=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT_AFTER_1" -ge 1 ] || { echo "FAIL: no png file written"; ls -la "$PROFILE_DIR"/ 2>/dev/null; exit 1; }
echo "  [B] OK: $COUNT_AFTER_1 png file(s) for member $MEMBER_ID"

# 5) 二次调：期望 cached=true 且文件数不变
RESP2=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/distributor/qrcode")
echo "[C] second: $RESP2"
CACHED2=$(echo "$RESP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cached', 'missing'))")
URL2=$(echo "$RESP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))")
[ "$CACHED2" = "True" ] || { echo "FAIL: second call cached=$CACHED2 (expect True)"; exit 1; }
[ "$URL1" = "$URL2" ] || { echo "FAIL: url changed across calls: $URL1 vs $URL2"; exit 1; }
echo "  [C] OK: cached=true url 复用"

sleep 0.3
COUNT_AFTER_2=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT_AFTER_2" = "$COUNT_AFTER_1" ] || { echo "FAIL: file count grew $COUNT_AFTER_1 -> $COUNT_AFTER_2"; exit 1; }
echo "  [C] OK: file count stable ($COUNT_AFTER_1)"

# 6) no auth：RuoYi 风格返 200 + body.code=401
NOAUTH=$(curl -s "$BASE_URL/api/distributor/qrcode")
NOAUTH_CODE=$(echo "$NOAUTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$NOAUTH_CODE" = "401" ] || { echo "FAIL: no auth body.code=$NOAUTH_CODE (expect 401); raw=$NOAUTH"; exit 1; }
echo "  [D] OK: no auth -> body.code=401"

echo "E10 smoke test PASSED"
