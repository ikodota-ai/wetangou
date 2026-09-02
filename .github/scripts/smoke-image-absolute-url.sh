#!/usr/bin/env bash
# smoke-image-absolute-url.sh
#
# 守「图片绝对 URL」这条链。两个独立根因，各自都能让小程序显示白图：
#
# 1) 后端没采纳 Nginx 的 X-Forwarded-Proto / X-Forwarded-Host。生产是
#    Nginx(443) 反代到 http://127.0.0.1:8083，request.getRequestURL() 于是拿到
#    后端自己监听的 http://127.0.0.1:8083。ServerConfig.getUrl() 和
#    ImageUrlUtils.toAbsolute() 都基于它拼图片地址 → 小程序 <image> 报
#    「图片链接不再支持 HTTP 协议，请升级到 HTTPS」并白图；头像上传接口还会把
#    内网 host 写进库变成永久脏数据（库里 biz_store.logo 就有一条
#    http://localhost:8080/profile/... 是这么来的）。
#    修法：server.forward-headers-strategy=framework（放基础 application.yml，
#    没有代理头时不改变任何行为，所以本地联调不受影响）。
#
# 2) /api/store/{id}/album 和 /api/banner/list 漏调 ImageUrlUtils.toAbsolute。
#    库里实测 biz_store_album 有 4 条 /profile/upload/demo/*.jpg 相对路径，
#    小程序 <image src> 走原生加载不经过任何代理，相对路径直接 404 ——
#    后台配了轮播图/相册，手机上却是空白。门店列表/详情的 logo 一直做了
#    绝对化，这两个端点是三个图片出口里漏掉的。
#
# 断言基准刻意选 biz_store_album 而不是 biz_store.logo：后者库里那条是历史
# 脏数据（本身就是绝对地址），toAbsolute 按约定原样返回，拿它断言会误判。
set -uo pipefail
BASE="${BASE:-http://localhost:8080}"
APP="${APP:-wx9e147c4e2151b123}"
EXT_HOST="${EXT_HOST:-daodian.lanaoboxiang.com}"
ALBUM_STORE="${ALBUM_STORE:-200}"
PASS=0; FAIL=0
ck() {
  if [ "$2" = "$3" ]; then echo "PASS | $1"; PASS=$((PASS+1));
  else echo "FAIL | $1 | got=[$2] exp=[$3]"; FAIL=$((FAIL+1)); fi
}

