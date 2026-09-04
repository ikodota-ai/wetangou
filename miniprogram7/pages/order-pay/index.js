// pages/pay/index.js
// 支付中间页（订单/买单共用）
const app = getApp()
const { api } = require('../../utils/request.js')
const { formatMoney } = require('../../utils/util.js')
const voucherUtil = require('../../utils/voucher.js')

Page({
  data: {
    // 类型: 'order' | 'bill'
    type: 'order',
    orderId: 0,
    amount: '0.00',
    orderNo: '',
    payNo: '',
    payInfoId: '',
    expireTimeText: '',
    paying: false,
    // prepay 内部缓存
    _prepayRes: null,
    // 代金券。下单页是 redirectTo 跳到本页的，用户退不回去，
    // 本页原先又没有券入口 —— 到店自取先下单、到店才付，
    // 在店里想起有券时整条路都是断的。买单(type=bill)的券在买单页选，这里不重复给入口。
    canUseVoucher: false,
    total: 0,
    discount: '0.00',
    vouchers: [],
    voucherList: [],
    voucherCount: 0,
    showVoucher: false,
    changing: false
  },

  onLoad(opts) {
    // 来源：order/list "去支付" 或 买单页 "提交"
    const t = opts && opts.type ? opts.type : 'order'
    const id = opts && opts.id ? Number(opts.id) : 0
    this.setData({ type: t, orderId: id, canUseVoucher: t === 'order' })
    if (!id) {
      wx.showToast({ title: '缺少订单号', icon: 'none' })
      return
    }
    this.loadPayInfo()
    this.loadOrderAmount()
    this.loadVouchers()
  },

  // 从领券中心返回时要重新拉一次，否则刚领的券在本页看不到
  onShow() {
    if (this.data.canUseVoucher) {
      this.loadVouchers()
    }
  },

  /**
   * 券可用性要按订单「商品总价」判，和下单页、后端 VoucherUsageService 同一个基准；
   * prepay 只返实付金额，用它判门槛会把「满 100 减 20 的券用在 200 减到 180 的单上」
   * 越判越不可用。所以另拉一次订单详情取 totalAmount / storeId / discountAmount。
   */
  loadOrderAmount() {
    if (!this.data.canUseVoucher) return
    api.orderDetail(this.data.orderId).then((res) => {
      const o = (res && (res.data || res)) || {}
      if (!o.orderId) return
      this.setData({
        total: parseFloat(o.totalAmount || 0) || 0,
        discount: formatMoney(o.discountAmount),
        _storeIdVal: o.storeId || null,
        // 订单已经不是待支付了就收掉入口（例如从历史页面返回时状态已变）
        canUseVoucher: o.status === '0'
      })
      this.refreshUsable()
    }).catch(() => {})
  },

  loadVouchers() {
    if (!this.data.canUseVoucher) return
    const u = (app && app.globalData && app.globalData.user) || {}
    if (!u.logged) return
    api.myVoucher({ status: '0' }).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || []
      const vouchers = (Array.isArray(rows) ? rows : []).map((v) => ({
        id: v.id,
        status: v.status,
        faceValue: formatMoney(v.faceValue),
        threshold: formatMoney(v.threshold),
        expireTime: v.expireTime || '',
        expireText: v.expireTime ? String(v.expireTime).slice(0, 10) : '',
        storeId: v.storeId,
        storeName: v.storeName || ''
      }))
      this.setData({ vouchers })
      this.refreshUsable()
    }).catch(() => {})
  },

  refreshUsable() {
    const usable = voucherUtil.usableList(this.data.vouchers, this.data.total, undefined, this.data._storeIdVal)
    this.setData({ voucherCount: usable.length })
  },

  openVoucher() {
    if (!this.data.canUseVoucher) return
    const u = (app && app.globalData && app.globalData.user) || {}
    if (!u.logged) {
      wx.navigateTo({ url: '/pages/login/login' })
      return
    }
    const sid = this.data._storeIdVal
    // 不可用的也列出来置灰写明原因，否则用户不知道是差门槛还是限门店
    const list = this.data.vouchers.map((v) => ({
      ...v,
      usable: voucherUtil.isUsable(v, this.data.total, undefined, sid),
      limitText: voucherUtil.storeMatch(v, sid) ? '' : ('仅限' + (v.storeName || '指定门店'))
    }))
    this.setData({ showVoucher: true, voucherList: list })
  },
  closeVoucher() { this.setData({ showVoucher: false }) },
  pickVoucher(e) {
    const id = e.currentTarget.dataset.id
    const v = this.data.vouchers.find((x) => String(x.id) === String(id))
    if (!v) return
    if (!voucherUtil.isUsable(v, this.data.total, undefined, this.data._storeIdVal)) {
      const why = voucherUtil.storeMatch(v, this.data._storeIdVal)
        ? '该券暂不可用'
        : ('该券仅限' + (v.storeName || '指定门店') + '使用')
      wx.showToast({ title: why, icon: 'none' })
      return
    }
    this.applyVoucher(v.id)
  },
  clearVoucher() { this.applyVoucher(null) },

  /**
   * 换券后必须重新 prepay。order_no 就是微信的 out_trade_no，
   * 后端换券时会重发单号作废旧预支付单；本页若继续拿旧的 paySign 去
   * requestPayment，微信按首次下单金额扣款 —— 页面显示 180 实际扣 200。
   */
  applyVoucher(memberVoucherId) {
    if (this.data.changing) return
    this.setData({ changing: true, showVoucher: false })
    wx.showLoading({ title: '处理中', mask: true })
    api.orderChangeVoucher(this.data.orderId, memberVoucherId).then(() => {
      wx.hideLoading()
      this.setData({ changing: false, _prepayRes: null })
      wx.showToast({ title: memberVoucherId ? '已使用代金券' : '已取消代金券', icon: 'success' })
      this.loadPayInfo()
      this.loadOrderAmount()
      this.loadVouchers()
    }).catch((err) => {
      wx.hideLoading()
      this.setData({ changing: false })
      wx.showToast({ title: (err && (err.msg || err.message)) || '操作失败', icon: 'none' })
    })
  },

  /**
   * 拉取订单/账单 + 预支付信息
   */
  loadPayInfo() {
    wx.showLoading({ title: '加载中', mask: true })
    if (this.data.type === 'bill') {
      // 买单：先调 bill/prepay
      api.billPrepay(this.data.orderId).then((res) => {
        wx.hideLoading()
        this._applyPrepay(res, this._billOrderNo())
      }).catch((err) => {
        wx.hideLoading()
        wx.showToast({ title: (err && (err.msg || err.message)) || '预支付失败', icon: 'none' })
      })
    } else {
      // 订单：调 order/prepay
      api.prepayOrder(this.data.orderId).then((res) => {
        wx.hideLoading()
        this._applyPrepay(res, '')
      }).catch((err) => {
        wx.hideLoading()
        wx.showToast({ title: (err && (err.msg || err.message)) || '预支付失败', icon: 'none' })
      })
    }
  },

  _billOrderNo() {
    // 买单没有 orderNo，使用 'BILL-' + billId
    return 'BILL-' + this.data.orderId
  },

  _applyPrepay(res, fallbackOrderNo) {
    // res 可能是 { code, msg, data, mock }
    const r = res || {}
    const data = r.data || r
    const mock = !!r.mock
    // 金额
    const amount = (data && (data.amount != null ? data.amount : data.total)) || '0.00'
    // 订单号（来自订单/账单本身，不在 prepay 响应里；fallback 由调用方提供）
    const orderNo = (data && (data.orderNo || data.billNo)) || fallbackOrderNo || ('O' + this.data.orderId)
    // 支付单号（prepay 才有）
    const payNo = (data && (data.payNo || data.transactionId)) || ''
    // 支付信息ID（prepay 响应里）
    const payInfoId = (data && (data.payInfoId || data.prepayId)) || ''
    // 过期时间
    const expireMs = data && data.expireTime ? Number(data.expireTime) : 0
    const expireTimeText = expireMs ? this._fmtTime(new Date(expireMs)) : this._defaultExpireText()

    this.setData({
      amount: typeof amount === 'number' ? amount.toFixed(2) : String(amount),
      orderNo,
      payNo,
      payInfoId: payInfoId ? String(payInfoId) : '',
      expireTimeText,
      _prepayRes: r
    })
  },

  _defaultExpireText() {
    // 默认 2 小时后过期
    const d = new Date(Date.now() + 2 * 60 * 60 * 1000)
    return this._fmtTime(d)
  },

  _fmtTime(d) {
    const pad = (n) => (n < 10 ? '0' + n : '' + n)
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes())
  },

  /**
   * 取消本单（订单或买单），释放代金券占用。
   *
   * <p>本页是券被锁死的主要现场：买单建单后是 redirectTo 到这里的，
   * 前一页已销毁，用户不想付时只能退到更早的页面，那笔待付单和它抵的券
   * 就一直挂着 —— 后端 assertNotHeld 判 status in ('0','1','2') 为占用，
   * 于是这张券再也用不了，提示「请先完成或取消那笔」而取消入口不存在。</p>
   */
  onCancelPay() {
    const isBill = this.data.type === 'bill'
    wx.showModal({
      title: isBill ? '取消买单' : '取消订单',
      content: '取消后不可恢复，已抵扣的优惠券会退回。确定取消？',
      confirmText: '确定取消',
      cancelText: '继续支付',
      success: (r) => {
        if (!r.confirm) return
        wx.showLoading({ title: '处理中', mask: true })
        const req = isBill ? api.cancelBill(this.data.orderId) : api.cancelOrder(this.data.orderId)
        req.then(() => {
          wx.hideLoading()
          wx.showToast({ title: '已取消', icon: 'success' })
          setTimeout(() => {
            if (isBill) {
              wx.switchTab({ url: '/pages/home/index' })
            } else {
              wx.redirectTo({ url: '/pages/order/list/index' })
            }
          }, 800)
        }).catch((e) => {
          wx.hideLoading()
          wx.showToast({ title: (e && e.msg) || '取消失败', icon: 'none' })
        })
      }
    })
  },

  onPickWxPay() {
    // 当前仅支持微信支付，留作未来扩展
  },

  /**
   * 点 "去支付" → 调起 wx.requestPayment
   */
  onConfirmPay() {
    if (this.data.paying) return
    const r = this.data._prepayRes || {}
    // mock 模式：直接成功
    if (r.mock) {
      this.setData({ paying: true })
      wx.showLoading({ title: '支付中', mask: true })
      setTimeout(() => {
        wx.hideLoading()
        this.setData({ paying: false, paid: true, paidTip: this.data.type === 'bill' ? '已支付，可在微信支付记录中查看' : '订单已支付完成' })
      }, 600)
      return
    }
    const p = (r && (r.data || r)) || {}
    if (!p.paySign) {
      // _prepayRes 被换券清空后还没刷回来时也会走到这里，提示要区分开
      wx.showToast({ title: this.data.changing ? '金额更新中，请稍候' : '暂未配置支付参数', icon: 'none' })
      return
    }
    this.setData({ paying: true })
    wx.requestPayment({
      timeStamp: String(p.timeStamp),
      nonceStr: p.nonceStr,
      package: p.package,
      signType: p.signType || 'RSA',
      paySign: p.paySign,
      success: () => {
        this.setData({ paying: false, paid: true, paidTip: this.data.type === 'bill' ? '已支付，可在微信支付记录中查看' : '订单已支付完成' })
      },
      fail: () => {
        this.setData({ paying: false })
        wx.showToast({ title: '已取消支付', icon: 'none' })
      }
    })
  },

  onPaidDone() {
    // 买单：跳回首页（买单入口在首页 tabBar，且微信支付有支付记录可查）
    // 订单：跳到订单列表
    if (this.data.type === 'bill') {
      wx.switchTab({ url: '/pages/home/index' })
    } else {
      wx.redirectTo({ url: '/pages/order/list/index?type=paid' })
    }
  },

  _goPaid() {
    // 兼容旧路径：直接跳
    this.onPaidDone();
  }
})
