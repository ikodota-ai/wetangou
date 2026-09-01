#!/usr/bin/env bash
# 小程序模板漂移护栏
#
# 背景（这是一个真实踩过的坑，不是假想）：
# 后台「一键打包小程序代码包」/biz/codepack/{merchantId} 读的是
# classpath:template/miniprogram7/。这份模板曾经是手工从 miniprogram7/ 复制的副本，
# 结果它停在 2026-08-06，此后 miniprogram7/ 改了 59 个 commit 一次都没同步过去——
# 商家下载到的始终是三周前的旧代码，症状是「代码里明明改好了，真机上还是没有」
# （例如到店自取下单页看不到优惠券入口、首页没有门店评分）。
#
# 修法是 ruoyi-admin/pom.xml 用 maven-resources-plugin 在 generate-resources 阶段
# 从唯一源 miniprogram7/ 自动拷贝。本脚本守住三件事，防止有人把副本改回来：
#   1) 源码目录下不能再出现手工副本 src/main/resources/template/miniprogram7
#   2) pom.xml 里那段自动拷贝配置必须还在
#   3) 若已编译，target/classes 下的模板必须与 miniprogram7/ 关键文件一致
set -u
cd "$(dirname "$0")/../.." || exit 1

PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "== 小程序模板漂移检查 =="

# 1) 手工副本不能存在（它一旦存在就会覆盖/混淆构建产物，并再次开始漂移）
COPY=ruoyi-admin/src/main/resources/template/miniprogram7
if [ -d "$COPY" ]; then
  ng "存在手工副本 $COPY —— 请删除，模板由 pom.xml 构建期自动同步"
else
  ok "无手工副本（模板唯一源为 miniprogram7/）"
fi

# 2) pom 自动拷贝配置在位
if grep -q "copy-miniprogram-template" ruoyi-admin/pom.xml; then
  ok "pom.xml 保留 copy-miniprogram-template 执行段"
else
  ng "pom.xml 缺 copy-miniprogram-template —— 代码包会打不进小程序模板"
fi
if grep -q "miniprogram7" ruoyi-admin/pom.xml; then
  ok "pom.xml 指向 ../miniprogram7 为源目录"
else
  ng "pom.xml 未指向 miniprogram7 源目录"
fi

# 3) 已编译时比对关键文件（未编译则跳过，不算失败）
OUT=ruoyi-admin/target/classes/template/miniprogram7
if [ -d "$OUT" ]; then
  DIFFN=0
  # 挑几个最能暴露漂移的文件：下单页(券入口)、首页、app.json、utils
  for f in pages/order/submit/index.js pages/order/submit/index.wxml \
           pages/home/index.js pages/home/index.wxml app.js app.json \
           utils/request.js utils/voucher.js utils/rating.js utils/contact.js; do
    if [ -f "miniprogram7/$f" ]; then
      if [ ! -f "$OUT/$f" ]; then
        ng "构建产物缺文件 $f"
        DIFFN=$((DIFFN+1))
      elif ! cmp -s "miniprogram7/$f" "$OUT/$f"; then
        ng "构建产物与源不一致 $f"
        DIFFN=$((DIFFN+1))
      fi
    fi
  done
  [ "$DIFFN" -eq 0 ] && ok "target/classes 模板与 miniprogram7/ 关键文件一致（10 项）"

  # node_modules 绝不能进代码包（体积爆炸 + 微信开发者工具会报错）
  if [ -d "$OUT/node_modules" ]; then
    ng "构建产物含 node_modules —— pom excludes 失效"
  else
    ok "构建产物不含 node_modules"
  fi
else
  echo "  ⏭  未编译（$OUT 不存在），跳过产物比对"
fi

echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
