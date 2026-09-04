#!/usr/bin/env bash
# 业务定时任务 smoke test
#
# 背景：项目此前只有 1 个业务定时任务（settleCommissionTask 佣金冷静期结算），
# 一批「到了时间就该自动发生」的状态流转压根没人管。实测本地积压：
#   biz_order 待付超 30 分钟 116 笔 / biz_pay_bill 待完成超时 9 笔 /
#   biz_booking 过期开放中 30 个 / biz_merchant_staff_invite 过期未失效 52 个 /
#   sys_job_log 75808 行（全部来自 settle_commission_task，因为它的 Cron
#   被历史调试改成了每 30 秒一跑，从没还原）
#
# 前两项不只是列表脏 —— 它们扣着的代金券全是废的：VoucherUsageService
# 把待支付也算券被占用，用户下单不付那张券就永久锁死。
#
# 本脚本锁的是「任务真跑、真改对了行、且不越界改无关数据」：
#   A) 通过 PUT /monitor/job/run 真实触发（不是直接调 Service），验 4 个 job 都在库里且可被调度器执行
#   B) 订单超时取消：造 1 笔刚下单 + 1 笔 2 小时前的带券单 → 只取消旧的，
#      status='3' 且 member_voucher_id 真置 NULL；新单不动
#   C) 买单超时取消：'0' 待确认 和 '1' 待支付 两种都收，'2' 已完成不动
#   D) 券真解锁：取消后同一张券可以再次下单（这是整件事的业务目的）
#   E) 过期预约关闭：昨天的场次 '0'→'3'，其下报名 '0'→'1'；今天的场次不动
#   F) 邀请码失效：过期的 '0'→'2'，未过期的不动
#   G) 日志清理：保留天数外的删掉，天数内的留着
#   H) 参数可配：把超时分钟改成 1 分钟后，5 分钟前的单也会被收（证明读的是 sys_config 不是硬编码）
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-quartz-jobs.sh
set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
PRODUCT=999829        # ¥200.00，门店 200（商户 1）。金额要大于券门槛 100
STORE=200
PASS=0; FAIL=0

ck() {
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=$((FAIL+1)); fi
}

jget() { python3 -c "
import sys,json
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print(''); sys.exit()
b=d.get('data') if isinstance(d.get('data'),dict) else d
v=b
for k in '$1'.split('.'):
    v=(v or {}).get(k) if isinstance(v,dict) else None
print('' if v is None else v)
"; }
jcode() { python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read() or "{}").get("code"))
except Exception: print("parse_error")'; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }

# 造的数据一律带可识别标记，cleanup 只删自己的，绝不 truncate
SMK_ORDER_NO_PREFIX='SMKQZ'
cleanup() {
  sql "delete from biz_order where order_no like '${SMK_ORDER_NO_PREFIX}%';"
  sql "delete from biz_pay_bill where bill_no like '${SMK_ORDER_NO_PREFIX}%';"
  sql "delete from biz_order where member_id in (select member_id from biz_member where openid='mock_smokeqz');"
  sql "delete from biz_pay_bill where member_id in (select member_id from biz_member where openid='mock_smokeqz');"
  sql "delete from biz_member_voucher where member_id in (select member_id from biz_member where openid='mock_smokeqz');"
  sql "delete from biz_member where openid='mock_smokeqz';"
  sql "delete from biz_booking_member where remark='${SMK_ORDER_NO_PREFIX}';"
  sql "delete from biz_booking where booking_no like '${SMK_ORDER_NO_PREFIX}%';"
  sql "delete from biz_merchant_staff_invite where scene like '${SMK_ORDER_NO_PREFIX}%' or invite_code in ('QZEXP001','QZOK0001');"
  sql "delete from sys_job_log where job_name like '${SMK_ORDER_NO_PREFIX}%';"
  # 参数还原（H 段会改）
  sql "update sys_config set config_value='30' where config_key='biz.order.unpaidTimeoutMinutes';"
  curl -s -o /dev/null -X DELETE "$BASE_URL/monitor/cache/clear" -H "Authorization: Bearer ${TK:-}" 2>/dev/null || true
  command -v redis-cli >/dev/null 2>&1 && redis-cli DEL 'sys_config:biz.order.unpaidTimeoutMinutes' >/dev/null 2>&1
}
trap cleanup EXIT
cleanup

TK=$(curl -s -X POST "$BASE_URL/login" -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | jget token)
[ -n "$TK" ] || { echo "FAIL: admin 登录拿不到 token"; exit 1; }

