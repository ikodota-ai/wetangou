# IDE 模拟器验证清单（不需要真机扫码）

> 微信开发者工具的"编译"模式能模拟大部分场景。除了扫码核销和真机定位外，都能验。

## 0) 准备

```
1) 启动后端：java -Dspring.profiles.active=prod -jar ruoyi-admin/target/ruoyi-admin.jar
2) 启动微信开发者工具 → 打开 miniprogram7
3) IDE 顶栏 → "编译" 按钮
4) IDE 左侧应显示模拟器窗口
```

## IDE 模拟器能验（5 分钟跑完）

| # | 步骤 | 期望 | 状态 |
|---|---|---|---|
| 1 | IDE 顶栏 "编译" | 模拟器出现首页，3.5s 内显示门店 | ☐ |
| 2 | IDE Console 标签 | 看到 [miniprogram] APPID / probeBaseUrl 日志 | ☐ |
| 3 | 模拟器 "添加编译模式" → 输入 lat=30.65 lng=104.10 | 首页 distanceText 应显示 859m | ☐ |
| 4 | 模拟器底部 Tab "预约" | 进入页面不卡顿；门店名显示"春熙路餐饮" | ☐ |
| 5 | 模拟器 "我的" → "推客" | 点"立即成为推客" → 立即切换 | ☐ |
| 6 | 推客 → "分享" | 进入 poster 页 | ☐ |
| 7 | 模拟器商品列表 | 至少 1 个商品卡片（图可能加载不出，文字应有） | ☐ |
| 8 | 点商品 → 详情 | 详情页正常渲染（typeCode 9 种映射） | ☐ |
| 9 | 详情 → "立即购买" | 跳到 submit 页 | ☐ |
| 10 | submit 页手机号 | 应自动从 profile 拉到明文（首次可能空） | ☐ |
| 11 | IDE 顶栏 "模拟位置" → 设置一个坐标 | 距离立即更新 | ☐ |
| 12 | IDE "清缓存" → "重新编译" | 不应卡白板 | ☐ |

## IDE 不能验（必须真机）

- 扫码核销（需要摄像头）
- 微信支付（需要真 appid + 微信支付回调）
- 真实定位（IDE 模拟的是固定坐标）
- 手机系统授权弹框（IDE 不会弹）
- "发送失败" 错误（IDE 网络走不同栈）

## Console 关键日志（IDE 调试器 Console 标签）

```
[miniprogram] APPID => wx9e147c4e2151b123
[miniprogram] probeBaseUrl switched to http://172.20.10.2:8080
[pickNearestStore] source=... storeId=...
[home] pickNearestStore => {...}
[booking/detail] raw => {...}
```

## 失败回退

任一步失败 → IDE Console 完整截图发我。
