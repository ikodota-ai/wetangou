const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');
const { payOrder } = require('../../../utils/pay.js');
const { parseOrderParam } = require('../../../utils/orderParam.js');

const STATUS_TEXT = {
  '0': '待支付',
  '1': '待使用',
  '2': '已完成',
  '3': '已取消',
  '4': '已退款'
};

Page({
  data: { id: null, orderNo: '', order: null, statusText: '', loading: true, qrDataUrl: '', qrLoading: false },
  // 两种入口都要支持，而且它们**共用 id 这个参数名**：
  //   ?id=999451           站内跳转，值是数据库主键
  //   ?id=D1787398679265359 微信支付「商品订单详情path」跳回来，值是商户订单号
  //
  // 微信那个配置填的是 pages/order/detail/index?id=${商品订单号}，
  // 占位符由微信替换成下单时的 out_trade_no（即 biz_order.order_no）。
  // 参数名就是我们自己写的 id，所以没法按键名分流，只能看值的形态 ——
  // 纯数字走主键接口，含字母走订单号接口。
  // 若按键名分流，订单号会被当主键去打 /api/order/D178...，
  // @PathVariable Long 转换失败直接 500，用户从微信账单点进来看到报错页。
  onLoad(opts) {
    const p = parseOrderParam(opts);
    this.setData({ id: p.id, orderNo: p.orderNo });
    if (!p.id && !p.orderNo) {
      this.setData({ loading: false });
      wx.showToast({ title: '缺少订单参数', icon: 'none' });
      return;
    }
    this.load();
  },
  load() {
    // 有主键优先用主键（站内跳转都是这条路，少一次字符串查询）
    const req = this.data.id
      ? api.orderDetail(this.data.id)
      : api.orderDetailByNo(this.data.orderNo);
    req.then((res) => {
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
      // 按订单号进来时 data.id 还是空的，从响应里补上 ——
      // loadQrCode 走的是 /api/order/{id}/qrcode-data，只认主键，
      // 不回填的话从微信账单跳进来的待使用订单看不到核销二维码。
      if (!this.data.id && o.orderId) {
        this.setData({ id: o.orderId });
      }
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
