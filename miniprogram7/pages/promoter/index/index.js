const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

Page({
  data: {
    user: {},
    joined: false,
    stat: {
      totalCommission: '0.00',
      withdrawAmount: '0.00',
      availableAmount: '0.00',
      withdrawingAmount: '0.00',
      frozenAmount: '0.00'
    },
    tab: 'order',
    orderCount: 0,
    fanCount: 0,
    orders: [],
    fans: [],
    loading: false,
    joining: false,
    showAgreement: false,
    agreement: ''
  },
  onLoad() {
    this.setData({ user: app.globalData.user });
  },
  onShow() {
    // 提现后返回需刷新余额
    this.loadCenter();
  },
  onUserUpdate(user) { this.setData({ user }); },
  loadCenter() {
    if (!app.globalData.user.logged) {
      this.setData({ joined: false });
      return;
    }
    this.setData({ loading: true });
    api.promoterInfo().then((res) => {
      // 未成为推客时后端不返回 data，据此展示加入入口
      const d = res && res.data;
      if (!d || !d.distributorId) {
        this.setData({ joined: false, loading: false });
        return;
      }
      this.setData({
        joined: true,
        loading: false,
        orderCount: d.orderCount || 0,
        stat: {
          totalCommission: formatMoney(d.totalCommission),
          withdrawAmount: formatMoney(d.withdrawAmount),
          availableAmount: formatMoney(d.availableAmount),
          withdrawingAmount: formatMoney(d.withdrawingAmount),
          frozenAmount: formatMoney(d.frozenAmount)
        }
      });
      this.loadOrders();
      this.loadFans();
    }).catch((err) => {
      this.setData({ loading: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' });
    });
  },
  loadOrders() {
    api.commissionList().then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const orders = (Array.isArray(rows) ? rows : []).map((c) => ({
        id: c.commissionId,
        orderNo: c.orderNo || '',
        storeName: c.storeName || '',
        memberName: c.memberName || '',
        amount: formatMoney(c.amount),
        rate: c.rate ? (Number(c.rate) * 100).toFixed(0) + '%' : '',
        statusText: c.status === '1' ? '已结算' : (c.status === '2' ? '已失效' : '待结算'),
        settleTime: c.settleTime ? String(c.settleTime).slice(0, 10) : ''
      }));
      this.setData({ orders, orderCount: orders.length });
    }).catch(() => {});
  },
  loadFans() {
    // 已登录但未成为推客时跳过，避免无意义请求
    if (!this.data.joined) {
      this.setData({ fans: [], fanCount: 0 });
      return;
    }
    api.promoterFans().then((res) => {
      const rows = (res && (Array.isArray(res) ? res : (res.data || res.rows || res))) || [];
      const list = (Array.isArray(rows) ? rows : []).map((f) => ({
        memberId: f.memberId,
        nickname: f.nickname,
        avatar: f.avatar ? toFullUrl(f.avatar) : '',
        inviteTime: f.inviteTime || '',
        lastLoginTime: f.lastLoginTime || ''
      }));
      this.setData({ fans: list, fanCount: list.length });
    }).catch(() => {
      this.setData({ fans: [], fanCount: 0 });
    });
  },
  goPoster() {
    if (!this.data.joined) {
      return wx.showToast({ title: '请先成为推客', icon: 'none' });
    }
    wx.navigateTo({ url: '/pages/promoter/poster/index' });
  },
  onJoin() {
    if (this.data.joining) return;
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    this.setData({ joining: true });
    wx.showLoading({ title: '提交中', mask: true });
    api.joinPromoter().then(() => {
      wx.hideLoading();
      this.setData({ joining: false });
      wx.showToast({ title: '已成为推客', icon: 'success' });
      this.loadCenter();
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ joining: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '加入失败', icon: 'none' });
    });
  },
  switchTab(e) { this.setData({ tab: e.currentTarget.dataset.t }); },
  goRecords() { wx.navigateTo({ url: '/pages/promoter/records/index' }); },
  goWithdraw() {
    if (!this.data.joined) return wx.showToast({ title: '请先成为推客', icon: 'none' });
    if (parseFloat(this.data.stat.availableAmount) <= 0) {
      return wx.showToast({ title: '暂无可提现余额', icon: 'none' });
    }
    wx.navigateTo({ url: '/pages/promoter/withdraw/index?available=' + this.data.stat.availableAmount });
  },
  openAgreement() {
    this.setData({ showAgreement: true });
    if (this.data.agreement) return;
    // 推客协议复用协议接口，后台的类型码值是 distributor
    api.agreement('distributor').then((res) => {
      const d = (res && (res.data || res)) || {};
      this.setData({ agreement: d.content || '' });
    }).catch(() => {});
  },
  closeAgreement() { this.setData({ showAgreement: false }); },
  noop() {},
  onBubble() { wx.showToast({ title: '分享商品给好友即可赚佣金', icon: 'none' }); }
});
