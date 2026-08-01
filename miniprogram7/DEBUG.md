# miniprogram7 调试指南

> 适用对象：前端开发 / 联调测试 / 客服  
> 工具：微信开发者工具 + 微信小程序测试号  
> 后端：本地 ruoyi-admin 启动（默认 8080）

---

## 1. 准备

### 1.1 工具下载

| 工具 | 链接 |
|---|---|
| 微信开发者工具 | https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html |
| 微信小程序 API | https://developers.weixin.qq.com/miniprogram/dev/api/ |

安装后**用个人微信扫码登录**（不需要管理员权限）。

### 1.2 申请测试号（免注册）

1. 打开微信开发者工具
2. 顶部菜单「设置 → 通用设置 → 微信开发者工具 → 详情」
3. 点击「**测试号**」→ 自动生成 AppID 和 AppSecret
4. **记下这 2 个值**（下一步要在后台填）

> ⚠️ 测试号**只能在开发者工具内**用，不能发布。真机扫码登录需要正式 AppID。

---

## 2. 启动后端

```bash
# 1. 启动 MySQL / Redis（Docker 或 brew）
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:8
docker run -d -p 6379:6379 redis:7

# 2. 初始化数据库（首次部署）
mysql -uroot -proot < sql/ry_20260417.sql
mysql -uroot -proot ry_vue < sql/biz_tables.sql
mysql -uroot -proot ry_vue < sql/biz_menu_reorganization.sql
mysql -uroot -proot ry_vue < sql/biz_tenant_tables.sql
mysql -uroot -proot ry_vue < sql/biz_tenant_upgrade.sql
mysql -uroot -proot ry_vue < sql/biz_tenant_menu.sql
mysql -uroot -proot ry_vue < sql/biz_mpconfig_menu.sql
mysql -uroot -proot ry_vue < sql/biz_distributor_invite.sql
mysql -uroot -proot ry_vue < sql/biz_booking_upgrade.sql
mysql -uroot -proot ry_vue < sql/quartz.sql
mysql -uroot -proot ry_vue < sql/biz_banner.sql
mysql -uroot -proot ry_vue < sql/biz_commission_settle_job.sql
mysql -uroot -proot ry_vue < sql/biz_wxconfig_init.sql
mysql -uroot -proot ry_vue < sql/biz_agent_store_quota.sql

# 3. 启动后端
mvn -pl ruoyi-admin spring-boot:run
# 看到 "Started RuoYiApplication" 表示成功
# 默认账号 admin / admin123
```

---

## 3. 后台配置商户

### 3.1 全局微信配置

浏览器打开 http://localhost 后台，用 `admin/admin123` 登录。

路径：**团购运营 → 平台配置 → 微信配置**

| key | 填什么 | 必填 |
|---|---|---|
| `wx.miniapp.appId` | 微信开发者工具的测试号 AppID | ✅ |
| `wx.miniapp.secret` | 微信开发者工具的测试号 AppSecret | ✅ |
| `wx.miniapp.mockEnabled` | `false` | ✅ |
| `wx.pay.mockEnabled` | `false` | ✅ |

> 这些是**平台兜底凭证**——多商户可独立覆盖。

### 3.2 创建测试商户

路径：**团购运营 → 租户管理 → 商户管理 → 新增**

| 字段 | 必填 | 调试时填什么 |
|---|---|---|
| 商户名称 | ✅ | `洞天团购（调试）` |
| 所属代理商 | 0 平台直营 | 0 |
| **小程序 AppId** | ✅ | **微信开发者工具的测试号 AppID**（与 3.1 一致） |
| 小程序 AppSecret | ✅ | 测试号 AppSecret |
| 联调 mock 开关 | 0 关闭 | 0 |
| 支付方式 | 0 商户自有商户号 | 0 |
| 状态 | 0 正常 | 0 |

> ⚠️ **关键**：商户的 appid 必须与微信开发者工具的 AppID **完全一致**。

保存后数据库：
```sql
SELECT * FROM biz_merchant;
-- 应看到一行 merchant_id=2（id=1 是默认商户），appid=你填的 AppID
```

### 3.3 验证登录链路

打开「微信开发者工具 → 调试器 → Console」，调用：

```javascript
wx.login({
  success: res => {
    wx.request({
      url: 'http://localhost:8080/api/auth/login',
      method: 'POST',
      data: { code: res.code, appid: getApp().globalData.appid || '' },
      success: r => console.log('登录响应', r.data),
      fail: e => console.error('登录失败', e)
    })
  }
})
```

期望响应：
```json
{
  "code": 200,
  "msg": "登录成功",
  "data": {
    "token": "eyJ0eXAiOiJKV1Qi...",
    "memberId": 1001
  }
}
```

---

## 4. 微信开发者工具导入项目

### 4.1 导入

