#!/usr/bin/env python3
"""统计脱离商户上下文的门店选择器。

按 <biz-select ...> 整个标签匹配，不能逐行 grep：
product/create.vue 的属性是分多行写的，逐行看永远找不到同一行上的 merchant-id。
"""
import io, os, re, sys

root_dir = sys.argv[1]
bad = []
for root, _, files in os.walk(root_dir):
    for fn in files:
        if not fn.endswith('.vue'):
            continue
        path = os.path.join(root, fn)
        text = io.open(path, encoding='utf-8').read()
        for m in re.finditer(r'<biz-select\b[^>]*>', text, re.S):
            tag = m.group(0)
            if 'type="store"' in tag and 'merchant-id' not in tag:
                bad.append(path)
for p in bad:
    print(p, file=sys.stderr)
print(len(bad))
