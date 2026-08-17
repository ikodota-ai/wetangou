const { api } = require('../../../utils/request.js')
const HISTORY_KEY = 'merchantVerifyHistory'

Page({
  data: {
    storeId: null, storeName: '', realName: '',
    verifyCode: '', orderNo: '',
    submitting: false, history: []
  },
  /**
   * 外部 Scheme 跳入：扫桌上的台卡二维码 → 微信唤起小程序
   * URL 形如 pages/merchant/verify/index?code=138F31FA1271&sid=200
   *
   * 注意：onLoad 时 wx.storage 可能还没拿到 staffUser（因为是 fresh open）
   * 所以先 setData code/sid，等 onShow 拿到 staff 后再决定是否自动核销。
   */
  onLoad(options) {
    if (options && (options.code || options.sid)) {
      this._schemeCode = options.code || ''
      this._schemeSid = options.sid ? Number(options.sid) : null
      this.setData({
        verifyCode: this._schemeCode,
        orderNo: ''
      })
      wx.showLoading({ title: '正在核销...', mask: true })
    }
  },

  onShow() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      // staff 还没登录，但有外部 scheme code → 跳到登录页带 redirect
      if (this._schemeCode) {
        wx.redirectTo({ url: '/pages/login/login?tab=account&redirect=verify&code=' + encodeURIComponent(this._schemeCode) + '&sid=' + (this._schemeSid || '') })
      } else {
        wx.redirectTo({ url: '/pages/login/login?tab=account' })
      }
      return
    }
    this.setData({ storeId: staff.storeId, storeName: staff.storeName || ('门店' + staff.storeId), realName: staff.realName || '' })
    this.loadHistory()

    // 外部 Scheme 进来 + 当前 staff.storeId 与 sid 不一致 → 切到 sid 对应的店
    if (this._schemeSid && staff.storeId !== this._schemeSid) {
      this._switchStoreThenVerify(this._schemeSid, this._schemeCode)
      return
    }

    // 已经在对门店 → 自动核销
    if (this._schemeCode) {
      this.setData({ verifyCode: this._schemeCode })
      // 延迟一帧确保 setData 完成
      setTimeout(() => {
        this.onSubmit()
        // 用完清掉
        this._schemeCode = ''
        this._schemeSid = null
      }, 50)
    }
  },

  /**
   * 切到目标门店后再核销（适用于店员扫了非当前 store 的台卡）
   */
  _switchStoreThenVerify(targetSid, code) {
    const token = wx.getStorageSync('token') || ''
    const APPID = require('../../../utils/request.js').APPID
    const BASE = require('../../../utils/request.js').BASE_URL
    wx.request({
      url: BASE + '/api/store/staff/switch-store',
      method: 'POST',
      header: { 'content-type': 'application/json', 'Authorization': 'Bearer ' + token, 'X-App-Id': APPID },
      data: { storeId: targetSid },
      success: (res) => {
        if (res.statusCode === 200 && (res.data.code === 200 || res.data.success)) {
          // 更新本地 staff
          const staff = wx.getStorageSync('staffUser') || {}
          staff.storeId = targetSid
          wx.setStorageSync('staffUser', staff)
          this.setData({ storeId: targetSid, storeName: '门店' + targetSid })
          this.setData({ verifyCode: code })
          setTimeout(() => {
            this.onSubmit()
            this._schemeCode = ''
            this._schemeSid = null
          }, 50)
        } else {
          wx.hideLoading()
          wx.showToast({ title: res.data.msg || '切店失败', icon: 'none' })
        }
      },
      fail: () => { wx.hideLoading(); wx.showToast({ title: '网络失败', icon: 'none' }) }
    })
  },
  onCode(e) { this.setData({ verifyCode: e.detail.value }) },
  onOrderNo(e) { this.setData({ orderNo: e.detail.value }) },
  onScan() {
    wx.scanCode({ scanType: ['qrCode'], success: (res) => {
      const text = (res && (res.result || res.path)) || ''
      const m = text.match(/(verifyCode|orderNo)=([^&]+)/)
      this.setData({ verifyCode: m ? m[2] : text })
    } })
  },
  loadHistory() {
    try { this.setData({ history: (wx.getStorageSync(HISTORY_KEY) || []).slice(0, 10) }) } catch(e) { this.setData({ history: [] }) }
  },
  saveHistory(item) {
    try {
      const list = wx.getStorageSync(HISTORY_KEY) || []
      list.unshift(item)
      wx.setStorageSync(HISTORY_KEY, list.slice(0, 20))
      this.setData({ history: list.slice(0, 10) })
    } catch(e) {}
  },
  onSubmit() {
    const { verifyCode, orderNo, storeId, submitting } = this.data
    if (submitting) return
    if (!verifyCode && !orderNo) { wx.showToast({ title: '请填写核销码或订单号', icon: 'none' }); return }
    this.setData({ submitting: true })
    wx.showLoading({ title: '核销中...', mask: true })
    // 复用 /api/order/verify（公开接口）
    wx.request({
      url: require('../../../utils/request.js').BASE_URL + '/api/order/verify',
      method: 'POST',
      header: {
        'content-type': 'application/json',
        'Authorization': 'Bearer ' + (wx.getStorageSync('token') || ''),
        'X-App-Id': require('../../../utils/request.js').APPID
      },
      data: { verifyCode: verifyCode || '', orderNo: orderNo || '', storeId: storeId || 0 },
      success: (res) => {
        if (res.statusCode === 200) {
          const d = res.data || {}
          if (d.code === 200 || d.success) {
            wx.showToast({ title: '核销成功', icon: 'success' })
            const item = (d.data && d.data.order) || { orderNo: orderNo || verifyCode, productName: '团购券', payAmount: 0, verifyTimeStr: new Date().toISOString().slice(0,16) }
            this.saveHistory({ ...item, verifyTimeStr: new Date().toISOString().slice(0,16) })
            this.setData({ verifyCode: '', orderNo: '' })
          } else {
            wx.showToast({ title: d.msg || '核销失败', icon: 'none' })
          }
        } else {
          wx.showToast({ title: 'HTTP ' + res.statusCode, icon: 'none' })
        }
      },
      fail: () => { wx.hideLoading(); wx.showToast({ title: '网络失败', icon: 'none' }) },
      complete: () => { wx.hideLoading(); this.setData({ submitting: false }) }
    })
  }
})
