#!/usr/bin/env bash
# 商品分享面板 + 海报 smoke test
#
# 用户实测报了 7 个问题，全在「商品详情页 → 分享」这一条链路上，
# 根因各不相同、但共性是这个面板从来没接过真实数据：
#
#  1) 头像不对    —— 面板直接 <image src="{{user.avatarUrl}}">，而后端存的是
#                    /profile/avatar/xxx.png 相对路径，没过 toFullUrl 必然裂图，
#                    显示的是 default.png。pages/mine/index 早就 toFullUrl 了，这里漏了。
#  2) 商品图不对  —— src 写死 /assets/img/RestaurantImg.png（一张示例餐厅图），
#                    跟当前商品毫无关系。
#  3) 小程序码不对 —— .qr-circle 是 CSS radial-gradient + conic-gradient 拼出来的
#                    「假二维码纹理」，看着像码但扫不出任何东西。
#  4) 三按钮间距不一致导致「保存图片」换行 —— share-ops 用 space-around，而
#                    两个 <button> 和一个 <view> 的默认宽度算法不同（button 块级
#                    默认撑满、view 由内容定），三项实宽不等，最长的那项被挤到换行。
#  5) 点「收藏」无反应 —— <button open-type="favorite"> 只在已发布版本 + 支持的
#                    基础库上生效，开发者工具里静默失效，用户以为坏了。
#  6) 保存图片弹出的海报里商品图为空 —— 海报页 _drawCover 在 img.onload 里异步
#                    drawImage，但 _draw 同步跑到底就 setData({generating:false})，
#                    此时导出拿到的是还没画上图的那一帧。
#  7) 原价下划线样式不对 + 海报太阳码还是不对 + 写死「洞天团购」——
#                    面板里 sp-old 绑的竟然也是 product.price（两个一样的数字并排），
#                    海报里删除线 y 写死 690 而基线在 700 所以偏到字外面；
#                    海报的码调 /api/distributor/qrcode，那个端点要求调用者是推客，
#                    普通会员必然拿不到，永远画占位；平台名硬编码在 3 处。
#
# 本脚本锁的是后端新端点 + 前端源码不再回退到硬编码：
#   A) GET /api/product/{id}/qrcode 匿名可访问（分享不该要求登录）
#   B) 返 dataUrl（canvas 能直接吃，不受 request 合法域名限制）+ url + scene
#   C) scene 是 p:<productId> 且 <= 32 字符（微信硬限制）
#   D) 文件层缓存：第二次请求 cached=true 且 dataUrl 完全一致
#   E) 下架/不存在商品返错，不泄漏
#   F) 源码守卫：面板不再有写死的示例图 / 假二维码渐变 / 平台名字面量
#   G) 源码守卫：头像过 toFullUrl、原价绑 marketPrice、三按钮等分、收藏有兜底反馈
#   H) 源码守卫：海报页先 decode 再画（不再 onload 里异步画）、码走商品端点
#
# 前置：后端在 8080 运行（druid profile），本地 mysql 可连
# 用法：bash .github/scripts/smoke-goods-share.sh
set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
APPID="${APPID:-wx9e147c4e2151b123}"
MYSQL="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCT=999829        # ¥200.00，门店 200（商户 1），上架态
PASS=0; FAIL=0

ck() {
  if [ "$2" = "$3" ]; then echo "  OK: $1 ($2)"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望 $3 实际 $2"; FAIL=$((FAIL+1)); fi
}
ckne() {  # 非空即通过（dataUrl 太长不便全等比较）
  if [ -n "$2" ]; then echo "  OK: $1 (len=${#2})"; PASS=$((PASS+1));
  else echo "  FAIL: $1 期望非空 实际空"; FAIL=$((FAIL+1)); fi
}

