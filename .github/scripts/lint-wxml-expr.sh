#!/usr/bin/env bash
# 扫 WXML 里不合法的表达式调用
#
# 为什么需要：小程序 WXML 的 {{ }} 只支持有限表达式，**不能调 Page 的方法，
# 也不能调数组/字符串的方法**。写错不会报错、不会白屏，只是静默渲染成空 ——
# 这类 bug 已经在项目里复发过 5 次：
#   pages/merchant/bill      {{statusText(item.status)}}        状态列全空白
#   pages/merchant/order     {{statusText(item.status)}}        同上
#   pages/merchant/history   {{statusText(item.status)}}        同上
#   pages/merchant/home      {{orderStatusText(item.status)}}   最近订单状态空白
#   pages/merchant/product/list  {{typeNameOf(item.typeCode)}}  类型标签是空色块
#   pages/merchant/product/combo {{totalCount}} {{typeIdxOf(..)}} 汇总空 + picker 不回显
# 正确做法：在 js 里算好派生字段塞进 setData（bill 页就是范本）。
#
# 用法：bash .github/scripts/lint-wxml-expr.sh
# 退出码：0 干净 / 1 有问题

cd "$(dirname "$0")/../.." || exit 1
ERR=0

# 允许在模板里出现的表达式函数（wxs 模块导出的除外，见下）
# WXML 原生不支持任何函数调用，这里只放行 wxs 模块名前缀形式 mod.fn()
for f in $(find miniprogram7/pages miniprogram7/components -name '*.wxml' 2>/dev/null); do
  d=$(dirname "$f")
  js="$d/$(basename "$f" .wxml).js"
  # 该 wxml 里通过 <wxs> 引入的模块名
  wxsmods=$(grep -oE '<wxs[^>]+module="[a-zA-Z0-9_]+"' "$f" 2>/dev/null | grep -oE 'module="[a-zA-Z0-9_]+"' | cut -d'"' -f2 | tr '\n' '|')

  # 抓 {{ ... }} 里形如 name( 的调用
  calls=$(grep -o '{{[^}]*}}' "$f" 2>/dev/null | grep -oE '[a-zA-Z_$][a-zA-Z0-9_$]*\s*\(' | sed 's/[[:space:]]*($//' | tr -d '(' | sort -u)

  for c in $calls; do
    # 语言字面量不是调用
    case "$c" in true|false|null|undefined) continue;; esac
    # wxs 模块导出的函数：形式是 mod.fn()，前缀已被 grep 掉，这里放行 wxs 模块名本身
    if [ -n "$wxsmods" ] && echo "$c" | grep -qE "^($wxsmods)$"; then continue; fi
    # 命中 Page 里定义的方法 → 必然渲染成空
    if [ -f "$js" ] && grep -qE "^[[:space:]]+(async )?$c[[:space:]]*\(|^[[:space:]]+$c:[[:space:]]*function" "$js"; then
      echo "  ❌ $f: {{$c(...)}} 调的是 Page 方法，WXML 调不到，会渲染成空"
      echo "     → 在 $js 里算好派生字段塞进 setData（参考 pages/merchant/bill/index.js）"
      ERR=$((ERR+1))
      continue
    fi
    # 没有 wxs 模块却出现函数调用 → 同样非法
    if [ -z "$wxsmods" ]; then
      echo "  ❌ $f: {{$c(...)}} 是函数调用，但本文件没有 <wxs> 模块，WXML 不支持"
      ERR=$((ERR+1))
    fi
  done

  # 数组/字符串方法调用：{{xxx.indexOf(..)}} / .includes( / .map( / .filter( / .join(
  bad=$(grep -o '{{[^}]*}}' "$f" 2>/dev/null | grep -oE '\.(indexOf|includes|map|filter|join|slice|split|toFixed|reduce|find|some|every)\s*\(' | sort -u)
  if [ -n "$bad" ]; then
    for b in $bad; do
      echo "  ❌ $f: {{...$b..}} WXML 不支持调数组/字符串方法，会得到 undefined"
      ERR=$((ERR+1))
    done
  fi
done

if [ "$ERR" -eq 0 ]; then
  echo "lint-wxml-expr: 未发现 WXML 非法表达式调用"
  exit 0
fi
echo "lint-wxml-expr: 发现 $ERR 处问题"
exit 1
