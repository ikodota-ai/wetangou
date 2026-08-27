#!/usr/bin/env bash
# Vue 单文件组件结构检查。
#
# 为什么要这个 lint：commit b9e51c3f 修「Component template should contain exactly
# one root element」时，diff 是 @@ -331,385 +331,5 @@ —— 把 385 行替换成 5 行，
# 连带整个 <script> 段（381 行）一起删了。
# 后果是 views/biz/mprelease/index.vue 只剩 <template>，页面打开直接白板：
#   TypeError: Cannot read properties of undefined (reading 'merchantId')
# 因为 codePackForm / wizardForm 这些 data 全没了。
#
# 这类错误 webpack 不报错（没 script 的 .vue 是合法的纯模板组件），
# 单测也覆盖不到（没有 UI 测试），只能靠静态检查挡住。
#
# 规则：
#   1) 有 <template> 且模板里引用了 v-model / @click / {{ }} 的组件，必须有 <script>
#   2) <template> 和 <script> 标签必须成对闭合
set -uo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0

# ParentView 是 RuoYi 内置的路由占位组件（只有一个 <router-view/>），合法的无 script 组件
WHITELIST="ruoyi-ui/src/components/ParentView/index.vue"

while IFS= read -r f; do
  case " $WHITELIST " in *" $f "*) continue;; esac

  has_tpl=$(grep -c '<template>' "$f" || true)
  has_scr=$(grep -c '<script' "$f" || true)

  # 1) 模板里有响应式绑定却没 script → 必然运行时报 undefined
  if [ "$has_tpl" -gt 0 ] && [ "$has_scr" -eq 0 ]; then
    if grep -qE 'v-model|@click|@change|\{\{' "$f"; then
      echo "  ❌ $f 有响应式模板但缺 <script>（data/methods 全丢，页面会白板）"
      FAIL=$((FAIL+1))
      continue
    fi
  fi

  # 2) 标签成对
  if [ "$has_scr" -gt 0 ]; then
    close=$(grep -c '</script>' "$f" || true)
    if [ "$has_scr" -ne "$close" ]; then
      echo "  ❌ $f <script> 与 </script> 数量不符（$has_scr vs $close）"
      FAIL=$((FAIL+1)); continue
    fi
  fi

  PASS=$((PASS+1))
done < <(find ruoyi-ui/src -name '*.vue' | sort)

# 3) 模板里 :model="X" 绑定的对象，X 必须在 data() 里声明。
#    Vue 的响应式只认 data 里声明过的键 —— 只在 methods 里 this.X = {...} 赋值的话，
#    初始渲染时 X 是 undefined，模板读 X.someField 直接抛
#    「Cannot read properties of undefined」，整页渲染中断变白板。
#    弹窗的 v-if 挡不住：el-form 的 :model 在外层就会先求值。
#    （实测 views/biz/mprelease/index.vue 的 wizardForm 就是这样，从 74f97704 起一直是白板）
echo ""
echo "检查 :model 绑定的对象是否在 data() 声明:"
MODEL_FAIL=0
while IFS= read -r f; do
  grep -q '<script' "$f" || continue
  # 取 data() { return { ... 段（到 created/methods/computed 之前）。
  # 注意不能用 \s —— BSD sed（macOS）不认，会静默取出 0 行让整个检查失效。
  blk=$(sed -n '/data[ ]*([ ]*)[ ]*{/,/^[[:space:]]*\(created\|methods\|computed\|mounted\|watch\)[[:space:]]*[(:]/p' "$f")
  [ -n "$blk" ] || continue
  # props 和 computed 里声明的也算（RuoYi 的 gen/*Form.vue 就把 info 作为 prop 传入）
  extra=$(sed -n '/^[[:space:]]*props[[:space:]]*:/,/^[[:space:]]*}/p' "$f"; \
          sed -n '/^[[:space:]]*computed[[:space:]]*:/,/^[[:space:]]*}[[:space:]]*[,;]*[[:space:]]*$/p' "$f")
  for v in $(grep -o ':model="[a-zA-Z_$][a-zA-Z0-9_$]*"' "$f" | sed 's/.*:model="//;s/"//' | sort -u); do
    if ! echo "$blk$extra" | grep -qE "^[[:space:]]+$v[[:space:]]*[:(]"; then
      echo "  ❌ $f :model=\"$v\" 但 data() 里没声明 $v"
      MODEL_FAIL=$((MODEL_FAIL+1))
    fi
  done
done < <(find ruoyi-ui/src -name '*.vue' | sort)
if [ "$MODEL_FAIL" -eq 0 ]; then
  echo "  ✅ 全部 :model 绑定的对象都已在 data() 声明"
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+MODEL_FAIL))
fi

echo ""
echo "vue sfc lint: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
