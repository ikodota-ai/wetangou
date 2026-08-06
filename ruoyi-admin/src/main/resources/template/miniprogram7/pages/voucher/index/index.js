const app = getApp();
const { api } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

Page({
  data: {
    tab: 'get',
    storeId: null,
    list: [],
    mine: [],
    mineTab: '0',
    loading: false,
    receiving: false
  },
  onLoad(opts) {
    const storeId = (opts && opts.storeId) || (app.globalData.store && app.globalData.store.storeId) || null;
    const tab = (opts && opts.tab) || 'get';
    this.setData({ storeId, tab });
    this.loadAll();
  },
  onShow() {
    // 买单用券后返回需刷新我的券
    if (this.data.list.length || this.data.mine.length) this.loadMine();
  },
  onPullDownRefresh() { this.loadAll(() => wx.stopPullDownRefresh()); },
  loadAll(done) {
    this.setData({ loading: true });
    const tasks = [this.loadList()];
    if (app.globalData.user.logged) tasks.push(this.loadMine());
    Promise.all(tasks).then(() => {
      this.setData({ loading: false });
      if (done) done();
    });
  },
  loadList() {
    const params = {};
    if (this.data.storeId) params.storeId = this.data.storeId;
    return api.voucherList(params).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const list = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.voucherId,
        name: v.voucherName || '代金券',
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        // total=0 视为不限量；剩余为 0 时按已领完展示
        total: v.total || 0,
        remain: v.total ? Math.max(v.total - (v.received || 0), 0) : null,
        validDays: v.validDays || 0,
        soldOut: !!v.total && (v.received || 0) >= v.total
      }));
      this.setData({ list });
    }).catch((err) => {
      wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' });
    });
  },
  loadMine() {
    if (!app.globalData.user.logged) {
      this.setData({ mine: [] });
      return Promise.resolve();
    }
    return api.myVoucher({ status: this.data.mineTab }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const mine = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.id,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        getTime: v.getTime ? String(v.getTime).slice(0, 10) : '',
        expireTime: v.expireTime ? String(v.expireTime).slice(0, 10) : '',
        useTime: v.useTime ? String(v.useTime).slice(0, 10) : '',
        status: v.status
      }));
      this.setData({ mine });
    }).catch(() => {});
  },
  switchTab(e) {
    const tab = e.currentTarget.dataset.t;
    this.setData({ tab });
    if (tab === 'mine') this.loadMine();
  },
  switchMineTab(e) {
    this.setData({ mineTab: e.currentTarget.dataset.s });
    this.loadMine();
  },
  onReceive(e) {
    if (this.data.receiving) return;
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    const id = e.currentTarget.dataset.id;
    this.setData({ receiving: true });
    wx.showLoading({ title: '领取中', mask: true });
    api.receiveVoucher(id).then(() => {
      wx.hideLoading();
      this.setData({ receiving: false });
      wx.showToast({ title: '领取成功', icon: 'success' });
      // 领取会改变剩余数量与我的券，两处都要刷新
      this.loadList();
      this.loadMine();
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ receiving: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '领取失败', icon: 'none' });
    });
  },
  goPay() {
    const id = this.data.storeId;
    wx.navigateTo({ url: '/pages/pay/index/index' + (id ? '?storeId=' + id : '') });
  },
  goLogin() { wx.navigateTo({ url: '/pages/login/login' }); }
});
