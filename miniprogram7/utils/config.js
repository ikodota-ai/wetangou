// utils/config.js 全局配置
// 说明：
// 1) BASE_URL 默认为本地开发地址；真机调试改成电脑本机 IP；上线改为 HTTPS 域名。
// 2) APPID 由小程序自带 api 取「当前运行环境」appid，多商户通过 ext.json 注入。
// 3) 全部环境（含 dev / prod）一律关闭前端 mock 兜底。
//    之前 dev 环境允许「接口失败时回退到本地 mock 数据」，会导致用户被告知
//    「操作成功」但实际没落库；现已永久关闭，由后端真实接口承担。
// 4) MOCK_ENABLED 常量保留仅为向后兼容，恒为 false。
// 5) 若后端不可达，前端须显式报错，禁止静默回退 mock。

const BASE_URL = 'http://localhost:8080';

const APPID = (function () {
  try {
    var info = wx.getAccountInfoSync && wx.getAccountInfoSync();
    if (info && info.miniProgram && info.miniProgram.appId) {
      return info.miniProgram.appId;
    }
  } catch (e) {}
  return '';
})();

const ENV = 'prod'; // 强制按线上行为：禁 mock

// 全部环境强制关闭 mock 兜底（保留常量仅为兼容）
const MOCK_ENABLED = false;

module.exports = {
  BASE_URL,
  APPID,
  ENV,
  MOCK_ENABLED,
  PAGE_SIZE: 20
};
