const { request } = require('../../../utils/request.js')

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },

  load() {
    return request('/api/store/staff/today/bills')
      .then((res) => {
        const list = (Array.isArray(res) ? res : []).map((b) => ({
          ...b,
          createTimeStr: b.createTime ? String(b.createTime).slice(0, 16) : ''
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[staff bill] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },

  statusText(s) {
    return ({ '0': '待确认', '1': '待支付', '2': '已完成', '3': '已取消' })[s] || s
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
