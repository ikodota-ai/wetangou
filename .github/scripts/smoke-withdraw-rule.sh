#!/usr/bin/env bash
# smoke-withdraw-rule.sh
#
# 守「提现规则」这条链。起因是微信小程序审核驳回：
#   「涉及提现服务，需在提现页面清晰展示提现规则，包括但不限于可提现额度、
#     每日提现次数、提现时间、到账时间等」
#
# 光贴文案过不了审，也会变成新 bug —— 原本 POST /api/distributor/withdraw 只校验
# 「金额>0 且不超余额」，页面写「最低 10 元」但提 0.01 元照样成功。
# 所以本脚本的核心断言不是「页面上有文案」，而是**文案里写的规则真的拦得住**：
#   1) 展示接口 GET /withdraw/rules 的字段与条款齐全（页面渲染依赖它）
#   2) 展示值与实际拦截一致：把起提额从 10 改成 500，原本能过的 100 元必须开始被拒
#   3) 每日次数 / 受理时段 / 单笔上限 逐条真实生效
set -uo pipefail
BASE="${BASE:-http://localhost:8080}"
APP="${APP:-wx9e147c4e2151b123}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
DB="${DB:-ry-vue}"
DBUSER="${DBUSER:-root}"
DBPASS="${DBPASS:-133301}"
OPENID="mock_smoke_withdraw_rule"
PASS=0; FAIL=0
ck() {
  if [ "$2" = "$3" ]; then echo "PASS | $1"; PASS=$((PASS+1));
  else echo "FAIL | $1 | got=[$2] exp=[$3]"; FAIL=$((FAIL+1)); fi
}
q() { "$MYSQL" -u"$DBUSER" -p"$DBPASS" "$DB" -N -B -e "$1" 2>/dev/null; }
# 取 JSON 字段：优先钻 data
pick() { python3 -c "
import sys,json
k=sys.argv[1]
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print('parse_error'); sys.exit()
src=d.get('data') if isinstance(d.get('data'),dict) else d
v=src.get(k, d.get(k))
print('<null>' if v is None else v)
" "$1"; }

# 提现申请，回显后端 msg（规则文案就在 msg 里，正好验证「展示=拦截」）
apply() {
  curl -s -X POST "$BASE/api/distributor/withdraw" \
    -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" -H 'Content-Type: application/json' \
    -d "{\"amount\":$1,\"withdrawType\":\"0\",\"account\":\"smoke\",\"accountName\":\"smoke\"}"
}
# 后台改一条提现规则配置
setcfg() { q "update sys_config set config_value='$2' where config_key='$1'"; }

cleanup() {
  # 规则配置恢复默认（与 sql/upgrade/biz_withdraw_rule_20260903.sql 的种子一致）
  setcfg withdraw.minAmount 10
  setcfg withdraw.maxAmount 5000
  setcfg withdraw.dailyTimes 3
  setcfg withdraw.startHour 9
  setcfg withdraw.endHour 21
  setcfg withdraw.feeRate 0
  redis-cli DEL 'sys_config:withdraw.minAmount' 'sys_config:withdraw.maxAmount' \
    'sys_config:withdraw.dailyTimes' 'sys_config:withdraw.startHour' \
    'sys_config:withdraw.endHour' 'sys_config:withdraw.feeRate' >/dev/null 2>&1 || true
  # 测试推客与其提现记录
  q "delete w from biz_withdraw w join biz_distributor d on d.distributor_id=w.distributor_id
     join biz_member m on m.member_id=d.member_id where m.openid='$OPENID'"
  q "delete d from biz_distributor d join biz_member m on m.member_id=d.member_id
     where m.openid='$OPENID'"
  q "delete from biz_member where openid='$OPENID'"
}
trap cleanup EXIT

# sys_config 有 Redis 缓存，改库后必须清，否则读到旧值
evictcfg() {
  redis-cli DEL "sys_config:$1" >/dev/null 2>&1 || true
}

# ---- 0) 前置：升级脚本跑过没
CFGN=$(q "select count(*) from sys_config where config_key like 'withdraw.%'")
ck "sys_config 提现规则 7 项齐全（升级脚本已跑）" "$CFGN" "7"

# 商户 1 推客开关必须是开的，否则整条链 403
if [ "$(q "select ifnull(promoter_enabled,'1') from biz_merchant where merchant_id=1")" = "0" ]; then
  q "update biz_merchant set promoter_enabled='1' where merchant_id=1"
  redis-cli DEL "merchant:appid:$APP" "merchant:id:1" >/dev/null 2>&1 || true
fi

# ---- 1) 登录 + 成为推客
MTOKEN=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -H "X-App-Id: $APP" \
  -d "{\"code\":\"smoke_withdraw_rule\",\"appid\":\"$APP\"}" | pick token)
[ -n "$MTOKEN" ] && [ "$MTOKEN" != "<null>" ] || { echo "FAIL | 会员登录拿不到 token"; exit 1; }
ck "会员登录成功" "$([ ${#MTOKEN} -gt 20 ] && echo yes || echo no)" "yes"

JOIN=$(curl -s -X POST "$BASE/api/distributor/join" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick distributorId)
ck "成为推客" "$([ "$JOIN" != "<null>" ] && echo yes || echo no)" "yes"
DID=$(q "select d.distributor_id from biz_distributor d join biz_member m on m.member_id=d.member_id where m.openid='$OPENID' limit 1")
[ -n "$DID" ] || { echo "FAIL | 建不出测试推客"; exit 1; }

# 给测试推客一点可提现余额，否则所有申请都会先被「余额不足」挡掉，
# 就验不出起提额/次数/时段这些规则到底有没有生效
q "update biz_distributor set available_amount=2000.00 where distributor_id=$DID"

# ---- 2) 展示接口：字段与条款齐全（小程序提现页靠它渲染）
R=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP")
for f in minAmount maxAmount dailyTimes remainingTimes serviceHours withinServiceHours feeRate arrivalDesc availableAmount; do
  v=$(echo "$R" | pick "$f")
  ck "rules 返回 $f" "$([ "$v" != "<null>" ] && [ "$v" != "parse_error" ] && echo yes || echo no)" "yes"
done
CNT=$(echo "$R" | python3 -c "import sys,json;print(len((json.load(sys.stdin).get('data') or {}).get('rules') or []))")
ck "规则条款 >= 7 条（微信要求的 4 类都覆盖）" "$([ "${CNT:-0}" -ge 7 ] && echo yes || echo no)" "yes"
# 微信点名要的 4 项必须逐条出现在条款里
BODY=$(echo "$R" | python3 -c "import sys,json;print(''.join((json.load(sys.stdin).get('data') or {}).get('rules') or []))")
for kw in 可提现额度 每日次数 提现时间 到账时间 手续费 提现审核; do
  ck "条款覆盖「$kw」" "$(echo "$BODY" | grep -q "$kw" && echo yes || echo no)" "yes"
done

# ---- 3) 起提额真实生效（展示 != 摆设）
MIN=$(echo "$R" | pick minAmount)
ck "默认起提额 = 10" "$MIN" "10"
M1=$(apply 1 | pick msg)
ck "提 1 元被拒且文案含起提额" "$(echo "$M1" | grep -q '单笔最低' && echo yes || echo no)" "yes"
M0=$(apply 0 | pick msg)
ck "提 0 元被拒" "$(echo "$M0" | grep -q '不合法' && echo yes || echo no)" "yes"
MN=$(apply -5 | pick msg)
ck "提负数被拒" "$(echo "$MN" | grep -q '不合法' && echo yes || echo no)" "yes"

# 关键断言：把起提额调到 500，原本能过的 100 元必须开始被拒 ——
# 证明页面上展示的数字就是服务端真正用的数字，不是两套
setcfg withdraw.minAmount 500; evictcfg withdraw.minAmount
NEWMIN=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick minAmount)
ck "改配置后展示值同步为 500" "$NEWMIN" "500"
M100=$(apply 100 | pick msg)
ck "起提额=500 时 100 元被拒（展示与拦截同源）" "$(echo "$M100" | grep -q '单笔最低提现 500 元' && echo yes || echo no)" "yes"
setcfg withdraw.minAmount 10; evictcfg withdraw.minAmount

