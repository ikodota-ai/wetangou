# 洞天团购 小程序 API 文档

> 适用版本：2026-08-01（多商户 + 代理商改造后）
> 后端实现：`ruoyi-admin/src/main/java/com/ruoyi/web/api/Api*Controller.java`
> 小程序调用封装：`miniprogram7/utils/request.js`
> 本文接口清单与响应结构**均以真实接口实测结果为准**，非按代码推断。差异与缺口见第 9 章。

---

## 1. 通用约定

### 1.1 基础信息

| 项 | 值 |
| --- | --- |
| 基础地址 | 开发 `http://localhost:8080`；生产取「小程序平台配置」→ 小程序接口域名（`wx.open.apiBaseUrl`） |
| 路径前缀 | `/api`，该前缀下全部接口由 `MemberAuthInterceptor` 统一拦截 |
| 报文格式 | 请求 `application/json`；上传用 `multipart/form-data` |
| 字符集 | UTF-8 |

### 1.2 请求头

| 头 | 必填 | 说明 |
| --- | --- | --- |
| `Authorization` | 登录态接口必填 | 会员 token 原文，**不带 `Bearer ` 前缀**（与后台管理端不同） |
| `X-App-Id` | 建议始终带 | 小程序 appid，后端据此识别商户实现数据隔离；缺失时兜底默认商户 |
| `Content-Type` | POST/PUT 必填 | `application/json` |

`X-App-Id` 在 `miniprogram7/utils/request.js` 中已统一注入，值取 `wx.getAccountInfoSync()`，各商户独立打包无需改代码。

### 1.3 统一响应结构

```json
{ "code": 200, "msg": "操作成功", "data": {} }
```

| code | 含义 | 处理建议 |
| --- | --- | --- |
| 200 | 成功 | 取 `data` |
| 401 | 未登录或 token 过期 | 清除本地 token，跳登录页 |
| 500 | 业务异常 | `msg` 是可直接展示的中文提示 |

**注意两处非标准返回**（小程序侧已兼容，新写代码需留意）：

- `POST /api/auth/login`：`token`、`memberId` 挂在**响应根级**，不在 `data` 里。
- `POST /api/member/phone`、`POST /api/member/avatar`：`phone`、`imgUrl`/`url` 同样挂根级。
- 部分列表接口在无数据时返回 `data: []`；`GET /api/distributor/center` 在未成为推客时**不返回 `data` 字段**，需判 `undefined`。

### 1.4 多商户隔离机制

- 已登录：token 载荷含 `merchantId`，拦截器写入租户上下文，MyBatis 自动给 SQL 追加 `merchant_id` 条件。
- 未登录（门店/商品/协议等匿名接口）：按 `X-App-Id` 查商户；查不到或未传则兜底默认商户 ID=1，**不置空**（否则匿名接口会返回全平台数据）。
- 同一微信 openid 在不同商户下是**互相独立的会员记录**。

---

## 2. 认证登录

### 2.1 微信登录

`POST /api/auth/login` · 匿名

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| code | string | 是 | `wx.login()` 返回的 code |
| appid | string | 否 | 商户识别用；建议传，未传则落到默认商户 |
| nickName | string | 否 | 首次登录时写入会员昵称 |
| avatarUrl | string | 否 | 首次登录时写入会员头像 |

响应（实测）：

```json
{ "msg": "登录成功", "code": 200, "token": "eyJhbGciOiJIUzUxMiJ9...", "memberId": 1011 }
```

行为说明：
- openid 不存在则自动注册会员，存在则更新 `last_login_time` 与传入的昵称/头像。
- appid 传了但查不到商户 → `小程序未接入或已停用：{appid}`；商户停用 → `商户已停用，请联系服务商`。
- 商户或全局开启 mock 且未配 appId 时，用 `mock_ + code` 派生 openid，便于本地全链路联调。

### 2.2 获取当前会员

`POST /api/auth/info` · 需登录。响应 `data` 为会员对象，同 `GET /api/member/profile`。

### 2.3 退出登录

`POST /api/auth/logout` · 需登录。服务端销毁 token。

---

## 3. 会员

### 3.1 我的资料

`GET /api/member/profile` · 需登录

```json
{ "code": 200, "data": {
  "memberId": 1011, "merchantId": 1, "openid": "mock_doctest001",
  "nickname": "文档验证", "avatar": "/assets/avatar/default.png",
  "phone": "", "gender": "0", "birthday": null,
  "status": "0", "lastLoginTime": "2026-08-01", "createTime": "2026-08-01 20:20:40"
} }
```

> 字段名是 `nickname` / `avatar`（非 `nickName` / `avatarUrl`），小程序侧需做映射。

### 3.2 修改资料

`PUT /api/member` · 需登录。请求体为会员对象部分字段（`nickname`、`avatar`、`gender`、`birthday` 等）。
`openid`、`unionid`、`status` 会被后端强制置空，防篡改。

### 3.3 绑定手机号

`POST /api/member/phone` · 需登录

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| code | string | 是 | `<button open-type="getPhoneNumber">` 回调里的 `e.detail.code` |

响应：`{ "code": 200, "msg": "操作成功", "phone": "13800000000" }`