| 字段 | 填写 |
|---|---|
| 项目目录 | `/Users/mac/dev/dytuangou/miniprogram7` |
| AppID | 你的测试号 AppID（**不要用项目里配置的 appid**） |
| 项目名称 | Wetangou |
| 后端服务 | 「不使用云服务」 |

> 导入时如果提示「appid 与项目不匹配」，点「**确定**」即可——项目 appid 是客户生产用的。

### 4.2 修改 utils/config.js

```javascript
// miniprogram7/utils/config.js
const BASE_URL = 'http://localhost:8080';
// 真机调试改成电脑 IP，例如：
// const BASE_URL = 'http://192.168.1.100:8080';
// 生产环境改成 HTTPS 域名：
// const BASE_URL = 'https://api.wetangou.com';
```

**调试时**：
- 开发者工具内（模拟器）：`localhost:8080` 即可
- 真机扫码调试：必须改成电脑 IP，且电脑与手机同一 WiFi

### 4.3 关闭域名校验

**仅调试用**：

微信开发者工具 → 右上角「详情 → 本地设置」：
- ☑️ 勾选「**不校验合法域名、web-view（业务域名）、TLS 版本以及 HTTPS 证书**」

> 生产环境必须去掉这个勾，且后端必须用 HTTPS。

### 4.4 启动

点击「编译」→ 模拟器显示首页 → 看到「首页 / 贴图 / 预约 / 我的 / 商城」5 个 tab。

第一次进入会要求微信登录授权 → 同意 → 登录成功。

---

## 5. 常见问题

### Q1：登录提示「小程序未接入或已停用」

**原因**：后端 `biz_merchant.appid` 找不到当前 AppID。

**排查**：
1. 微信开发者工具右上角「详情 → 基本信息」看 AppID
2. 后台「商户管理」编辑该商户，核对 appid **完全一致**（注意空格、大小写）
3. 浏览器调试器 → Network → `/api/auth/login` 的 request body 里有 appid 字段

### Q2：登录成功但数据是别的商户的（多商户串号）

**原因**：X-App-Id 头被中间层覆盖 / 走错后端。

**排查**：
1. 打开 Network 面板，**每个请求**的 Request Headers 应有 `X-App-Id: wx...`
2. 后端 `/api/auth/login` 返回的 token 解析后应有 `merchantId`
3. 数据库 `biz_member` 中新会员的 `merchant_id` 应等于 `biz_merchant.merchant_id`

### Q3：真机调试连不上后端

**原因**：`localhost` 在手机上不通（手机没装后端）。

**修复**：
1. 查电脑 IP：终端跑 `ifconfig | grep inet`（Mac）
2. 修改 `config.js` 的 `BASE_URL = 'http://你的IP:8080'`
3. 电脑防火墙放开 8080 端口：`系统设置 → 网络 → 防火墙 → 允许应用`
4. 手机和电脑**必须同一 WiFi**

### Q4：支付报「商户号错误」

**原因**：没配置微信支付凭证，或配置错误。

**修复**：
1. 后台「商户管理 → 微信配置」填：
   - 支付商户号 mchId
   - 支付 AppId
   - 证书序列号
   - 私钥路径（服务器绝对路径）
   - APIv3 密钥
   - 支付回调地址

2. **调试用沙箱环境**：
   - 申请：https://pay.weixin.qq.com/wiki/doc/api/jsapi.php?chapter=23_1
   - 用沙箱商户号配一遍上述字段
   - 测试支付金额填 0.01 元

3. **生产前**：私钥文件**不入库**、服务器间用 scp 同步、权限 `chmod 600`

### Q5：首页不显示 Banner

**原因**：banner 没数据 / 状态未启用 / 时间窗未到。

**修复**：
1. 后台「首页 Banner」新增一条：
   - 所属商户：你的测试商户
   - 位置：home
   - 图片 URL：先用「/assets/img/RestaurantImg.png」做测试
   - 状态：0 启用
   - 生效时间：留空 = 立即生效
2. 重启小程序

### Q6：下单后订单状态没变

**原因**：支付回调地址不达。

**排查**：
1. 后端日志 `grep "WxPayService" logs/wetangou.log`
2. 商户平台「产品中心 → 开发配置」核对回调 URL
3. 用「回调通知签名校验工具」验证签名

### Q7：手机号显示 `138****1234`

**原因**：@Sensitive 脱敏生效（正常行为）。

**说明**：
- admin / 平台账号：自动看明文
- 代理商 / 商户：看到 `138****1234` 是正常的

### Q8：想清空测试数据

```sql
-- 保留商户、清业务数据
DELETE FROM biz_order WHERE merchant_id = 2;
DELETE FROM biz_member WHERE merchant_id = 2;
DELETE FROM biz_store WHERE merchant_id = 2;
DELETE FROM biz_commission WHERE merchant_id = 2;
DELETE FROM biz_product WHERE merchant_id = 2;
```

