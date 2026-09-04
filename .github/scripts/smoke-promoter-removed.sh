#!/usr/bin/env bash
# 推客功能过审期间必须彻底不可达
#
# 背景（微信第二轮驳回 + 用户反馈）：
#   线上 biz_merchant.promoter_enabled 已是 '0'，用户以为推客已关闭，
#   但审核员仍截到了提现页。排查出两个真 bug：
#
#   bug1 入口有异步窗口：mine/index 的 promoterEnabled 初始值是 true
#        （原注释「接口没回来时宁可显示入口」），开关值靠异步 bootMerchant
#        回来才 setData(false)。中间那一两秒入口是渲染出来的，录屏审核逐帧
#        必然抓到。更糟的是 syncPromoterSwitch 第一行遇 undefined 直接 return，
#        bootMerchant 失败时入口永久停留在显示状态。
#
#   bug2 页面可直达：app.json 注册着 4 个 promoter 页，直接跳
#        pages/promoter/withdraw/index 就能看到完整的提现页 ——
#        而那页 onLoad 先用本地 FALLBACK_RULE 常量把「单笔最低 10 元」
#        「每日 3 次」「9:00-21:00」渲染出来，再去请求后端。后端 403 只
#        影响数据，门槛文案照样完整显示，正好对上驳回说的「设置提现门槛」。
#
# 所以本脚本断言的是「彻底不可达」这三层，缺一层审核就可能再截到图：
#   A. app.json 不注册 promoter 页（页面不存在，直达也进不去）
#   B. 「我的」页入口不渲染（wxml 注释掉 + JS 默认值 false + 无异步翻转）
#   C. 没有任何活跃代码还在调推客接口（避免必然 403 的无效请求）
#
# 这些都是纯静态断言 —— 摘除的本质就是「代码里没有」，起后端也测不出什么。
# 后端刻意一行未动（拦截器本来就拦得对），所以不断言后端行为。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MP="$ROOT/miniprogram7"

PASSN=0; FAILN=0
ok(){ echo "  ✅ $1"; PASSN=$((PASSN+1)); }
ng(){ echo "  ❌ $1"; FAILN=$((FAILN+1)); }

# 剥掉 JS 行注释与块注释，只留真实会执行的代码。
# 摘除手法是「注释保留原实现」，直接 grep 会把注释里的旧代码当成活跃代码。
nocomment_js(){ python3 - "$1" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
s=re.sub(r'/\*.*?\*/','',s,flags=re.S)      # 块注释
s=re.sub(r'^\s*//.*$','',s,flags=re.M)      # 整行行注释
s=re.sub(r'//.*$','',s,flags=re.M)          # 行尾注释
print(s)
PY
}

# 剥掉 WXML 注释
nocomment_wxml(){ python3 - "$1" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
print(re.sub(r'<!--.*?-->','',s,flags=re.S))
PY
}

echo "== A. app.json 不能注册 promoter 页面（页面不存在 → 直达也进不去） =="
APPJSON="$MP/app.json"
if [ ! -f "$APPJSON" ]; then
  echo "FAIL: 找不到 app.json"; exit 1
fi
# 必须先确认是合法 JSON：JSON 不支持注释，如果有人想「注释掉」这几行会直接把
# 小程序整包搞坏（本次改动时就先犯过这个错），所以这条断言必须在最前面。
if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$APPJSON" 2>/dev/null; then
  ok "app.json 是合法 JSON"
else
  ng "app.json 不是合法 JSON（JSON 不支持 # 或 // 注释）"
fi
PCNT=$(python3 - "$APPJSON" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1],encoding='utf-8'))
except Exception:
    print(-1); raise SystemExit
pages=d.get('pages',[]) or []
sub=[]
for pkg in (d.get('subPackages') or d.get('subpackages') or []):
    root=(pkg.get('root') or '').strip('/')
    for pg in (pkg.get('pages') or []):
        sub.append(root+'/'+pg)
print(sum(1 for pg in list(pages)+sub if 'pages/promoter/' in pg or pg.startswith('promoter/')))
PY
)
if [ "$PCNT" = "0" ]; then
  ok "pages / subPackages 里都没有 promoter 页面"
elif [ "$PCNT" = "-1" ]; then
  ng "app.json 解析失败，无法确认"
else
  ng "app.json 仍注册着 $PCNT 个 promoter 页面（可被直接跳转访问）"
fi

echo "== B. 「我的」页推客入口不能渲染 =="
MJS="$MP/pages/mine/index/index.js"
MWXML="$MP/pages/mine/index/index.wxml"

# B1 WXML 剥注释后不能还有推客入口
if nocomment_wxml "$MWXML" | grep -q 'goPromoter'; then
  ng "index.wxml 仍有活跃的 goPromoter 入口"
