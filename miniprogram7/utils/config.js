// utils/config.js 全局配置
// 说明：
// 1) BASE_URL 默认为本地开发地址；真机调试改成电脑本机 IP；上线改为 HTTPS 域名。
// 2) APPID 解析顺序：手动覆盖(localStorage 'manualAppId') > wx.getAccountInfoSync > 编译期 project.config.json。
//    编译期 appid 来自 project.config.json（多商户通过 ext.json 注入）。
// 3) 全部环境（含 dev / prod）一律关闭前端 mock 兜底。
// 4) MOCK_ENABLED 常量保留仅为向后兼容，恒为 false。
// 5) 若后端不可达，前端须显式报错，禁止静默回退 mock。

const BASE_URL = 'http://localhost:8080';

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

module.exports = {
  BASE_URL,
  APPID,
  BUILD_IN_APPID,
  ENV,
  MOCK_ENABLED,
  PAGE_SIZE: 20
};
