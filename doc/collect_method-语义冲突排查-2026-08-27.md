# `biz_product.collect_method` 语义冲突排查报告

> 起因：补商品查看态详情页（commit `ef467d38`）时发现，后台 `create.vue` 把这一列
> 当「收单方式 HEAD/STORE」用，而建表 comment 和 `Product.java` 注释写的是
> 「券码类型 PLATFORM/THIRD_PARTY/MERCHANT_OWN」。详情页当时只做了兼容展示，
> 语义统一留作独立排查。本文是排查结论。

---

## 一、结论先说

**这一列的 comment 是错的，「券码类型」语义已在上一轮被独立字段取代。**

`collect_method` 现在唯一合法语义就是字段名本身的意思——**收款方式**。
但它目前是一个**影子字段**：三套取值混在一列、没有任何业务代码读它、
两端表单显示的和落库的还不一致。

需要修的有 4 处，都不涉及数据语义变更风险（因为没人读）。

---

## 二、三套取值的来源，逐一定位

| 取值 | 来源 | 首次引入 |
|---|---|---|
| `PLATFORM` / `THIRD_PARTY` / `MERCHANT_OWN` | 建表 DEFAULT + comment（**券码类型**语义） | `4e071924` `sql/biz_product_model_v2.sql:92` |
| `HEAD` / `STORE` | 后台 `create.vue` 的「收单方式」单选（**收款方式**语义） | `83bf4493` / `7e1e8056` |
| `HEADQUARTERS` / `STORE` | PRD 原始定义（**收款方式**语义） | `doc/PRD-抖音来客商品模型.md:111` |

### 冲突根因

PRD 里这本来是**两个不同字段**，分属两个表单区块：

```
doc/PRD-抖音来客商品模型.md:111
| 收款方式  | 不可编辑 | enum | HEADQUARTERS / STORE                  | 总部统一收款 / 门店独立收款 |
doc/PRD-抖音来客商品模型.md:121
| 券码类型  | 是      | enum | PLATFORM / THIRD_PARTY / MERCHANT_OWN | 抖音券/第三方券/商家自有码   |
```

`4e071924` 建列时把「券码类型」的取值和 comment 挂到了名叫 `collect_method`
（收款方式）的列上 —— 名字取的是前者，语义写的是后者。后续两批开发各自
按「名字」和「comment」理解，就分叉成两套值。

### 「券码类型」现在有专属列了

上一轮字段落库（`7e1e8056` / `sql/upgrade/biz_product_field_gap_v4.sql:77`）已经建了
`biz_product_ext.code_type`，取值 `MERCHANT` / `PLATFORM`，实测 415 行全有值：

```
biz_product_ext.code_type  default 'MERCHANT'  -- MERCHANT商家券/PLATFORM平台券
select code_type, count(*) from biz_product_ext group by code_type;
→ MERCHANT  415
```

**所以 `collect_method` 上的「券码类型」comment 是彻底的历史遗留，
现在是重复定义，必须清掉，否则后来人还会再踩一次。**

---

## 三、存量数据分布与归因（实测）

```sql
select collect_method, count(*) cnt, min(create_time), max(create_time)
  from biz_product where del_flag='0' group by collect_method;
```

| 取值 | 条数 | 最早 | 最晚 | 归因 |
|---|---|---|---|---|
| `PLATFORM` | 229 | 2026-07-24 | 2026-08-22 | **全部是建表 DEFAULT 兜底**，没有任何一条是用户选的 |
| `HEAD` | 2 | 2026-08-26 09:18 | 2026-08-26 15:29 | 后台 `create.vue` 上线后建的 2 个商品 |

- 无 NULL、无空串（`default 'PLATFORM'` 顶住了）
- 那 2 条 `HEAD` 是 `999846`「99元任选3件」和 `999860`「多分组子商品测试」——
  时间线与后台分段式创建页上线完全吻合
