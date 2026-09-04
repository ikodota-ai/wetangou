const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');
const { payOrder } = require('../../../utils/pay.js');
const { parseOrderParam } = require('../../../utils/orderParam.js');
const voucherUtil = require('../../../utils/voucher.js');

const STATUS_TEXT = {
  '0': '待支付',
  '1': '待使用',
  '2': '已完成',
  '3': '已取消',
  '4': '已退款'
};

Page({
  // 代金券相关字段：订单建出来之后（待支付）也要能选券。
  // 原先券入口只在下单页 pages/order/submit，订单一进待支付就没入口了 ——
  // 「到店自取」正是先下单、到店才付，用户领了券在这一步用不上。
  data: {
    id: null, orderNo: '', order: null, statusText: '', loading: true,
    qrDataUrl: '', qrLoading: false,
    vouchers: [], voucherList: [], voucherCount: 0, showVoucher: false, changing: false
  },
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
    this.loadVouchers();
  },
  // 从领券中心/登录页返回时要重新拉，否则刚领的券在本页看不到
  onShow() {
    if (this.data.order) this.loadVouchers();
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
          // 券的门店限制要拿本单门店比，不带上它跨店券会被算成可用
          storeId: o.storeId,
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
      this.refreshUsable();
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
  // 取消待支付订单。原先全端没有这个动作，于是用券下了单又不付的用户
  // 会被卡死：那张券被后端 assertNotHeld 判为「已用于另一笔待支付订单」，
  // 提示让他去取消，而取消入口根本不存在。
  onCancel() {
    const o = this.data.order;
    if (!o || o.status !== '0') return;
    wx.showModal({
      title: '取消订单',
      content: '取消后订单不可恢复，已抵扣的优惠券会退回。确定取消？',
      confirmText: '取消订单',
      cancelText: '再想想',
      success: (r) => {
        if (!r.confirm) return;
        wx.showLoading({ title: '处理中', mask: true });
        api.cancelOrder(o.orderId).then(() => {
          wx.hideLoading();
          wx.showToast({ title: '已取消', icon: 'success' });
          this.load();
        }).catch((e) => {
          wx.hideLoading();
          wx.showToast({ title: (e && e.msg) || '取消失败', icon: 'none' });
        });
      }
    });
  },
  // 我的未使用券。可用性按订单「商品总价」算 —— 和下单页、后端
  // VoucherUsageService 保持同一个基准（后端是拿 total_amount 比门槛的）
  loadVouchers() {
    const app = getApp();
    const u = (app && app.globalData && app.globalData.user) || {};
    if (!u.logged) return;
    api.myVoucher({ status: '0' }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const vouchers = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.id,
        status: v.status,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        expireTime: v.expireTime || '',
        expireText: v.expireTime ? String(v.expireTime).slice(0, 10) : '',
        storeId: v.storeId,
        storeName: v.storeName || ''
      }));
      this.setData({ vouchers });
      this.refreshUsable();
    }).catch(() => {});
  },
  _total() {
    return parseFloat((this.data.order && this.data.order.totalAmount) || 0) || 0;
  },
  _storeId() {
    return (this.data.order && this.data.order.storeId) || null;
  },
  refreshUsable() {
    if (!this.data.order) return;
    const usable = voucherUtil.usableList(this.data.vouchers, this._total(), undefined, this._storeId());
    this.setData({ voucherCount: usable.length });
  },
  openVoucher() {
    if (!this.data.order || this.data.order.status !== '0') return;
    const app = getApp();
    const u = (app && app.globalData && app.globalData.user) || {};
    if (!u.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    const total = this._total();
    const sid = this._storeId();
    // 不可用的也列出来置灰并写明原因，否则用户不知道是差门槛还是限门店
    const list = this.data.vouchers.map((v) => ({
      ...v,
      usable: voucherUtil.isUsable(v, total, undefined, sid),
      limitText: voucherUtil.storeMatch(v, sid) ? '' : ('仅限' + (v.storeName || '指定门店'))
    }));
    this.setData({ showVoucher: true, voucherList: list });
  },
  closeVoucher() { this.setData({ showVoucher: false }); },
  pickVoucher(e) {
    const id = e.currentTarget.dataset.id;
    const v = this.data.vouchers.find((x) => String(x.id) === String(id));
    if (!v) return;
    if (!voucherUtil.isUsable(v, this._total(), undefined, this._storeId())) {
      const why = voucherUtil.storeMatch(v, this._storeId())
        ? '该券暂不可用'
        : ('该券仅限' + (v.storeName || '指定门店') + '使用');
      wx.showToast({ title: why, icon: 'none' });
      return;
    }
    this.applyVoucher(v.id);
  },
  clearVoucher() { this.applyVoucher(null); },
  // 抵扣金额一律以后端返回为准：前端只做展示试算，
  // 后端会重新校验归属/门槛/门店/是否已被别的单占用
  applyVoucher(memberVoucherId) {
    if (this.data.changing) return;
    const o = this.data.order;
    if (!o || o.status !== '0') return;
    this.setData({ changing: true, showVoucher: false });
    wx.showLoading({ title: '处理中', mask: true });
    api.orderChangeVoucher(o.orderId, memberVoucherId).then(() => {
      wx.hideLoading();
      this.setData({ changing: false });
      wx.showToast({ title: memberVoucherId ? '已使用代金券' : '已取消代金券', icon: 'success' });
      // 换券后端会重发 order_no，必须重新加载，否则拿旧号去支付会对不上
      this.setData({ orderNo: '' });
      this.load();
      this.loadVouchers();
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ changing: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '操作失败', icon: 'none' });
    });
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
