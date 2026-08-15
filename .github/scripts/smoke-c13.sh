#!/usr/bin/env bash
# C13 首页 Banner 链路端到端
# 验证:
#   A) GET /api/banner/list anonymous 返 home position banners
#   B) GET /api/banner/list?position=agent 仅 agent
#   C) GET /api/banner/list?merchantId=1 仅该商户
#   D) GET /api/banner/list?merchantId=2 隔离
#   E) status=1 停用后不再返
#   F) 按 sort 排序
#   G) mini 端 utils/request.js 的 bannerList 已就绪
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# fixture: 1 条 home merchant=1 status=0 + 1 条 agent merchant=1 + 1 条 home merchant=2
B_HOME_1=$($DB_CMD -N -e "INSERT INTO biz_banner (merchant_id, position, title, image_url, link_url, sort, status, create_time) VALUES (1, 'home', 'C13_home_m1', 'https://x', '', 50, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
B_AGENT=$($DB_CMD -N -e "INSERT INTO biz_banner (merchant_id, position, title, image_url, link_url, sort, status, create_time) VALUES (1, 'agent', 'C13_agent_m1', 'https://x', '', 50, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
B_HOME_2=$($DB_CMD -N -e "INSERT INTO biz_banner (merchant_id, position, title, image_url, link_url, sort, status, create_time) VALUES (2, 'home', 'C13_home_m2', 'https://x', '', 50, '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
B_DISABLED=$($DB_CMD -N -e "INSERT INTO biz_banner (merchant_id, position, title, image_url, link_url, sort, status, create_time) VALUES (1, 'home', 'C13_DISABLED', 'https://x', '', 99, '1', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "[init] home_m1=$B_HOME_1 agent=$B_AGENT home_m2=$B_HOME_2 disabled=$B_DISABLED"

cleanup() {
  [ "$B_HOME_1" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_banner WHERE banner_id=$B_HOME_1;" 2>/dev/null || true
  [ "$B_AGENT" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_banner WHERE banner_id=$B_AGENT;" 2>/dev/null || true
  [ "$B_HOME_2" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_banner WHERE banner_id=$B_HOME_2;" 2>/dev/null || true
  [ "$B_DISABLED" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_banner WHERE banner_id=$B_DISABLED;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C13 首页 Banner 链路 smoke:"

# A) home 默认
A=$(curl -s "$H/api/banner/list")
chk "A home 默认匿名 200" "操作成功" "$A"
chk "A 包含 C13_home_m1" "C13_home_m1" "$A"
echo "$A" | grep -q "C13_agent_m1" && { echo "  ❌ A 不应包含 agent 位置 banner"; FAIL=$((FAIL+1)); } || { echo "  ✅ A 仅 home 位置"; PASS=$((PASS+1)); }
echo "$A" | grep -q "C13_home_m2" && { echo "  ❌ A merchantId=2 不应被 default (merchantId=NULL) 列出"; FAIL=$((FAIL+1)); } || { echo "  ✅ A merchantId=NULL 隔离 merchantId=2"; PASS=$((PASS+1)); }

# B) agent
B=$(curl -s "$H/api/banner/list?position=agent")
chk "B agent position 包含 C13_agent_m1" "C13_agent_m1" "$B"
echo "$B" | grep -q "C13_home_m1" && { echo "  ❌ B 不应包含 home banner"; FAIL=$((FAIL+1)); } || { echo "  ✅ B 仅 agent 位置"; PASS=$((PASS+1)); }

# C) merchantId=1
C=$(curl -s "$H/api/banner/list?merchantId=1")
chk "C merchantId=1 包含 C13_home_m1" "C13_home_m1" "$C"
echo "$C" | grep -q "C13_home_m2" && { echo "  ❌ C 不应包含 merchantId=2"; FAIL=$((FAIL+1)); } || { echo "  ✅ C merchantId 隔离"; PASS=$((PASS+1)); }

# D) shared 表语义: 默认拉 (IN 0, ctx=1) 应包含 merchantId=1 (C13_home_m1), 不应含 merchantId=2 (C13_home_m2)
D=$(curl -s "$H/api/banner/list?merchantId=2")
echo "$D" | grep -q "C13_home_m2" && { echo "  ❌ D ctx=1 不应拉 merchantId=2 banner"; FAIL=$((FAIL+1)); } || { echo "  ✅ D shared 语义: ctx=1 不含 merchantId=2 banner"; PASS=$((PASS+1)); }
D_DEFAULT=$(curl -s "$H/api/banner/list")
echo "$D_DEFAULT" | grep -q "C13_home_m1" && echo "  ✅ D shared 语义: 默认拉含 merchantId=1 banner (C13_home_m1)" && PASS=$((PASS+1)) || { echo "  ❌ D C13_home_m1 缺失"; FAIL=$((FAIL+1)); }

# E) 停用后不返
E=$(curl -s "$H/api/banner/list")
echo "$E" | grep -q "C13_DISABLED" && { echo "  ❌ E status=1 不应出现"; FAIL=$((FAIL+1)); } || { echo "  ✅ E status=1 排除"; PASS=$((PASS+1)); }

# F) sort 排序：取 merchantId=1 home 的两个 banner (sort=1 和 sort=50)，sort 小的应在前
# 已有 banner_id=3,4 (sort=1) + C13_home_m1 (sort=50)
F=$(curl -s "$H/api/banner/list?merchantId=1")
SORT_OK=$(echo "$F" | python3 -c "
import sys, json
arr = json.load(sys.stdin).get('data', [])
# 只测 merchantId=1 的
m1 = [b for b in arr if b.get('merchantId') == 1]
sort_list = [b.get('sort', 0) for b in m1]
print('OK' if sort_list == sorted(sort_list) else f'BAD: {sort_list}')")
chk "F sort 升序" "OK" "$SORT_OK"

# G) mini 端 bannerList 已就绪
grep -q "bannerList.*api/banner/list" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ G mini 端 bannerList 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ G mini bannerList 缺失"; FAIL=$((FAIL+1)); }

# H) 端点不需鉴权（@Anonymous）
HEAD=$(curl -sI "$H/api/banner/list" | head -1)
echo "$HEAD" | grep -q "200" && echo "  ✅ H anonymous 200" && PASS=$((PASS+1)) || { echo "  ❌ H $HEAD"; FAIL=$((FAIL+1)); }

echo ""
echo "C13 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
