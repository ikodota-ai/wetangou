#!/usr/bin/env bash
# 门店类匿名接口的 appid（租户）归属校验
#
# 背景（真实事故）：管理员登录商家版后点顶部 home 回到会员端，首页顶着 A 商户的
# 招牌显示了 B 商户的门店。两个原因叠加：
#   1) StoreMapper.selectStoreByStoreId 标了 @IgnoreTenant（按主键查不带 merchant_id
#      条件），归属本该由调用方自己断言 —— PC 端 StoreController 一直有
#      TenantFilterHelper.assertDataScope，小程序端 /api/store/{id} 系列 3 个端点漏了。
#   2) 小程序 lastStoreId 是不区分 appid 的全局缓存键，换个商户的小程序进来会拿
#      上一家残留的 storeId 直接调详情还原（已改为 lastStoreId:<appid>）。
# appid 即租户边界，任意小程序都不该读到别家门店。
set -u
BASE="${BASE:-http://localhost:8080}"
APP_M1="wx9e147c4e2151b123"        # 商户 1
APP_M200="wx-test-agent02-0001"    # 商户 200
STORE_M1=100                        # 属商户 1
STORE_M200=201                      # 属商户 200

PASS=0; FAIL=0
ck() {
  local name="$1" got="$2" exp="$3"
  if [ "$got" = "$exp" ]; then echo "PASS | $name"; PASS=$((PASS+1));
  else echo "FAIL | $name | got=[$got] exp=[$exp]"; FAIL=$((FAIL+1)); fi
}
code() { curl -s "$BASE$2" -H "X-App-Id: $1" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('code',''))
except Exception: print('')"; }
field() { curl -s "$BASE$2" -H "X-App-Id: $1" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin).get('data') or {}
    print(d.get('$3',''))
except Exception: print('')"; }

echo "=== 门店接口租户归属 ($BASE) ==="

# --- 同租户：正常可读 ---
ck "本商户读自家门店详情"     "$(code $APP_M1 /api/store/$STORE_M1)"            "200"
ck "  → 返回的是自家门店"     "$(field $APP_M1 /api/store/$STORE_M1 merchantId)" "1"
ck "本商户读自家门店服务"     "$(code $APP_M1 /api/store/$STORE_M1/services)"   "200"
ck "本商户读自家门店相册"     "$(code $APP_M1 /api/store/$STORE_M1/album)"      "200"

# --- 跨租户：三个端点都必须拒 ---
ck "他家 appid 读门店详情被拒" "$(code $APP_M200 /api/store/$STORE_M1)"          "500"
ck "他家 appid 读门店服务被拒" "$(code $APP_M200 /api/store/$STORE_M1/services)" "500"
ck "他家 appid 读门店相册被拒" "$(code $APP_M200 /api/store/$STORE_M1/album)"    "500"
# 反向同样成立（不是只保护商户 1）
ck "反向跨租户读详情被拒"      "$(code $APP_M1 /api/store/$STORE_M200)"          "500"

# --- 列表/最近门店本就带租户条件，确认没被误伤 ---
ck "门店列表仍可用"            "$(code $APP_M1 /api/store/list)"                 "200"
ck "最近门店仍可用"            "$(code $APP_M1 /api/store/nearest)"              "200"
LIST_MIDS=$(curl -s "$BASE/api/store/list" -H "X-App-Id: $APP_M200" | python3 -c "import sys,json
try:
    rows=json.load(sys.stdin).get('data') or []
    print(','.join(sorted({str(r.get('merchantId')) for r in rows})) or 'empty')
except Exception: print('ERR')")
ck "他家列表不含商户1的门店"   "$(echo "$LIST_MIDS" | grep -q '^1$\|^1,' && echo leaked || echo clean)" "clean"

# --- 小程序侧：门店缓存键必须按 appid 隔离 ---
APPJS="miniprogram7/app.js"
ck "缓存键带 appid"            "$(grep -q "lastStoreId:' + APPID" "$APPJS" && echo yes || echo no)" "yes"
ck "不再用全局 lastStoreId"    "$(grep -qE "getStorageSync\('lastStoreId'\)|setStorageSync\('lastStoreId'" "$APPJS" && echo no || echo yes)" "yes"

# --- 商家端首页要有退出入口（原来只藏在「我的」子页里）---
MHOME="miniprogram7/pages/merchant/home/index.wxml"
ck "商家端首页有退出入口"      "$(grep -q 'onLogoutStaff' "$MHOME" && echo yes || echo no)" "yes"

echo "=== PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