# ---- 4) 单笔上限真实生效
setcfg withdraw.maxAmount 50; evictcfg withdraw.maxAmount
MMAX=$(apply 100 | pick msg)
ck "超单笔上限被拒" "$(echo "$MMAX" | grep -q '单笔最高提现 50 元' && echo yes || echo no)" "yes"
setcfg withdraw.maxAmount 5000; evictcfg withdraw.maxAmount

# ---- 5) 受理时段真实生效：把时段设成一个当前时刻必然不在的窗口
HOUR=$(date +%-H)
S=$(( (HOUR + 2) % 24 )); E=$(( (HOUR + 3) % 24 )); [ "$E" -eq 0 ] && E=24
setcfg withdraw.startHour "$S"; evictcfg withdraw.startHour
setcfg withdraw.endHour "$E"; evictcfg withdraw.endHour
WIN=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick withinServiceHours)
ck "非受理时段 withinServiceHours=false" "$WIN" "False"
MHR=$(apply 100 | pick msg)
ck "非受理时段申请被拒" "$(echo "$MHR" | grep -q '受理时间' && echo yes || echo no)" "yes"
setcfg withdraw.startHour 0; evictcfg withdraw.startHour
setcfg withdraw.endHour 24; evictcfg withdraw.endHour
WIN2=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick withinServiceHours)
ck "0-24 视为全天受理" "$WIN2" "True"

