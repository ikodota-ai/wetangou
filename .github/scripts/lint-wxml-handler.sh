#!/usr/bin/env bash
# 扫 WXML 上「绑了事件但 js 里没这个方法」的死按钮
#
# 为什么需要：小程序里 bindtap 指向一个不存在的方法，**既不报错也不警告**，
# 点下去就是完全没反应。这类缺陷编译过、接口正常、日志干净，只有真机上
# 一个个按过去才发现 —— 而它伤的往往是最高频的动作。项目里已经复发 4 次：
#   pages/merchant/bill      「确认买单」按钮      → 按钮已删（端点也不该由店员调）
#   pages/merchant/history   「onConfirm」         → 整页重写时清掉
#   pages/merchant/order     「核销」按钮          → 店员在今日订单里点核销毫无反应，
#                                                   只能退出去改走核销页手抄核销码
#   pages/merchant/verify    「核销记录」「切换回会员」「最近核销」点一条
#                                                   → 其中「核销记录」是刚做出来的
#                                                     verify/records 在核销页的唯一入口
#
# 误报排除（这两类是合法写法，不是死按钮）：
#   1) catchtap="noop" —— 阻止冒泡的惯用法，故意什么都不做（弹层/抽屉的内容区
#      要拦住点击不让穿透到遮罩），js 里没有 noop 也不影响
#   2) 出现在 WXML 注释 <!-- --> 里的绑定 —— 已经被删掉的按钮，注释只是留个说明
#
# 用法：bash .github/scripts/lint-wxml-handler.sh
# 退出码：0 干净 / 1 有死按钮

cd "$(dirname "$0")/../.." || exit 1

python3 - <<'PY'
import os, re, sys

# 阻止冒泡占位：故意不定义，见文件头说明
ALLOW = {'noop'}
ev = re.compile(r'(?:bind|catch|capture-bind|capture-catch):?([a-zA-Z]+)\s*=\s*"([^"]*)"')
comment = re.compile(r'<!--.*?-->', re.S)

bad = 0
scanned = 0
for root in ('miniprogram7/pages', 'miniprogram7/components'):
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if not fn.endswith('.wxml'):
                continue
            wx = os.path.join(dp, fn)
            js = wx[:-5] + '.js'
            if not os.path.exists(js):
                continue
            scanned += 1
            # 注释里的绑定是已删按钮的说明，不算
            wsrc = comment.sub('', open(wx, encoding='utf-8').read())
            jsrc = open(js, encoding='utf-8').read()
            seen = set()
            for m in ev.finditer(wsrc):
                h = m.group(2).strip()
                # 空值 / 动态绑定 {{...}} 无法静态判定
                if not h or '{' in h or h in ALLOW or h in seen:
                    continue
                seen.add(h)
                # js 里方法可写成 h(...) 简写、h: function、h: (...) =>
                if re.search(r'\b%s\s*\(' % re.escape(h), jsrc) or \
                   re.search(r'\b%s\s*:' % re.escape(h), jsrc):
                    continue
                print('  ❌ %s: bind*="%s" 在 %s 里没有定义，点了没反应' % (wx, h, os.path.basename(js)))
                bad += 1

print()
if bad:
    print('lint-wxml-handler: 扫 %d 个 wxml，发现 %d 个死按钮' % (scanned, bad))
    sys.exit(1)
print('lint-wxml-handler: 扫 %d 个 wxml，未发现死按钮' % scanned)
PY
