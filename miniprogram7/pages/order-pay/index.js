// pages/pay/index.js
// 支付中间页（订单/买单共用）
const app = getApp()
const { api } = require('../../utils/request.js')

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
    _prepayRes: null
  },

  onLoad(opts) {
    // 来源：order/list "去支付" 或 买单页 "提交"
    const t = opts && opts.type ? opts.type : 'order'
    const id = opts && opts.id ? Number(opts.id) : 0
    this.setData({ type: t, orderId: id })
    if (!id) {
      wx.showToast({ title: '缺少订单号', icon: 'none' })
      return
    }
    this.loadPayInfo()
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
        this.setData({ paying: false })
        wx.showToast({ title: '支付成功', icon: 'success' })
        setTimeout(() => this._goPaid(), 800)
      }, 600)
      return
    }
    const p = (r && (r.data || r)) || {}
    if (!p.paySign) {
      wx.showToast({ title: '暂未配置支付参数', icon: 'none' })
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
        this.setData({ paying: false })
        wx.showToast({ title: '支付成功', icon: 'success' })
        setTimeout(() => this._goPaid(), 800)
      },
      fail: () => {
        this.setData({ paying: false })
        wx.showToast({ title: '已取消支付', icon: 'none' })
      }
    })
  },

  _goPaid() {
    // 跳到对应"已支付"列表或详情
    if (this.data.type === 'bill') {
      wx.redirectTo({ url: '/pages/bill/index' })
    } else {
      wx.redirectTo({ url: '/pages/order/list/index?type=paid' })
    }
  }
})