> 后端走的是**微信新版 `getPhoneNumber` 流程（回传 code 后端换号）**，
> 不是旧版 `encryptedData` + `iv` 解密。传 `encryptedData`/`iv` 会因缺少 `code` 而返回「缺少手机号授权code」。

### 3.4 上传头像

`POST /api/member/avatar` · 需登录 · `multipart/form-data`，文件字段名 `avatarfile`。
响应：`{ "code": 200, "imgUrl": "http://host/profile/avatar/xxx.png", "url": "同上" }`

---

## 4. 门店与商品

均为**匿名接口**，按 `X-App-Id` 隔离商户，只返回状态正常/已上架的数据。

| 接口 | 方法 | 参数 | 说明 |
| --- | --- | --- | --- |
| `/api/store/list` | GET | `storeName`、`city` 等 Store 字段可选 | 门店列表，后端强制 `status=0` |
| `/api/store/{storeId}` | GET | 路径参数 | 门店详情 |
| `/api/store/{storeId}/album` | GET | 路径参数 | 门店相册 |
| `/api/product/list` | GET | `storeId`、`categoryId`、`productType` 可选 | 商品列表，后端强制 `status=0` |
| `/api/product/{productId}` | GET | 路径参数 | 商品详情（含 `detail` 富文本） |
| `/api/product/category/list` | GET | `storeId` 可选 | 分类列表 |

门店列表实测字段：`storeId`、`storeName`、`address`、`province`/`city`/`district`、
`businessHours`、`phone`、`latitude`、`longitude`、`logo`、`intro`、`merchantId`、`status`。

商品列表实测字段：`productId`、`productName`、`categoryId`/`categoryName`、`price`、
`cover`、`images`、`detail`、`stock`、`sales`、`validityDays`、`productType`、`storeId`、`status`。

> 图片与富文本里的地址可能是 `/profile/upload/...` 或含 `/dev-api` 前缀的相对路径，
> 需用 `toFullUrl()` / `fixRichText()` 补全（`miniprogram7/utils/request.js` 已提供）。

---

## 5. 代金券

| 接口 | 方法 | 登录 | 说明 |
| --- | --- | --- | --- |
| `/api/voucher/list` | GET | 否 | 可领券列表，`storeId` 可选 |
| `/api/voucher/receive/{voucherId}` | POST | 是 | 领券，返回会员券对象 |
| `/api/voucher/my` | GET | 是 | 我的券，`status` 可选（0未使用 1已使用 2已过期） |

领券校验：券停用 → `代金券不存在或已停用`；已领完 → `代金券已被领完`。
有效期优先按券的 `validDays` 从领取日推算，否则取券的 `validTo`。

---

## 6. 订单（团购券）

### 6.1 下单

`POST /api/order` · 需登录

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| productId | long | 是 | 商品 ID |
| num | long | 否 | 数量，默认 1 |
| memberVoucherId | long | 否 | 使用的会员券 ID |
| distributorId | long | 否 | 推客 ID，用于佣金归属（分享链路带入） |

响应 `data` 关键字段：`orderId`、`orderNo`、`status`、`price`、`num`、
`totalAmount`、`discountAmount`、`payAmount`、`storeId`、`productName`、`productCover`。

校验：商品下架 → `商品不存在或已下架`；库存不足 → `商品库存不足`；
券不属于本人/已用 → `代金券不可用`；未达门槛 → `未达到代金券使用门槛`。

### 6.2 发起支付

`POST /api/order/prepay/{orderId}` · 需登录

- 真实模式：返回 `wx.requestPayment` 所需参数（`timeStamp`、`nonceStr`、`package`、`signType`、`paySign`）。
- mock 模式（未配齐支付凭证）：直接置为已支付，返回 `{ "code": 200, "mock": true }`。
  小程序需判断 `mock === true` 时跳过 `wx.requestPayment` 直接刷新订单。

校验：非本人订单 → `无权支付该订单`；非待支付 → `订单状态不允许支付`。

### 6.3 模拟支付成功

`POST /api/order/pay/{orderId}` · 需登录 · **仅 mock 模式可用**，真实模式返回 `请通过微信支付完成付款`。

支付成功后后端自动：`status=1`（待使用）、生成 12 位核销码、按商品 `validityDays` 计算 `expireTime`、
冻结已用代金券、按佣金规则生成推客佣金记录。

### 6.4 订单列表 / 详情

`GET /api/order/list?status=` · 需登录，仅返回本人订单。
`GET /api/order/{orderId}` · 需登录。

订单状态：`0` 待支付、`1` 待使用、`2` 已核销、`3` 已取消、`4` 已退款。

### 6.5 核销

`POST /api/order/verify` · 需登录

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| verifyCode | string | 是 | 核销码 |
| storeId | long | 否 | 门店 ID，传了会校验订单归属该门店 |

校验：码无效 → `核销码无效`；门店不符 → `该订单不属于当前门店`；重复核销 → `订单状态不可核销`。

> 该接口面向**门店店员**使用，当前用会员 token 鉴权，任何登录会员都能核销任意有效码。
> 生产前需改为门店端角色鉴权（见第 9 章遗留风险）。

---

## 7. 到店买单

流程：会员发起 → 店员确认金额 → 会员支付。

