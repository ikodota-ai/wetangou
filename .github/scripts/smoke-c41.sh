#!/usr/bin/env bash
# C41 「商家端商品创建+列表+搭配+上下架」端到端 smoke

# fixture 自备（见 .github/scripts/lib/smoke-fixture.sh）
# 背景：62 smoke 串行跑会互相污染（改密码/耗库存/覆盖 openid），造成假 FAIL
source "$(dirname "$0")/lib/smoke-fixture.sh"
fx_ensure_mock_on
fx_reset_staff_pwd staff001

set -e
H=http://127.0.0.1:8080
LOG=/tmp/jrun-c41.log
TS=$(date +%s | tail -c 7)
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

echo "C41 「商家端商品创建+列表+搭配+上下架」 smoke:"

# A) 商家登录拿 token
LOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"code\":\"smoke_c41_mer_${TS}\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c41_mer\"}" $H/api/auth/login)
# MTOK 原先用「会员 token」冒充商家建商品；V5-1 给 /api/product/add 加了
# @RequireRole({OWNER,MANAGER}) 后必须用真实 OWNER token（会员建商品本就该 403）。
MTOK=$(fx_login_owner)
[ -n "$MTOK" ] && echo "  ✅ A) 商家登录" && PASS=$((PASS+1)) || { echo "  ❌ A) login"; FAIL=$((FAIL+1)); exit 1; }

# B) 创建团购商品
ADD=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"storeIds\":\"200\",\"typeCode\":\"GROUPON\",\"productName\":\"C41_$TS\",\"subtitle\":\"测试副标题\",\"price\":9.9,\"marketPrice\":29,\"stock\":100,\"sales\":10,\"validityDays\":30,\"productType\":\"0\",\"status\":\"0\",\"delFlag\":\"0\",\"sort\":0,\"bookingRequired\":0,\"maxPerOrder\":1}" $H/api/product/add)
PID=$(echo "$ADD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('productId') or d.get('data',{}).get('productId',0))")
[ -n "$PID" ] && [ "$PID" -gt 0 ] && echo "  ✅ B) 创建商品 id=$PID" && PASS=$((PASS+1)) || { echo "  ❌ B) add: $ADD"; FAIL=$((FAIL+1)); exit 1; }

# C) 商品列表
LIST=$(curl -s -H "Authorization: Bearer $MTOK" "$H/api/product/list?merchantId=1&pageNum=1&pageSize=20&typeCode=GROUPON")
chk "C) 列表接口返回" "C41_$TS" "$LIST"
chk "C+) status=0 在列表里" "\"status\":\"0\"" "$LIST"

# D) 编辑商品（搭配保存后回填）
EDIT=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"productId\":$PID,\"productName\":\"C41_$TS\",\"subitemPickRuleJson\":\"[{\\\"name\\\":\\\"套餐\\\",\\\"subitemType\\\":\\\"GROUPON\\\",\\\"pickQuantity\\\":1,\\\"price\\\":99}]\"}" $H/api/product)
chk "D) PUT 编辑商品成功" "操作成功" "$EDIT"
echo "$EDIT" | grep -q "操作成功" && echo "  ✅ D+) 返回操作成功" && PASS=$((PASS+1))

# E) 上下架：下架
DOWN=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"productId\":$PID,\"status\":\"1\"}" $H/api/product/status)
chk "E) 下架成功" "操作成功" "$DOWN"
ST=$(python3 -c "
import pymysql
c=pymysql.connect(host='127.0.0.1',port=3306,user='root',password='133301',database='ry-vue')
cur=c.cursor(); cur.execute(\"SELECT status FROM biz_product WHERE product_id=$PID\"); print(cur.fetchone()[0])
")
[ "$ST" = "1" ] && echo "  ✅ E+) DB status=1" && PASS=$((PASS+1)) || { echo "  ❌ E+) status=$ST"; FAIL=$((FAIL+1)); }

# F) 重新上架
UP=$(curl -s -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $MTOK" \
  -d "{\"productId\":$PID,\"status\":\"0\"}" $H/api/product/status)
chk "F) 重新上架成功" "操作成功" "$UP"

# G) 商品搭配：添加商品组
# 用 admin token 调 subitem admin 接口
ALOGIN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' $H/login)
ATOK=$(echo "$ALOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
[ -n "$ATOK" ] || ATOK=$MTOK  # fallback
GR=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ATOK" \
  -d "{\"productId\":$PID,\"groupName\":\"主食\",\"pickRule\":\"ALL\",\"sort\":1}" $H/biz/productSubitem/group)
# BizProductSubitemController.addGroup 返回 rows=1 不带 groupId，从 list 接口取最新的
GID=$(curl -s -H "Authorization: Bearer $ATOK" "$H/biz/productSubitem/groups?productId=$PID" | python3 -c "import sys,json; d=json.load(sys.stdin); rows=d.get('data') or d.get('rows') or []; print(rows[0].get('groupId',0) if rows else 0)" 2>/dev/null)
[ -n "$GID" ] && [ "$GID" -gt 0 ] && echo "  ✅ G) 添加商品组 id=$GID" && PASS=$((PASS+1)) || { echo "  ❌ G) group: $GR"; FAIL=$((FAIL+1)); }

# H) 添加单品
SUB=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ATOK" \
  -d "{\"productId\":$PID,\"groupId\":$GID,\"subitemName\":\"红烧肉\",\"quantity\":1,\"price\":15.0,\"subitemType\":\"GROUPON\",\"pickQuantity\":1,\"totalValue\":15.0}" $H/biz/productSubitem/subitem)
chk "H) 添加子品成功" "操作成功" "$SUB"

# I) 列出商品组
GRL=$(curl -s -H "Authorization: Bearer $ATOK" "$H/biz/productSubitem/groups?productId=$PID")
chk "I) 列出商品组含主食" "主食" "$GRL"
SUBLIST=$(curl -s -H "Authorization: Bearer $ATOK" "$H/biz/productSubitem/subitem?groupId=$GID")
chk "I+) 含子品红烧肉" "红烧肉" "$SUBLIST"


# J) 未登录调 edit → 应被拒
DENY=$(curl -s -X PUT -H "Content-Type: application/json" \
  -d "{\"productId\":$PID,\"productName\":\"hack\"}" $H/api/product)
chk "J) 未登录编辑被拒" "401" "$DENY"