MTK=$(curl -s -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APPID" -d "{\"code\":\"smokeqz\",\"appid\":\"$APPID\"}" | jget token)
[ -n "$MTK" ] || { echo "FAIL: 会员登录拿不到 token（本地需 wx.miniapp.mockEnabled=true）"; exit 1; }
MID=$(sql1 "select member_id from biz_member where openid='mock_smokeqz';")
echo "[0] admin ok, member=$MID 商品=$PRODUCT 门店=$STORE"

runjob() { # runjob <job_name> → 触发一次，返回 code
  local jid
  jid=$(sql1 "select job_id from sys_job where job_name='$1';")
  [ -n "$jid" ] || { echo "-1"; return; }
  curl -s -X PUT "$BASE_URL/monitor/job/run" -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $TK" \
    -d "{\"jobId\":$jid,\"jobGroup\":\"DEFAULT\"}" | jcode
}

# ------------------------------------------------------------------ A) 4 个 job 都在且可被调度器执行
echo "[A] 4 个 job 注册且可执行"
for j in cancel_timeout_order_task close_overdue_booking_task expire_staff_invite_task clean_job_log_task; do
  ck "$j 已注册" "$(sql1 "select count(*) from sys_job where job_name='$j' and status='0';")" "1"
done
# invoke_target 必须落在 quartz 白名单包内（Constants.JOB_WHITELIST_STR），
# 否则 ScheduleUtils.whiteList 会拒掉，run 返 500
ck "cancel job 的 bean 名可解析" \
   "$(sql1 "select count(*) from sys_job where job_name='cancel_timeout_order_task' and invoke_target='cancelTimeoutOrderTask.ryNoParams()';")" "1"
ck "settle_commission Cron 已从每30秒调试值改回凌晨3点" \
   "$(sql1 "select cron_expression from sys_job where job_name='settle_commission_task';")" "0 0 3 * * ?"

# ------------------------------------------------------------------ B) 订单超时取消
echo "[B] 订单超时取消：只收超时的，且释放券"
V1=$(sql1 "insert into biz_member_voucher(merchant_id,voucher_id,member_id,face_value,threshold,status,get_time,expire_time)
     values(1,0,$MID,20.00,100.00,'0',now(),date_add(now(), interval 30 day)); select last_insert_id();")
# 旧单：2 小时前下单、带券、待支付
sql "insert into biz_order(merchant_id,order_no,store_id,member_id,product_id,product_name,order_type,price,num,
     total_amount,discount_amount,pay_amount,member_voucher_id,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}OLD',$STORE,$MID,$PRODUCT,'smoke旧单','1',200.00,1,200.00,20.00,180.00,$V1,'0',
            date_sub(now(), interval 2 hour));"
OLD=$(sql1 "select order_id from biz_order where order_no='${SMK_ORDER_NO_PREFIX}OLD';")
# 新单：刚下单，不该被收
sql "insert into biz_order(merchant_id,order_no,store_id,member_id,product_id,product_name,order_type,price,num,
     total_amount,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}NEW',$STORE,$MID,$PRODUCT,'smoke新单','1',200.00,1,200.00,0.00,200.00,'0',now());"
NEW=$(sql1 "select order_id from biz_order where order_no='${SMK_ORDER_NO_PREFIX}NEW';")
# 已支付旧单：不该被取消（钱货两空）
sql "insert into biz_order(merchant_id,order_no,store_id,member_id,product_id,product_name,order_type,price,num,
     total_amount,discount_amount,pay_amount,status,create_time,pay_time)
     values(1,'${SMK_ORDER_NO_PREFIX}PAID',$STORE,$MID,$PRODUCT,'smoke已付','1',200.00,1,200.00,0.00,200.00,'1',
            date_sub(now(), interval 3 hour), date_sub(now(), interval 3 hour));"
PAID=$(sql1 "select order_id from biz_order where order_no='${SMK_ORDER_NO_PREFIX}PAID';")

ck "触发 cancel_timeout_order_task" "$(runjob cancel_timeout_order_task)" "200"
sleep 3
ck "超时旧单被取消" "$(sql1 "select status from biz_order where order_id=$OLD;")" "3"
ck "超时旧单的券已释放（字段真置 NULL）" \
   "$(sql1 "select count(*) from biz_order where order_id=$OLD and member_voucher_id is null;")" "1"
ck "未超时新单不动" "$(sql1 "select status from biz_order where order_id=$NEW;")" "0"
ck "已支付订单不动（要走退款）" "$(sql1 "select status from biz_order where order_id=$PAID;")" "1"

