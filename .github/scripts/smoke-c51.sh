#!/usr/bin/env bash
# V2.6 P0 下单校验 smoke
# 覆盖 5 类限制条件：库存 / 单次限购 / 每人限购 / 售卖开始 / 售卖结束
set -u
H=http://127.0.0.1:8080
MYSQL="/usr/local/mysql/bin/mysql --default-character-set=utf8mb4 -uroot -p133301 ry-vue"
PASS=0; FAIL=0

# 工具函数
check() {
  local label="$1" expected_substr="$2" got="$3"
  if echo "$got" | grep -q "$expected_substr"; then
    echo "  ✅ $label"
    PASS=$((PASS+1))
  else
    echo "  ❌ $label expect~'$expected_substr' got='$got'"
    FAIL=$((FAIL+1))
  fi
}

# 登录拿 token（mock 模式用 code 当 openid）
login() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"code\":\"$1\",\"appid\":\"wx9e147c4e2151b123\",\"nickName\":\"c51\"}" \
    $H/api/auth/login \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))"
}

# 下单接口
place() {
  local tk="$1" pid="$2" num="$3"
  curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $tk" \
    -d "{\"productId\":$pid,\"num\":$num,\"storeId\":200}" \
    $H/api/order
}

# === 准备：登录拿两个测试账号 ===
TS=$(date +%s)
TK_A=$(login "c51_a_${TS}")
TK_B=$(login "c51_b_${TS}")
[ -n "$TK_A" ] && [ -n "$TK_B" ] || { echo "login FAIL"; exit 2; }
echo "tokens: A=${#TK_A} B=${#TK_B}"

# === 创建 5 个测试商品，每个对应一种限制 ===
PIDS=()
# P1: stock=0 (库存不足)
P1=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-stock0', 'GROUPON', 9.9, 0, '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P1")
# P2: maxPerOrder=2 (单次限购 2)
P2=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,max_per_order,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-mpo2', 'GROUPON', 9.9, 100, 2, '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P2")
# P3: limitPerUser=1 (每人限购 1)
P3=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,limit_per_user,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-lpu1', 'GROUPON', 9.9, 100, 1, '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P3")
# P4: saleStartDate 未来 (未开售)
P4=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,sale_start_date,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-future', 'GROUPON', 9.9, 100, DATE_ADD(NOW(), INTERVAL 7 DAY), '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P4")
# P5: saleEndDate 过去 (已过售卖期)
P5=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,sale_end_date,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-past', 'GROUPON', 9.9, 100, DATE_SUB(NOW(), INTERVAL 1 DAY), '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P5")
# P_OK: 正常商品 (对照组)
P_OK=$($MYSQL -N -e "
INSERT INTO biz_product (merchant_id,store_id,product_name,type_code,price,stock,status,del_flag,create_by,create_time)
VALUES (1, 200, 'C51-ok', 'GROUPON', 9.9, 100, '0', '0', 'smoke-c51', NOW());
SELECT LAST_INSERT_ID();" 2>/dev/null)
PIDS+=("$P_OK")
echo "test product ids: ${PIDS[*]}"

# === 1) 库存 = 0 → 拒绝 ===
R=$(place "$TK_A" "$P1" 1)
check "stock=0 拒绝" "库存不足" "$R"

# === 2) maxPerOrder=2 → 数量 3 拒绝 ===
R=$(place "$TK_A" "$P2" 3)
check "maxPerOrder=2 数量 3 拒绝" "单次最多购买 2" "$R"

# === 3) limitPerUser=1 → 第一次 OK，第二次拒绝 ===
R1=$(place "$TK_A" "$P3" 1)
check "limitPerUser 首次 OK" "操作成功" "$R1"
R2=$(place "$TK_A" "$P3" 1)
check "limitPerUser 二次拒绝" "每人限购 1" "$R2"

# === 4) saleStartDate 未来 → 拒绝 ===
R=$(place "$TK_A" "$P4" 1)
check "未开售拒绝" "尚未开始售卖" "$R"

# === 5) saleEndDate 过去 → 拒绝 ===
R=$(place "$TK_A" "$P5" 1)
check "已过售卖期拒绝" "已过售卖期" "$R"

# === 6) 对照组：正常商品应该下单成功 ===
R=$(place "$TK_A" "$P_OK" 1)
check "正常商品 OK" "操作成功" "$R"

# === 7) 每人限购：另一个账号首次应该 OK (上面 A 限了 1 件，B 没买过) ===
R=$(place "$TK_B" "$P3" 1)
check "limitPerUser 另一个账号 OK" "操作成功" "$R"

# 清理
$MYSQL -e "
DELETE FROM biz_order WHERE product_id IN (${PIDS[*]});
DELETE FROM biz_product WHERE product_id IN (${PIDS[*]});
DELETE FROM biz_member WHERE openid LIKE 'mock_c51_%';
DELETE FROM sys_user WHERE user_name LIKE 'c51_%';
" 2>/dev/null

echo "============================="
echo "V2.6 P0 smoke: $PASS pass / $FAIL fail"
[ $FAIL -eq 0 ] || exit 1
