#!/usr/bin/env bash
# sql/upgrade/ 增量迁移脚本的静态检查。
#
# 为什么要这个 lint：实测发现 biz_mpauth_menu_fix.sql 和 biz_category_menu_rename.sql
# 都按写死的 menu_id 定位菜单，而 menu_id 由各菜单脚本的插入顺序决定、不同库不一致 ——
# init-all.sh 建出来的全新库里 2294/2295/2296 是「在线预约」的增删改按钮，
# 旧版脚本把它们当 mpauth 按钮绑给了 admin/platform，还从代理商/商户手里 DELETE 掉。
# 这类错误不报错、不回滚，只会静默改错权限，只能靠静态检查挡住。
#
# 规则：
#   1) 每个 upgrade 脚本必须被接进部署链（init-all.sh + build-merged.py），
#      否则全新库会缺这部分（历史上 6 个脚本就是这么漏的）
#   2) 非注释代码里不许出现写死的 4 位 menu_id，改用 perms / component 定位
#   3) 必须以 -- 注释开头（声明用途 + 幂等性）
set -uo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0

for f in sql/upgrade/*.sql; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .sql)

  # 1) 接进部署链
  # init-all.sh 里的 run 行常带行尾注释，build-merged.py 里是独占一行的名字
  if grep -qE "^[[:space:]]*run[[:space:]]+$name([[:space:]]|#|\$)" sql/deploy/init-all.sh \
     && grep -qE "^$name\$" sql/deploy/build-merged.py; then
    echo "  ✅ $name 已接入部署链"; PASS=$((PASS+1))
  else
    echo "  ❌ $name 未接入部署链（init-all.sh 的 5.5 段 + build-merged.py 的 BUSINESS 都要加）"
    FAIL=$((FAIL+1))
  fi

  # 2) 非注释行不许写死 menu_id
  hard=$(grep -vE '^[[:space:]]*--' "$f" | grep -nE "menu_id[[:space:]]*(=|IN|in)[[:space:]]*\(?[[:space:]]*[0-9]{3,}" | head -3)
  if [ -z "$hard" ]; then
    echo "  ✅ $name 未写死 menu_id"; PASS=$((PASS+1))
  else
    echo "  ❌ $name 写死了 menu_id（menu_id 各库不一致，请改用 perms / component 定位）:"
    echo "$hard" | sed 's/^/       /'
    FAIL=$((FAIL+1))
  fi

  # 3) 以注释开头
  if head -1 "$f" | grep -qE '^[[:space:]]*--'; then
    echo "  ✅ $name 有头部说明"; PASS=$((PASS+1))
  else
    echo "  ❌ $name 首行不是 -- 注释（需说明用途与幂等性）"; FAIL=$((FAIL+1))
  fi
done

echo ""
echo "sql upgrade lint: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