# ------------------------------------------------------------------ C) 买单超时取消
echo "[C] 买单超时取消：'0' 待确认 与 '1' 待支付 都收，'2' 已完成不动"
V2=$(sql1 "insert into biz_member_voucher(merchant_id,voucher_id,member_id,face_value,threshold,status,get_time,expire_time)
     values(1,0,$MID,20.00,100.00,'0',now(),date_add(now(), interval 30 day)); select last_insert_id();")
sql "insert into biz_pay_bill(merchant_id,bill_no,store_id,member_id,amount,member_voucher_id,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}B0',$STORE,$MID,200.00,$V2,20.00,180.00,'0',date_sub(now(), interval 2 hour));"
sql "insert into biz_pay_bill(merchant_id,bill_no,store_id,member_id,amount,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}B1',$STORE,$MID,200.00,0.00,200.00,'1',date_sub(now(), interval 2 hour));"
sql "insert into biz_pay_bill(merchant_id,bill_no,store_id,member_id,amount,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}B2',$STORE,$MID,200.00,0.00,200.00,'2',date_sub(now(), interval 2 hour));"
sql "insert into biz_pay_bill(merchant_id,bill_no,store_id,member_id,amount,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}BNEW',$STORE,$MID,200.00,0.00,200.00,'0',now());"

ck "再次触发 cancel_timeout_order_task" "$(runjob cancel_timeout_order_task)" "200"
sleep 3
ck "超时待确认买单被取消" "$(sql1 "select status from biz_pay_bill where bill_no='${SMK_ORDER_NO_PREFIX}B0';")" "3"
ck "超时待确认买单的券已释放" \
   "$(sql1 "select count(*) from biz_pay_bill where bill_no='${SMK_ORDER_NO_PREFIX}B0' and member_voucher_id is null;")" "1"
ck "超时待支付买单被取消" "$(sql1 "select status from biz_pay_bill where bill_no='${SMK_ORDER_NO_PREFIX}B1';")" "3"
ck "已完成买单不动" "$(sql1 "select status from biz_pay_bill where bill_no='${SMK_ORDER_NO_PREFIX}B2';")" "2"
ck "未超时买单不动" "$(sql1 "select status from biz_pay_bill where bill_no='${SMK_ORDER_NO_PREFIX}BNEW';")" "0"

# ------------------------------------------------------------------ D) 券真解锁（业务目的）
echo "[D] 取消后同一张券可以再用（整件事的业务目的）"
# V1 原本被 OLD 单占着，B 段任务已把它释放，现在应该能正常下单
D_CODE=$(curl -s -X POST "$BASE_URL/api/order" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $MTK" -H "X-App-Id: $APPID" \
  -d "{\"productId\":$PRODUCT,\"num\":1,\"memberVoucherId\":$V1}" | jcode)
ck "被超时单锁过的券可再次下单" "$D_CODE" "200"

# ------------------------------------------------------------------ E) 过期预约关闭
echo "[E] 过期预约场次关闭 + 其下报名取消"
sql "insert into biz_booking(merchant_id,booking_no,store_id,product_id,service_name,booking_date,time_slot,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}BK1',100,1002,'smoke过期场次',date_sub(curdate(), interval 1 day),'10:00-11:00','0',now());"
BK1=$(sql1 "select booking_id from biz_booking where booking_no='${SMK_ORDER_NO_PREFIX}BK1';")
sql "insert into biz_booking(merchant_id,booking_no,store_id,product_id,service_name,booking_date,time_slot,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}BK2',100,1002,'smoke今日场次',curdate(),'10:00-11:00','0',now());"
BK2=$(sql1 "select booking_id from biz_booking where booking_no='${SMK_ORDER_NO_PREFIX}BK2';")
sql "insert into biz_booking_member(merchant_id,booking_id,member_id,contact,phone,people,status,remark,create_time)
     values(1,$BK1,$MID,'smoke','13800000000',1,'0','${SMK_ORDER_NO_PREFIX}',now());"
sql "insert into biz_booking_member(merchant_id,booking_id,member_id,contact,phone,people,status,remark,create_time)
     values(1,$BK2,$MID,'smoke','13800000000',1,'0','${SMK_ORDER_NO_PREFIX}',now());"

ck "触发 close_overdue_booking_task" "$(runjob close_overdue_booking_task)" "200"
sleep 3
ck "昨天的开放中场次被关闭" "$(sql1 "select status from biz_booking where booking_id=$BK1;")" "3"
ck "过期场次下的报名被取消" \
   "$(sql1 "select status from biz_booking_member where booking_id=$BK1 and remark='${SMK_ORDER_NO_PREFIX}';")" "1"
ck "今天的场次不动（晚上时段白天还能约）" "$(sql1 "select status from biz_booking where booking_id=$BK2;")" "0"
ck "今日场次下的报名不动" \
   "$(sql1 "select status from biz_booking_member where booking_id=$BK2 and remark='${SMK_ORDER_NO_PREFIX}';")" "0"

# ------------------------------------------------------------------ F) 邀请码失效
echo "[F] 过期邀请码失效"
# invite_code varchar(8) 唯一且非空，列名是 role 不是 role_code
sql "insert into biz_merchant_staff_invite(invite_code,scene,merchant_id,store_id,role,status,expire_at,create_time)
     values('QZEXP001','${SMK_ORDER_NO_PREFIX}EXP',1,100,'STAFF','0',date_sub(now(), interval 1 hour),now());"
sql "insert into biz_merchant_staff_invite(invite_code,scene,merchant_id,store_id,role,status,expire_at,create_time)
     values('QZOK0001','${SMK_ORDER_NO_PREFIX}OK',1,100,'STAFF','0',date_add(now(), interval 1 day),now());"

ck "触发 expire_staff_invite_task" "$(runjob expire_staff_invite_task)" "200"
sleep 3
ck "过期邀请码置为已失效" \
   "$(sql1 "select status from biz_merchant_staff_invite where scene='${SMK_ORDER_NO_PREFIX}EXP';")" "2"
ck "未过期邀请码不动" \
   "$(sql1 "select status from biz_merchant_staff_invite where scene='${SMK_ORDER_NO_PREFIX}OK';")" "0"

# ------------------------------------------------------------------ G) 日志清理按天保留
echo "[G] 调度日志按天保留（不是 truncate 一刀切）"
KEEP=$(sql1 "select config_value from sys_config where config_key='sys.jobLog.keepDays';")
sql "insert into sys_job_log(job_name,job_group,invoke_target,job_message,status,create_time)
     values('${SMK_ORDER_NO_PREFIX}OLDLOG','DEFAULT','x.y()','smoke','0',date_sub(now(), interval $((KEEP+5)) day));"
sql "insert into sys_job_log(job_name,job_group,invoke_target,job_message,status,create_time)
     values('${SMK_ORDER_NO_PREFIX}NEWLOG','DEFAULT','x.y()','smoke','0',now());"

ck "触发 clean_job_log_task" "$(runjob clean_job_log_task)" "200"
sleep 3
ck "保留天数外的日志被删" \
   "$(sql1 "select count(*) from sys_job_log where job_name='${SMK_ORDER_NO_PREFIX}OLDLOG';")" "0"
ck "保留天数内的日志留着（失败堆栈是排障唯一线索）" \
   "$(sql1 "select count(*) from sys_job_log where job_name='${SMK_ORDER_NO_PREFIX}NEWLOG';")" "1"

# ------------------------------------------------------------------ H) 阈值真从 sys_config 读
echo "[H] 超时阈值来自 sys_config 而不是硬编码"
sql "insert into biz_order(merchant_id,order_no,store_id,member_id,product_id,product_name,order_type,price,num,
     total_amount,discount_amount,pay_amount,status,create_time)
     values(1,'${SMK_ORDER_NO_PREFIX}CFG',$STORE,$MID,$PRODUCT,'smoke5分钟前','1',200.00,1,200.00,0.00,200.00,'0',
            date_sub(now(), interval 5 minute));"
CFG=$(sql1 "select order_id from biz_order where order_no='${SMK_ORDER_NO_PREFIX}CFG';")
ck "默认 30 分钟阈值下 5 分钟前的单不该被收" "$(runjob cancel_timeout_order_task)" "200"
sleep 3
ck "5 分钟前的单仍待支付" "$(sql1 "select status from biz_order where order_id=$CFG;")" "0"
# 参数改成 1 分钟。sys_config 有 Redis 缓存，必须走后台改接口或清缓存
sql "update sys_config set config_value='1' where config_key='biz.order.unpaidTimeoutMinutes';"
command -v redis-cli >/dev/null 2>&1 && redis-cli DEL 'sys_config:biz.order.unpaidTimeoutMinutes' >/dev/null 2>&1
ck "改成 1 分钟后再触发" "$(runjob cancel_timeout_order_task)" "200"
sleep 3
ck "5 分钟前的单被收（证明读的是参数不是硬编码 30）" "$(sql1 "select status from biz_order where order_id=$CFG;")" "3"

echo
echo "=============================="
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
