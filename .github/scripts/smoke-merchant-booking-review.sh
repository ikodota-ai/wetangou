#!/usr/bin/env bash
# 商家版「预约」页：店员确认/拒绝到店预约，拒绝原因必须是人话
#
# 为什么需要这个脚本：
#   拒绝原因会原样显示给顾客（「门店拒绝了你的预约：___」）。后端原本用
#   String.valueOf(body.get("reason")) 取值 —— 而 String.valueOf(null) 返回的是
#   字符串 "null" 而不是 null，于是「缺 reason 字段」这种请求会直接绕过空校验，
#   顾客那边看到的是「拒绝原因：null」。实测不带 reason 打这个端点返回「已拒绝」，
#   review_remark 落库就是 'null'。
#
#   同一个坑还有两处，一起钉住：
#     · confirm 的 remark 原来只判 != null，传空串会写一条全空白的备注；
#     · 报名列表的排序用 String.valueOf(signupTime) 后再判 null（死代码），
#       没有报名时间的记录拿到 "null"，倒序比较时 'n' > '2' 会把它顶到最前面，
#       店员一打开预约页最上面全是时间未知的脏数据。
#
#   另外锁住状态机：已确认的不能再拒绝、已拒绝的不能重复拒、跨门店的报名碰不到。
#
# 前置：后端跑在 $H，商户 1 有门店和预约（脚本自建报名 fixture）
# 用法：bash .github/scripts/smoke-merchant-booking-review.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
APPID="wx9e147c4e2151b123"
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 --default-character-set=utf8mb4 -N -B ry-vue"

PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
ck() { [ "$2" = "$3" ] && ok "$1 ($2)" || bad "$1 期望「$3」实得「$2」"; }
ckin() { case "$2" in *"$3"*) ok "$1";; *) bad "$1 未含「$3」: $(echo "$2"|head -c 150)";; esac }
q()  { $MYSQL -e "$1" 2>/dev/null | grep -v Warning | head -1; }
jget() { python3 -c 'import sys,json
d=json.load(sys.stdin)
b=d.get("data") if isinstance(d.get("data"),dict) else {}
for k in sys.argv[1:]:
    v=b.get(k, d.get(k))
    print("" if v is None else v)' "$@" 2>/dev/null
}

BK=""
cleanup() {
  $MYSQL -e "delete from biz_booking_member where remark='ZZ审核测试';
             delete from biz_booking where service_name='ZZ审核测试预约';" 2>/dev/null | grep -v Warning || true
}
trap cleanup EXIT
cleanup

mplogin() {
  curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
       -H "X-App-Id: $APPID" -d "{\"username\":\"$1\",\"password\":\"admin123\"}" | jget token
}
post() { # $1 path $2 token $3 body(可空)
  if [ -n "$3" ]; then
    curl -s -X POST "$H$1" -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
         -H "Authorization: Bearer $2" -d "$3"
  else
    # 故意不带 body：复现「缺 reason 字段」那条路径
    curl -s -X POST "$H$1" -H 'Content-Type: application/json' -H "X-App-Id: $APPID" \
         -H "Authorization: Bearer $2"
  fi
}

echo "=== 商家版预约审核 ($H) ==="

OWNER_TK=$(mplogin owner_c43)
ck "老板登商家版" "$([ -n "$OWNER_TK" ] && echo yes || echo no)" yes
[ -n "$OWNER_TK" ] || exit 1
STORE=$(q "select store_id from biz_store where merchant_id=1 order by store_id limit 1;")
MEMBER=$(q "select member_id from biz_member order by member_id limit 1;")
ck "取到门店与会员" "$([ -n "$STORE" ] && [ -n "$MEMBER" ] && echo yes || echo no)" yes

echo "[1] 造一条待审核报名"
$MYSQL -e "insert into biz_booking (merchant_id, store_id, booking_no, service_name, booking_date, status, create_by, create_time)
           values (1, $STORE, concat('ZZBK',unix_timestamp()), 'ZZ审核测试预约', curdate(), '0', 'smoke', now());" 2>/dev/null | grep -v Warning
BK=$(q "select booking_id from biz_booking where service_name='ZZ审核测试预约' limit 1;")
mk_signup() { # 造一条报名，回显 id
  $MYSQL -e "insert into biz_booking_member (merchant_id, booking_id, member_id, contact, phone, people, status, remark, create_time)
             values (1, $BK, $MEMBER, 'ZZ顾客', '13900000001', 2, '0', 'ZZ审核测试', now());" 2>/dev/null | grep -v Warning
  q "select id from biz_booking_member where remark='ZZ审核测试' order by id desc limit 1;"
}
S1=$(mk_signup)
ck "报名已建" "$([ -n "$S1" ] && echo yes || echo no)" yes
[ -n "$S1" ] || exit 1

echo "[2] 拒绝时不填原因必须被挡住（原本会写入字符串 null 给顾客看）"
R=$(post "/api/merchant/staff/booking/reject/$S1" "$OWNER_TK" "")
ckin "缺 reason 字段被拒" "$R" "请填写拒绝原因"
ck "  → 状态没被改动（仍待处理）" "$(q "select status from biz_booking_member where id=$S1;")" 0
ck "  → 没写入 null 字面量" "$(q "select count(*) from biz_booking_member where id=$S1 and review_remark='null';")" 0
R=$(post "/api/merchant/staff/booking/reject/$S1" "$OWNER_TK" '{"reason":null}')
ckin "reason 显式传 null 被拒" "$R" "请填写拒绝原因"
R=$(post "/api/merchant/staff/booking/reject/$S1" "$OWNER_TK" '{"reason":"   "}')
ckin "reason 全空白被拒" "$R" "请填写拒绝原因"
ck "  → 三次非法请求后状态仍是待处理" "$(q "select status from biz_booking_member where id=$S1;")" 0

