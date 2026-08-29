#!/usr/bin/env bash
# 小程序首页 7 处「设置了却不生效」问题的回归护栏。
#
# 这些 bug 的共性是：后台有数据 / 门店有配置，但顾客端要么写死、要么把参数传坏、
# 要么被脱敏拦掉，表现全是「我明明配了，小程序上看不到」。所以断言分两类：
#   1) 后端接口层：typeCode 能筛、门店电话不被脱敏
#   2) 前端源码层：不许再写死中文文案 / 不许再传 merchantId=0
H=${H:-http://localhost:8080}
MP=miniprogram7
PASS=0; FAIL=0

chk() { if [ "$2" = "$3" ]; then echo "  ✅ $1"; PASS=$((PASS+1)); else echo "  ❌ $1 (期望 $3 实得 $2)"; FAIL=$((FAIL+1)); fi }
chkf() { local n="$1" f="$2" pat="$3"
  if grep -q -- "$pat" "$f" 2>/dev/null; then echo "  ✅ $n"; PASS=$((PASS+1));
  else echo "  ❌ $n (未在 $f 找到: $pat)"; FAIL=$((FAIL+1)); fi
}
chkfn() { local n="$1" f="$2" pat="$3"
  if grep -q -- "$pat" "$f" 2>/dev/null; then echo "  ❌ $n (仍在 $f 命中: $pat)"; FAIL=$((FAIL+1));
  else echo "  ✅ $n"; PASS=$((PASS+1)); fi
}
# 同 chkfn，但先剔掉注释行 —— 这些修复的注释里往往要引用被删掉的旧写法说明
# 「为什么不能这么写」，纯文本 grep 会把注释当成 bug 复现。
chkfn_code() { local n="$1" f="$2" pat="$3"
  if grep -v -E '^[[:space:]]*(//|\*|/\*|--)' "$f" 2>/dev/null | grep -q -- "$pat"; then
    echo "  ❌ $n (仍在 $f 的非注释代码里命中: $pat)"; FAIL=$((FAIL+1));
  else echo "  ✅ $n"; PASS=$((PASS+1)); fi
}

echo "小程序首页硬编码/失效配置 smoke:"

# ---------- A. 后端：/api/product/list 支持 typeCode ----------
# 首页「预约服务」tab 原先只能写死一张图，根因就是这个端点没有 typeCode 入参
BK=$($H_CURL curl -s "$H/api/product/list?merchantId=1&typeCode=BOOKING" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);r=d.get("data") or [];print(len(r), len([x for x in r if x.get("typeCode")=="BOOKING"]))')
BK_N=$(echo "$BK" | awk '{print $1}')
BK_OK=$(echo "$BK" | awk '{print $2}')
chk "A1) typeCode=BOOKING 返回非空" "$([ "${BK_N:-0}" -gt 0 ] && echo yes || echo no)" "yes"
chk "A2) typeCode=BOOKING 结果全是 BOOKING" "$BK_N" "$BK_OK"

ALL_N=$(curl -s "$H/api/product/list?merchantId=1" \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("data") or []))')
chk "A3) 不传 typeCode 仍返全量（兼容既有调用）" "$([ "${ALL_N:-0}" -gt "${BK_N:-0}" ] && echo yes || echo no)" "yes"

