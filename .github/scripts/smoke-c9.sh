#!/usr/bin/env bash
# C9 commission 冷静期真实结算链路（端到端 Quartz）
# 验证:
#   A) fixture: distributor.frozen_amount=12.80 + commission.status=0 create_time=NOW-8天
#   B) admin PUT /monitor/job/run 触发真实 SettleCommissionTask bean（与生产 cron 同链路）
#   C) 验证 commission.status=1 + settle_time 非空
#   D) 验证 distributor.frozen_amount=0 + available_amount=12.80 + total_commission += 12.80
#   E) 幂等：再次触发应无新增结算
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}
num_eq() { python3 -c "import sys; sys.exit(0 if abs($1 - $2) < 0.01 else 1)"; }

# admin 登录
ADMIN_TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
[ ${#ADMIN_TOK} -gt 50 ] || { echo "FAIL: admin login"; exit 1; }

# Quartz jobId=4 (settle_commission_task)
JOB_ID=4

MEMBER_ID=0
DIST_ID=0
COMM_ID=0

cleanup() {
  [ "$COMM_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null || true
  [ "$DIST_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null || true
  [ "$MEMBER_ID" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_member WHERE member_id=$MEMBER_ID;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C9 commission 冷静期真实结算链路 smoke:"

# A) fixture: member + distributor(frozen=12.80) + commission(create_time=NOW-8天, status=0)
MEMBER_ID=$($DB_CMD -N -e "INSERT INTO biz_member (merchant_id, openid, nickname, status, create_time, last_login_time) VALUES (1, 'c9smoke_$(date +%s)_$$', 'C9 smoke', '0', NOW(), NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
DIST_ID=$($DB_CMD -N -e "INSERT INTO biz_distributor (member_id, merchant_id, level, total_commission, available_amount, frozen_amount, withdraw_amount, status, join_time, create_time) VALUES ($MEMBER_ID, 1, 1, 0.00, 0.00, 12.80, 0.00, '0', NOW(), NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
COMM_ID=$($DB_CMD -N -e "INSERT INTO biz_commission (merchant_id, distributor_id, order_id, store_id, amount, rate, status, settled_to_distributor, create_time) VALUES (1, $DIST_ID, 999901, 200, 12.80, 10.00, '0', 0, DATE_SUB(NOW(), INTERVAL 8 DAY)); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
[ "$DIST_ID" -gt 0 ] && [ "$COMM_ID" -gt 0 ] || { echo "FAIL: fixture insert"; exit 1; }
echo "[A] member=$MEMBER_ID dist=$DIST_ID comm=$COMM_ID (frozen=12.80, comm 8 天前)"

# B) 触发真实 Quartz SettleCommissionTask bean（与生产 cron 完全同链路）
RUN=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"jobId\":$JOB_ID}" $H/monitor/job/run)
echo "  [B] /monitor/job/run resp: $(echo $RUN | head -c 200)"
chk "B Quartz 触发 HTTP 200" '"msg":"操作成功"' "$RUN"
# 等一拍：Quartz 异步跑（虽然这里 cron-trigger 同步执行 ryNoParams）
sleep 2

# C) commission.status=1 + settle_time 非空
COMM_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null)
COMM_SETTLE_TIME=$($DB_CMD -N -e "SELECT IFNULL(settle_time,'null') FROM biz_commission WHERE commission_id=$COMM_ID;" 2>/dev/null)
[ "$COMM_STATUS" = "1" ] && echo "  ✅ C commission.status=1" && PASS=$((PASS+1)) || { echo "  ❌ C status=$COMM_STATUS want 1"; FAIL=$((FAIL+1)); }
[ "$COMM_SETTLE_TIME" != "null" ] && [ -n "$COMM_SETTLE_TIME" ] && echo "  ✅ C settle_time=$COMM_SETTLE_TIME" && PASS=$((PASS+1)) || { echo "  ❌ C settle_time empty"; FAIL=$((FAIL+1)); }

# D) distributor 联动: frozen=0, available=12.80, total_commission=12.80
FROZEN=$($DB_CMD -N -e "SELECT IFNULL(frozen_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
AVAIL=$($DB_CMD -N -e "SELECT IFNULL(available_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
TOTAL=$($DB_CMD -N -e "SELECT IFNULL(total_commission,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
num_eq "$FROZEN" "0" && echo "  ✅ D frozen_amount=0" && PASS=$((PASS+1)) || { echo "  ❌ D frozen=$FROZEN want 0"; FAIL=$((FAIL+1)); }
num_eq "$AVAIL" "12.80" && echo "  ✅ D available_amount=12.80" && PASS=$((PASS+1)) || { echo "  ❌ D available=$AVAIL want 12.80"; FAIL=$((FAIL+1)); }
num_eq "$TOTAL" "12.80" && echo "  ✅ D total_commission=12.80" && PASS=$((PASS+1)) || { echo "  ❌ D total=$TOTAL want 12.80"; FAIL=$((FAIL+1)); }

# E) 幂等：再次触发，comm 应保持 status=1，dist 金额不变
RUN2=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"jobId\":$JOB_ID}" $H/monitor/job/run)
sleep 2
FROZEN2=$($DB_CMD -N -e "SELECT IFNULL(frozen_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
AVAIL2=$($DB_CMD -N -e "SELECT IFNULL(available_amount,0) FROM biz_distributor WHERE distributor_id=$DIST_ID;" 2>/dev/null)
num_eq "$FROZEN2" "0" && num_eq "$AVAIL2" "12.80" && echo "  ✅ E 幂等：二次触发无重复结算" && PASS=$((PASS+1)) || { echo "  ❌ E frozen2=$FROZEN2 avail2=$AVAIL2"; FAIL=$((FAIL+1)); }

# F) 冷静期未到（create_time=NOW）的 commission 不应被结算（隔离检查）
COMM_FRESH_ID=$($DB_CMD -N -e "INSERT INTO biz_commission (merchant_id, distributor_id, order_id, store_id, amount, rate, status, settled_to_distributor, create_time) VALUES (1, $DIST_ID, 999902, 200, 5.00, 10.00, '0', 0, NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
$DB_CMD -e "UPDATE biz_distributor SET frozen_amount = frozen_amount + 5.00, available_amount = available_amount - 5.00 WHERE distributor_id=$DIST_ID;" 2>/dev/null
sleep 1
RUN3=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOK" \
  -d "{\"jobId\":$JOB_ID}" $H/monitor/job/run)
sleep 2
FRESH_STATUS=$($DB_CMD -N -e "SELECT status FROM biz_commission WHERE commission_id=$COMM_FRESH_ID;" 2>/dev/null)
[ "$FRESH_STATUS" = "0" ] && echo "  ✅ F 冷静期未到：comm 保持 status=0" && PASS=$((PASS+1)) || { echo "  ❌ F fresh_status=$FRESH_STATUS want 0"; FAIL=$((FAIL+1)); }
# 还原
$DB_CMD -e "UPDATE biz_distributor SET frozen_amount = frozen_amount - 5.00, available_amount = available_amount + 5.00 WHERE distributor_id=$DIST_ID;" 2>/dev/null
$DB_CMD -e "DELETE FROM biz_commission WHERE commission_id=$COMM_FRESH_ID;" 2>/dev/null

echo ""
echo "C9 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
