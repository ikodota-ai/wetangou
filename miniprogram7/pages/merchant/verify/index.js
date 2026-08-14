const { api } = require('../../../utils/request.js')
const HISTORY_KEY = 'merchantVerifyHistory'

Page({
  data: {
    storeId: null, storeName: '', realName: '',
    verifyCode: '', orderNo: '',
    submitting: false, history: []
  },
  onShow() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) { wx.redirectTo({ url: '/pages/merchant/login/index' }); return }
    this.setData({ storeId: staff.storeId, storeName: staff.storeName || ('门店' + staff.storeId), realName: staff.realName || '' })
    this.loadHistory()
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
      fail: () => wx.showToast({ title: '网络失败', icon: 'none' }),
      complete: () => this.setData({ submitting: false })
    })
  }
})
