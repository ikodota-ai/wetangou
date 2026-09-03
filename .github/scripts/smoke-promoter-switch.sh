#!/usr/bin/env bash
# smoke-promoter-switch.sh
#
# 守「推客功能商户级总开关」这条链：
#   后台「商户管理 → 编辑 → 推客功能」= 关闭
#   → /api/merchant/info 返 promoterEnabled='0'
#   → 小程序「我的」页不渲染「推客中心」入口（wxml wx:if="{{logged && promoterEnabled}}"）
#
# 两个已实测踩到的坑，都在这里上断言：
#
# 1) 【本轮真实 bug】商户缓存 merchant:appid:* 是 fastjson 序列化对象且**没有 TTL**，
#    只有编辑商户时才 evict。加 promoter_enabled 列之前写进 Redis 的那份快照里
#    根本没这个 key，反序列化回来是 null。实测：库里 merchant 1 是 '1'，
#    接口却返 null → 小程序按 '0' 之外的值判断本可放过，但若前端写成
#    `=== '1'` 才显示，已开通商户的推客入口会在升级那一刻集体消失。
#    修法：controller 层对空值兜底成 '1'。所以这里断言「库里 NULL 时接口也要返 '1'」。
#
# 2) 改库不 evict 缓存 → 接口读到旧值。所以每次改库后必须 evict，
#    这也顺带验证了 clearMerchantCache 的 appid 维度 key 拼得对。
set -uo pipefail
BASE="${BASE:-http://localhost:8080}"
APP="${APP:-wx9e147c4e2151b123}"
MID="${MID:-1}"
MYSQL="${MYSQL:-/usr/local/mysql/bin/mysql}"
DB="${DB:-ry-vue}"
DBUSER="${DBUSER:-root}"
DBPASS="${DBPASS:-133301}"
REDIS="${REDIS:-redis-cli}"
PASS=0; FAIL=0
ck() {
  if [ "$2" = "$3" ]; then echo "PASS | $1"; PASS=$((PASS+1));
  else echo "FAIL | $1 | got=[$2] exp=[$3]"; FAIL=$((FAIL+1)); fi
}
q() { "$MYSQL" -u"$DBUSER" -p"$DBPASS" "$DB" -N -B -e "$1" 2>/dev/null; }
# 改库后必须清缓存，否则接口读的是旧快照（坑 2）
evict() { "$REDIS" DEL "merchant:appid:$APP" >/dev/null 2>&1 || true;
          "$REDIS" DEL "merchant:id:$MID"   >/dev/null 2>&1 || true; }