# ---- 6) 每日次数真实生效（此时全天受理、起提 10、上限 5000、余额 2000）
setcfg withdraw.dailyTimes 2; evictcfg withdraw.dailyTimes
OK1=$(apply 10 | pick code)
ck "第 1 笔提现成功" "$OK1" "200"
OK2=$(apply 10 | pick code)
ck "第 2 笔提现成功" "$OK2" "200"
M3=$(apply 10 | pick msg)
ck "第 3 笔超每日次数被拒" "$(echo "$M3" | grep -q '今日提现次数已达上限' && echo yes || echo no)" "yes"
LEFT=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick remainingTimes)
ck "剩余次数归 0" "$LEFT" "0"

# 已驳回的不该占用次数：把一笔改成 status=2 后，剩余次数要回到 1
q "update biz_withdraw set status='2' where distributor_id=$DID order by withdraw_id desc limit 1"
LEFT2=$(curl -s "$BASE/api/distributor/withdraw/rules" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" | pick remainingTimes)
ck "已驳回的申请不占用每日次数" "$LEFT2" "1"
setcfg withdraw.dailyTimes 3; evictcfg withdraw.dailyTimes

# ---- 7) 申请成功后余额被冻结（原有行为不能被规则改动破坏）
AVAIL=$(q "select available_amount from biz_distributor where distributor_id=$DID")
ck "2 笔 x10 元后可提现余额 2000 -> 1980" "$AVAIL" "1980.00"

# ---- 8) 后台配置页
ADMIN=$(curl -s -X POST "$BASE/login" -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | pick token)
[ -n "$ADMIN" ] && [ "$ADMIN" != "<null>" ] || { echo "FAIL | admin 登录失败"; exit 1; }
CFG=$(curl -s "$BASE/biz/withdrawRule" -H "Authorization: Bearer $ADMIN")
ck "后台 GET /biz/withdrawRule 200" "$(echo "$CFG" | pick code)" "200"
PV=$(echo "$CFG" | python3 -c "import sys,json;print(len((json.load(sys.stdin).get('data') or {}).get('preview') or []))")
ck "配置页返回用户端文案预览" "$([ "${PV:-0}" -ge 7 ] && echo yes || echo no)" "yes"
PUTC=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/biz/withdrawRule" -H "Authorization: Bearer $ADMIN" \
  -H 'Content-Type: application/json' -d '{"withdraw.arrivalDesc":"审核通过后 1-3 个工作日到账"}')
ck "后台 PUT /biz/withdrawRule 200" "$PUTC" "200"

# ---- 9) 小程序端静态守卫：规则必须真的渲染在提现页上
WXML="miniprogram7/pages/promoter/withdraw/index.wxml"
JS="miniprogram7/pages/promoter/withdraw/index.js"
ck "提现页渲染规则条款列表" "$(grep -q 'rule.rules' "$WXML" && echo yes || echo no)" "yes"
ck "提现页展示可提现额度" "$(grep -q '可提现额度' "$WXML" && echo yes || echo no)" "yes"
ck "提现页展示每日次数" "$(grep -q '每日次数' "$WXML" && echo yes || echo no)" "yes"
ck "提现页展示提现时间" "$(grep -q '提现时间' "$WXML" && echo yes || echo no)" "yes"
ck "提现页展示到账时间" "$(grep -q '到账时间' "$WXML" && echo yes || echo no)" "yes"
ck "提现页拉取规则接口" "$(grep -q 'withdrawRules' "$JS" && echo yes || echo no)" "yes"
ck "接口失败时有兜底规则（页面不能空白）" "$(grep -q 'FALLBACK_RULE' "$JS" && echo yes || echo no)" "yes"
ck "api 注册 withdrawRules" "$(grep -q 'withdrawRules' miniprogram7/utils/request.js && echo yes || echo no)" "yes"

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
