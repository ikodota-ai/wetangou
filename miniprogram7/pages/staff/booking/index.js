const { request, staffBookingConfirm, staffBookingReject } = require('../../../utils/request.js')

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },

  load() {
    return request('/api/store/staff/booking/signup/list')
      .then((res) => {
        const list = Array.isArray(res) ? res : []
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[staff booking] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },

  onConfirm(e) {
    const id = e.currentTarget.dataset.id
    if (!id) return
    wx.showModal({
      title: '确认到店', content: '确认该顾客已到店？', success: (r) => {
        if (!r.confirm) return
        staffBookingConfirm(id, { remark: '到店确认' })
          .then(() => { wx.showToast({ title: '已确认' }); this.load() })
          .catch((err) => wx.showToast({ title: (err && (err.msg||err.message)) || '操作失败', icon: 'none' }))
      }
    })
  },
  onReject(e) {
    const id = e.currentTarget.dataset.id
    if (!id) return
    wx.showModal({
      title: '拒绝预约', editable: true, placeholderText: '请填写拒绝原因', success: (r) => {
        if (!r.confirm) return
        const reason = (r.content || '').trim()
        if (!reason) { wx.showToast({ title: '请填写原因', icon: 'none' }); return }
        staffBookingReject(id, { reason })
          .then(() => { wx.showToast({ title: '已拒绝' }); this.load() })
          .catch((err) => wx.showToast({ title: (err && (err.msg||err.message)) || '操作失败', icon: 'none' }))
      }
    })
  }
  }
})