# 取 /api/merchant/info 的某个字段
info() { curl -s "$BASE/api/merchant/info" -H "X-App-Id: $APP" | python3 -c "
import sys,json
k=sys.argv[1]
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print('parse_error'); sys.exit()
v=(d.get('data') or {}).get(k, d.get(k))
print('<null>' if v is None else v)
" "$1"; }

ORIG=$(q "select ifnull(promoter_enabled,'<null>') from biz_merchant where merchant_id=$MID")
[ -n "$ORIG" ] || { echo "FAIL | 取不到 merchant_id=$MID，检查 DB/MID"; exit 1; }
echo "# baseline merchant_id=$MID promoter_enabled=[$ORIG]"
restore() {
  if [ "$ORIG" = "<null>" ]; then q "update biz_merchant set promoter_enabled=null where merchant_id=$MID";
  else q "update biz_merchant set promoter_enabled='$ORIG' where merchant_id=$MID"; fi
  evict
}
trap restore EXIT

# ---- 1) 列存在（升级脚本 biz_merchant_promoter_enabled_20260903 是否跑过）
COL=$(q "select count(*) from information_schema.columns where table_schema='$DB' and table_name='biz_merchant' and column_name='promoter_enabled'")
ck "biz_merchant.promoter_enabled 列存在" "$COL" "1"

# ---- 2) 开关=启用 → 接口返 '1'
q "update biz_merchant set promoter_enabled='1' where merchant_id=$MID"; evict
ck "启用时 promoterEnabled='1'" "$(info promoterEnabled)" "1"

# ---- 3) 开关=关闭 → 接口返 '0'（小程序据此隐藏入口）
q "update biz_merchant set promoter_enabled='0' where merchant_id=$MID"; evict
ck "关闭时 promoterEnabled='0'" "$(info promoterEnabled)" "0"

# ---- 4) 库里 NULL（老数据/老缓存）→ 必须兜底成 '1'，不能是 null（坑 1）
q "update biz_merchant set promoter_enabled=null where merchant_id=$MID"; evict
ck "库里 NULL 时兜底为 '1'（不得返 null）" "$(info promoterEnabled)" "1"

# ---- 5) 空串同样兜底（char(1) 允许写 ''）
q "update biz_merchant set promoter_enabled='' where merchant_id=$MID"; evict
ck "库里空串时兜底为 '1'" "$(info promoterEnabled)" "1"

# ---- 6) 缓存未 evict 时接口读旧值 —— 证明 evict 是必需的，
#         也就是说 admin 端保存商户必须走 clearMerchantCache（MerchantServiceImpl 已调）
q "update biz_merchant set promoter_enabled='1' where merchant_id=$MID"; evict
info promoterEnabled >/dev/null   # 预热，把 '1' 写进 Redis
q "update biz_merchant set promoter_enabled='0' where merchant_id=$MID"   # 故意不 evict
ck "缓存未失效时读到旧值（说明保存商户必须清缓存）" "$(info promoterEnabled)" "1"
evict
ck "evict 后立即读到新值 '0'" "$(info promoterEnabled)" "0"

# ---- 7) 端点本身没被搞坏：其他字段仍在
ck "merchantId 仍正常返回" "$(info merchantId)" "$MID"
NAME=$(info merchantName)
ck "merchantName 非空" "$([ -n "$NAME" ] && [ "$NAME" != "<null>" ] && echo yes || echo no)" "yes"

# ---- 8) 小程序端静态守卫：入口必须受开关控制，且 js 里有兜底判断
WXML="miniprogram7/pages/mine/index/index.wxml"
JS="miniprogram7/pages/mine/index/index.js"
# 注意断言的是裸 &&，不是 HTML 实体 &amp;&amp; —— WXML 的 {{}} 表达式里不做
# 实体解码，写成 &amp;&amp; 微信编译器直接报
# "Bad attr wx:if with message: unexpected `;`"，真机调试上传就失败。
G=$(grep -c 'wx:if="{{logged && promoterEnabled}}".*goPromoter' "$WXML" 2>/dev/null || true)
ck "wxml 推客入口受 promoterEnabled 控制" "$([ "${G:-0}" -ge 1 ] && echo yes || echo no)" "yes"
G=$(grep -c "promoterEnabled) === '0'" "$JS" 2>/dev/null || true)
ck "js goPromoter 有关闭态兜底拦截" "$([ "${G:-0}" -ge 1 ] && echo yes || echo no)" "yes"
G=$(grep -c "onMerchantUpdate" "$JS" 2>/dev/null || true)
ck "js 接 onMerchantUpdate 广播（冷启动 bootMerchant 异步）" "$([ "${G:-0}" -ge 1 ] && echo yes || echo no)" "yes"

# ---- 9) 推客页自身也要守：本页能被分享卡片/海报 path/扫码绕过入口直达，
#         关闭时不能让「成为推客」还点得动（点了后端 join 会真建推客记录）
PJS="miniprogram7/pages/promoter/index/index.js"
PWXML="miniprogram7/pages/promoter/index/index.wxml"
G=$(grep -c 'wx:if="{{!promoterEnabled}}"' "$PWXML" 2>/dev/null || true)
ck "推客页关闭态渲染「未开通」占位" "$([ "${G:-0}" -ge 1 ] && echo yes || echo no)" "yes"
G=$(grep -c 'promoterEnabled' "$PJS" 2>/dev/null || true)
ck "推客页 js 读 promoterEnabled" "$([ "${G:-0}" -ge 3 ] && echo yes || echo no)" "yes"
G=$(grep -c 'this.data.promoterEnabled' "$PJS" 2>/dev/null || true)
ck "推客页 onJoin/loadCenter 有开关拦截" "$([ "${G:-0}" -ge 2 ] && echo yes || echo no)" "yes"
# 推客页要能被服务端 403 反向纠正（直达本页时 bootMerchant 可能还没回来/失败，
# 本地 promoterEnabled 还是默认 true，会先渲染出整个数据面板）。
G=$(grep -c "未开通推客" "$PJS" 2>/dev/null || true)
ck "推客页凭服务端 403 文案自愈成未开通" "$([ "${G:-0}" -ge 1 ] && echo yes || echo no)" "yes"

# ---- 10) 【核心】服务端必须自己挡，不能只靠前端隐藏入口。
#     实测过的真洞：开关=0 时直接 POST /api/distributor/join 返 200 并真的
#     在 biz_distributor 建了一条 distributor_id=999927。前端隐藏入口只是
#     体验层，分享卡片/海报 path/扫码/手搓请求都能绕过。
#     守法：DistributorAuthInterceptor 在 @Anonymous 判定**之前**先判开关
#     （/join 是 @Anonymous 的，放后面等于不生效）。
MTOKEN=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
  -H "X-App-Id: $APP" -d '{"code":"smoke_promoter_sw","appid":"'"$APP"'"}' \
  | python3 -c 'import sys,json;print(json.loads(sys.stdin.read() or "{}").get("token",""))')
