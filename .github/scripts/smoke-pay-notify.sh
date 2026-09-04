#!/usr/bin/env bash
# ===========================================================================
# 微信支付回调端到端：验证「支付成功 → 订单/买单真的入账」
#
# 这条链线上是断的，且断在三个各自独立的地方（任一处都足以让钱收了单不动）：
#   1. selectOrderByOrderNo / selectPayBillByBillNo 没有 @IgnoreTenant。
#      微信通知不带 X-App-Id，拦截器把租户兜底成默认商户 1，SQL 被追加
#      merchant_id = 1，于是商户 100 的单一律「不存在」。
#   2. paySuccess 扣库存走 productService.updateProduct，那里第一行是
#      assertStoresBelongToMerchant，撞上门店归属脏数据就抛异常，
#      而 doNotify 整个方法是一个事务 → 订单状态被连带回滚。
#   3. catch 里返回 HTTP 200 + code=FAIL。微信只看 HTTP 状态码，
#      收到 200 就认为送达、永不重试 —— 这笔单再也补不回来。
#
# 用真实 AES-256-GCM 报文打 /api/pay/notify/{merchantId}，不走任何调试后门。
# ===========================================================================
set -uo pipefail
BASE=${BASE:-http://localhost:8080}
MYSQL="/usr/local/mysql/bin/mysql -uroot -p133301 -N -B ry-vue --default-character-set=utf8mb4"
PASS=0; FAIL=0
V3KEY="SMOKEPAYV3KEY_000000000000000000"   # 32 字节
MID=990
STORE=990001
PROD=990002
ORDER_NO="DSMOKEPAY$$"
BILL_NO="PSMOKEPAY$$"

ok(){ PASS=$((PASS+1)); echo "  ✅ $1"; }
no(){ FAIL=$((FAIL+1)); echo "  ❌ $1"; }
chk(){ [ "$2" = "$3" ] && ok "$1 ($2)" || no "$1 期望[$3] 实际[$2]"; }
q(){ $MYSQL -e "$1" 2>/dev/null | grep -v Warning; }

cleanup(){
  echo "--- cleanup ---"
  q "delete from biz_order where order_no like 'DSMOKEPAY%';
     delete from biz_pay_bill where bill_no like 'PSMOKEPAY%';
     delete from biz_product where product_id = $PROD;
     delete from biz_store where store_id in ($STORE, 990003);
     delete from biz_member where member_id = 990004;
     delete from biz_merchant where merchant_id = $MID;"
  redis-cli DEL "merchant:appid:wxsmokepay990" "merchant:id:$MID" >/dev/null 2>&1
}
trap cleanup EXIT

echo "=== 准备数据：商户 $MID（配 APIv3 密钥）+ 两个门店 + 一个跨商户脏 store_ids 商品 ==="
q "insert into biz_merchant (merchant_id, merchant_no, merchant_name, appid, pay_appid, pay_mch_id,
      pay_api_v3_key, status, create_time)
   values ($MID, 'SMOKEPAY$MID', 'SMOKE支付回调商户', 'wxsmokepay990', 'wxsmokepay990', '1900000990',
      '$V3KEY', '0', sysdate())
   on duplicate key update pay_api_v3_key = '$V3KEY', status = '0';
   insert into biz_store (store_id, merchant_id, store_name, status, create_time)
     values ($STORE, $MID, 'SMOKE支付门店', '0', sysdate())
     on duplicate key update merchant_id = $MID;
   -- 990003 属于别的商户：故意混进商品的 store_ids，复刻线上的归属脏数据
   insert into biz_store (store_id, merchant_id, store_name, status, create_time)
     values (990003, 1, 'SMOKE别家门店', '0', sysdate())
     on duplicate key update merchant_id = 1;
   insert into biz_product (product_id, merchant_id, store_id, store_ids, product_name,
       type_code, price, pay_amount_placeholder_ignore, stock, sales, status, del_flag, create_time)
     values ($PROD, $MID, $STORE, '$STORE,990003', 'SMOKE支付回调商品',
       'GROUPON', 10.00, null, 50, 0, '0', '0', sysdate())
     on duplicate key update stock = 50, sales = 0;" 2>/dev/null