echo "[3] 正常拒绝：原因原样落库（顾客要看这句话）"
R=$(post "/api/merchant/staff/booking/reject/$S1" "$OWNER_TK" '{"reason":"今天满座了，改约明天可以吗"}')
ck "拒绝成功" "$(echo "$R" | jget code)" 200
ck "  → 状态=3 已拒绝" "$(q "select status from biz_booking_member where id=$S1;")" 3
ck "  → 原因原样落库" "$(q "select review_remark from biz_booking_member where id=$S1;")" "今天满座了，改约明天可以吗"
ck "  → 记下了操作人" "$(q "select count(*) from biz_booking_member where id=$S1 and confirm_user is not null;")" 1
ckin "重复拒绝被挡" "$(post "/api/merchant/staff/booking/reject/$S1" "$OWNER_TK" '{"reason":"再拒一次"}')" "已拒绝"
ckin "已拒绝的不能再确认" "$(post "/api/merchant/staff/booking/confirm/$S1" "$OWNER_TK" '{}')" "拒绝"

echo "[4] 正常确认：备注为空时不写空白备注"
S2=$(mk_signup)
R=$(post "/api/merchant/staff/booking/confirm/$S2" "$OWNER_TK" '{}')
ck "确认成功（不带备注）" "$(echo "$R" | jget code)" 200
ck "  → 状态=2 已确认" "$(q "select status from biz_booking_member where id=$S2;")" 2
ck "  → 没写入空白/null 备注" "$(q "select count(*) from biz_booking_member where id=$S2 and (review_remark='null' or review_remark='');")" 0
ckin "已确认的不能再拒绝" "$(post "/api/merchant/staff/booking/reject/$S2" "$OWNER_TK" '{"reason":"改主意了"}')" "不能拒绝"
S3=$(mk_signup)
R=$(post "/api/merchant/staff/booking/confirm/$S3" "$OWNER_TK" '{"remark":"已电话确认，靠窗位"}')
ck "确认成功（带备注）" "$(echo "$R" | jget code)" 200
ck "  → 备注原样落库" "$(q "select review_remark from biz_booking_member where id=$S3;")" "已电话确认，靠窗位"

echo "[5] 列表排序：没有报名时间的记录不许顶到最前面"
# 造一条 create_time 为 NULL 的脏数据（历史数据里真实存在这种）
$MYSQL -e "insert into biz_booking_member (merchant_id, booking_id, member_id, contact, phone, people, status, remark, create_time)
           values (1, $BK, $MEMBER, 'ZZ无时间顾客', '13900000002', 1, '0', 'ZZ审核测试', null);" 2>/dev/null | grep -v Warning
S4=$(q "select id from biz_booking_member where contact='ZZ无时间顾客' limit 1;")
FIRST=$(curl -s "$H/api/merchant/staff/booking/signup/list" -H "X-App-Id: $APPID" -H "Authorization: Bearer $OWNER_TK" \
        | python3 -c 'import sys,json
d=json.load(sys.stdin); rows=d.get("data") or []
print(rows[0].get("contact") if rows else "")' 2>/dev/null)
ck "列表第一条不是无时间那条脏数据" "$([ "$FIRST" = "ZZ无时间顾客" ] && echo topped || echo ok)" ok

echo "[6] 跨门店/跨商户的报名碰不到"
OTHER_STORE=$(q "select store_id from biz_store where merchant_id not in (0,1) limit 1;")
if [ -n "$OTHER_STORE" ]; then
  $MYSQL -e "insert into biz_booking (merchant_id, store_id, booking_no, service_name, booking_date, status, create_by, create_time)
             values (2, $OTHER_STORE, concat('ZZBKO',unix_timestamp()), 'ZZ审核测试预约', curdate(), '0', 'smoke', now());" 2>/dev/null | grep -v Warning
  OBK=$(q "select booking_id from biz_booking where service_name='ZZ审核测试预约' and store_id=$OTHER_STORE limit 1;")
  $MYSQL -e "insert into biz_booking_member (merchant_id, booking_id, member_id, contact, phone, people, status, remark, create_time)
             values (2, $OBK, $MEMBER, 'ZZ别家顾客', '13900000003', 1, '0', 'ZZ审核测试', now());" 2>/dev/null | grep -v Warning
  OS=$(q "select id from biz_booking_member where contact='ZZ别家顾客' limit 1;")
  R6=$(post "/api/merchant/staff/booking/reject/$OS" "$OWNER_TK" '{"reason":"越权拒绝"}')
  ck "跨门店拒绝被挡" "$([ "$(echo "$R6" | jget code)" != "200" ] && echo rejected || echo passed)" rejected
  ck "  → 别家报名状态未变" "$(q "select status from biz_booking_member where id=$OS;")" 0
else
  bad "库里没有别家商户门店，跨门店用例无法构造"
fi
ck "无 token 被拒" "$(curl -s -X POST "$H/api/merchant/staff/booking/reject/$S1" -H 'Content-Type: application/json' -H "X-App-Id: $APPID" -d '{"reason":"x"}' | jget code)" 401

echo "[7] 清理"
cleanup
ck "报名 fixture 已删" "$(q "select count(*) from biz_booking_member where remark='ZZ审核测试';")" 0
ck "预约 fixture 已删" "$(q "select count(*) from biz_booking where service_name='ZZ审核测试预约';")" 0

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
