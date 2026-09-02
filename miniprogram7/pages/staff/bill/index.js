const { request } = require('../../../utils/request.js')

// 状态文案在 js 里映射好塞进 list，不放模板。
// 小程序 WXML 只能调 wxs 模块的函数，不能调 Page 的方法 ——
// {{statusText(item.status)}} 恒渲染成空，状态那一列一直是空白的。
const STATUS_TEXT = { '0': '待确认', '1': '待支付', '2': '已完成', '3': '已取消' }

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },

  load() {
    return request('/api/store/staff/today/bills')
      .then((res) => {
        const rows = (res && (res.data || res.rows || res)) || []
        const list = (Array.isArray(rows) ? rows : []).map((b) => ({
          ...b,
          createTimeStr: b.createTime ? String(b.createTime).slice(0, 16) : '',
          statusText: STATUS_TEXT[b.status] || b.status
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[staff bill] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },

  onConfirm(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({
      title: '确认买单',
      content: '确定已收银该笔买单？',
      success: (res) => {
        if (!res.confirm) return
        // 调后端 /api/bill/confirm/{billId} (StoreStaffRequired 校验)
        request(`/api/bill/confirm/${id}`, { method: 'POST' })
          .then(() => {
            wx.showToast({ title: '已确认', icon: 'success' })
            this.load()
          })
          .catch((err) => {
            wx.showToast({ title: (err && (err.msg || err.message)) || '确认失败', icon: 'none' })
          })
      }
    })
  }
})
