#!/usr/bin/env bash
# MyBatis mapper XML 静态 lint
# 防止:
#   1) </mapper> 之后还有非空白内容（孤立行，e5fc6735 类 bug）
#   2) XML 非法（ElementTree 解析失败）
#   3) 缺少 </mapper> 结束标签
#   4) namespace 重复
#
# 用法: bash .github/scripts/lint-mybatis.sh [mapper_dir]
# 默认扫 ruoyi-system/src/main/resources/mapper
set -e

MAPPER_DIR="${1:-ruoyi-system/src/main/resources/mapper}"

if [ ! -d "$MAPPER_DIR" ]; then
  echo "FAIL: $MAPPER_DIR 不存在" >&2
  exit 1
fi

# 单次 Python 调用：扫所有 xml + namespace 唯一性 + 尾部孤立行
python3 - "$MAPPER_DIR" <<'PY'
import sys, os
import xml.etree.ElementTree as ET
from collections import Counter

mapper_dir = sys.argv[1]
errors = 0
total = 0
namespaces = Counter()

for root, _, files in os.walk(mapper_dir):
    for f in files:
        if not f.endswith('.xml'):
            continue
        path = os.path.join(root, f)
        total += 1
        # 1) 解析
        try:
            tree = ET.parse(path)
        except ET.ParseError as e:
            print(f"PARSE_ERROR: {path}: {e}", file=sys.stderr)
            errors += 1
            continue
        # 2) namespace 唯一
        root_el = tree.getroot()
        ns = root_el.get('namespace') if root_el.tag == 'mapper' else None
        if ns:
            namespaces[ns] += 1
        # 3) 尾部孤立行（原始字节判断）
        with open(path, 'rb') as fh:
            data = fh.read()
        end = data.rfind(b'</mapper>')
        if end == -1:
            print(f"NO_END: {path} 缺 </mapper>", file=sys.stderr)
            errors += 1
        else:
            trailing = data[end + len(b'</mapper>'):].strip()
            if trailing:
                print(f"TRAILING: {path} </mapper> 后还有 {len(trailing)} 字节: {trailing[:60]!r}", file=sys.stderr)
                errors += 1

# 4) namespace 重复
dups = {ns: c for ns, c in namespaces.items() if c > 1}
if dups:
    for ns, c in dups.items():
        print(f"DUP_NAMESPACE: {ns} 出现 {c} 次", file=sys.stderr)
    errors += len(dups)

print(f"lint-mybatis: scanned {total} xml, errors={errors}")
sys.exit(1 if errors > 0 else 0)
PY
