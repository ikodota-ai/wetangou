const { api, fixRichText } = require('../../../utils/request.js');

const FALLBACK_TITLES = {
  user: '用户服务协议',
  privacy: '用户隐私政策'
};

Page({
  data: { title: '', nodes: '', loading: true },
  onLoad(opts) {
    const type = (opts && opts.type) || 'privacy';
    this.setData({ title: FALLBACK_TITLES[type] || '用户协议' });
    this.load(type);
  },
  load(type) {
    api.agreement(type).then((res) => {
      const d = (res && (res.data || res)) || null;
      if (d && d.content) {
        this.setData({
          title: d.title || this.data.title,
          nodes: fixRichText(d.content),
          loading: false
        });
      } else {
        // 后端返回 200 但 content 为空：提示用户协议未配置
        this.setData({
          nodes: '<p>协议内容暂未配置，请联系平台运营人员补充。</p>',
          loading: false
        });
      }
    }).catch((err) => {
      console.error('[agreement] FAIL', type, err);
      this.setData({
        nodes: '<p>协议加载失败，请稍后重试。</p>',
        loading: false
      });
    });
  }
});