---

## 6. 调试技巧

### 6.1 抓包

| 工具 | 用途 |
|---|---|
| 微信开发者工具 Network 面板 | 查看所有 wx.request |
| 后端日志 | `tail -f logs/wetangou.log \| grep "租户过滤"` |
| 数据库 | `SELECT * FROM biz_member ORDER BY member_id DESC LIMIT 5` |
| Redis（租户上下文） | `redis-cli HGETALL "tenant:user:1"` |

### 6.2 重置小程序缓存

```
微信开发者工具 → 顶部菜单「工具 → 清除缓存 → 全部清除」
```

或小程序内：
```javascript
wx.clearStorageSync()
```

### 6.3 跳过登录

开发时如想直接看某个页面，临时改 `app.js`：
```javascript
// 临时 mock 已登录
this.globalData.user = {
  memberId: 1001,
  openid: 'mock_openid_xxx',
  nickName: '调试用户',
  logged: true,
  token: 'mock_token_xxx'
}
```

> ⚠️ 测试完要改回去，否则会跳过 wx.login 真流程。

### 6.4 切到不同商户调试

`miniprogram7/utils/config.js` 的 `APPID` 是自取的，**改 project.config.json 里的 appid**：

```json
{
  "appid": "wx新的测试号appid"
}
```

然后对应在后台「商户管理」加一条新商户（appid 相同）。

---

## 7. 文件位置速查

| 用途 | 路径 |
|---|---|
| 全局配置 | `miniprogram7/utils/config.js` |
| 请求封装 | `miniprogram7/utils/request.js` |
| 全局 state | `miniprogram7/app.js` |
| TabBar | `miniprogram7/custom-tab-bar/` |
| 业务页面 | `miniprogram7/pages/` |
| 图片资源 | `miniprogram7/assets/img/` |
| 项目配置 | `miniprogram7/project.config.json` |
| 项目私有配置（不入 git） | `miniprogram7/project.private.config.json` |

---

## 8. 一句话速查

```bash
# 启动后端
mvn -pl ruoyi-admin spring-boot:run

# 改后端地址
vim miniprogram7/utils/config.js

# 看后端日志
tail -f ruoyi-admin/logs/wetangou.log

# 重置小程序
微信开发者工具 → 工具 → 清除缓存
```


### Q9：门店列表为空，store_id=200 看不到

**症状**：后台 `biz_store` 里有 `store_id=200`、`status=0`，但小程序首页门店列表返回空。

**根因链路**：
1. 小程序请求带 `X-App-Id` header
2. 后端 `MemberAuthInterceptor.resolveTenantByAppid` 用该 appid 查 `biz_merchant.appid`
3. 命中 → 写入 `TenantContextHolder.ofMerchant(merchant_id)`，后续 SQL 自动追加 `WHERE merchant_id = ?`
4. **不命中**（appid 缺失 / 不匹配 / 商户停用）→ **fallback 到 `DEFAULT_MERCHANT_ID=1`**（已在 `ruoyi-common/.../constant/TenantConstants.java` 写死）
5. 如果 store_id=200 属于 `merchant_id ≠ 1` 的商户，就被租户拦截器过滤掉 → 列表为空

**排查**：
```sql
-- 1. 确认 store 200 属于哪个商户
SELECT store_id, store_name, merchant_id, status, del_flag FROM biz_store WHERE store_id=200;

-- 2. 确认默认商户 1 的 appid 与小程序编译期 appid 是否一致
SELECT merchant_id, merchant_name, appid, status FROM biz_merchant WHERE merchant_id=1;
-- 期望 appid = miniprogram7/project.config.json 里的 appid
```

**修复（按优先级）**：
- 改 store 200 的 `merchant_id = 1`（最简单，但有数据归属语义风险）
- 改 `miniprogram7/project.config.json` 的 `appid` = store 200 所属商户的 appid（仅限多商户调试）
- 后端日志会打 `[resolveTenantByAppid] X-App-Id=xxx 未匹配到有效商户`，照日志里实际 appid 排查

**辅助工具**：
- 小程序启动会在 Console 打印 `[miniprogram] APPID => wx... | BUILD_IN_APPID => wx...`，一眼看出当前生效的是哪个 appid
- 调试期想强制覆盖 appid：在「微信开发者工具 → Console」执行 `wx.setStorageSync('manualAppId','wx...')` 再刷新

**说明**：`DEFAULT_MERCHANT_ID=1` 不能去掉，否则匿名接口会因租户上下文为空而走 `ISOLATED_TABLES` 全表扫，对多商户体系是跨商户泄露。保留 fallback 是为了「单商户小程序在未配置 appid 时还能用」的兼容性。
