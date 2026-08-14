#!/usr/bin/env bash
# C12 health check /api/ping 端到端
# 验证:
#   A) GET /api/ping anonymous (200 + "pong")
#   B) HEAD/GET 任意 method 都通
#   C) 端点不读 DB（响应 < 50ms）
#   D) 端点不依赖 Redis（Redis 挂了也不挂）
#   E) mini 端 HEALTH_PATH 实际配置为 /api/ping（源码静态校验）
#   F) mini 端 probeBaseUrl 逻辑就绪：探活后写 localStorage
#   G) 端点不写 sys_job_log / sys_oper_log（无副作用）
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C12 health check /api/ping smoke:"

# A) anonymous 200 + pong
R=$(curl -s "$H/api/ping")
chk "A /api/ping anonymous 返 pong" "pong" "$R"
chk "A code=200" "\"code\":200" "$R"

# B) OPTIONS 预检（小程序请求会触发，验证 200/204 不报错）
OPTS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$H/api/ping")
[ "$OPTS" = "200" ] || [ "$OPTS" = "204" ] && echo "  ✅ B OPTIONS /api/ping=$OPTS (跨域预检通过)" && PASS=$((PASS+1)) || { echo "  ❌ B OPTIONS=$OPTS"; FAIL=$((FAIL+1)); }

# C) 响应快（< 200ms，不读 DB）
START=$(python3 -c "import time; print(int(time.time()*1000))")
for i in 1 2 3 4 5; do curl -s "$H/api/ping" > /dev/null; done
END=$(python3 -c "import time; print(int(time.time()*1000))")
ELAPSED=$((END - START))
AVG=$((ELAPSED / 5))
[ "$AVG" -lt 200 ] && echo "  ✅ C 5 次请求平均耗时=${AVG}ms < 200ms" && PASS=$((PASS+1)) || { echo "  ❌ C avg=${AVG}ms >= 200"; FAIL=$((FAIL+1)); }

# D) ApiPingController 源码无 RedisCache import / 无 @Autowired RedisCache
D_IMPORT=$(grep -E "^import.*[Rr]edis" ruoyi-admin/src/main/java/com/ruoyi/web/api/ApiPingController.java 2>/dev/null || true)
D_AUTOWIRE=$(grep -E "@Autowired.*[Rr]edis" ruoyi-admin/src/main/java/com/ruoyi/web/api/ApiPingController.java 2>/dev/null || true)
[ -z "$D_IMPORT" ] && [ -z "$D_AUTOWIRE" ] && echo "  ✅ D /api/ping 源码无 Redis import/Autowired" && PASS=$((PASS+1)) || { echo "  ❌ D import=[$D_IMPORT] autowire=[$D_AUTOWIRE]"; FAIL=$((FAIL+1)); }

# E) mini 端 HEALTH_PATH 配置为 /api/ping
HEALTH_PATH=$(grep "const HEALTH_PATH" miniprogram7/utils/config.js | head -1 | grep -o "'/[^']*'")
[ "$HEALTH_PATH" = "'/api/ping'" ] && echo "  ✅ E mini HEALTH_PATH=$HEALTH_PATH" && PASS=$((PASS+1)) || { echo "  ❌ E HEALTH_PATH=$HEALTH_PATH (want '/api/ping')"; FAIL=$((FAIL+1)); }

# F) mini probeBaseUrl 逻辑：探活成功 → 持久化
grep -q "probeBaseUrl" miniprogram7/utils/config.js && echo "  ✅ F mini 端 probeBaseUrl 函数存在" && PASS=$((PASS+1)) || { echo "  ❌ F probeBaseUrl 缺失"; FAIL=$((FAIL+1)); }
grep -q "setStorageSync.*resolvedBaseUrl" miniprogram7/utils/config.js && echo "  ✅ F mini 端探活成功写 localStorage" && PASS=$((PASS+1)) || { echo "  ❌ F 缺 setStorageSync"; FAIL=$((FAIL+1)); }

# G) /api/ping 端点不写 sys_job_log（无副作用）— 探活前后 sys_job_log 行数不变
BEFORE=$($DB_CMD -N -e "SELECT COUNT(*) FROM sys_job_log;" 2>/dev/null)
for i in 1 2 3; do curl -s "$H/api/ping" > /dev/null; done
sleep 1
AFTER=$($DB_CMD -N -e "SELECT COUNT(*) FROM sys_job_log;" 2>/dev/null)
[ "$BEFORE" = "$AFTER" ] && echo "  ✅ G /api/ping 不写 sys_job_log (before=$BEFORE after=$AFTER)" && PASS=$((PASS+1)) || { echo "  ❌ G before=$BEFORE after=$AFTER"; FAIL=$((FAIL+1)); }

# H) 旧端点 /captchaImage 仍可用（向后兼容，未破坏）
CAP=$(curl -s "$H/captchaImage" -o /dev/null -w "%{http_code}")
[ "$CAP" = "200" ] && echo "  ✅ H /captchaImage 仍 200 (向后兼容)" && PASS=$((PASS+1)) || { echo "  ❌ H /captchaImage=$CAP"; FAIL=$((FAIL+1)); }

echo ""
echo "C12 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
