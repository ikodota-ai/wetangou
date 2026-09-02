#!/usr/bin/env bash
# smoke-bizcode-numeric.sh
#
# 守「HTTP 200 + 业务失败码」这条链的两端一致性。
#
# 根因（实测）：后端有三条错误输出链，HTTP 状态都是 200：
#   * AjaxResult / ServiceException → {"code":500,...}   数字
#   * DistributorAuthInterceptor    → {"code":"403",...}  字符串（手写 JSON，已修）
#   * RoleAuthInterceptor           → {"code":"403",...}  字符串（手写 JSON，已修）
# 小程序 utils/request.js 按业务码分派。字符串 code 会被漏判成「成功」，
# 实测后果：非推客会员提交提现，后端返「您还不是推客」，前端却弹「提现申请已提交」；
# 店员点「招人」拿到角色 403，前端进成功分支渲染出一张空白邀请码。
#
# 本脚本用真实端点断言这些错误响应里的 code 是 JSON 数字而非字符串。
set -uo pipefail
BASE="${BASE:-http://localhost:8080}"
APP="${APP:-wx9e147c4e2151b123}"
PASS=0; FAIL=0

ck() { # ck 名称 实际 期望
  if [ "$2" = "$3" ]; then echo "PASS | $1"; PASS=$((PASS+1));
  else echo "FAIL | $1 | got=[$2] exp=[$3]"; FAIL=$((FAIL+1)); fi
}

# 取 body.code 的 JSON 原生类型 + 值
codetype() { python3 -c "
import sys,json
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print('parse_error'); sys.exit()
c=d.get('code')
print(('int' if isinstance(c,bool) is False and isinstance(c,int) else type(c).__name__)+':'+str(c))
"; }

# ---- 会员 token（普通会员，不是推客）
MTOK=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -H "X-App-Id: $APP" \
  -d '{"code":"smk_bizcode_member","appid":"'"$APP"'"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token") or "")')
ck "会员登录拿到 token" "$([ -n "$MTOK" ] && echo yes || echo no)" "yes"

# ---- 1) 推客拦截器 403：非推客会员打推客端点
for u in "/api/distributor/center" "/api/distributor/fans" "/api/distributor/withdraw/list"; do
  R=$(curl -s "$BASE$u" -H "Authorization: Bearer $MTOK" -H "X-App-Id: $APP" | codetype)
  ck "非推客打 $u → code 是数字 403" "$R" "int:403"
done

# 提现是最危险的一个：前端漏判会弹「提现申请已提交」
R=$(curl -s -X POST "$BASE/api/distributor/withdraw" -H "Authorization: Bearer $MTOK" -H "X-App-Id: $APP" \
  -H 'Content-Type: application/json' -d '{"amount":10,"withdrawType":"WECHAT","account":"a","accountName":"b"}' | codetype)
ck "非推客提交提现 → code 是数字 403（不能是字符串）" "$R" "int:403"

# ---- 2) 角色拦截器 403：店员打 OWNER/MANAGER 专属端点
STOK=$(curl -s -X POST "$BASE/api/merchant/staff/login" -H 'Content-Type: application/json' -H "X-App-Id: $APP" \
  -d '{"username":"staff_c43","password":"admin123"}' \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("token") or (d.get("data") or {}).get("token") or "")')
ck "店员登录拿到 token" "$([ -n "$STOK" ] && echo yes || echo no)" "yes"

for u in "/api/merchant/staff/staff/list" "/api/merchant/staff/staff/audit/list" "/api/merchant/staff/staff/invite/list"; do
  R=$(curl -s "$BASE$u" -H "Authorization: Bearer $STOK" -H "X-App-Id: $APP" | codetype)
  ck "店员打 $u → code 是数字 403" "$R" "int:403"
done
R=$(curl -s -X POST "$BASE/api/merchant/staff/staff/invite" -H "Authorization: Bearer $STOK" -H "X-App-Id: $APP" \
  -H 'Content-Type: application/json' -d '{"role":"STAFF"}' | codetype)
ck "店员点「招人」 → code 是数字 403" "$R" "int:403"
R=$(curl -s -X POST "$BASE/api/merchant/staff/staff/resetPwd" -H "Authorization: Bearer $STOK" -H "X-App-Id: $APP" \
  -H 'Content-Type: application/json' -d '{"userId":59}' | codetype)
ck "店员重置密码 → code 是数字 403" "$R" "int:403"

# ---- 3) 会员拦截器 401 本来就是数字，别被顺手改坏
R=$(curl -s "$BASE/api/member/profile" -H "X-App-Id: $APP" | codetype)
ck "无 token 打会员端点 → code 是数字 401" "$R" "int:401"
R=$(curl -s "$BASE/api/distributor/center" -H "Authorization: Bearer BAD.TOKEN.X" -H "X-App-Id: $APP" | codetype)
ck "坏 token 打推客端点 → code 是数字 401" "$R" "int:401"

# ---- 4) ServiceException 那条链（数字 500）保持不变
R=$(curl -s "$BASE/api/product/999999999" -H "Authorization: Bearer $MTOK" -H "X-App-Id: $APP" | codetype)
case "$R" in
  int:*) ck "不存在的商品 → code 仍是数字" "int" "int" ;;
  *)     ck "不存在的商品 → code 仍是数字" "$R" "int" ;;
esac

# ---- 5) 成功响应仍是数字 200
R=$(curl -s "$BASE/api/store/list" -H "X-App-Id: $APP" | codetype)
ck "门店列表成功 → code 是数字 200" "$R" "int:200"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
