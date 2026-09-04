const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney, formatDate } = require('../../../utils/util.js');
const { payOrder } = require('../../../utils/pay.js');

// tab 与后端订单状态的映射：后端 0待支付 1待使用 2已核销 3已取消 4已退款
const TAB_STATUS = {
  all: '',
  pending: '0',
  unused: '1',
  done: '2',
  refund: '4'
};
const STATUS_TEXT = {
  '0': '待支付',
  '1': '待使用',
  '2': '已完成',
  '3': '已取消',
  '4': '已退款'
};

Page({
  data: { tab: 'all', list: [], loading: false, loaded: false, merchantName: '' },
  onLoad(opts) {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {}
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({ tab: opts.type || 'all', merchantName: m.merchantName || '当前商家' })
    this.loadList()
  },
  // 从详情页返回或支付回来时刷新，保证状态是最新的
  onShow() {
    if (this.data.loaded) this.loadList();
  },
  switchTab(e) {
    const t = e.currentTarget.dataset.t;
    if (t === this.data.tab) return;
    this.setData({ tab: t });
    this.loadList();
  },
  loadList() {
    if (!app.globalData.user.logged) {
      this.setData({ list: [], loaded: true });
      wx.showToast({ title: '请先登录', icon: 'none' });
      setTimeout(() => wx.navigateTo({ url: '/pages/login/login' }), 800);
      return;
    }
    this.setData({ loading: true });
    const status = TAB_STATUS[this.data.tab];
    api.orderList(status ? { status } : {}).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const list = (Array.isArray(rows) ? rows : []).map((o) => ({
        orderId: o.orderId,
        orderNo: o.orderNo,
        shop: o.storeName || '',
        name: o.productName || '',
        cover: o.productCover ? toFullUrl(o.productCover) : '/assets/img/RestaurantImg.png',
        price: formatMoney(o.price),
        qty: o.num || 1,
        total: formatMoney(o.payAmount),
        time: o.createTime ? String(o.createTime).slice(0, 16) : '',
        status: o.status,
        statusText: STATUS_TEXT[o.status] || ''
      }));
      this.setData({ list, loading: false, loaded: true });
    }).catch((err) => {
      this.setData({ list: [], loading: false, loaded: true });
      if (err && err.code === 401) {
        wx.navigateTo({ url: '/pages/login/login' });
        return;
      }
      wx.showToast({ title: '订单加载失败', icon: 'none' });
    });
  },
  // 点卡片一律进详情，包括待支付的。
  // 原先待支付会被拦下来直接拉支付，于是这类订单根本进不去详情页 ——
  // 微信支付商户平台要配「订单页面路径」，那个路径得真能打开订单详情，
  // 被拦掉就等于配了也没用。续付改由卡片上的「去支付」按钮负责。
  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    wx.navigateTo({ url: '/pages/order/detail/index?id=' + id });
  },
  // catchtap 绑定：不能用 bindtap，否则点按钮会冒泡到卡片的 goDetail，
  // 变成「既跳详情又拉支付」
  onPay(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    this.continuePay(id);
  },
  continuePay(orderId) {
    payOrder(orderId, () => this.loadList());
  },
  // 同 onPay 用 catchtap。取消入口原先全端都没有，用券下的待付单会把券锁死
  onCancel(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    wx.showModal({
      title: '取消订单',
      content: '取消后订单不可恢复，已抵扣的优惠券会退回。确定取消？',
      confirmText: '取消订单',
      cancelText: '再想想',
      success: (r) => {
        if (!r.confirm) return;
        wx.showLoading({ title: '处理中', mask: true });
        api.cancelOrder(id).then(() => {
          wx.hideLoading();
          wx.showToast({ title: '已取消', icon: 'success' });
          this.loadList();
        }).catch((err) => {
          wx.hideLoading();
          wx.showToast({ title: (err && err.msg) || '取消失败', icon: 'none' });
        });
      }
    });
  }
});
