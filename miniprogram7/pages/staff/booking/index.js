const { request } = require('../../../utils/request.js')

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
  }
})
