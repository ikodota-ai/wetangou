const app = getApp();
const { toFullUrl } = require('../../../utils/request.js');

const DEFAULT_PHONE = '13434123069';

Page({
  data: { phone: DEFAULT_PHONE, qrcode: '', hours: '', intro: '' },
  onLoad() {
    // 客服信息优先用当前门店的；门店没配时回退到商家级（merchant.servicePhone）
    const store = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (store) {
      this.apply(store);
      return;
    }
    app.pickNearestStore((s) => this.apply(s));
  },
  // 返回客服信息：门店优先，商家兜底
  resolveContact() {
    const store = app.globalData.store || {};
    const merchant = (app.globalData && app.globalData.merchant) || {};
    return {
      phone: store.servicePhone || store.phone || merchant.servicePhone || DEFAULT_PHONE,
      qrcode: store.serviceQrcode || merchant.serviceQrcode || '',
      hours: store.businessHours || store.hours || merchant.businessHours || '',
      intro: merchant.intro || ''
    };
  },
  apply(store) {
    // 先用 store 数据，再用 merchant 兜底
    const c = this.resolveContact();
    this.setData(c);
  },
  callService() {
    wx.makePhoneCall({ phoneNumber: this.data.phone || DEFAULT_PHONE });
  },
  previewQr() {
    if (!this.data.qrcode) return;
    const url = toFullUrl(this.data.qrcode);
    wx.previewImage({ urls: [url] });
  }
});