| 接口 | 方法 | 登录 | 说明 |
| --- | --- | --- | --- |
| `/api/bill` | POST | 是 | 发起买单，参数 `storeId`(必填)、`amount`(必填)、`memberVoucherId`(可选) |
| `/api/bill/{billId}` | GET | 是 | 查买单状态（会员轮询店员是否已确认） |
| `/api/bill/confirm/{billId}` | POST | 是 | 店员确认 |
| `/api/bill/prepay/{billId}` | POST | 是 | 发起支付，mock 模式返回 `mock: true` |
| `/api/bill/pay/{billId}` | POST | 是 | 模拟支付成功（仅 mock 模式） |

买单状态：`0` 待确认、`1` 已确认待支付、`2` 已支付。
响应 `data` 含 `billId`、`billNo`、`amount`、`discountAmount`、`payAmount`、`status`。

校验：门店或金额缺失 → `门店与消费金额必填`；未确认就支付 → `买单未确认或状态异常`；
用券未达门槛 → `未达到代金券使用门槛`；券已使用或已过期 → `代金券不可用`。

支付成功后所用会员券自动转 `status=1` 并写 `use_time`，`myVoucher?status=0` 中不再返回。
小程序侧实现见 `miniprogram7/pages/pay/index/index.js`（轮询 `billDetail` 等确认，2 秒/次，上限 2 分钟）。

> ⚠️ `/api/bill/confirm/{billId}` 目前用会员 token 即可调用，`confirmUser` 记为 `member:{memberId}`，
> 缺门店端角色鉴权，待整改（见 10.5）。

---

## 8. 预约与推客

### 8.1 预约

| 接口 | 方法 | 登录 | 说明 |
| --- | --- | --- | --- |
| `/api/booking` | POST | 是 | 报名预约 |
| `/api/booking/list` | GET | 是 | 我的预约，`status` 可选 |
| `/api/booking/{bookingId}` | GET | 是 | 场次详情 |
| `/api/booking/cancel/{signupId}` | POST | 是 | 取消我的报名 |

`POST /api/booking` 参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| bookingId | long | 否 | 指定已有场次；不传则按下列字段**自动建场次** |
| storeId | long | 不传 bookingId 时必填 | 门店 |
| productId | long | 否 | 关联商品 |
| serviceName | string | 否 | 服务名（如「包间」） |
| bookingDate | date | 否 | `yyyy-MM-dd` |
| timeSlot | string | 否 | 如 `18:00-19:00` |
| contact / phone | string | 否 | 联系人与电话 |
| people | int | 否 | 人数，默认 1 |
| remark | string | 否 | 备注 |

响应：`{ "code": 200, "bookingId": 100004, "signupId": 8 }`（同样在根级，不在 `data`）。
报名状态：`0` 待确认、`1` 已取消。

### 8.2 推客

| 接口 | 方法 | 登录 | 说明 |
| --- | --- | --- | --- |
| `/api/distributor/center` | GET | 是 | 推客中心；未加入时无 `data` 字段 |
| `/api/distributor/join` | POST | 是 | 成为推客（幂等，已是推客则返回现有记录） |
| `/api/distributor/commission/list` | GET | 是 | 佣金明细 |
| `/api/distributor/withdraw/list` | GET | 是 | 提现记录 |
| `/api/distributor/withdraw` | POST | 是 | 申请提现 |

提现参数：`amount`(必填)、`withdrawType`、`account`、`accountName`。
校验：非推客 → `您还不是推客`；金额 ≤0 → `提现金额不合法`；超额 → `可提现余额不足`。
申请成功即从 `availableAmount` 扣减冻结。

推客字段：`distributorId`、`level`、`totalCommission`、`availableAmount`、`frozenAmount`、`withdrawAmount`、`status`、`joinTime`。

---

## 9. 协议与支付回调

| 接口 | 方法 | 登录 | 说明 |
| --- | --- | --- | --- |
| `/api/agreement?type=user` | GET | 否 | 用户协议；`type=privacy` 为隐私政策 |
| `/api/pay/notify` | POST | 否 | 微信支付回调，仅微信服务器调用 |

协议响应 `data`：`agreementId`、`agreementType`、`title`、`content`(HTML)、`status`。

> 支付回调当前是**单一地址**，按 `out_trade_no` 前缀区分订单/买单。
> 多商户下不同商户商户号与 APIv3 密钥不同，需改为 `/api/pay/notify/{merchantId}`（见下）。

---

## 10. 小程序功能完整度盘点（2026-08-01 实测）

结论：**后端 C 端接口基本齐备且已实测跑通；小程序侧 21 个页面里只有 4 个真正接了后端，其余仍是 mock 或纯本地假动作。**
即「接口可用，但小程序没调」，这是当前最大的完整度缺口。

### 10.1 后端接口实测结果

以 mock 模式 + 默认商户实测（测试数据已清理、配置已复原）：

