// pages/merchant/poster-invite/index.js 员工邀请海报（OWNER/MANAGER）
const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { drawStaffInvite } = require('../../../utils/poster.js');

// 与后端 BizRole 口径一致：OWNER=老板 / MANAGER=店长 / STAFF=店员。
// 原先这里写成 OWNER:'店长' / MANAGER:'管理员'，海报上的职位和实际权限对不上。
const ROLE_LABEL = { OWNER: '老板', MANAGER: '店长', STAFF: '店员' };

Page({
  data: {
    generating: true,
    savedPath: '',
    inviteId: null,
    inviteCode: ''
  },

  onLoad(opts) {
    this.opts = opts || {};
    this.inviteId = opts && opts.inviteId;
    this.setData({ inviteId: this.inviteId });
    if (!this.inviteId) {
      wx.showToast({ title: '邀请码ID缺失', icon: 'none' });
      setTimeout(() => wx.navigateBack(), 800);
      return;
    }
    this._loadAndDraw();
  },

  _loadAndDraw() {
    this.setData({ generating: true });
    api.merchantStaffInviteQrcode(this.inviteId)
      .then((res) => {
        const d = (res && res.data) || res || {};
        const url = d.url || '';
        const code = d.inviteCode || '';
        const scene = d.scene || '';
        if (!url) {
          this.setData({ generating: false });
          wx.showToast({ title: '太阳码生成失败', icon: 'none' });
          return;
        }
        this.inviteCode = code;
        this.scene = scene;
        const staff = wx.getStorageSync('staffUser') || {};
        const storeName = staff.storeName || ('门店' + (staff.storeId || ''));
        // 海报上要写的是「被邀请人的角色」，取邀请码自身的 role。
        // 原先取 staff.staffRole（当前登录者的角色），店长发店员码时海报会写成
        // 「扫码成为 XX 的店长」—— 招进来的人看到的职位是错的。
        const roleLabel = ROLE_LABEL[d.role] || ROLE_LABEL[this.opts && this.opts.role] || '员工';
        return drawStaffInvite({
          canvasId: 'posterCanvas',
          qrcodeUrl: toFullUrl(url),
          storeName,
          inviteCode: code,
          roleLabel
        }).then((path) => {
          this.savedPath = path;
          this.setData({ generating: false, inviteCode: code });
        });
      })
      .catch((err) => {
        console.error('[poster-invite] FAIL', err);
        this.setData({ generating: false });
        wx.showToast({ title: (err && (err.msg || err.message)) || '生成失败', icon: 'none' });
      });
  },

  onPreview() {
    if (!this.savedPath) return;
    wx.previewImage({ urls: [this.savedPath], current: this.savedPath });
  },

  onSave() {
    if (!this.savedPath) return wx.showToast({ title: '海报还没生成', icon: 'none' });
    wx.saveImageToPhotosAlbum({
      filePath: this.savedPath,
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
  }
});