# ---------- B. 后端：门店电话不再被脱敏 ----------
# Store.phone/servicePhone 曾加 @Sensitive(PHONE)，而 SensitiveJsonSerializer
# 拿不到 LoginUser 时 catch 返 true → 匿名请求一律打码 → wx.makePhoneCall 必失败
MASKED=$(curl -s "$H/api/store/list?page=1&pageSize=20" \
  | python3 -c 'import sys,json
d=json.load(sys.stdin); rows=d.get("rows") or d.get("data") or []
print(len([r for r in rows if "*" in str(r.get("phone") or "") or "*" in str(r.get("servicePhone") or "")]))')
chk "B1) 匿名门店列表里没有被打码的电话" "$MASKED" "0"
chkfn_code "B2) Store.java 不再给电话字段加 @Sensitive" "ruoyi-system/src/main/java/com/ruoyi/biz/domain/Store.java" "@Sensitive"

# ---------- C. 前端：banner 不传 merchantId=0 ----------
HJS=$MP/pages/home/index.js
chkfn "C1) loadBanners 不再硬传 merchantId: 0" "$HJS" "merchantId: 0"
chkf  "C2) merchantId 拿到才传" "$HJS" "if (mid) params.merchantId = mid"
chkf  "C3) 丢弃 http 图（小程序 image 只支持 https）" "$HJS" "http:\\\\/\\\\/"
# banner 是平台/商户级资源，必须在 onLoad 直接拉。
# 它曾经挂在 loadData 的 pickNearestStore 回调里，而那个回调只在门店「变化」时
# 触发（app.js useStore: if (changed) callback(s)）；app.js onLaunch 的
# bootDefaultStore() 已先把 globalData.store 填好 → changed=false → 回调不执行
# → loadBanners 一次都没被调用，后台配了 banner 也恒空白。
chkf  "C4) onLoad 直接调 loadBanners（不依赖门店回调）" "$HJS" "this.loadBanners();"
chkfn_code "C5) loadBanners 不再挂在门店回调里按 storeId 调" "$HJS" "this.loadBanners(store.storeId)"

# ---------- D. 前端：距离不再恒「计算中」 ----------
chkfn_code "D1) 距离不再兜底成「计算中…」" "$HJS" "|| '计算中…'"
chkf  "D2) 提供点击取位入口 requestDistance" "$HJS" "requestDistance()"
chkf  "D3) wxml 用 hasDistance 分支" "$MP/pages/home/index.wxml" "store.hasDistance"

# ---------- E. 前端：设施标签/详情不再写死 ----------
chkfn "E1) 不再写死「可堂食」标签" "$MP/pages/home/index.wxml" ">可堂食<"
chkf  "E2) 标签走后端 facilityTags" "$MP/pages/home/index.wxml" "facilityTags"
chkf  "E3) 详情抽屉可滚动（原先写死 height:120rpx 截断内容）" "$MP/pages/home/index.wxss" "max-height: 60vh"

# ---------- F. 前端：预约服务 tab 接真实商品 ----------
chkfn "F1) 预约面板不再写死「堂食预约」" "$MP/pages/home/index.wxml" "bp-ttl\">堂食预约"
chkf  "F2) 预约面板渲染 bookingGoods" "$MP/pages/home/index.wxml" "wx:for=\"{{bookingGoods}}\""
chkf  "F3) loadBookingGoods 按 typeCode=BOOKING 拉" "$HJS" "typeCode: 'BOOKING'"

# ---------- G. 前端：商品副标题不再写死有效期 ----------
chkfn "G1) 不再写死「购买后365天内可用」" "$MP/pages/home/index.wxml" "购买后365天内可用"
chkf  "G2) app.js 按 validityDays/typeCode 生成描述" "$MP/app.js" "buildGoodsDesc(p)"

# ---------- H. 商家端建品：品类不再写死 5 条服饰串 ----------
CJS=$MP/pages/merchant/product/create/index.js
chkfn_code "H1) categoryList 不再硬编码中文品类" "$CJS" "购物·服饰鞋帽·服装"
chkf  "H2) 品类来自 /api/product/category/list" "$CJS" "api.categoryList()"
chkf  "H3) 选品类同时落 form.categoryId（原先只写展示串，落库恒 null）" "$CJS" "'form.categoryId': id > 0 ? id : 0"

CAT_N=$(curl -s "$H/api/product/category/list" \
  | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("data") or []))')
chk "H4) 品类接口返回非空" "$([ "${CAT_N:-0}" -gt 0 ] && echo yes || echo no)" "yes"

echo ""
echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
