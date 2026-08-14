const { api } = require('../../../utils/request.js')

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  load() {
    return api.merchantStaffTodayBills()
      .then((res) => {
        const list = (Array.isArray(res) ? res : []).map((b) => ({
          ...b,
          createTimeStr: b.createTime ? String(b.createTime).slice(0, 16) : ''
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },
  statusText(s) {
    return ({ '0': '待确认', '1': '待支付', '2': '已完成', '3': '已取消' })[s] || s
  }
})