jget() { python3 -c "
import sys,json
try: d=json.loads(sys.stdin.read() or '{}')
except Exception: print(''); sys.exit()
v=d
for k in '$1'.split('.'):
    v=(v or {}).get(k) if isinstance(v,dict) else None
# Python 的 True/False 打出来跟 JSON 的 true/false 不一样，断言侧统一按 JSON 写法
if isinstance(v, bool): print('true' if v else 'false')
else: print('' if v is None else v)
"; }

sql()  { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 ry-vue -e "$1" 2>/dev/null || true; }
sql1() { "$MYSQL" -h127.0.0.1 -uroot -p133301 --default-character-set=utf8mb4 -N -B -e "use \`ry-vue\`; $1" 2>/dev/null || true; }

# 剥 JS/WXSS 注释后再 grep —— 本次改动在注释里写了「不能写死洞天团购」这类说明，
# 直接 grep 会命中注释、把已修好的判成没修
strip_js() { python3 - "$1" <<'PY'
import sys, re, io
s = io.open(sys.argv[1], encoding='utf-8').read()
s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
s = re.sub(r'^\s*//.*$', '', s, flags=re.M)
print(s)
PY
}
strip_wxml() { python3 - "$1" <<'PY'
import sys, re, io
s = io.open(sys.argv[1], encoding='utf-8').read()
s = re.sub(r'<!--.*?-->', '', s, flags=re.S)
print(s)
PY
}

DETAIL_JS="$ROOT/miniprogram7/pages/goods/detail/index.js"
DETAIL_WXML="$ROOT/miniprogram7/pages/goods/detail/index.wxml"
DETAIL_WXSS="$ROOT/miniprogram7/pages/goods/detail/index.wxss"
SHARE_JS="$ROOT/miniprogram7/pages/goods/share/index.js"

# 清掉残留的缓存文件，保证 D 段第一次真的走 miss 分支。
# 目录取 ruoyi.profile（application.yml 本地默认 ~/ruoyi/uploadPath，
# 生产 -prod 是 /var/dytuangou/uploadPath），不能想当然拼在仓库目录下。
QRDIR="${RUOYI_PROFILE_PATH:-$HOME/ruoyi/uploadPath}/product_qr"
cleanup() {
  python3 -c "
import shutil
shutil.rmtree('$QRDIR', ignore_errors=True)
" 2>/dev/null || true
}
trap cleanup EXIT
cleanup

# ------------------------------------------------------------------ A) 匿名可访问
echo "[A] 商品小程序码端点匿名可访问（分享不该要求登录）"
R1=$(curl -s "$BASE_URL/api/product/$PRODUCT/qrcode" -H "X-App-Id: $APPID")
ck "匿名请求返回 200" "$(echo "$R1" | jget code)" "200"

# ------------------------------------------------------------------ B) 返回结构
echo "[B] 返回 dataUrl + url + scene"
D1=$(echo "$R1" | jget dataUrl)
ckne "dataUrl 非空" "$D1"
case "$D1" in
  data:image/png\;base64,*) echo "  OK: dataUrl 是 png base64"; PASS=$((PASS+1));;
  *) echo "  FAIL: dataUrl 前缀不对：${D1:0:40}"; FAIL=$((FAIL+1));;
esac
ckne "url 非空" "$(echo "$R1" | jget url)"

# ------------------------------------------------------------------ C) scene 格式与长度
echo "[C] scene = p:<productId> 且 <= 32 字符（微信硬限制）"
SC=$(echo "$R1" | jget scene)
ck "scene 内容" "$SC" "p:$PRODUCT"
if [ "${#SC}" -le 32 ]; then echo "  OK: scene 长度 ${#SC} <= 32"; PASS=$((PASS+1));
else echo "  FAIL: scene 超长 ${#SC}"; FAIL=$((FAIL+1)); fi

# ------------------------------------------------------------------ D) 文件缓存
echo "[D] 文件层缓存：wxacode 有日调用上限，同一商品不该每次重新生成"
ck "首次为 miss" "$(echo "$R1" | jget cached)" "false"
R2=$(curl -s "$BASE_URL/api/product/$PRODUCT/qrcode" -H "X-App-Id: $APPID")
ck "二次命中缓存" "$(echo "$R2" | jget cached)" "true"
D2=$(echo "$R2" | jget dataUrl)
if [ "$D1" = "$D2" ]; then echo "  OK: 命中后 dataUrl 与首次完全一致"; PASS=$((PASS+1));
else echo "  FAIL: 缓存命中却返回了不同的图"; FAIL=$((FAIL+1)); fi

# ------------------------------------------------------------------ E) 下架/不存在
echo "[E] 下架或不存在的商品不给码"
ck "不存在的商品返错" "$(curl -s "$BASE_URL/api/product/99999999/qrcode" -H "X-App-Id: $APPID" | jget code)" "500"
# 造一个下架商品
sql "insert into biz_product(merchant_id,store_id,product_name,type_code,price,market_price,status,create_time)
     values(1,200,'smoke分享下架商品','GROUPON',200.00,300.00,'1',now());"
OFFID=$(sql1 "select product_id from biz_product where product_name='smoke分享下架商品' order by product_id desc limit 1;")
ck "下架商品返错" "$(curl -s "$BASE_URL/api/product/$OFFID/qrcode" -H "X-App-Id: $APPID" | jget code)" "500"
sql "delete from biz_product where product_name='smoke分享下架商品';"

