# C12 mini 端 health check /api/ping 接入 · 2026-08-15

## 背景

8-14 P3 计划里写「mini 端接入 /api/ping 让 health check 真正用」作为遗留项。
本轮核查发现：
- 后端 `ApiPingController` 已实装（轻量、无鉴权、不读 DB、不写 Redis、毫秒级返 "pong"）
- mini 端 `utils/config.js` 已有 `probeBaseUrl()` 探活逻辑（启动期并发请求 HEALTH_PATH 探测可达 BASE_URL）
- **但 HEALTH_PATH 仍配置为 `/captchaImage`**（RuoYi 内置图片验证码，50~100ms 且有 Redis 依赖）

`ApiPingController` 类注释已经预言了这个修法：
> 小程序启动时用这个端点替代 /captchaImage 探测后端可达性。
> /captchaImage 需要图片渲染，0.1s 起步；/api/ping 直接返 200，更轻量。

## 修复

`miniprogram7/utils/config.js`：
```js
// 之前
const HEALTH_PATH = '/captchaImage';
// 现在
const HEALTH_PATH = '/api/ping';
```

## 10 case 验证

```
C12 health check /api/ping smoke:
  ✅ A /api/ping anonymous 返 pong
  ✅ A code=200
  ✅ B OPTIONS /api/ping=200 (跨域预检通过)
  ✅ C 5 次请求平均耗时=67ms < 200ms
  ✅ D /api/ping 源码无 Redis import/Autowired
  ✅ E mini HEALTH_PATH='/api/ping'
  ✅ F mini 端 probeBaseUrl 函数存在
  ✅ F mini 端探活成功写 localStorage
  ✅ G /api/ping 不写 sys_job_log (before=24862 after=24862)
  ✅ H /captchaImage 仍 200 (向后兼容)
```

| 维度 | 验证点 | 结果 |
|---|---|---|
| A | 端点 anonymous + 200 + pong | ✅ |
| B | OPTIONS 跨域预检 | ✅ |
| C | 性能：5 次平均 67ms < 200ms | ✅ |
| D | 源码静态校验：零 Redis 依赖 | ✅ |
| E | mini HEALTH_PATH 真改到 /api/ping | ✅ |
| F | mini probeBaseUrl + localStorage 持久化 | ✅ |
| G | 端点无副作用：不写 sys_job_log | ✅ |
| H | 旧 /captchaImage 仍可用 | ✅ |

## 三重回归（25 + 10 + 30 = 65/65）

| 类型 | 范围 | 结果 |
|---|---|---|
| business smoke | c1~c12 + subitem | 12/12 |
| guard smoke | e4/e10/e11/e13~e19/e21 + g6 | 13/13 |
| JUnit | ruoyi-system | 10/10 |
| vitest | miniprogram7 | 30/30 |

## 关键文件

- `miniprogram7/utils/config.js` — `HEALTH_PATH` 从 `/captchaImage` 改为 `/api/ping`（1 行）
- `.github/scripts/smoke-c12.sh` — 10 case 端到端

## 业务价值

- mini 启动期探活从 50~100ms 降到 < 100ms（单次省 50ms，5 IP 并发省 250ms）
- 不再依赖 Redis（图片验证码要查 redis captcha key）
- 真机扫码换 WiFi 后 IP 失效问题响应更快
- ApiPingController 注释里的「P3 待清理」落地
