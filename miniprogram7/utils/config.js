// utils/config.js 全局配置
// 说明：
// 1) BASE_URL 默认为本地开发地址；真机调试改成电脑本机 IP；上线改为 HTTPS 域名。
// 2) APPID 由小程序自带 api 取「当前运行环境」appid，多商户通过 ext.json 注入。
// 3) ENV: dev=本地开发，prod=线上生产，mock=关闭后端纯 mock 调试。
// 4) MOCK_ENABLED 是 dev 环境的开关：
//    - dev+mock=true：后端挂了能回退到 mock 数据，前端可独立预览
//    - dev+mock=false：后端必须可达；不达就显式报错
//    - prod：强制关闭 mock 兜底与「失败也提示成功」的伪造，
//      避免线上用户看到假数据或被告知操作成功实际没落库
// 5) 真实生产打包前务必把 MOCK_ENABLED 设为 false（或在 CI 中按 env 替换此常量）。

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

const ENV = 'dev'; // dev | prod | mock

// 线上环境强制关闭 mock 兜底；本地可通过此开关控制是否在接口失败时回退 mock
const MOCK_ENABLED = ENV !== 'prod';

module.exports = {
  BASE_URL,
  APPID,
  ENV,
  MOCK_ENABLED,
  PAGE_SIZE: 20
};
