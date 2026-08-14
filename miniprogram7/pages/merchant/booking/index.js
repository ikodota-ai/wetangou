const { api } = require('../../../utils/request.js')

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  load() {
    return api.merchantStaffBookingSignupList()
      .then((res) => {
        const list = Array.isArray(res) ? res : []
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[merchant booking] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },
  onConfirm(e) {
    const id = e.currentTarget.dataset.id
    if (!id) return
    wx.showModal({ title: '确认到店', content: '确认该顾客已到店？', success: (r) => {
      if (!r.confirm) return
      console.log('[merchant booking] confirm start id=', id)
      api.merchantStaffBookingConfirm(id, { remark: '到店确认' })
        .then((res) => {
          console.log('[merchant booking] confirm OK =>', JSON.stringify(res))
          wx.showToast({ title: '已确认' }); this.load()
        })
        .catch((err) => {
          console.error('[merchant booking] confirm FAIL =>', JSON.stringify(err))
          const msg = (err && (err.msg || err.message)) || '操作失败'
          wx.showModal({ title: '确认失败', content: msg + '\n请截图发开发者', showCancel: false })
        })
    } })
  },
  onReject(e) {
    const id = e.currentTarget.dataset.id
    if (!id) return
    wx.showModal({ title: '拒绝预约', editable: true, placeholderText: '请填写拒绝原因', success: (r) => {
      if (!r.confirm) return
      const reason = (r.content || '').trim()
      if (!reason) { wx.showToast({ title: '请填写原因', icon: 'none' }); return }
      console.log('[merchant booking] reject start id=', id, 'reason=', reason)
      api.merchantStaffBookingReject(id, { reason })
        .then((res) => {
          console.log('[merchant booking] reject OK =>', JSON.stringify(res))
          wx.showToast({ title: '已拒绝' }); this.load()
        })
        .catch((err) => {
          console.error('[merchant booking] reject FAIL =>', JSON.stringify(err))
          const msg = (err && (err.msg || err.message)) || '操作失败'
          wx.showModal({ title: '拒绝失败', content: msg + '\n请截图发开发者', showCancel: false })
        })
    } })
  }
})
