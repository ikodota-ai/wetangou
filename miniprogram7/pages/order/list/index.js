const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney, formatDate } = require('../../../utils/util.js');

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
  data: { tab: 'all', list: [], loading: false, loaded: false },
  onLoad(opts) {
    this.setData({ tab: opts.type || 'all' });
    this.loadList();
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
  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    const order = this.data.list.find((o) => String(o.orderId) === String(id));
    // 待支付订单点进去直接续付，其余展示核销码等详情
    if (order && order.status === '0') {
      this.continuePay(id);
      return;
    }
    wx.navigateTo({ url: '/pages/order/detail/index?id=' + id });
  },
  continuePay(orderId) {
    wx.showLoading({ title: '发起支付', mask: true });
    api.prepayOrder(orderId).then((res) => {
      wx.hideLoading();
      if (res && res.mock) {
        wx.showToast({ title: '支付成功', icon: 'success' });
        this.loadList();
        return;
      }
      const p = (res && (res.data || res)) || {};
      if (!p.paySign) {
        wx.showToast({ title: '暂不可支付，请稍后重试', icon: 'none' });
        return;
      }
      wx.requestPayment({
        timeStamp: String(p.timeStamp),
        nonceStr: p.nonceStr,
        package: p.package,
        signType: p.signType || 'RSA',
        paySign: p.paySign,
        success: () => {
          wx.showToast({ title: '支付成功', icon: 'success' });
          this.loadList();
        },
        fail: () => wx.showToast({ title: '已取消支付', icon: 'none' })
      });
    }).catch((err) => {
      wx.hideLoading();
      wx.showToast({ title: (err && err.msg) || '支付失败', icon: 'none' });
    });
  }
});