- 交叉核对商户侧：两个商户 `biz_merchant.pay_mode` 都是 `0`（商户自有商户号），
  231 个商品的 `collect_method` 与之**毫无关联** → 进一步印证这列没被任何
  真实收款逻辑使用

---

## 四、穷举读写路径：没有任何业务代码读它

全仓 grep（`ruoyi-system` / `ruoyi-admin` / `ruoyi-common` / `ruoyi-ui/src` / `miniprogram7`）：

**写入方（3 处）**
- `ProductMapper.xml:197/249/304` —— insert / update 的 `<if>` 分支
- `ruoyi-ui/src/views/biz/product/create.vue:121` —— 后台表单单选，默认 `HEAD`
- `miniprogram7/pages/merchant/product/create/index.js:275/340/660` —— 默认 `PLATFORM`

**读取方（0 处业务逻辑）**
- `ProductMapper.xml:44/97` —— resultMap 映射 + select 列
- `Product.java:418` —— getter（无调用方）
- `detail.vue:296` —— 本轮新加的详情展示
- `ProductValidator` **无任何校验**
- 顾客端 `/api/product/*` 响应里带着它，但小程序 wxml **从不渲染**

**即：改这一列的取值不会破坏任何现有业务逻辑。这是本次治理风险极低的根本原因。**

---

## 五、排查中发现的两个真实 bug

### bug 1：小程序商家端「显示总部统一收款、落库 PLATFORM」

```
miniprogram7/pages/merchant/product/create/index.wxml:73-74
  <text class="row-label">收款方式 <text class="readonly-tag">不可编辑</text></text>
  <text class="readonly-value">总部统一收款</text>      ← 硬编码文案

miniprogram7/pages/merchant/product/create/index.js:660
  collectMethod: f.collectMethod || 'PLATFORM',         ← 实际落库
```

UI 写死显示「总部统一收款」（对应 `HEAD`），却往库里写 `PLATFORM`。
且商家端**没有任何交互能改这个值**（`grep collectMethod` 在 wxml 里 0 处绑定），
纯粹是无脑透传一个常量。229 条 `PLATFORM` 里绝大部分就是这么来的。

### bug 2：后台标「不可编辑」的字段，在后台却能编辑

PRD 明确写「收款方式 | **不可编辑**」，小程序端也标了「不可编辑」徽标，
但后台 `create.vue:121` 给的是一个可点的 `el-radio-group`，运营能随便改。
这也是那 2 条 `HEAD` 的由来。

> 业务上讲得通的做法：收款方式应由**商户的支付配置**推导（`biz_merchant.pay_mode`：
> 0 商户自有商户号 / 1 平台统一收款），而不是建每个商品时手选 ——
> 同一商户的两个商品收款方式不同在结算上没有意义。

---

## 六、可执行方案

### 方案 A（推荐）：统一为收款方式语义，值从商户配置推导

**为什么推荐**：与 PRD「不可编辑」一致，消灭影子字段，且没有任何读取方
需要适配（第四节已穷举）。

1. **SQL**（幂等）
   - 改 comment：`'券码类型 PLATFORM/THIRD_PARTY/MERCHANT_OWN'`
     → `'收款方式 HEAD总部统一收款/STORE门店独立收款'`
   - 改 DEFAULT：`'PLATFORM'` → `'HEAD'`
   - 存量归一：229 条 `PLATFORM` → 按所属商户 `pay_mode` 映射
     （`pay_mode='1'`→`HEAD`，`'0'`→ 也落 `HEAD`，因为「商户自有商户号」
     在当前单店形态下等价于总部收款；等真有连锁分店独立收款场景再区分 `STORE`）
   - 取值统一用 `HEAD` 而非 PRD 的 `HEADQUARTERS`：列宽 `varchar(20)` 够，
     但仓内已有 2 条 `HEAD` 且 `create.vue`/`detail.vue` 都用 `HEAD`，
     改成 `HEADQUARTERS` 要动 3 个文件却没有任何收益