| 链路 | 结果 |
| --- | --- |
| 匿名：门店/商品/分类/券/协议列表 | 全部 200，数据正确按商户隔离 |
| 登录：`auth/login` → `member/profile` | 通过，自动注册会员，`merchantId=1` |
| 下单 → prepay(mock) → 核销码生成 | 通过，`status` 0→1，生成 12 位核销码与 30 天有效期 |
| 核销 → 重复核销拦截 | 通过，重复返回 `订单状态不可核销` |
| 领券 → 我的券 | 通过 |
| 买单：发起 → 确认 → 支付 | 通过，`status` 0→1→2 |
| 预约：报名 → 列表 → 取消 | 通过 |
| 推客：join → center → 佣金 → 超额提现拦截 | 通过，超额返回 `可提现余额不足` |
| 手机号绑定（新版 code 流程） | 通过，mock 返回 `13800000000` |
| 改资料 / 无 token 401 | 通过 |

### 10.2 实测中发现并已修复的 3 个阻塞级 bug

这些 bug 会让 C 端主链路在真实使用中直接失败，属本次顺带修复：

1. **10 张业务表的 update/delete 语句带了无效表别名** —— 例如 `OrderMapper.xml` 的
   `where o.order_id = #{orderId}`，但 update/delete 语句并未声明别名 `o`，
   MySQL 直接报 `Unknown column 'o.order_id' in 'where clause'`。
   影响：订单支付、买单确认与支付、提现、佣金、代金券、门店相册、协议、分类、佣金规则、推客
   的**所有更新与删除操作全部失败**。已批量修正为不带别名的列名，涉及
   `Agreement/Category/Commission/CommissionRule/Distributor/Order/PayBill/StoreAlbum/Voucher/Withdraw` 共 20 个语句块。
2. **`biz_order.verify_code` 默认空串 + 全局唯一索引** —— 核销码在支付成功后才生成，
   未支付订单该列为 `''`，而 `uk_verify_code` 是唯一索引，
   导致**同一商户的第二笔订单永远无法创建**（`Duplicate entry '' for key 'uk_verify_code'`）。
   已改列为 `DEFAULT NULL`（MySQL 唯一索引允许多个 NULL），修复脚本 `sql/biz_order_verifycode_fix.sql`，
   建表脚本 `sql/biz_tables.sql` 同步修正。
3. **`SysConfigMapper.updateConfig` 对 `config_value` 判空串** —— 清空任何系统参数时
   只更新了 Redis 缓存、库里仍是旧值，重启后旧值复活。已改为仅判 `null`。

### 10.3 小程序侧接口调用现状

**已真正接后端（4 处）**

| 位置 | 调用 |
| --- | --- |
| `miniprogram7/app.js` | `storeList`、`productList`、`login`、`getUserInfo`（均带 mock 兜底） |
| `miniprogram7/pages/login/login.js` | `/api/auth/login`（失败时 mock 兜底登录） |
| `miniprogram7/pages/goods/detail/index.js` | `productDetail`（**但 mock 命中优先，真实接口实际很少走到**） |
| `miniprogram7/pages/mine/profile/index.js` | 头像上传、改昵称、绑手机号（三者失败均「mock 成功兜底」） |

**未接后端、纯 mock 或假动作（主要缺口）**

| 页面 | 现状 | 应调用 |
| --- | --- | --- |
| ~~`pages/order/submit/index.js`~~ | ✅ **已接真实下单**：商品/门店取后端，下单→prepay，mock 与真实支付双分支 | 已完成 |
| ~~`pages/order/list/index.js`~~ | ✅ **已接真实列表**：5 个 tab 映射后端状态，待支付点击续付；新增 `pages/order/detail` 展示核销码 | 已完成 |
| ~~`pages/pay/index/index.js`~~ | ✅ **已接真实买单**：门店动态加载、真实券筛选、轮询店员确认后支付 | 已完成 |
| `pages/booking/create/index.js` | 时段取 `mock.bookingSlots`，提交只弹成功弹窗 | `POST /api/booking` |
| `pages/booking/list/index.js` | 硬编码 1 条假「待确认」 | `GET /api/booking/list` |
| `pages/booking/detail/index.js` | 取消只弹 toast，门店坐标写死 | `GET /api/booking/{id}`、`POST /api/booking/cancel/{signupId}` |
| `pages/promoter/index/index.js` | 佣金/粉丝数恒为 0，提现弹「已提交」 | `GET /api/distributor/center`、`POST /api/distributor/join` |
| `pages/promoter/records/index.js` | 只切 tab，无数据 | `GET /api/distributor/commission/list` |
| `pages/promoter/withdraw/index.js` | 只弹「已保存」 | `POST /api/distributor/withdraw` |
| ~~`pages/agreement/user|privacy`~~ | ✅ **已接接口**，改用 `rich-text` 渲染 HTML 正文 | 已完成 |
| ~~`pages/album/index.js`~~ | ✅ **已接接口**，跟随当前门店 + 新增全屏预览 | 已完成 |
| `pages/home/index.js` | banner 与设施写死在 data | 需后端补 banner/设施接口，或复用门店 `intro`/`services` |
| ~~`pages/store/service/index.js`~~ | ✅ **已接门店数据**，客服电话/二维码/营业时间跟随门店 | 已完成 |
| 代金券 | **小程序完全没有领券/我的券入口** | `GET /api/voucher/list`、`POST /api/voucher/receive/{id}`、`GET /api/voucher/my` |

