const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');
const { payOrder } = require('../../../utils/pay.js');

const STATUS_TEXT = {
  '0': '待支付',
  '1': '待使用',
  '2': '已完成',
  '3': '已取消',
  '4': '已退款'
};

Page({
  data: { id: null, order: null, statusText: '', loading: true, qrDataUrl: '', qrLoading: false },
  onLoad(opts) {
    this.setData({ id: opts.id });
    this.load();
  },
  load() {
    api.orderDetail(this.data.id).then((res) => {
      const o = (res && (res.data || res)) || null;
      if (!o || !o.orderId) {
        this.setData({ loading: false });
        wx.showToast({ title: '订单不存在', icon: 'none' });
        return;
      }
      this.setData({
        order: {
          orderId: o.orderId,
          orderNo: o.orderNo,
          storeName: o.storeName || '',
          productName: o.productName || '',
          cover: o.productCover ? toFullUrl(o.productCover) : '/assets/img/RestaurantImg.png',
          price: formatMoney(o.price),
          num: o.num || 1,
          totalAmount: formatMoney(o.totalAmount),
          discountAmount: formatMoney(o.discountAmount),
          payAmount: formatMoney(o.payAmount),
          status: o.status,
          verifyCode: o.verifyCode || '',
          expireTime: o.expireTime ? String(o.expireTime).slice(0, 10) : '',
          createTime: o.createTime ? String(o.createTime).slice(0, 16) : '',
          payTime: o.payTime ? String(o.payTime).slice(0, 16) : ''
        },
        statusText: STATUS_TEXT[o.status] || '',
        loading: false
      });
      if (o.status === '1' && o.verifyCode) {
        this.loadQrCode();
      }
    }).catch((err) => {
      this.setData({ loading: false });
      wx.showToast({ title: (err && err.msg) || '加载失败', icon: 'none' });
    });
  },
  copyCode() {
    const code = this.data.order && this.data.order.verifyCode;
    if (!code) return;
    wx.setClipboardData({ data: code, success: () => wx.showToast({ title: '核销码已复制', icon: 'success' }) });
  },
  copyNo() {
    const no = this.data.order && this.data.order.orderNo;
    if (!no) return;
    wx.setClipboardData({ data: no, success: () => wx.showToast({ title: '订单号已复制', icon: 'success' }) });
  },
  // 详情页原来没有任何支付入口，所以列表页才不得不拦截待支付订单的点击、
  // 直接拉支付 —— 结果这类订单永远进不来。微信支付商户平台配的
  // 「订单页面路径」指向的就是本页，进不来等于那个配置形同虚设。
  onPay() {
    const o = this.data.order;
    if (!o || o.status !== '0') return;
    payOrder(o.orderId, () => this.load());
  },
  loadQrCode() {
    this.setData({ qrLoading: true });
    api.orderQrcodeData(this.data.id).then((res) => {
      const d = (res && (res.data || res)) || {};
      this.setData({ qrDataUrl: d.dataUrl || '', qrLoading: false });
    }).catch((err) => {
      this.setData({ qrLoading: false });
      console.warn('[order/detail] qrcode FAIL', err);
    });
  }
});