# pay_amount_placeholder_ignore 不存在时上面整条会失败，改成不带它的版本
q "insert ignore into biz_product (product_id, merchant_id, store_id, store_ids, product_name,
       type_code, price, stock, sales, status, del_flag, create_time)
   values ($PROD, $MID, $STORE, '$STORE,990003', 'SMOKE支付回调商品',
       'GROUPON', 10.00, 50, 0, '0', '0', sysdate());
   update biz_product set store_ids = '$STORE,990003', stock = 50, sales = 0,
       merchant_id = $MID, store_id = $STORE where product_id = $PROD;
   insert ignore into biz_member (member_id, merchant_id, openid, nickname, status, create_time)
     values (990004, $MID, 'smoke_pay_990004', 'SMOKE支付会员', '0', sysdate());"

q "insert into biz_order (order_no, merchant_id, store_id, member_id, product_id, product_name,
      num, price, total_amount, pay_amount, status, create_time)
   values ('$ORDER_NO', $MID, $STORE, 990004, $PROD, 'SMOKE支付回调商品',
      2, 10.00, 20.00, 20.00, '0', sysdate());
   insert into biz_pay_bill (bill_no, merchant_id, store_id, member_id, amount, pay_amount,
      status, confirm_time, create_time)
   values ('$BILL_NO', $MID, $STORE, 990004, 15.00, 15.00, '1', sysdate(), sysdate());"

echo "商户/门店/商品/订单/买单准备完成："
q "select concat('  order ', order_no, ' status=', status, ' pay_no=[', ifnull(pay_no,''), ']')
     from biz_order where order_no = '$ORDER_NO';
   select concat('  bill  ', bill_no, ' status=', status)
     from biz_pay_bill where bill_no = '$BILL_NO';
   select concat('  product store_ids=', store_ids, ' (990003 属于商户1，是故意埋的脏数据)')
     from biz_product where product_id = $PROD;"

notify(){  # $1=out_trade_no  $2=transaction_id
  local body
  body=$(node -e '
    const crypto = require("crypto")
    const key = process.argv[2], plain = process.argv[3]
    const aad = "transaction", nonce = "abcdefghijkl"
    const c = crypto.createCipheriv("aes-256-gcm", Buffer.from(key,"utf8"), Buffer.from(nonce,"utf8"))
    c.setAAD(Buffer.from(aad,"utf8"))
    const enc = Buffer.concat([c.update(plain,"utf8"), c.final(), c.getAuthTag()])
    console.log(JSON.stringify({ id:"evt", event_type:"TRANSACTION.SUCCESS",
      resource:{ algorithm:"AEAD_AES_256_GCM", original_type:"transaction",
                 associated_data:aad, nonce:nonce, ciphertext:enc.toString("base64") }}))
  ' _ "$V3KEY" "{\"trade_state\":\"SUCCESS\",\"out_trade_no\":\"$1\",\"transaction_id\":\"$2\"}")
  curl -s -o /tmp/notify_body.json -w "%{http_code}" -X POST \
    -H 'Content-Type: application/json' -d "$body" \
    "$BASE/api/pay/notify/$MID"
}

echo
echo "=== A. 订单回调（注意：故意不带 X-App-Id，就像微信服务器那样） ==="
HTTP=$(notify "$ORDER_NO" "4200SMOKE0001")
chk "A1 回调返回 HTTP 200" "$HTTP" "200"
chk "A2 响应体 code=SUCCESS" "$(python3 -c "import json;print(json.load(open('/tmp/notify_body.json')).get('code'))")" "SUCCESS"
chk "A3 订单状态 0→1（待使用）" "$(q "select status from biz_order where order_no='$ORDER_NO'")" "1"
chk "A4 落了微信真实 transaction_id（不是 MOCKPAY）" "$(q "select pay_no from biz_order where order_no='$ORDER_NO'")" "4200SMOKE0001"
chk "A5 pay_time 已写入" "$(q "select if(pay_time is null,'NULL','SET') from biz_order where order_no='$ORDER_NO'")" "SET"
chk "A6 生成了核销码" "$(q "select if(verify_code is null or verify_code='','NONE','SET') from biz_order where order_no='$ORDER_NO'")" "SET"
chk "A7 库存原子扣减 50→48（买了 2 份）" "$(q "select stock from biz_product where product_id=$PROD")" "48"
chk "A8 销量 0→2" "$(q "select sales from biz_product where product_id=$PROD")" "2"

echo
echo "=== B. 幂等：微信重复通知同一笔 ==="
HTTP=$(notify "$ORDER_NO" "4200SMOKE0001")
chk "B1 重复通知仍返 200" "$HTTP" "200"
chk "B2 状态没被改坏" "$(q "select status from biz_order where order_no='$ORDER_NO'")" "1"
chk "B3 库存没有被二次扣减" "$(q "select stock from biz_product where product_id=$PROD")" "48"

echo
echo "=== C. 买单回调 ==="
HTTP=$(notify "$BILL_NO" "4200SMOKE0002")
chk "C1 回调返回 HTTP 200" "$HTTP" "200"
chk "C2 买单状态 1→2（已完成）" "$(q "select status from biz_pay_bill where bill_no='$BILL_NO'")" "2"
chk "C3 买单 pay_time 已写入" "$(q "select if(pay_time is null,'NULL','SET') from biz_pay_bill where bill_no='$BILL_NO'")" "SET"
chk "C4 买单落了 transaction_id" "$(q "select pay_no from biz_pay_bill where bill_no='$BILL_NO'")" "4200SMOKE0002"

echo
echo "=== D. 单号查不到时必须返 500 让微信重试（原来返 200，永不重试 = 永久漏单） ==="
HTTP=$(notify "D_NOT_EXIST_$$" "4200SMOKE0003")
chk "D1 未知订单号返 HTTP 500" "$HTTP" "500"
chk "D2 响应体 code=FAIL" "$(python3 -c "import json;print(json.load(open('/tmp/notify_body.json')).get('code'))")" "FAIL"

echo
echo "=== E. 交易单据禁止物理删除 ==="
TOKEN=$(curl -s -X POST "$BASE/login" -H 'Content-Type: application/json' \
   -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))")