**`request.js` 路径错配（✅ 已于 2026-08-01 修复）**

| 封装 | 原声明路径 | 现指向 | 状态 |
| --- | --- | --- | --- |
| `promoterInfo` | `/api/promoter/info` | `/api/distributor/center` | ✅ 已修 |
| `withdrawRecord` → `commissionList` | `/api/promoter/records` | `/api/distributor/commission/list` | ✅ 已修并改名 |
| `withdrawList` | `/api/withdraw/list` | `/api/distributor/withdraw/list` | ✅ 已修 |
| `agreementUser`/`agreementPrivacy` | `/api/agreement/user`、`/api/agreement/privacy` | `/api/agreement?type=` | ✅ 已修 |
| `bookingSlots` | `/api/booking/slots` | 后端不存在 | ⬜ 已移除封装，待后端补接口 |
| `updatePhone` | 传 `encryptedData`+`iv` | 传 `code`（新版流程） | ✅ 已修（含两个调用页） |
| 新增封装 | — | `categoryList`、`verifyOrder`、`cancelBooking`、`prepayBill`、`voucherList`、`receiveVoucher`、`myVoucher`、`joinPromoter`、`applyWithdraw` | ✅ 已补 |

### 10.4 mock 兜底的隐患

`miniprogram7/utils/config.js` 中 `MOCK_ENABLED = true`，且多处 catch 里「失败也报成功」：

- `pages/login/login.js`、`app.js` 的 `wxLogin`：后端不可用时写入 `mock-token-xxx` 并置 `logged = true`，
  用户看起来已登录，但后续所有登录态接口都会 401。
- `pages/mine/profile/index.js`：头像上传、改昵称、绑手机号失败都弹「已更新/授权成功」，
  甚至把手机号伪造成 `138****8888` 写进 globalData，**用户以为保存成功实际没落库**。
- ~~`app.js` 的 `loadStores`/`loadGoods`：接口返回空数组也会切到 mock 数据~~
  ✅ 已修：接口通但无数据时返回空列表并告警，只有**请求失败**才回退 mock，
  避免把示例门店当成商户自己的门店展示。

上线前建议：`MOCK_ENABLED` 改为按环境开关（生产必须 false），
并移除「失败仍提示成功」的兜底，改为明确报错。

### 10.5 后端待补接口

| 需求 | 建议接口 | 优先级 |
| --- | --- | --- |
| 预约可选时段 | `GET /api/booking/slots?storeId=&date=`，按门店营业时间与已满场次计算 | 高（小程序已在调） |
| 首页 banner | `GET /api/home/banner`，或复用门店相册按 tag 过滤 | 中 |
| 门店设施标签 | 门店表已有 `services`，需在详情接口明确返回并约定格式 | 中 |
| 支付回调按商户路由 | `/api/pay/notify/{merchantId}`，`WxPayService` 按商户取凭证 | 高（多商户上线前必须） |
| 门店端核销鉴权 | 现 `/api/order/verify`、`/api/bill/confirm/{id}` 均用会员 token，任何会员可核销/确认任意单 | 高（安全风险） |

### 10.6 收口顺序与进度

1. ✅ 修 `request.js` 路径错误 + `updatePhone` 改传 code（**已完成**）。
2. ✅ 接订单链路：`order/submit`、`order/list`、新增 `order/detail`（**已完成**，实测通过）。
3. ✅ 接买单页 `pay/index`（**已完成**，实测通过，见 10.9）。
4. 接预约三页 + 后端补 `booking/slots`（1.5 天）。
5. 接推客三页（0.7 天）；✅ 协议 + 相册 + 客服页已完成。
6. 补代金券入口（0.5 天，后端已就绪，演示券已入库）。
7. 关闭 mock 兜底、改门店端核销鉴权、支付回调按商户路由（1.5 天）。

8. 修日期字段序列化精度（0.3 天，见 10.10）。

合计约 6 人日可让小程序功能达到「无 mock、全链路真实」的完整状态，其中第 1、2、3 项已完成。

### 10.7 演示数据落库（2026-08-01）

小程序原先在接口无数据时回退 `miniprogram7/utils/mock.js`，关闭 mock 后页面会空白。
已将该份演示数据提取入库，脚本 `sql/biz_demo_data.sql`（幂等，按固定 ID 删除后重建）：

| 内容 | 落库结果 |
| --- | --- |
| 门店「菌鑫来餐饮」 | ID 200，含地址/经纬度/营业时间/客服电话/简介，`services` 用 `biz_store_service` 字典码值 |
| 商品 4 款 | ID 2000-2003（498/268/168/138 元），含市场价、副标题、多图 |
| 套餐明细 | mock 的 `packages` 转 HTML 表格写入 `detail` |
| 使用规则 | mock 的 `availableTime`/`purchaseLimit`/`bookingRule` 等 6 项转列表写入 `notice` |
| 门店相册 | 4 张 |
| 商品分类 | 野生菌套餐 / 火锅锅底 / 预约服务（ID 200-202） |
| 用户协议、隐私政策 | mock 长文转富文本，正文 46 字 → **635 / 686 字** |
| 代金券 | 新客立减 10 元、满 300 减 50（ID 200-201） |

