const { request } = require('../../../utils/request.js')

Page({
  data: { list: [], storeId: null, loaded: false },

  onShow() {
    const staff = wx.getStorageSync('staffUser') || {}
    this.setData({ storeId: staff.storeId || null })
    this.load()
  },

  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },

  load() {
    return request('/api/store/staff/today/orders')
      .then((res) => {
        const list = (Array.isArray(res) ? res : []).map((o) => ({
          ...o,
          createTimeStr: o.createTime ? String(o.createTime).slice(0, 16) : ''
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[staff order] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },

  statusText(s) {
    return ({ '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' })[s] || s
  },

  onVerify(e) {
    const { code, no, store } = e.currentTarget.dataset
    wx.showModal({
      title: '确认核销',
      content: '订单 ' + no + ' 立即核销？',
      success: (res) => {
        if (!res.confirm) return
        request('/api/order/verify', { method: 'POST', data: { verifyCode: code, orderNo: no, storeId: store } })
          .then(() => {
            wx.showToast({ title: '核销成功', icon: 'success' })
            this.load()
          })
          .catch((err) => {
            wx.showToast({ title: (err && (err.msg || err.message)) || '核销失败', icon: 'none' })
          })
      }
    })
  }
})
