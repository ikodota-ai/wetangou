#!/usr/bin/env bash
# C38 P2-3 菜单/权限 + P2-2 字典化 smoke
set -e
H=http://127.0.0.1:8080
DB="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 ry-vue"
LOG=/tmp/jrun-c38.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk_ge() { local n="$1" g="$2" want="$3"
  if [ "$g" -ge "$want" ] 2>/dev/null; then echo "  ✅ $n ($g ≥ $want)"; PASS=$((PASS+1));
  else echo "  ❌ $n (got $g, want ≥$want)"; FAIL=$((FAIL+1)); fi
}
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C38 P2-3 菜单/权限 + P2-2 字典化 smoke:"

# A) admin 登录
TOK=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' $H/login | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$TOK" ] && echo "  ✅ A) admin 登录" && PASS=$((PASS+1)) || { echo "  ❌ A) 登录失败"; FAIL=$((FAIL+1)); exit 1; }

# B) getRouters 返 11+ TOP 菜单 + 3 个新菜单都在
ROUTERS=$(curl -s -H "Authorization: Bearer $TOK" $H/getRouters)
TOP_COUNT=$(echo "$ROUTERS" | python3 -c "import sys,json; d=json.load(sys.stdin); items = d if isinstance(d, list) else d.get('data', []); print(len(items))")
chk_ge "B) getRouters 返 ≥10 TOP 菜单" "$TOP_COUNT" "10"

HIT_PT=$(echo "$ROUTERS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('data', [])
hit = 0
for it in items:
    for c in it.get('children', []):
        p = (c.get('path','') or '').lower()
        if 'producttype' in p: hit+=1
        if 'productsubitem' in p: hit+=1
        if 'staffinvite' in p: hit+=1
print(hit)
")
chk "B+) getRouters 含 productType/productSubitem/staffInvite 3 个子菜单" "3" "$HIT_PT"

# B++) Tenant 节点存在 + StaffInvite 是其子
TENANT_CHILD=$(echo "$ROUTERS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('data', [])
for it in items:
    if 'tenant' in (it.get('path','') or '').lower() or it.get('name') == 'Tenant':
        for c in it.get('children', []):
            if 'staffinvite' in (c.get('path','') or '').lower(): print('Y'); break
        break
")
chk "B++) StaffInvite 挂在 Tenant 下" "Y" "$TENANT_CHILD"

# C) P2-2 字典 API
PT_LIST=$(curl -s -H "Authorization: Bearer $TOK" "$H/biz/productType/list?pageNum=1&pageSize=20&status=0")
PT_COUNT=$(echo "$PT_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('rows', [])))")
echo "  [C] 商品类型字典条数=$PT_COUNT"
chk_ge "C) 字典返 ≥8 条" "$PT_COUNT" "8"

# C+) appCreatable 字典
APP=$(curl -s -H "Authorization: Bearer $TOK" "$H/biz/productType/appCreatable")
APP_COUNT=$(echo "$APP" | python3 -c "import sys,json; d=json.load(sys.stdin); rows = d if isinstance(d, list) else d.get('data', d.get('rows', [])); print(len(rows) if isinstance(rows, list) else 0)")
echo "  [C+] app 可创建 type 数=$APP_COUNT"
chk_ge "C+) appCreatable 返 ≥6 条" "$APP_COUNT" "6"

# D) 字典关键 type 全在
for code in GROUPON VOUCHER TIMECARD STORED_CARD PERIOD_CARD HUIXIANG_CARD COMBO BILL BOOKING; do
  G=$(echo "$PT_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); rs=d.get('rows',[]); print('Y' if any(x.get('typeCode')=='$code' for x in rs) else 'N')")
  chk "D) 字典含 $code" "Y" "$G"
done

# E) 前端 typeText 用字典查
grep -q "typeList.*find\|this.typeList.find" ruoyi-ui/src/views/biz/product/index.vue && echo "  ✅ E) typeText 从字典查 (非 hardcode)" && PASS=$((PASS+1)) || { echo "  ❌ E) typeText 未用字典"; FAIL=$((FAIL+1)); }
grep -q "v-for=\"t in typeList\"" ruoyi-ui/src/views/biz/product/index.vue && echo "  ✅ E+) typeCode 下拉 v-for 渲染" && PASS=$((PASS+1)) || { echo "  ❌ E+) typeCode 下拉未 v-for"; FAIL=$((FAIL+1)); }
grep -q "loadTypeList\|selectProductTypeList" ruoyi-ui/src/views/biz/product/index.vue && echo "  ✅ E++) loadTypeList 调字典 API" && PASS=$((PASS+1)) || { echo "  ❌ E++) 未调字典 API"; FAIL=$((FAIL+1)); }

# F) 三方对账
SQL_COUNT=$($DB -N -e "SELECT COUNT(*) FROM biz_product_type WHERE status='0';" 2>/dev/null | head -1)
ADMIN_COUNT=$(grep -oE "(GROUPON|VOUCHER|TIMECARD|STORED_CARD|PERIOD_CARD|HUIXIANG_CARD|COMBO|BILL|BOOKING|MONTH|QUARTER|YEAR|PRESALE|PICKUP_VOUCHER)" ruoyi-ui/src/views/biz/product/index.vue | sort -u | wc -l | tr -d ' ')
echo "  [F] 三方对账: admin=$ADMIN_COUNT SQL=$SQL_COUNT"
[ "$SQL_COUNT" = "11" ] && echo "  ✅ F) SQL 字典 11 条" && PASS=$((PASS+1)) || { echo "  ❌ F) SQL=$SQL_COUNT (want 11)"; FAIL=$((FAIL+1)); }

echo ""
echo "C38 结果: $PASS PASS / $FAIL FAIL"
[ $FAIL -eq 0 ] && echo "🎉 ALL PASS" || echo "❌ 有失败用例"