图片：`miniprogram7/assets/img` 下 4 张图拷至上传目录 `upload/demo/`，
经 `http://host/profile/upload/demo/*` 实测 200 可访问（脚本末尾附拷贝命令）。

实测各页数据来源：门店 3 个、菌鑫来商品 4 款、相册 4 张、协议 2 份、可领券 2 张，
商品详情的 `detail` 表格与 `notice` 规则均正确返回。

### 10.8 订单链路落地记录（2026-08-01 实测）

改动文件：
- `miniprogram7/utils/request.js`：修 4 处路径错配、补 9 个封装、`updatePhone` 改新版 code 流程。
- `miniprogram7/pages/order/submit/index.js`：商品与门店改由 `productDetail`/`storeDetail` 拉取
  （价格库存以后端为准，避免用本地假数据下单导致金额不符），提交走 `createOrder` → `prepayOrder`，
  `res.mock === true` 时跳过 `wx.requestPayment`，真实模式走签名支付，取消支付引导至待支付列表。
- `miniprogram7/pages/order/list/index.js`：5 个 tab 映射后端状态（全部/0/1/2/4），
  待支付订单点击直接续付，`onShow` 回到页面自动刷新。
- `miniprogram7/pages/order/detail/index.js`（新增，含 wxml/wxss/json 并注册进 `app.json`）：
  展示核销码（大字号 + 一键复制）、有效期、金额构成与订单号。
- `miniprogram7/pages/goods/detail/index.js`：改为**后端优先**（原先 mock 命中就 return，
  真实接口几乎走不到，且会把 mock 的假 productId 带进下单页），仅接口不可用时回退 mock；
  图片与富文本统一 `toFullUrl`/`fixRichText`。
- `miniprogram7/pages/mine/profile/index.js`：头像上传、改昵称、绑手机号改用统一 `api` 封装，
  **移除「失败也提示成功」的伪造兜底**（原先会把手机号伪造成 `138****8888`），
  昵称字段名修正为后端的 `nickname`。

实测（mock 模式，测试数据已清理、配置已复原）：
- 商品详情返回 `price=128.00 stock=95 storeId=100`，门店详情返回「洞天团购·旗舰店」，
  submit 页依赖字段全部对齐。
- 下单 num=2 → `totalAmount=256.00`、`status=0`；prepay 返回 `mock:true`；
  订单转 `status=1` 并生成核销码 `5CB824D558B9`、有效期 `2026-08-31`。
- tab 筛选正确：unused 1 条、pending 0 条、全部 2 条。
- 待支付订单续付后从 pending 列表消失。
- 库存正确扣减 95 → 92（两单共 3 件）。

### 10.9 买单链路落地记录（2026-08-01 实测）

改动文件：
- `miniprogram7/pages/pay/index/index.js`：门店改为动态加载（支持 `?storeId=` 从首页/门店页带入），
  代金券从 `myVoucher` 拉取真实未使用券，按「消费总额 − 不参与优惠金额」筛选可用券
  （已选券在金额变化后不再满足门槛时自动取消，避免提交时被后端拒绝）；
  提交走 `createBill` → **轮询 `billDetail` 等店员确认**（2 秒间隔、上限 60 次即 2 分钟）
  → `prepayBill`，`res.mock === true` 时跳过 `wx.requestPayment`，成功后跳「我的」。
- `miniprogram7/pages/pay/index/index.wxml`：门店信息动态渲染，新增代金券选择弹层
  （含「不使用」选项与「未达门槛」置灰态）、买单号与当前状态提示行。
- `miniprogram7/pages/pay/index/index.wxss`：追加弹层与优惠行样式。

实测（mock 模式，会员券 id=6 面值 10/门槛 50、id=7 面值 50/门槛 300）：

| 用例 | 结果 |
| --- | --- |
| 缺 `storeId` | `门店与消费金额必填` ✅ |
| `amount=100` 用券 id=7（门槛 300） | `未达到代金券使用门槛` ✅ |
| `amount=400` 用券 id=7 | `billId=100005`、`discountAmount=50.00`、`payAmount=350.00`、`status=0` ✅ |
| `GET /api/bill/100005`（模拟轮询） | `status=0`，并回填 `storeName=菌鑫来餐饮`、`memberName` ✅ |
| 未确认直接 prepay | `买单未确认或状态异常` ✅ |
| `confirm` | `status=1`、写入 `confirmUser=member:1013` ✅ |
| `prepay` | `{"code":200,"mock":true}`，买单转 `status=2` ✅ |
| 券状态联动 | `biz_member_voucher` id=7 转 `status=1` 并写 `use_time` ✅ |
| 已用券再次下单 | `代金券不可用` ✅ |
| `myVoucher?status=0` | 只剩 id=6，已用券不再出现 ✅ |

> 说明：`confirm` 接口当前用会员 token 即可调用（`confirmUser` 记为 `member:{id}`），
> 与 `/api/order/verify` 同属「门店端操作缺角色鉴权」问题，需一并整改（见 10.5）。

### 10.10 待整改：日期字段序列化精度丢失

