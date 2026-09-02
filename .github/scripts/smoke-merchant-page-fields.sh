#!/usr/bin/env bash
# 商家端页面字段契约烟测（后端返回的字段名必须和 WXML 里读的一致）
#
# 为什么需要这个脚本：
#   小程序页面不报错也能整片空白 —— WXML 读 {{item.contact}}，后端返的是
#   memberName，两边都「正常」，只有店员手上那一屏是「匿名顾客 · 时间待定 ·
#   无电话」。这类缺陷编译过、接口 200、日志干净，只有对着真机截图逐字段比
#   才发现，所以必须用断言钉死。
#
#   本轮实测抓到两处：
#     1) /booking/signup/list 六个字段全对不上或压根没返：
#        contact / phone / timeSlot 被改名成 memberName / memberPhone /
#        bookingTime；people / serviceName / remark 完全没返（模板里那两行
#        wx:if 永远不成立）。店员看不到几位客人、订的什么项目、有什么忌口，
#        接单只能靠猜。
#     2) /staff/invite/list 没返 storeName，team/index.wxml 只能退化显示
#        「门店100」这种编号 —— 店长同时管两三家店时认不出这张码是哪家的。
#
#   附带锁两条业务口径：
#     · 报名电话不脱敏。店员接单的动作就是回拨顾客确认到店，拿到 137****7777
#       根本拨不出去（同 smoke-pay-phone-star.sh 那次「商家回拨也拨不出去」）。
#     · 联系人优先取报名时填的 contact，而不是微信昵称：替朋友订位很常见，
#       拿昵称去店里喊人喊不到。
#
# 用法：bash .github/scripts/smoke-merchant-page-fields.sh [host]
# 退出码：0 全通 / 1 有失败