# ------------------------------------------------------------------ F) 源码守卫：不再有硬编码
echo "[F] 分享面板不再回退到硬编码"
WXML_CLEAN=$(strip_wxml "$DETAIL_WXML")
JS_CLEAN=$(strip_js "$DETAIL_JS")
SHARE_CLEAN=$(strip_js "$SHARE_JS")

ck "面板商品图不再写死示例餐厅图" \
   "$(printf '%s' "$WXML_CLEAN" | grep -c 'share-cover.*RestaurantImg')" "0"
ck "面板商品图绑真实 cover" \
   "$(printf '%s' "$WXML_CLEAN" | grep -c 'class="share-cover" src="{{product.cover}}"')" "1"
ck "假二维码 CSS 渐变纹理已删" \
   "$(grep -c 'qr-circle' "$DETAIL_WXSS")" "0"
ck "详情页不再有写死的平台名字面量" \
   "$(printf '%s' "$JS_CLEAN" | grep -c "'洞天团购'")" "0"
ck "海报页不再有写死的平台名字面量" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c "'洞天团购'")" "0"

# ------------------------------------------------------------------ G) 源码守卫：面板数据链路
echo "[G] 面板数据链路修好了"
# 不能只数 _normalizeUser 出现次数 —— 函数在、但体内不调 toFullUrl 一样裂图
# （mutation 验证时这条就漏过了）。断言 avatarUrl 那一行真套了 toFullUrl。
ck "头像过 toFullUrl（否则相对路径必裂图）" \
   "$(printf '%s' "$JS_CLEAN" | grep -c 'avatarUrl: src.avatarUrl ? toFullUrl(src.avatarUrl)')" "1"
ck "_normalizeUser 在 onLoad 和 onUserUpdate 两处都用上" \
   "$(printf '%s' "$JS_CLEAN" | grep -c 'this._normalizeUser(')" "2"
ck "原价绑 marketPrice 而不是再绑一次 price" \
   "$(printf '%s' "$WXML_CLEAN" | grep -c 'sp-old.*product.marketPrice')" "1"
# 2 处：data 里声明 + openShare 里按 marketPrice>price 计算
ck "原价仅在真的高于现价时显示" \
   "$(printf '%s' "$JS_CLEAN" | grep -c 'showSharePriceOld')" "2"
ck "三按钮改等分（flex:1）不再 space-around" \
   "$(grep -c 'justify-content: space-around' "$DETAIL_WXSS")" "0"
ck "按钮文案 nowrap 兜底不换行" \
   "$(grep -c 'so-t.*nowrap' "$DETAIL_WXSS")" "1"
ck "收藏按钮有 bindtap 兜底反馈" \
   "$(printf '%s' "$WXML_CLEAN" | grep -c 'open-type="favorite".*bindtap="onFavTap"')" "1"
ck "onFavTap 已实现" \
   "$(printf '%s' "$JS_CLEAN" | grep -c 'onFavTap()')" "1"
# 2 处：_loadShareQr 里调用 + 失败日志里的标签
ck "面板码走商品端点" \
   "$(printf '%s' "$JS_CLEAN" | grep -c 'productQrcode')" "2"

# ------------------------------------------------------------------ H) 源码守卫：海报页
echo "[H] 海报页异步竞争修好了"
# 3 处：函数定义 1 + Promise.all 里 cover/qr 各 1
ck "先 decode 再画（新增 _decode）" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c '_decode(canvas, ')" "3"
# 同理不能只数 _paint 出现次数 —— 定义在、但 then 里没真调（或被 if(false) 包住）
# 海报就是白的（mutation 验证时这条漏过了）。断言 then 回调里那一行完整成立。
ck "decode 完成后真的调用 _paint（不能只是定义了）" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -cE '^ *this\._paint\(ctx, imgs\[0\], imgs\[1\]\);$')" "1"
ck "_paint 是同步绘制函数（已定义）" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c '_paint(ctx, coverImg, qrImg)')" "1"
ck "_drawCover 不再用 img.onload 异步画" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c 'img.onload')" "1"
ck "海报码不再调推客端点（普通会员必然 403）" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c 'promoterQrcode')" "0"
ck "海报码走商品端点" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c 'api.productQrcode')" "1"
ck "小程序码不再做圆形裁剪（会切掉定位图案导致扫不出）" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c 'arc(510, 810')" "0"
ck "占位文案改成用户能懂的「小程序码」" \
   "$(printf '%s' "$SHARE_CLEAN" | grep -c "fillText('小程序码'")" "1"

echo
echo "=============================="
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
