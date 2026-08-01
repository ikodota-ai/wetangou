const app = getApp();
const { toFullUrl } = require('../../../utils/request.js');

const DEFAULT_PHONE = '13434123069';

Page({
  data: { phone: DEFAULT_PHONE, qrcode: '', hours: '' },
  onLoad() {
    // 客服信息跟随当前门店，优先用门店配置的客服电话
    const store = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (store) {
      this.apply(store);
      return;
    }
    app.pickNearestStore((s) => this.apply(s));
  },
  apply(store) {
    if (!store) return;
    this.setData({
      phone: store.servicePhone || store.phone || DEFAULT_PHONE,
      qrcode: store.serviceQrcode ? toFullUrl(store.serviceQrcode) : '',
      hours: store.businessHours || store.hours || ''
    });
  },
  callService() {
    wx.makePhoneCall({ phoneNumber: this.data.phone || DEFAULT_PHONE });
  },
  previewQr() {
    if (!this.data.qrcode) return;
    wx.previewImage({ urls: [this.data.qrcode] });
  }
});