else
  ok "index.wxml 无活跃推客入口"
fi
if nocomment_wxml "$MWXML" | grep -q '推客中心'; then
  ng "index.wxml 仍会渲染「推客中心」文案"
else
  ok "index.wxml 不渲染「推客中心」"
fi

# B2 默认值必须是 false —— 这条直接对着 bug1。
#     哪怕入口 wxml 注释了，默认值留 true 也说明这个取向没纠正，
#     恢复功能时容易又原样退回去。
if nocomment_js "$MJS" | grep -qE 'promoterEnabled:\s*false'; then
  ok "promoterEnabled 默认值是 false"
elif nocomment_js "$MJS" | grep -qE 'promoterEnabled:\s*true'; then
  ng "promoterEnabled 默认值仍是 true（bug1 的根因：异步窗口内入口会闪现）"
else
  ok "data 里已无 promoterEnabled（等价于不渲染）"
fi

# B3 不能还有活跃的 syncPromoterSwitch 调用 —— 那个方法体已被注释，
#     若还有调用点，运行时会直接 TypeError（is not a function）。
SYNC_CALLS=$(nocomment_js "$MJS" | grep -c 'this\.syncPromoterSwitch()' || true)
if [ "${SYNC_CALLS:-0}" = "0" ]; then
  ok "无活跃 syncPromoterSwitch() 调用"
else
  ng "仍有 $SYNC_CALLS 处活跃 syncPromoterSwitch() 调用，但方法体已注释 → 运行时 TypeError"
fi

# B4 活跃代码里不能还有跳 promoter 页的 navigateTo（页面已不注册，跳过去是白屏报错）
if nocomment_js "$MJS" | grep -q "pages/promoter/"; then
  ng "index.js 仍有活跃的 pages/promoter/ 跳转（页面已不注册，会白屏）"
else
  ok "index.js 无活跃 promoter 跳转"
fi

echo "== C. 全局不能有活跃代码调推客接口（否则每次必然 403） =="
# 只查活跃代码。request.js 里的接口封装本身保留不动（恢复时要用），
# 所以查的是「有没有人调用」，不是「有没有定义」。
CALLERS=""
for f in $(find "$MP/pages" "$MP/utils" -name '*.js' 2>/dev/null | grep -v '/promoter/'); do
  if nocomment_js "$f" | grep -qE 'api\.(promoterInfo|promoterQrcode|promoterFans|joinPromoter|applyWithdraw|withdrawList|withdrawRules|commissionList)\s*\('; then
    CALLERS="$CALLERS ${f#$MP/}"
  fi
done
if [ -z "$CALLERS" ]; then
  ok "无活跃代码调用推客/提现接口"
else
  ng "以下文件仍在调推客接口：$CALLERS"
fi

echo "== D. promoter 页面文件必须保留（摘除≠删除，恢复时要用） =="
KEEP=0
for d in index withdraw records poster; do
  if [ -f "$MP/pages/promoter/$d/index.js" ]; then
    KEEP=$((KEEP+1))
  else
    ng "pages/promoter/$d/index.js 被删了 —— 摘除应该只是不注册"
  fi
done
[ "$KEEP" = "4" ] && ok "4 个 promoter 页面文件都在（可随时恢复）"

echo "== E. 后端必须保持原样（本次刻意不动后端） =="
ITC="$ROOT/ruoyi-framework/src/main/java/com/ruoyi/framework/api/DistributorAuthInterceptor.java"
if [ -f "$ITC" ] && grep -q 'isPromoterEnabled' "$ITC"; then
  ok "后端推客开关拦截仍在（拦截器第 0 步判商户开关）"
else
  ng "后端拦截器的推客开关判断不见了"
fi
WRS="$ROOT/ruoyi-system/src/main/java/com/ruoyi/biz/api/service/WithdrawRuleService.java"
if [ -f "$WRS" ]; then
  ok "WithdrawRuleService 保留（恢复时直接改 sys_config 即可放宽门槛）"
else
  ng "WithdrawRuleService 被删了"
fi

echo "== F. 恢复清单文档必须存在（否则以后没人知道怎么恢复） =="
DOC="$ROOT/doc/推客功能恢复清单-2026-09-04.md"
if [ -f "$DOC" ]; then
  ok "恢复清单文档存在"
  for kw in "app.json" "promoterEnabled" "withdraw.minAmount" "商家转账"; do
    if grep -q "$kw" "$DOC"; then
      ok "清单含关键项：$kw"
    else
      ng "清单缺关键项：$kw"
    fi
  done
else
  ng "缺 doc/推客功能恢复清单-2026-09-04.md"
fi

echo
echo "PASS=$PASSN FAIL=$FAILN"
[ "$FAILN" -eq 0 ] || exit 1