[ -n "$TOKEN" ] && ok "E0 admin 登录成功" || no "E0 admin 登录失败"
OID=$(q "select order_id from biz_order where order_no='$ORDER_NO'")
DEL=$(curl -s -X DELETE "$BASE/biz/order/$OID" -H "Authorization: Bearer $TOKEN")
chk "E1 删已支付订单被拒（code=500）" "$(python3 -c "import sys,json;print(json.loads('''$DEL''').get('code'))")" "500"
echo "     拒绝原因：$(python3 -c "import json;print(json.loads('''$DEL''').get('msg'))")"
chk "E2 订单确实还在" "$(q "select count(*) from biz_order where order_no='$ORDER_NO'")" "1"

BID=$(q "select bill_id from biz_pay_bill where bill_no='$BILL_NO'")
DELB=$(curl -s -X DELETE "$BASE/biz/bill/$BID" -H "Authorization: Bearer $TOKEN")
chk "E3 删已完成买单被拒" "$(python3 -c "import json;print(json.loads('''$DELB''').get('code'))")" "500"
chk "E4 买单确实还在" "$(q "select count(*) from biz_pay_bill where bill_no='$BILL_NO'")" "1"

# 待支付订单应当允许删除（不能一刀切拦死，否则脏数据没法清）
q "insert into biz_order (order_no, merchant_id, store_id, member_id, product_id, product_name,
      num, price, total_amount, pay_amount, status, create_time)
   values ('DSMOKEPAY${$}X', $MID, $STORE, 990004, $PROD, 'SMOKE待支付', 1, 10, 10, 10, '0', sysdate());"
UID2=$(q "select order_id from biz_order where order_no='DSMOKEPAY${$}X'")
DELC=$(curl -s -X DELETE "$BASE/biz/order/$UID2" -H "Authorization: Bearer $TOKEN")
chk "E5 待支付订单允许删除（不能一刀切）" "$(python3 -c "import json;print(json.loads('''$DELC''').get('code'))")" "200"

echo
echo "=== 结果 PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" = "0" ] || exit 1
