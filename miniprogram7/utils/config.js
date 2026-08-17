// utils/config.js 全局配置
// 说明：
// 1) BASE_URL 默认为本地开发地址；真机调试改成电脑本机 IP；上线改为 HTTPS 域名。
// 2) APPID 解析顺序：手动覆盖(localStorage 'manualAppId') > wx.getAccountInfoSync > 编译期 project.config.json。
//    编译期 appid 来自 project.config.json（多商户通过 ext.json 注入）。
// 3) 全部环境（含 dev / prod）一律关闭前端 mock 兜底。
// 4) MOCK_ENABLED 常量保留仅为向后兼容，恒为 false。
// 5) 若后端不可达，前端须显式报错，禁止静默回退 mock。

// 微信开发者工具的 cronet 网络栈 + macOS SOCKS 代理会拦截 127.0.0.1 / localhost，
// 用电脑的 LAN IP（en0 上的 172.31.26.216）绕开。当前为 WiFi 局域网。
// 切换网络/WiFi 后 IP 可能变，重新跑 ifconfig en0 | grep 'inet ' 取新值。
// 真机调试改成电脑本机 IP；上线改成 HTTPS 域名。
const BASE_URL = 'http://172.31.26.216:8080';

// 备选 IP 列表（按"手机可能访问到"顺序降序，新环境时把新 IP 加到最前）。
// 真机扫码后若首个 IP 不可达，自动尝试下一个，避免每次换网络都要改代码。
// 顺序含义：
//   1) 热点模式（电脑连手机热点）下电脑拿到的 IP（en0）
//   2) 局域网模式（电脑连 WiFi）下电脑拿到的 IP（en0/en1）
//   3) 127.0.0.1（仅开发工具模拟器可用）
// 4) 兜底：模拟器内通常可达
const BASE_URL_FALLBACKS = [
  'http://172.31.26.216:8080',// 当前 WiFi 环境（电脑 en0）
  'http://192.168.1.136:8080',// 历史 WiFi 局域网
  'http://127.0.0.1:8080',    // 仅开发工具模拟器
];

// 健康检查端点：用 /api/ping (ApiPingController 已实装, 纯 JSON 不渲染图片, 0.5ms)
// 之前用 /captchaImage (RuoYi 内置图片验证码, 50~100ms 且有 Redis 依赖)
const HEALTH_PATH = '/api/ping';
const HEALTH_TIMEOUT_MS = 2500;

/** 编译期 project.config.json.appid（开发者工具里能直接读到） */
const BUILD_IN_APPID = 'wx9e147c4e2151b123';

/**
 * 运行时解析 APPID
 * 优先级：手动覆盖(localStorage 'manualAppId') > wx.getAccountInfoSync > 编译期 project.config.json
 * 任意环境都能解析到，绝不返回空串（空串会让后端回退到默认商户 1，导致跨商户看不到门店）
 */
function resolveAppId() {
  try {
    var manual = wx.getStorageSync && wx.getStorageSync('manualAppId');
    if (manual) return manual;
  } catch (e) {}
  try {
    var info = wx.getAccountInfoSync && wx.getAccountInfoSync();
    if (info && info.miniProgram && info.miniProgram.appId) {
      return info.miniProgram.appId;
    }
  } catch (e) {}
  return BUILD_IN_APPID;
}

const APPID = resolveAppId();

const ENV = 'prod'; // 强制按线上行为：禁 mock

// 全部环境强制关闭 mock 兜底（保留常量仅为兼容）
const MOCK_ENABLED = false;

// 网络层：自动探测可达的 BASE_URL，避免换 WiFi 后 IP 失效导致全站"发送失败"。
// 策略：启动时并发请求 HEALTH_PATH，首个 2xx 响应即作为新的 BASE_URL。
// 持久化到 localStorage（resolvedBaseUrl），下次启动优先复用。
// 探测失败：保留当前 BASE_URL 不变，由业务层显示具体错误。
function resolveBaseUrl() {
  try {
    var cached = wx.getStorageSync && wx.getStorageSync('resolvedBaseUrl');
    if (cached && typeof cached === 'string') return cached;
  } catch (e) {}
  return BASE_URL;
}
const RESOLVED_BASE_URL = resolveBaseUrl();

let _probed = false;
function probeBaseUrl() {
  if (_probed) return Promise.resolve(RESOLVED_BASE_URL);
  _probed = true;
  return new Promise(function (resolve) {
    var candidates = [BASE_URL].concat(BASE_URL_FALLBACKS.filter(function (u) { return u !== BASE_URL; }));
    var done = false;
    candidates.forEach(function (url) {
      wx.request({
        url: url + HEALTH_PATH,
        method: 'GET',
        timeout: HEALTH_TIMEOUT_MS,
        success: function (res) {
          if (done) return;
          if (res.statusCode >= 200 && res.statusCode < 500) {
            done = true;
            try { wx.setStorageSync && wx.setStorageSync('resolvedBaseUrl', url); } catch (e) {}
            resolve(url);
          }
        },
        fail: function () { /* try next */ },
        complete: function () { /* noop */ }
      });
    });
    // 兜底：3.5s 后必返回，避免探测卡死
    setTimeout(function () { if (!done) { done = true; resolve(RESOLVED_BASE_URL); } }, HEALTH_TIMEOUT_MS + 1000);
  });
}

module.exports = {
  BASE_URL: RESOLVED_BASE_URL,
  BASE_URL_FALLBACKS,
  HEALTH_PATH,
  HEALTH_TIMEOUT_MS,
  APPID,
  BUILD_IN_APPID,
  ENV,
  MOCK_ENABLED,
  PAGE_SIZE: 20,
  probeBaseUrl
};
