#!/usr/bin/env bash
# 全部 smoke 脚本语法静态检查（不需要 jar/DB）
# macos-14 runner 缺 docker + mysql-client，无法端到端跑 smoke
# 这里只做 bash -n 语法校验 + 检查 shebang + 检查 exit 路径
set -e
DIR="${1:-.github/scripts}"
FAIL=0
TOTAL=0

for s in $DIR/smoke-*.sh; do
  [ -f "$s" ] || continue
  TOTAL=$((TOTAL+1))
  # 1) shebang
  if ! head -1 "$s" | grep -q "^#!/usr/bin/env bash"; then
    echo "  ❌ $s: 缺 shebang"; FAIL=$((FAIL+1)); continue
  fi
  # 2) bash 语法
  if ! bash -n "$s"; then
    echo "  ❌ $s: bash 语法错"; FAIL=$((FAIL+1)); continue
  fi
  # 3) 必须有 exit 路径（trap cleanup EXIT 模式）
  if ! grep -q "trap.*EXIT" "$s"; then
    echo "  ⚠️  $s: 无 trap cleanup EXIT (可能 leak fixture)"
  fi
  echo "  ✅ $s"
done

echo ""
echo "smoke lint: total=$TOTAL fail=$FAIL"
[ "$FAIL" -eq 0 ]
