const { request } = require('../../../utils/request.js')

// 状态文案在 js 里映射好塞进 list，不放模板。
// 小程序 WXML 只能调 wxs 模块的函数，不能调 Page 的方法 ——
// {{statusText(item.status)}} 恒渲染成空，状态那一列一直是空白的。
const STATUS_TEXT = { '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' }

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
        const rows = (res && (res.data || res.rows || res)) || []
        const list = (Array.isArray(rows) ? rows : []).map((o) => ({
          ...o,
          createTimeStr: o.createTime ? String(o.createTime).slice(0, 16) : '',
          statusText: STATUS_TEXT[o.status] || o.status
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[staff order] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
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
