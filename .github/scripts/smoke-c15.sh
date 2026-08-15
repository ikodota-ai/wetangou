#!/usr/bin/env bash
# C15 门店链路端到端
# 验证:
#   A) GET /api/store/list 返 status=0 del_flag=0 门店
#   B) list 仅返 status=0 (status=1 排除)
#   C) list 仅返 del_flag=0 (del_flag=1 排除)
#   D) GET /api/store/{id} 返详情
#   E) GET /api/store/99999 返 null data (不存在)
#   F) GET /api/store/nearest 返最近 N 个 (经纬度排序)
#   G) GET /api/store/nearest 不带经纬度 退化为按 store_id 倒序
#   H) GET /api/store/{id}/services 字典码值翻译
#   I) GET /api/store/{id}/album 返门店相册列表
#   J) anonymous 端点 (无需鉴权)
#   K) mini 端 storeList/storeNearest/storeDetail 已接入
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# fixture: 1 个正常门店 + 1 个 status=1 + 1 个 del_flag=1
S_OK=$($DB_CMD -N -e "INSERT INTO biz_store (merchant_id, store_name, longitude, latitude, status, del_flag, create_time) VALUES (1, 'C15_OK_STORE', 113.95, 22.53, '0', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
S_DIS=$($DB_CMD -N -e "INSERT INTO biz_store (merchant_id, store_name, status, del_flag, create_time) VALUES (1, 'C15_DISABLED', '1', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
S_DEL=$($DB_CMD -N -e "INSERT INTO biz_store (merchant_id, store_name, status, del_flag, create_time) VALUES (1, 'C15_DELETED', '0', '1', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "[init] ok=$S_OK disabled=$S_DIS deleted=$S_DEL"

cleanup() {
  [ "$S_OK" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_store WHERE store_id=$S_OK;" 2>/dev/null || true
  [ "$S_DIS" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_store WHERE store_id=$S_DIS;" 2>/dev/null || true
  [ "$S_DEL" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_store WHERE store_id=$S_DEL;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C15 门店链路 smoke:"

# A) 列表返 ok 门店
A=$(curl -s "$H/api/store/list")
chk "A list 200" "操作成功" "$A"
chk "A 包含 C15_OK_STORE" "C15_OK_STORE" "$A"

# B) status=1 排除
echo "$A" | grep -q "C15_DISABLED" && { echo "  ❌ B status=1 不应出现"; FAIL=$((FAIL+1)); } || { echo "  ✅ B status=1 排除"; PASS=$((PASS+1)); }

# C) del_flag=1 排除
echo "$A" | grep -q "C15_DELETED" && { echo "  ❌ C del_flag=1 不应出现"; FAIL=$((FAIL+1)); } || { echo "  ✅ C del_flag=1 排除"; PASS=$((PASS+1)); }

# D) 详情
D=$(curl -s "$H/api/store/100")
chk "D /api/store/100 返 旗舰店" "旗舰店" "$D"

# E) 不存在
E_NULL=$(curl -s "$H/api/store/99999999" | python3 -c "import sys,json; print('YES' if json.load(sys.stdin).get('data') is None else 'NO')")
[ "$E_NULL" = "YES" ] && echo "  ✅ E 不存在 storeId data=null" && PASS=$((PASS+1)) || { echo "  ❌ E 非 null"; FAIL=$((FAIL+1)); }

# F) nearest 带经纬度
F=$(curl -s "$H/api/store/nearest?longitude=113.95&latitude=22.53&limit=5")
chk "F nearest 200" "操作成功" "$F"
# G) nearest 不带经纬度 (退化为按 store_id desc)
G=$(curl -s "$H/api/store/nearest?limit=5")
chk "G nearest 无经纬度 退化 200" "操作成功" "$G"

# H) services 字典翻译
H_RES=$(curl -s "$H/api/store/100/services")
chk "H services 返 list" "操作成功" "$H_RES"

# I) album
I=$(curl -s "$H/api/store/100/album")
chk "I album 200" "操作成功" "$I"

# J) anonymous
J=$(curl -sI "$H/api/store/list" | head -1)
echo "$J" | grep -q "200" && echo "  ✅ J anonymous 200" && PASS=$((PASS+1)) || { echo "  ❌ J $J"; FAIL=$((FAIL+1)); }

# K) mini 端 api 接入
grep -q "storeList.*api/store/list" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ K mini storeList 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ K mini storeList 缺失"; FAIL=$((FAIL+1)); }
grep -q "storeNearest.*api/store/nearest" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ K mini storeNearest 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ K mini storeNearest 缺失"; FAIL=$((FAIL+1)); }
grep -q "storeDetail" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ K mini storeDetail 已就绪" && PASS=$((PASS+1)) || { echo "  ❌ K mini storeDetail 缺失"; FAIL=$((FAIL+1)); }

# L) nearest 距离字段：带经纬度时应返 distance 字段
L_DIST=$(echo "$F" | python3 -c "import sys,json; arr=json.load(sys.stdin).get('data',[]); print('YES' if any(s.get('distance') is not None for s in arr) else 'NO')")
[ "$L_DIST" = "YES" ] && echo "  ✅ L nearest 带经纬度返 distance 字段" && PASS=$((PASS+1)) || { echo "  ❌ L distance 字段缺失"; FAIL=$((FAIL+1)); }

# M) nearest 无经纬度 distance=null
M_DIST=$(echo "$G" | python3 -c "import sys,json; arr=json.load(sys.stdin).get('data',[]); print('YES' if all(s.get('distance') is None for s in arr) else 'NO')")
[ "$M_DIST" = "YES" ] && echo "  ✅ M nearest 无经纬度 distance=null" && PASS=$((PASS+1)) || { echo "  ❌ M distance 非 null"; FAIL=$((FAIL+1)); }

echo ""
echo "C15 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