# 挑出 JSON 里所有指定字段，判断它们的形态：abs_https / abs_http / relative / none
shape() { python3 -c "
import sys,json
key=sys.argv[1]
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print('parse_error'); sys.exit()
def walk(x,out):
    if isinstance(x,dict):
        for k,v in x.items():
            if k==key and isinstance(v,str) and v: out.append(v)
            else: walk(v,out)
    elif isinstance(x,list):
        for i in x: walk(i,out)
vals=[]; walk(d,vals)
if not vals: print('none'); sys.exit()
kinds=set()
for v in vals:
    if v.startswith('https://'): kinds.add('abs_https')
    elif v.startswith('http://'): kinds.add('abs_http')
    else: kinds.add('relative')
print('|'.join(sorted(kinds)))
" "$1"; }

# 模拟 Nginx 反代：外网 Host + https 协议头
proxied() { curl -s "$BASE$1" -H "X-App-Id: $APP" \
  -H "X-Forwarded-Host: $EXT_HOST" -H 'X-Forwarded-Proto: https' \
  -H 'X-Forwarded-Port: 443' -H 'X-Forwarded-For: 203.0.113.9'; }
direct()  { curl -s "$BASE$1" -H "X-App-Id: $APP"; }

# ---- 1) 代理头生效：库里的相对路径要被拼成外网 https 域名
BODY=$(proxied "/api/store/$ALBUM_STORE/album")
HAS_EXT=$(printf '%s' "$BODY" | grep -c "https://$EXT_HOST/profile/" || true)
ck "反代下相册相对路径拼成 https://外网域名" "$([ "$HAS_EXT" -ge 1 ] && echo yes || echo no)" "yes"
HAS_LOCAL=$(printf '%s' "$BODY" | grep -c "localhost:8080/profile/" || true)
ck "反代下相册不再拼内网 host" "$HAS_LOCAL" "0"
HAS_HTTP=$(printf '%s' "$BODY" | grep -c "http://$EXT_HOST" || true)
ck "反代下协议是 https 不是 http（小程序 image 拒 http）" "$HAS_HTTP" "0"

# ---- 2) 相册 / banner 不再返相对路径（漏调 toAbsolute 的直接症状）
S=$(proxied "/api/store/$ALBUM_STORE/album" | shape imageUrl)
case "$S" in *relative*) ck "反代下相册 imageUrl 无相对路径" "$S" "no_relative" ;; *) ck "反代下相册 imageUrl 无相对路径" "ok" "ok" ;; esac
S=$(proxied "/api/banner/list" | shape imageUrl)
case "$S" in *relative*) ck "反代下 banner imageUrl 无相对路径" "$S" "no_relative" ;; *) ck "反代下 banner imageUrl 无相对路径" "ok" "ok" ;; esac
S=$(direct "/api/store/$ALBUM_STORE/album" | shape imageUrl)
case "$S" in *relative*) ck "直连时相册 imageUrl 也已绝对化" "$S" "no_relative" ;; *) ck "直连时相册 imageUrl 也已绝对化" "ok" "ok" ;; esac
S=$(direct "/api/banner/list" | shape imageUrl)
case "$S" in *relative*) ck "直连时 banner imageUrl 也已绝对化" "$S" "no_relative" ;; *) ck "直连时 banner imageUrl 也已绝对化" "ok" "ok" ;; esac

# ---- 3) 已经是 http(s):// 的外部地址（OSS/CDN）不能被改写
BODY=$(proxied "/api/banner/list")
KEEP=$(printf '%s' "$BODY" | grep -c "https://wetuango.oss-cn-shenzhen.aliyuncs.com" || true)
ck "OSS 绝对地址原样保留（不被重拼）" "$([ "$KEEP" -ge 1 ] && echo yes || echo no)" "yes"
BAD=$(printf '%s' "$BODY" | grep -c "$EXT_HOST/http" || true)
ck "没有把绝对地址二次拼接成 域名/https://…" "$BAD" "0"

# ---- 4) 直连（无代理头）时行为不变：策略只在收到 X-Forwarded-* 时改写，
#         这条守的是「别把本地开发环境搞坏」
BODY=$(direct "/api/store/$ALBUM_STORE/album")
OK=$(printf '%s' "$BODY" | grep -c "http://localhost:8080/profile/\|http://127\.0\.0\.1:8080/profile/" || true)
ck "直连时相册仍拼本机地址（策略不影响本地联调）" "$([ "$OK" -ge 1 ] && echo yes || echo no)" "yes"
NOEXT=$(printf '%s' "$BODY" | grep -c "$EXT_HOST" || true)
ck "直连时不会凭空拼出外网域名" "$NOEXT" "0"

# ---- 5) 门店列表/详情的 logo 绝对化没被改坏（原本就有，回归保护）
BODY=$(direct "/api/store/list")
S=$(printf '%s' "$BODY" | shape logo)
case "$S" in *relative*) ck "门店列表 logo 无相对路径" "$S" "no_relative" ;; *) ck "门店列表 logo 无相对路径" "ok" "ok" ;; esac

# ---- 6) 端点本身仍正常
for u in "/api/store/$ALBUM_STORE/album" "/api/banner/list" "/api/store/list"; do
  C=$(direct "$u" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read() or "{}").get("code"))')
  ck "$u code=200" "$C" "200"
done

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
