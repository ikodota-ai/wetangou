// utils/config.js 全局配置
// 说明：
// 1) BASE_URL 默认为本地开发地址；真机调试改成电脑本机 IP；上线改为 HTTPS 域名。
// 2) APPID 解析顺序：手动覆盖(localStorage 'manualAppId') > wx.getAccountInfoSync > 编译期 project.config.json。
//    编译期 appid 来自 project.config.json（多商户通过 ext.json 注入）。
// 3) 全部环境（含 dev / prod）一律关闭前端 mock 兜底。
// 4) MOCK_ENABLED 常量保留仅为向后兼容，恒为 false。
// 5) 若后端不可达，前端须显式报错，禁止静默回退 mock。

// 默认已切到线上 HTTPS 域名（daodian.lanaoboxiang.com）。
// 微信小程序正式版/体验版只允许 https 且域名须在「开发管理-服务器域名」白名单内，
// 所以默认值必须是 https，不能是内网 IP。
//
// 本地联调时不要改这里：开发者工具勾「不校验合法域名」后，
// 在 Console 执行 wx.setStorageSync('resolvedBaseUrl','http://<电脑IP>:8080') 即可覆盖，
// 改回线上则执行 wx.removeStorageSync('resolvedBaseUrl')。
// 这样避免"本地调试改了默认值、忘了改回去就发版"这类事故。
//
// BASE_URL 解析顺序：ext.json 注入的 baseUrl > localStorage 缓存 > 下方默认值
//
// 关于 ext.json（重要，别误判成 bug）：
//   wx.getExtConfigSync() 只在「第三方平台代开发」场景返回值，即代码由开放平台
//   第三方平台代上传到商户自己的 appid 下，且提交时带了 ext.json。
//   用自有 appid 直接在开发者工具里跑（当前情形）时它恒返空对象 / 抛错，
//   开发者工具还会提示「xxx 不是 3rdMiniProgramAppid, ext.json 无法生效」——
//   这是预期行为，不是配置写错了。此时自动 fallback 到下方默认值。
//   仓库根的 miniprogram7/ext.json 仅作占位与格式参考；真正下发的 ext.json 由
//   后端 MpReleaseServiceImpl.buildExtJson() 按 biz_merchant.appid +
//   sys_config['wx.open.apiBaseUrl'] 动态生成，不读这个文件。
//   接入第三方平台代发布后本函数即生效，届时每个商户可有独立 API 域名，
//   所以这段读取逻辑必须保留。
function resolveBaseUrlDefault() {
  try {
    var ext = wx.getExtConfigSync && wx.getExtConfigSync();
    if (ext && ext.baseUrl) return ext.baseUrl;
  } catch (e) {}
  return 'https://daodian.lanaoboxiang.com';
}
const BASE_URL_DEFAULT = resolveBaseUrlDefault();

// 备选地址列表：probeBaseUrl() 并发探测，首个可达者胜出。
// 上线后刻意只留线上域名，不再列内网 IP —— 否则真机上探测到某个同网段 IP
// 就会把 resolvedBaseUrl 缓存成 http 内网地址，正式版直接全站请求失败，
// 且这种"偶发串到开发机"的故障极难排查。
// 本地联调用 resolvedBaseUrl 手动覆盖（见上方说明），不依赖这个列表。
const BASE_URL_FALLBACKS = [
  'https://daodian.lanaoboxiang.com',
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
  return BASE_URL_DEFAULT;
}
const RESOLVED_BASE_URL = resolveBaseUrl();

let _probed = false;
function probeBaseUrl() {
  if (_probed) return Promise.resolve(RESOLVED_BASE_URL);
  _probed = true;
  return new Promise(function (resolve) {
    var candidates = [BASE_URL_DEFAULT].concat(BASE_URL_FALLBACKS.filter(function (u) { return u !== BASE_URL_DEFAULT; }));
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
  BASE_URL_DEFAULT,
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
