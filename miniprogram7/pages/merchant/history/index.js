const { api } = require('../../../utils/request.js')

// 同 pages/merchant/order：状态文案必须在 js 里算好，WXML 调不到 Page 方法。
const STATUS_TEXT = { '0': '待确认', '1': '待支付', '2': '已完成', '3': '已取消' }

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  load() {
    return api.merchantStaffTodayBills()
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
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  }
})

module.exports = module.exports || {}
module.exports.__test__ = { STATUS_TEXT }
