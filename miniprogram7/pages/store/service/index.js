const app = getApp();
const { toFullUrl } = require('../../../utils/request.js');
const { resolveContact } = require('../../../utils/contact.js');

Page({
  // 不再给 phone 预置默认值：原先写死 DEFAULT_PHONE = '13434123069'，
  // 那是某个门店的号码，对所有商户都拨过去是错的；后台没配时应该明说没配，
  // 而不是把顾客引到一个不相干的号码上。
  data: { phone: '', qrcode: '', hours: '', intro: '', isStoreService: false },

  onLoad() {
    const store = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (store) this.apply(store);
    // 仍然要挂回调：onLoad 时 globalData.store 可能还没就绪
    // （bootDefaultStore 是异步的），门店从占位升级成最近门店时也要刷新。
    app.pickNearestStore((s) => this.apply(s));
  },

  // 客服信息：门店优先、商家兜底，四项各自独立降级。
  // 规则收口在 utils/contact.js，和首页「在线咨询」共用同一套 ——
  // 原先这页自己写了一遍 resolveContact，用的是
  // store.businessHours（营业时间）当客服时间、且没有 serviceHours 这一级，
  // 与首页结果不一致。
  apply(store) {
    if (!store) return;
    const merchant = (app.globalData && app.globalData.merchant) || {};
    const c = resolveContact(store, merchant);
    this.setData({
      phone: c.servicePhone,
      // 二维码可能是 /profile/... 相对路径，要补成绝对地址，否则 <image> 加载不出来
      qrcode: c.qrcode ? toFullUrl(c.qrcode) : '',
      hours: c.serviceHours,
      intro: merchant.intro || '',
      isStoreService: c.isStoreService
    });
  },

  // 商家信息是 app.bootMerchant 异步拉的，onLoad 时通常还没到 ——
  // 门店没配客服的那几项这时会算成空且不再重算。拿到商家后重算一次。
  onMerchantUpdate() {
    const store = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
    if (store) this.apply(store);
  },

  callService() {
    const tel = this.data.phone;
    if (!tel) return wx.showToast({ title: '商家暂未配置客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: tel });
  },

  previewQr() {
    if (!this.data.qrcode) return;
    wx.previewImage({ urls: [this.data.qrcode] });
  }
});
