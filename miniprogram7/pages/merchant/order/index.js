const { api } = require('../../../utils/request.js')

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  load() {
    return api.merchantStaffTodayOrders()
      .then((res) => {
        const list = (Array.isArray(res) ? res : []).map((o) => ({
          ...o,
          createTimeStr: o.createTime ? String(o.createTime).slice(0, 16) : ''
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[merchant order] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },
  statusText(s) {
    return ({ '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' })[s] || s
  }
})
