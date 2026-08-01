// pages/promoter/poster/index.js 推客邀请海报
const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');

Page({
  data: {
    user: {},
    qrcode: '',
    scene: '',
    saving: false
  },

  onLoad() {
    this.setData({ user: app.globalData.user || {} });
    this.loadQrcode();
  },

  loadQrcode() {
    wx.showLoading({ title: '生成海报中...' });
    api.promoterQrcode().then((res) => {
      const url = (res && (res.url || (res.data && res.data.url))) || '';
      const scene = (res && (res.scene || (res.data && res.data.scene))) || '';
      this.setData({ qrcode: toFullUrl(url), scene });
    }).catch((err) => {
      wx.showToast({ title: (err && (err.msg || err.message)) || '生成失败', icon: 'none' });
    }).finally(() => wx.hideLoading());
  },

  onPreview() {
    if (!this.data.qrcode) return;
    wx.previewImage({ urls: [this.data.qrcode], current: this.data.qrcode });
  },

  onSave() {
    if (!this.data.qrcode) return wx.showToast({ title: '海报还没生成', icon: 'none' });
    if (this.data.saving) return;
    this.setData({ saving: true });
    wx.showLoading({ title: '保存中...' });
    wx.downloadFile({
      url: this.data.qrcode,
      success: (res) => {
        if (res.statusCode !== 200) {
          wx.showToast({ title: '下载失败', icon: 'none' });
          return;
        }
        wx.saveImageToPhotosAlbum({
          filePath: res.tempFilePath,
          success: () => wx.showToast({ title: '已保存到相册', icon: 'success' }),
          fail: (err) => {
            if (err && /auth deny|authorize/i.test(err.errMsg || '')) {
              wx.showModal({
                title: '需要相册权限',
                content: '保存海报需要您授权访问相册',
                confirmText: '去设置',
                success: (r) => { if (r.confirm) wx.openSetting(); }
              });
            } else {
              wx.showToast({ title: '保存失败', icon: 'none' });
            }
          }
        });
      },
      fail: () => wx.showToast({ title: '下载失败', icon: 'none' }),
      complete: () => { this.setData({ saving: false }); wx.hideLoading(); }
    });
  },

  onShareAppMessage() {
    const name = (this.data.user && this.data.user.nickName) || '我';
    return {
      title: name + ' 邀请你加入，一起省钱 / 赚钱',
      path: '/pages/home/index'
    };
  }
});