H="${1:-http://localhost:8080}"
PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
chk_eq() { # $1 desc $2 want $3 got
  [ "$3" = "$2" ] && ok "$1 ($3)" || bad "$1 期望「$2」实得「$3」"
}
chk_code() { # $1 desc $2 want $3 body
  local got
  got=$(echo "$3" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code"))' 2>/dev/null)
  [ "$got" = "$2" ] && ok "$1 (code=$got)" || bad "$1 期望 code=$2 实得 $got: $3"
}

MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 --default-character-set=utf8mb4 ry-vue"

# 从列表里挑出本次自建那条，再取某个字段（缺字段返回固定串 __MISSING__，
# 这样断言不会因为 None/空串被 shell 判成「取值失败」而误报成别的原因）
pick() { # pick <匹配键> <匹配值> <要取的字段>
  python3 -c "
import sys,json
d=json.load(sys.stdin)
b=d.get('data')
rows=b if isinstance(b,list) else (b or {}).get('rows') or []
for r in rows:
    if str(r.get('$1'))=='$2':
        print('__MISSING__' if '$3' not in r else ('' if r.get('$3') is None else r.get('$3')))
        break
else:
    print('__NOROW__')
" 2>/dev/null
}

echo "=== 商家端页面字段契约 ($H) ==="

# ---------- 0) 登录 ----------
echo "[0] 登录：老板 / 店员"
LO=$(curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
  -d '{"username":"owner_c43","password":"admin123"}')
OTK=$(echo "$LO" | python3 -c 'import sys,json;d=json.load(sys.stdin);x=d.get("data") if isinstance(d.get("data"),dict) else d;print((x or {}).get("token") or d.get("token") or "")')
if [ -z "$OTK" ]; then echo "  ❌ 老板登录失败，后续跳过: $LO"; exit 1; fi
ok "老板登录成功"
LS=$(curl -s -X POST "$H/api/merchant/staff/login" -H 'Content-Type: application/json' \
  -d '{"username":"staff_c43","password":"admin123"}')
STK=$(echo "$LS" | python3 -c 'import sys,json;d=json.load(sys.stdin);x=d.get("data") if isinstance(d.get("data"),dict) else d;print((x or {}).get("token") or d.get("token") or "")')
[ -n "$STK" ] && ok "店员登录成功" || bad "店员登录失败: $LS"

AUTH="Authorization: Bearer $OTK"

cleanup() {
  $MYSQL -e "
    delete from biz_booking_member where booking_id in (select booking_id from biz_booking where booking_no like 'ZZFLD\\_%');
    delete from biz_booking where booking_no like 'ZZFLD\\_%';" 2>/dev/null
  local left
  left=$($MYSQL -N -B -e "select count(*) from biz_booking where booking_no like 'ZZFLD\\_%';" 2>/dev/null)
  echo "  [cleanup] 残留测试预约 left=$left"
}
trap cleanup EXIT

# ---------- 1) 造两条今日报名：一条填了联系人，一条只有微信昵称 ----------
# 门店 100 是 owner_c43 的授权门店；两条都挂今天，页面标题就是「今日预约报名」
# 第二条要挂一个真有昵称的会员，才能验「没填联系人 → 退回微信昵称」这条兜底
NICK_MID=$($MYSQL -N -B -e "select member_id from biz_member where merchant_id=1 and nickname is not null and nickname<>'' order by member_id limit 1;" 2>/dev/null)
NICK_NAME=$($MYSQL -N -B -e "select nickname from biz_member where member_id='$NICK_MID';" 2>/dev/null)
echo "[1] 造今日预约报名（含联系人 / 不含联系人两种，昵称会员=$NICK_MID/$NICK_NAME）"
$MYSQL -e "
insert into biz_booking (merchant_id, booking_no, store_id, service_name, booking_type, booking_date, time_slot, status, create_time)
values (1,'ZZFLD_BK1',100,'ZZ足浴60分钟','TOSTORE',curdate(),'18:00-19:00','0',now());
insert into biz_booking_member (merchant_id, booking_id, member_id, contact, phone, people, status, remark, create_time)
values (1,(select booking_id from biz_booking where booking_no='ZZFLD_BK1'),999247,'ZZ张先生','13900001111',3,'0','ZZ靠窗座位',now());
insert into biz_booking (merchant_id, booking_no, store_id, service_name, booking_type, booking_date, time_slot, status, create_time)
values (1,'ZZFLD_BK2',100,'ZZ理疗90分钟','TOSTORE',curdate(),'20:00-21:00','0',now());
insert into biz_booking_member (merchant_id, booking_id, member_id, contact, phone, people, status, create_time)
values (1,(select booking_id from biz_booking where booking_no='ZZFLD_BK2'),$NICK_MID,'','13900002222',1,'0',now());" 2>/dev/null
S1=$($MYSQL -N -B -e "select bm.id from biz_booking_member bm join biz_booking b on b.booking_id=bm.booking_id where b.booking_no='ZZFLD_BK1' limit 1;" 2>/dev/null)
S2=$($MYSQL -N -B -e "select bm.id from biz_booking_member bm join biz_booking b on b.booking_id=bm.booking_id where b.booking_no='ZZFLD_BK2' limit 1;" 2>/dev/null)
[ -n "$S1" ] && [ -n "$S2" ] && ok "报名数据就绪 signupId=$S1,$S2" || bad "报名数据没造出来"

# ---------- 2) booking/index.wxml 读的六个字段必须都在 ----------
echo "[2] 预约页六个字段（contact/phone/people/serviceName/timeSlot/remark）"
BL=$(curl -s "$H/api/merchant/staff/booking/signup/list" -H "$AUTH")
chk_code "报名列表可读" 200 "$BL"
chk_eq "contact 联系人"    "ZZ张先生"      "$(echo "$BL" | pick signupId "$S1" contact)"
chk_eq "timeSlot 时段"     "18:00-19:00"   "$(echo "$BL" | pick signupId "$S1" timeSlot)"
chk_eq "people 人数"       "3"             "$(echo "$BL" | pick signupId "$S1" people)"
chk_eq "serviceName 项目"  "ZZ足浴60分钟"  "$(echo "$BL" | pick signupId "$S1" serviceName)"
chk_eq "remark 备注"       "ZZ靠窗座位"    "$(echo "$BL" | pick signupId "$S1" remark)"
# 电话必须原样可拨：脱敏成 139****1111 店员回拨不了
chk_eq "phone 未脱敏"      "13900001111"   "$(echo "$BL" | pick signupId "$S1" phone)"
# 模板里 wx:if="{{item.status === '0'}}" 才出「确认到店/拒绝」两个按钮，
# status 一旦返成数字 0 就恒不成立，店员点不到任何按钮
chk_eq "status 是字符串态" "0"             "$(echo "$BL" | pick signupId "$S1" status)"

# ---------- 3) 没填联系人时退回微信昵称，不能是空白 ----------
echo "[3] 联系人缺失时的兜底"
chk_eq "未填联系人退回昵称" "$NICK_NAME" "$(echo "$BL" | pick signupId "$S2" contact)"

# ---------- 4) 邀请码列表要带 storeName ----------
echo "[4] 邀请码列表 storeName"
IL=$(curl -s "$H/api/merchant/staff/staff/invite/list" -H "$AUTH")
chk_code "邀请码列表可读" 200 "$IL"
SNAME=$(echo "$IL" | python3 -c "
import sys,json
d=json.load(sys.stdin)
b=d.get('data'); rows=b if isinstance(b,list) else (b or {}).get('rows') or []
if not rows: print('__NOROW__')
else: print('__MISSING__' if 'storeName' not in rows[0] else (rows[0].get('storeName') or ''))
" 2>/dev/null)
WANT=$($MYSQL -N -B -e "select store_name from biz_store where store_id=100;" 2>/dev/null)
if [ "$SNAME" = "__NOROW__" ]; then
  echo "  ⚠️  跳过：库里没有本商户可见的邀请码"
else
  chk_eq "storeName 门店名" "$WANT" "$SNAME"
fi
# 店员不该看到邀请码列表（能看就能照着发码给自己提权）
chk_code "店员看邀请码被拒" 403 "$(curl -s "$H/api/merchant/staff/staff/invite/list" -H "Authorization: Bearer $STK")"

# ---------- 5) 未登录一律 401 ----------
echo "[5] 无 token"
chk_code "无 token 读报名列表" 401 "$(curl -s "$H/api/merchant/staff/booking/signup/list")"

echo
echo "=== 结果：PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