ck "mock 登录拿到会员 token" "$([ -n "$MTOKEN" ] && echo yes || echo no)" "yes"

# 取业务 code（拦截器手写 JSON，code 是数字）
bcode() { curl -s -X "$1" "$BASE$2" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" \
  | python3 -c 'import sys,json
try: print(json.loads(sys.stdin.read() or "{}").get("code"))
except Exception: print("parse_error")'; }

q "update biz_merchant set promoter_enabled='0' where merchant_id=$MID"; evict
ck "关闭时 POST /api/distributor/join 被拒(403)"        "$(bcode POST /api/distributor/join)"          "403"
ck "关闭时 GET  /api/distributor/center 被拒(403)"      "$(bcode GET  /api/distributor/center)"        "403"
ck "关闭时 GET  /api/distributor/qrcode 被拒(403)"      "$(bcode GET  /api/distributor/qrcode)"        "403"
ck "关闭时 GET  /api/distributor/fans 被拒(403)"        "$(bcode GET  /api/distributor/fans)"          "403"
ck "关闭时 GET  /api/distributor/withdraw/list 被拒"    "$(bcode GET  /api/distributor/withdraw/list)" "403"
# 最要紧的一条：被拒之后库里不能留下推客记录
LEFT=$(q "select count(*) from biz_distributor d join biz_member m on m.member_id=d.member_id
          where m.openid='mock_smoke_promoter_sw'")
ck "关闭时被拒后库里没建出推客记录" "${LEFT:-x}" "0"

# ---- 11) 开关打开后语义要完全恢复：非推客拿到的仍是原来那句「您还不是推客」，
#         而不是被开关误伤成「未开通」；join 仍然可用（否则谁都成不了推客）。
q "update biz_merchant set promoter_enabled='1' where merchant_id=$MID"; evict
MSG=$(curl -s "$BASE/api/distributor/center" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" \
  | python3 -c 'import sys,json;print((json.loads(sys.stdin.read() or "{}").get("msg") or ""))')
case "$MSG" in *"还不是推客"*) ck "开启时非推客返原始提示（未被开关误伤）" "ok" "ok" ;;
               *) ck "开启时非推客返原始提示（未被开关误伤）" "$MSG" "含'还不是推客'" ;; esac
ck "开启时 join 仍可用(200)" "$(bcode POST /api/distributor/join)" "200"

# ---- 12) 服务端 403 文案必须能被前端那段自愈判断命中（前端匹配 '未开通推客'）。
#      两边是字符串耦合，谁改了文案而没改对面，自愈就静默失效 —— 所以这里锁住。
q "update biz_merchant set promoter_enabled='0' where merchant_id=$MID"; evict
SMSG=$(curl -s "$BASE/api/distributor/center" -H "Authorization: Bearer $MTOKEN" -H "X-App-Id: $APP" \
  | python3 -c 'import sys,json;print((json.loads(sys.stdin.read() or "{}").get("msg") or ""))')
case "$SMSG" in *未开通推客*) ck "服务端 403 文案含前端匹配串「未开通推客」" "ok" "ok" ;;
                *) ck "服务端 403 文案含前端匹配串「未开通推客」" "$SMSG" "含'未开通推客'" ;; esac
q "update biz_merchant set promoter_enabled='1' where merchant_id=$MID"; evict

# 清理本脚本 mock 登录产生的会员/推客
q "delete d from biz_distributor d join biz_member m on m.member_id=d.member_id
   where m.openid='mock_smoke_promoter_sw'"
q "delete from biz_member where openid='mock_smoke_promoter_sw'"
LEFT=$(q "select count(*) from biz_member where openid='mock_smoke_promoter_sw'")
ck "测试数据已清理" "${LEFT:-x}" "0"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
