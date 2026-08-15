# C28 /api/pay/notify 异常处理 smoke · 2026-08-15

## 目标
小程序支付回调入口端到端异常路径端到端覆盖,mock 模式下验证错误处理,7/7 PASS。

## 端点定义
- POST /api/pay/notify (旧版,按 out_trade_no 反查所属商户)
- POST /api/pay/notify/{merchantId} (多商户版,URL 直接带 merchantId)

## 异常处理路径
| 异常源 | 行为 |
|---|---|
| 缺 resource 字段 | 返 {code:FAIL, message:缺少resource} |
| resource 齐全但解密失败 (mock 模式无 APIv3 key) | 返 {code:FAIL, message:未配置 APIv3 密钥} |
| 错 HTTP method (GET) | 返 {code:500, msg:Request method 'GET' is not supported} (RuoYi 全局异常包装) |
| out_trade_no 不存在 | resolveMerchantIdByOutTradeNo 回退默认商户=1, 然后解密失败 (同上) |

## smoke 覆盖 (C28 7/7)
| # | 用例 | 验证 |
|---|---|---|
| A | POST /api/pay/notify 缺 resource | "缺少resource" ✅ |
| B | POST /api/pay/notify 资源齐全 mock | "未配置 APIv3 密钥" + code=FAIL ✅ |
| C | POST /api/pay/notify/1 mock | 同 B ✅ |
| D | POST /api/pay/notify/1 缺 resource | "缺少resource" ✅ |
| E | POST /api/pay/notify 旧版 + out_trade_no 不存在 | "未配置 APIv3 密钥" (resolveMerchantIdByOutTradeNo 回退到 1) ✅ |
| F | GET /api/pay/notify | "GET not supported" 业务拒绝 ✅ |

## 真实业务缺陷发现 (Known Limitation, 本轮不修)
**HTTP 状态码错位**: 错方法返 HTTP 200 + body code=500, 应返 HTTP 405
**根因**: `GlobalExceptionHandler` 把 HttpRequestMethodNotSupportedException 包装成 AjaxResult(500)
**影响范围**: 全局所有错方法请求 (不限于 notify 端点)
**业务侧建议**: 在 GlobalExceptionHandler 增加 `if (e instanceof HttpRequestMethodNotSupportedException) return 405;`

## 历史覆盖对比
- c2/c4/c18 走过 mock 模式 prepay (直接 markPaid, 走 isMock=true 分支, 不触发真实 notify 路径)
- C28 首次覆盖 notify 入口的异常处理

## 全套回归
- 39/39 smoke PASS (含 C28)
- 10/10 JUnit PASS
- 30/30 vitest PASS