`ruoyi-system/src/main/java/com/ruoyi/biz/domain/` 下 17 个 `Date` 字段标注了
`@JsonFormat(pattern = "yyyy-MM-dd")`，但库表对应列均为 `datetime`（代码生成器默认行为）。
表现：`confirmTime` 库里是 `2026-08-01 21:29:09`，接口只返回 `2026-08-01`，
时分秒在小程序与后台列表上都看不到。

受影响字段（除 `Member.birthday`、`Booking.bookingDate`、`Voucher.validFrom/validTo` 属真日期语义，
其余建议改为 `yyyy-MM-dd HH:mm:ss`）：

| 实体 | 字段 |
| --- | --- |
| `Order` | `verifyTime`、`payTime`、`expireTime` |
| `PayBill` | `confirmTime` |
| `MemberVoucher` | `getTime`、`useTime`、`expireTime` |
| `Commission` | `settleTime` |
| `SettleRecord` | `finishTime` |
| `Withdraw` | `applyTime`、`finishTime` |
| `Distributor` | `joinTime` |
| `Member` | `lastLoginTime` |

同步需调整的前端列格式化：`ruoyi-ui/src/views/biz/{order,bill,commission,record,distributor,withdraw}/index.vue`
中 `parseTime(row.x, '{y}-{m}-{d}')` → `'{y}-{m}-{d} {h}:{i}:{s}'`。
优先级：中（不阻塞功能，但核销/确认/结算的时分秒是对账依据）。


### 10.11 预约链路落地记录（2026-08-01 实测）

后端改动：
- `ApiBookingController` 新增 `GET /api/booking/slots?storeId=&date=`：按门店 `businessHours` 解析
  起止小时切分时段，18:00 为白天/晚上分界。已取消场次不占容量，剩余 = `biz.booking.slotLimit`（默认 10，可在
  `sys_config` 调整）− 已报名人数，`full`/`expired` 字段分别标记已满与已过；`date=今天` 自动把
  `nowHour` 及之前的时段置 `expired=true`，避免用户点选已过时间。
- 同 controller 新增 `GET /api/booking/signup/{signupId}`：仅允许查询本人报名，越权返回
  `预约记录不存在`，详情页改用此接口。
- `GET /api/booking/{bookingId}` 改为只回传当前会员的报名明细（同场次其他会员的手机号不再泄露）。
- `POST /api/booking/cancel/{signupId}` 改为拒绝越权取消；已取消 / 已完成场次给出明确提示，不再静默成功。
- 报名 `POST /api/booking` 加重复拦截（同会员同场次已报名返回 `您已预约该时段`），
  场次按门店+日期+时段复用，避免多人报名时为同一场次建出多条主表记录。
- `BookingMember` VO 补门店信息（地址/客服电话/经纬度）+ 场次状态 + 场次编号，
  让列表页可直接渲染门店导航与拨号、tab 正确分到「待确认/已完成/已取消」。
- 顺带修掉 `BookingMemberMapper.countByBookingId`/`sumPeopleByBookingId` 在
  `ONLY_FULL_GROUP_BY` 模式下会报错的隐式 bug（select 列表被错带 `merchant_id`）。
- 新增配置脚本 `sql/biz_booking_slot_config.sql` 写入 `biz.booking.slotLimit`，幂等。

小程序改动：
- `pages/booking/create/index.{js,wxml,wxss}`：门店动态加载（支持 `?storeId=`），
  时段取后端接口并按 `available` 过滤；时段下方加「已过 / 已满 / 剩 N」提示，金额变化时自动取消已选券，
  提交时过滤同场次重复预约，失败时刷新时段。
- `pages/booking/list/index.{js,wxml,wxss}`：4 个 tab 对应全部/待确认/已完成/已取消；
  列表行带门店导航/拨号入口；空态分「未登录/无记录/无该分类记录」分别提示。
- `pages/booking/detail/index.{js,wxml,wxss}`：改读本人报名接口，按场次状态显示
  「待确认/已确认/已完成/已取消」并按能否取消控制底部按钮。
- `pages/booking/index.{js,wxml,wxss}`：去掉写死的菌鑫来数据，门店/客服跟随 `app.globalData.store`，
  下方新增「我的预约」入口。
- `request.js` 新增 `bookingSlots`/`bookingSignupDetail` 两个封装。

实测（mock 模式，参数 `biz.booking.slotLimit=10`，测试数据已清理、配置已复原）：

| 用例 | 结果 |
| --- | --- |
| `GET /api/booking/slots?storeId=200`（今天 21 时后） | 所有时段 `expired=true`、`available=false`，门店不存在 99999 报 `门店不存在`，日期格式错报 `预约日期格式应为 yyyy-MM-dd` ✅ |
| `GET /api/booking/slots?storeId=200&date=2026-08-02` | day `09:00-17:00` 全可约，night `18:00-21:00` 全可约 ✅ |
| 缺 `bookingDate` 或 `timeSlot` | `预约日期与时段必填` ✅ |
| 缺 `storeId` | `门店不能为空` ✅ |
| 会员 A 报 18:00 4 人 | `bookingId=100005,signupId=9`；再次报同段时 `您已预约该时段` ✅ |
| 会员 B 报同段 7 人 | 复用场次 100005，`signupId=10` ✅ |
| 此时 18:00 容量已满 | `remain=0,full=true,available=false` ✅ |
| 会员 B 查会员 A 报名 | `预约记录不存在`（越权拒绝） ✅ |
| 场次详情（会员 B 视角） | `signupCount=2, signupPeople=11, members` 仅含本人 ✅ |
| 会员 B 越权取消会员 A 报名 | 拒绝（修改后）；重复取消报 `该预约已取消` ✅ |
| 取消本人 7 人后 | 18:00 容量回收 `remain=6`；再报名 19:00 2 人成功（新建场次 100006） ✅ |
| `GET /api/booking/list?status=1` | 只返回 `status=1` 的报名 ✅ |

