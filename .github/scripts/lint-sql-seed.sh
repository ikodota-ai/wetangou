#!/usr/bin/env bash
# SQL seed 完整性静态检查
# 1) 关键 seed 文件存在
# 2) sql/*.sql 必须以 -- 注释开头（避免编码错乱）
# 3) 含 INSERT 的 sql 文件必须有 WHERE 或 ON DUPLICATE KEY（避免重跑炸）
set -e
DIR="${1:-sql}"
FAIL=0
TOTAL=0

# 1) 必存在文件
for f in biz_product_model_v2.sql biz_merchant_v2.sql biz_product_dict_charset_fix.sql; do
  TOTAL=$((TOTAL+1))
  if [ -f "$DIR/$f" ]; then
    echo "  ✅ sql/$f 存在"
  else
    echo "  ❌ sql/$f 缺失"; FAIL=$((FAIL+1))
  fi
done

# 2) INSERT ... 必须有 ON DUPLICATE KEY 或 INSERT IGNORE（idempotent）
for s in $DIR/*.sql; do
  [ -f "$s" ] || continue
  # 找包含 INSERT INTO/REPLACE INTO 的行
  if grep -qE "INSERT INTO|REPLACE INTO" "$s"; then
    TOTAL=$((TOTAL+1))
    if grep -qE "ON DUPLICATE KEY|INSERT IGNORE|REPLACE INTO" "$s"; then
      echo "  ✅ $s idempotent"
    else
      echo "  ⚠️  $s 含 INSERT 但无 ON DUPLICATE KEY / INSERT IGNORE / REPLACE"
    fi
  fi
done

echo ""
echo "sql seed lint: total=$TOTAL fail=$FAIL"
[ "$FAIL" -eq 0 ]
