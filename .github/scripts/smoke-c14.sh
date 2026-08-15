#!/usr/bin/env bash
# C14 协议链路端到端（小程序用户/隐私/推客协议）
# 验证:
#   A) GET /api/agreement?type=user 返 user 协议
#   B) GET /api/agreement?type=privacy 返 privacy 协议
#   C) GET /api/agreement?type=distributor 返 distributor 协议
#   D) 不存在的 type 返 null data（不报错）
#   E) status=1 停用后不返
#   F) anonymous 端点（不需鉴权）
#   G) mini 端 page 没硬编码协议内容（按 type 走 API）
#   H) merchantId 共享表隔离（IN 0, ctx.merchantId）
set -e
H=http://127.0.0.1:8080
DB_CMD="/usr/local/mysql/bin/mysql -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue"
PASS=0; FAIL=0
chk() { local n="$1" e="$2" g="$3"
  if [[ "$g" == *"$e"* ]]; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (want ~$e, got: ${g:0:200})"; FAIL=$((FAIL+1)); fi
}

# fixture: 3 个 typeCode 各一条 + 1 条 status=1
A_USER=$($DB_CMD -N -e "INSERT INTO biz_agreement (merchant_id, agreement_type, title, content, status, create_time) VALUES (1, 'c14user', 'C14用户协议', '<p>c14 test</p>', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
A_PRIV=$($DB_CMD -N -e "INSERT INTO biz_agreement (merchant_id, agreement_type, title, content, status, create_time) VALUES (1, 'c14privacy', 'C14隐私协议', '<p>c14 test</p>', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
A_DIST=$($DB_CMD -N -e "INSERT INTO biz_agreement (merchant_id, agreement_type, title, content, status, create_time) VALUES (1, 'c14dist', 'C14推客协议', '<p>c14 test</p>', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
A_DIS=$($DB_CMD -N -e "INSERT INTO biz_agreement (merchant_id, agreement_type, title, content, status, create_time) VALUES (1, 'c14dis', 'C14停用', '<p>x</p>', '1', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
A_OTHER_M=$($DB_CMD -N -e "INSERT INTO biz_agreement (merchant_id, agreement_type, title, content, status, create_time) VALUES (2, 'c14other', 'C14其他商户', '<p>x</p>', '0', NOW()); SELECT LAST_INSERT_ID();" 2>/dev/null | tail -1)
echo "[init] user=$A_USER priv=$A_PRIV dist=$A_DIST disabled=$A_DIS other_mid=2=$A_OTHER_M"

cleanup() {
  [ "$A_USER" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_agreement WHERE agreement_id=$A_USER;" 2>/dev/null || true
  [ "$A_PRIV" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_agreement WHERE agreement_id=$A_PRIV;" 2>/dev/null || true
  [ "$A_DIST" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_agreement WHERE agreement_id=$A_DIST;" 2>/dev/null || true
  [ "$A_DIS" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_agreement WHERE agreement_id=$A_DIS;" 2>/dev/null || true
  [ "$A_OTHER_M" -gt 0 ] && $DB_CMD -e "DELETE FROM biz_agreement WHERE agreement_id=$A_OTHER_M;" 2>/dev/null || true
}
trap cleanup EXIT

echo "C14 协议链路 smoke:"

# A) user
A=$(curl -s "$H/api/agreement?type=c14user")
chk "A user 协议 200" "操作成功" "$A"
chk "A user 协议 title=C14用户协议" "C14用户协议" "$A"

# B) privacy
B=$(curl -s "$H/api/agreement?type=c14privacy")
chk "B privacy 协议 title=C14隐私协议" "C14隐私协议" "$B"

# C) distributor
C=$(curl -s "$H/api/agreement?type=c14dist")
chk "C distributor 协议 title=C14推客协议" "C14推客协议" "$C"

# D) 不存在 type 返 null
D=$(curl -s "$H/api/agreement?type=nonexistent_c14_xxx")
chk "D 不存在 type 不报错" "操作成功" "$D"
D_NULL=$(echo "$D" | python3 -c "import sys,json; print('YES' if json.load(sys.stdin).get('data') is None else 'NO')")
[ "$D_NULL" = "YES" ] && echo "  ✅ D 不存在 type data=null" && PASS=$((PASS+1)) || { echo "  ❌ D data 不为 null: $D"; FAIL=$((FAIL+1)); }

# E) status=1 停用后不返（c14dis 不会出现在 c14user 里因为 type 不同，但 DB 里有）
E=$(curl -s "$H/api/agreement?type=c14dis")
E_NULL=$(echo "$E" | python3 -c "import sys,json; print('YES' if json.load(sys.stdin).get('data') is None else 'NO')")
[ "$E_NULL" = "YES" ] && echo "  ✅ E status=1 不返" && PASS=$((PASS+1)) || { echo "  ❌ E status=1 仍返: $E"; FAIL=$((FAIL+1)); }

# F) anonymous 端点
F=$(curl -sI "$H/api/agreement?type=c14user" | head -1)
echo "$F" | grep -q "200" && echo "  ✅ F anonymous 200" && PASS=$((PASS+1)) || { echo "  ❌ F $F"; FAIL=$((FAIL+1)); }

# G) mini 端 agreement page 走 API
grep -q "/api/agreement" "$(dirname $0)/../../miniprogram7/utils/request.js" && echo "  ✅ G mini 端 agreement API 已接入" && PASS=$((PASS+1)) || { echo "  ❌ G mini 端缺 agreement API"; FAIL=$((FAIL+1)); }
# 检查 mini 端有 agreement 页面
ls "$(dirname $0)/../../miniprogram7/pages/agreement/" 2>/dev/null | head -3 && echo "  ✅ G mini 端 agreement 页面存在" && PASS=$((PASS+1)) || { echo "  ❌ G mini 端 agreement 页面缺失"; FAIL=$((FAIL+1)); }

# H) shared 表隔离 (ctx.merchantId=1 看不到 merchantId=2)
H_RES=$(curl -s "$H/api/agreement?type=c14other")
H_NULL=$(echo "$H_RES" | python3 -c "import sys,json; print('YES' if json.load(sys.stdin).get('data') is None else 'NO')")
[ "$H_NULL" = "YES" ] && echo "  ✅ H shared 隔离: ctx=1 看不到 merchantId=2" && PASS=$((PASS+1)) || { echo "  ❌ H shared 失效: $H_RES"; FAIL=$((FAIL+1)); }

# I) 已有的真实协议（user/privacy/distributor）也能拉到
I=$(curl -s "$H/api/agreement?type=user")
chk "I 已有 user 协议 200" "操作成功" "$I"
chk "I 已有 user 协议 包含 用户服务协议" "用户服务协议" "$I"

echo ""
echo "C14 smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
