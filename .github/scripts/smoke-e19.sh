#!/usr/bin/env bash
# E19 写入端点越权防护验证
#   - add: TenantInsertInterceptor 拦 (无权向非名下商户写入数据 → 500)
#   - edit: TenantSqlInterceptor 改写 WHERE merchant_id=ctx (跨 mid 0 行 → 500)
#   - delete: 同 edit (跨 mid 0 行 → 500)
#   - edit 自己传 mid=2: 200 但 DB mid 仍是 1 (TenantSqlInterceptor 保护)
set -e
H=http://127.0.0.1:8080
J() { python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"; }
T1=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"agent001","password":"admin123"}' $H/login | J)
[ ${#T1} -gt 50 ] || { echo "login fail"; exit 1; }
PASS=0; FAIL=0
chk() {
  local name="$1" expect="$2" got="$3"
  if [[ "$got" == *"$expect"* ]]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (want ~$expect, got: ${got:0:200})"
    FAIL=$((FAIL+1))
  fi
}
P() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code',''), d.get('msg',''))"; }

echo "E19 写入端点越权防护 (agent001 已 grant biz:order/voucher/agreement/banner/album perms):"

# 1) add 越权
echo "1) add mid=2 别人 (期望 500 无权向非名下商户写入数据)"
for spec in "voucher:voucher" "agreement:agreement" "banner:banner" "album:album"; do
  name="${spec%:*}"; path="${spec#*:}"
  case $name in
    voucher) data='{"merchantId":2,"storeId":1,"voucherName":"HIJACK","faceValue":999,"total":1,"received":0,"status":"0"}';;
    agreement) data='{"agreementType":"SERVICE","merchantId":2,"title":"HIJACK","content":"x","status":"0"}';;
    banner) data='{"merchantId":2,"title":"HIJACK","imageUrl":"http://x","position":"home","status":"0","sort":0}';;
    album) data='{"merchantId":2,"storeId":1,"imageUrl":"http://x/hi.jpg","albumType":"0","sort":0}';;
  esac
  chk "POST /biz/$path mid=2" "无权向非名下商户写入数据" "$(curl -s -X POST -H "Authorization: Bearer $T1" -H "Content-Type: application/json" -d "$data" $H/biz/$path | P)"
done

# 2) edit 自己 (999502 mid=1) 传 mid=2 → 期望 200 但 DB mid 仍 1
echo "2) edit 自己 999502 传 mid=2 (期望 200 操作成功 + DB mid 仍 1)"
chk "PUT /biz/voucher 999502 mid=2" "200 操作成功" "$(curl -s -X PUT -H "Authorization: Bearer $T1" -H "Content-Type: application/json" -d '{"voucherId":999502,"merchantId":2,"storeId":1,"voucherName":"HIJACK","faceValue":999,"total":1,"status":"0"}' $H/biz/voucher | P)"
DB_MID=$(/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue -N -e "SELECT merchant_id FROM biz_voucher WHERE voucher_id=999502;" 2>/dev/null)
chk "  DB 999502 merchantId (期望 1)" "1" "$DB_MID"

# 3) delete 别人 (999501 mid=2) → 期望 500 操作失败
echo "3) delete 别人 999501 (mid=2) (期望 500 操作失败 + DB 仍在)"
chk "DELETE /biz/voucher/999501" "500 操作失败" "$(curl -s -X DELETE -H "Authorization: Bearer $T1" $H/biz/voucher/999501 | P)"
DB_EXISTS=$(/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue -N -e "SELECT COUNT(*) FROM biz_voucher WHERE voucher_id=999501;" 2>/dev/null)
chk "  DB 999501 still exists (期望 1)" "1" "$DB_EXISTS"

echo "E19 result: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ] || exit 1
