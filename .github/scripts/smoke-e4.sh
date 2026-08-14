#!/usr/bin/env bash
# E4 推客二维码 admin 端 smoke
# 验证:
#   A) admin GET /biz/distributor/qrcode?distributorId=... 返 cached=false + 落盘 1 文件
#   B) 同 distributorId 二次调返 cached=true + URL 复用
#   C) no auth → 401
#
# 前置: 后端在 8080 运行, MySQL 可直连
set -e

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-133301}"
DB_NAME="${DB_NAME:-ry-vue}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
PROFILE_DIR="${PROFILE_DIR:-/Users/mac/ruoyi/uploadPath/distributor}"

# 1) admin token
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  "$BASE_URL/login" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] || { echo "FAIL: no admin token"; exit 1; }
echo "[login] admin token len=${#TOKEN}"

# 2) 找已存在 distributor
DIST_ID=$($MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e \
  "SELECT distributor_id FROM biz_distributor ORDER BY distributor_id LIMIT 1" 2>/dev/null)
MEMBER_ID=$($MYSQL -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e \
  "SELECT member_id FROM biz_distributor WHERE distributor_id=$DIST_ID" 2>/dev/null)
[ -n "$DIST_ID" ] && [ "$DIST_ID" -gt 0 ] || { echo "FAIL: no distributor in DB"; exit 1; }
echo "[setup] distributorId=$DIST_ID memberId=$MEMBER_ID"

# 3) 准备：清空历史 qr_<MEMBER_ID>_*.png
PRE_EXISTING=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | while read f; do
  DEST=$(mktemp -t e4rm)
  mv "$f" "$DEST"
  echo "  [prep] moved $f -> $DEST"
done

# 4) 首次调：期望 cached=false
RESP1=$(curl -s -H "Authorization: $TOKEN" "$BASE_URL/biz/distributor/qrcode?distributorId=$DIST_ID")
echo "[A] first: $RESP1"
CACHED1=$(echo "$RESP1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cached', 'missing'))")
URL1=$(echo "$RESP1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))")
SCENE1=$(echo "$RESP1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('scene',''))")
[ "$CACHED1" = "False" ] || { echo "FAIL: first call cached=$CACHED1 (expect False)"; exit 1; }
[ -n "$URL1" ] || { echo "FAIL: no url"; exit 1; }
[ "$SCENE1" = "distributor:1:$MEMBER_ID" ] || { echo "FAIL: scene=$SCENE1 (expect distributor:1:$MEMBER_ID)"; exit 1; }
echo "  [A] OK: cached=false url=$URL1 scene=$SCENE1"

sleep 0.3
COUNT_1=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT_1" -ge 1 ] || { echo "FAIL: no png file written"; exit 1; }
echo "  [A] OK: $COUNT_1 png file(s) for member $MEMBER_ID"

# 5) 二次调：cached=true
RESP2=$(curl -s -H "Authorization: $TOKEN" "$BASE_URL/biz/distributor/qrcode?distributorId=$DIST_ID")
echo "[B] second: $RESP2"
CACHED2=$(echo "$RESP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cached', 'missing'))")
URL2=$(echo "$RESP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url',''))")
[ "$CACHED2" = "True" ] || { echo "FAIL: second call cached=$CACHED2 (expect True)"; exit 1; }
[ "$URL1" = "$URL2" ] || { echo "FAIL: url changed: $URL1 vs $URL2"; exit 1; }
echo "  [B] OK: cached=true url 复用"

sleep 0.3
COUNT_2=$(ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT_2" = "$COUNT_1" ] || { echo "FAIL: file count grew $COUNT_1 -> $COUNT_2"; exit 1; }
echo "  [B] OK: file count stable ($COUNT_1)"

# 6) no auth
NOAUTH=$(curl -s "$BASE_URL/biz/distributor/qrcode?distributorId=$DIST_ID")
NOAUTH_CODE=$(echo "$NOAUTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',0))")
[ "$NOAUTH_CODE" = "401" ] || { echo "FAIL: no auth body.code=$NOAUTH_CODE (expect 401); raw=$NOAUTH"; exit 1; }
echo "  [C] OK: no auth -> body.code=401"

# 清理
ls "$PROFILE_DIR"/qr_${MEMBER_ID}_*.png 2>/dev/null | while read f; do
  DEST=$(mktemp -t e4rm)
  mv "$f" "$DEST"
  echo "  [cleanup] moved $f -> $DEST"
done

echo "E4 smoke test PASSED"