2. **后端**
   - `Product.java:141` 注释同步改成收款方式
   - 新建商品时若未传，由 `merchantId` 查 `pay_mode` 推导（而非依赖 DDL DEFAULT）

3. **前端**
   - 后台 `create.vue:121`：`el-radio-group` → 只读 `el-input`（与 PRD「不可编辑」
     和小程序端徽标一致），值由所属商家带出
   - 小程序 `create/index.js:275/660`：`'PLATFORM'` → 不再硬传，跟随后端推导；
     wxml 硬编码文案改成绑定真实值（修 bug 1）
   - `detail.vue`：把兼容用的 `PLATFORM/THIRD_PARTY/MERCHANT_OWN` 三条映射删掉

4. **顾客端接线**（审计文档 B 类第 4 项，`detail_379` 有「收款方式」行）
   - 小程序商品详情「购买须知」补这一行，让后台配的东西真被顾客看到

### 方案 B（最小改动）：只清 comment，不动数据

只改 comment + `Product.java` 注释，说明「取值以 `HEAD`/`STORE` 为准，
存量 `PLATFORM` 视同 `HEAD`」，`detail.vue` 保留兼容映射。

- 代价：229 条脏值永久留着，每个新来的人都要看一遍兼容注释才敢动
- 适用：如果短期内不打算做连锁分店独立收款

### 不建议的方案

**把 `collect_method` 改回券码类型语义** —— `biz_product_ext.code_type` 已经承接
这个语义且 415 行全有值，改回去等于制造两列重复定义，是在放大问题。

---

## 七、影响面清单（改动时的 checklist）

| 文件 | 位置 | 动作 |
|---|---|---|
| `sql/biz_product_model_v2.sql` | :92 | comment + DEFAULT |
| `sql/biz_product_model_v2_safe.sql` | :56 | 同上 |
| 新建迁移 SQL | — | 改 comment / DEFAULT + 229 条存量归一 |
| `sql/deploy/wetuangou.sql` | 自动 | 改完源脚本后跑 `build-merged.py` 重新生成 |
| `ruoyi-system/.../domain/Product.java` | :141 | 注释 |
| `ruoyi-ui/src/views/biz/product/create.vue` | :121, :612 | 单选改只读 + 默认值 |
| `ruoyi-ui/src/views/biz/product/detail.vue` | COLLECT 常量 | 删兼容映射 |
| `miniprogram7/pages/merchant/product/create/index.js` | :275, :340, :660 | 默认值 |
| `miniprogram7/pages/merchant/product/create/index.wxml` | :73-74 | 硬编码文案改绑定 |
| `.github/scripts/smoke-product-detail.sh` | B12/B17 | 断言随之调整 |

`ProductMapper.xml` 无需改（只是列的读写，与取值无关）。

---

## 八、实测命令（复现本报告数据）

```bash
DB="/usr/local/mysql/bin/mysql -uroot -pxxx ry-vue --default-character-set=utf8mb4"

# 存量分布 + 时间归因
$DB -e "select collect_method, count(*) cnt, min(create_time), max(create_time)
          from biz_product where del_flag='0' group by collect_method;"

# 那 2 条 HEAD 是谁
$DB -e "select product_id, product_name, create_time from biz_product
         where collect_method='HEAD' and del_flag='0';"

# 与商户支付配置的关联（结论：无关联）
$DB -e "select p.collect_method, m.merchant_id, m.pay_mode, count(*)
          from biz_product p left join biz_merchant m on m.merchant_id=p.merchant_id
         where p.del_flag='0' group by 1,2,3;"

# 券码类型已独立
$DB -e "select code_type, count(*) from biz_product_ext group by code_type;"

# 穷举读写方
grep -rn "collectMethod\|collect_method" ruoyi-system/src ruoyi-admin/src \
  ruoyi-common/src ruoyi-ui/src miniprogram7/pages miniprogram7/utils
```