> 说明：会员取消当前按「自己签到的报名」操作，门店端「审核报名」权限暂未引入；
> 同样 `cancel` 仍用会员 token，建议后续一并加门店角色鉴权（见 10.5）。

### 10.12 推客与代金券落地记录（2026-08-01 实测）

后端改动：
- `ApiDistributorController.center` 由「直接返回推客档案」改为返回完整概览：
  `orderCount`（佣金条数）、`withdrawCount`（提现条数）、`withdrawingAmount`
  （处理中金额，待审 0 + 已通过待打款 1 之和）、`availableAmount`/`frozenAmount`/`totalCommission`/`withdrawAmount`。
  未成为推客时 `data` 字段缺省（`undefined`），前端据此展示「成为推客」入口。
- `commission/list`、`withdraw/list` 在未成为推客时返回 `[]` 而非 `undefined`，
  避免小程序端 `.data || res` 取值失败。
- `ApiStoreController` 新增 `GET /api/store/{storeId}/services`：把 `biz_store.services`
  码值经字典表翻译成中文标签，门店未配时返回 `[]`。
- `ApiVoucherController.receive` 增同券同会员重复领取拦截；`biz_voucher.received` 在领券后累加。
- 推客协议原库仅 15 字占位，更新为《推客推广服务协议》全文 905 字，脚本同步入 `sql/biz_demo_data.sql`（幂等）。

小程序改动：
- `pages/promoter/index/{js,wxml,wxss}`：数据概览改为读真实后端（包含 `冷静期收入`），tab 分订单/粉丝，
  订单卡按门店聚合显示；「去提现」未加入 / 可提现为 0 时给出提示；推客协议弹层走 `api.agreement('distributor')`。
- `pages/promoter/records/{js,wxml,wxss}`：4 个 tab（全部/处理中/已完成/已驳回），卡片含提现单号、
  收款人/账户/申请与完成时间/驳回原因等明细。
- `pages/promoter/withdraw/{js,wxml,wxss}`：提现方式 3 选 1（微信/支付宝/银行卡），
  提现金额前端先校验是否超额再发请求，「全部提现」一键填入。
- 新增 `pages/voucher/index/{js,wxml,wxss,json}`：领券中心 + 我的代金券 3 状态 tab，
  未使用券可一键「去买单」。首页与「我的」均加入口。
- `pages/home/index.{js,wxml,wxss}`：banner 复用门店相册（无相册时回退内置图），
  设施抽屉按后端返回的中文标签渲染，客服电话/二维码/营业时间跟随门店数据；
  商品划线价只显示与现价不同的市场价；首页新增领券中心入口。
- `pages/mine/index/{js,wxml,wxss}`：新增「代金券」入口；客服弹层改为读门店客服电话 / 二维码 / 营业时间。
- `request.js` 新增 `storeServices` 封装与 `toFullUrl` 重导出。

实测（mock 模式，测试数据已清理、配置已复原）：

| 用例 | 结果 |
| --- | --- |
| 推客中心（未成为） | `data` 为 `undefined`，前端展示「成为推客」 ✅ |
| `POST /api/distributor/join` | `distributorId=1002, level=1, status=0, joinTime=2026-08-01` ✅ |
| 推客中心（已成为） | `orderCount=0, withdrawCount=0, availableAmount=0, withdrawingAmount=0` ✅ |
| `withdraw amount=0` | `提现金额不合法` ✅ |
| `withdraw amount=99`（>余额） | `可提现余额不足` ✅ |
| `withdraw/list` / `commission/list` | 返回 `[]` ✅ |
| `GET /api/store/200/services` | `["可堂食","可预约","提供独立空间","提供免费停车场","免费停车"]` ✅ |
| `GET /api/store/100/services` | `["可堂食","可预约"]` ✅ |
| `GET /api/store/99999/services` | `[]` ✅ |
| `GET /api/agreement?type=distributor` | `title=推客推广服务协议, content=905` 字 ✅ |
| `GET /api/voucher/list` | 3 张券（演示 200/201 剩余 0，存量 100 剩余 996） ✅ |
| 会员B 领 200 | 成功 → `id=8`，我的券出现 ✅ |
| 重复领 200 | `您已领取该代金券，可在「我的代金券」中查看` ✅ |
| 领 201 | 成功 → `id=10` ✅ |
| 领 9999 | `代金券不存在或已停用` ✅ |
| `my?status=0/1` | 正确按状态过滤 ✅ |

> 待办：粉丝功能需先在「会员表」加 `invite_by` 关系与邀请海报页（约 0.5 天），
> 暂在小程序明示「即将开放」，避免上线时文案不一致。