const { api, fixRichText } = require('../../../utils/request.js');
const mock = require('../../../utils/mock.js');

// 纯文本协议转 rich-text 可渲染的段落（mock 兜底时用）
function textToHtml(txt) {
  return String(txt || '')
    .split('\n')
    .filter((line) => !!line.trim())
    .map((line) => '<p>' + line.trim() + '</p>')
    .join('');
}

Page({
  data: { title: '用户隐私政策', nodes: '', loading: true },
  onLoad() {
    api.agreement('privacy').then((res) => {
      const d = (res && (res.data || res)) || null;
      if (d && d.content) {
        this.setData({
          title: d.title || this.data.title,
          nodes: fixRichText(d.content),
          loading: false
        });
      } else {
        this.fallback();
      }
    }).catch(() => this.fallback());
  },
  // 接口不可用时回退内置文本，保证协议页不空白（合规要求必须可查看）
  fallback() {
    this.setData({ nodes: textToHtml(mock.agreement.privacy), loading: false });
  }
});
