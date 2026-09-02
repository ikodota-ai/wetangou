const { api } = require('../../../utils/request.js')

// 状态映射在 js 里算好塞进 list，不放模板。
// 小程序 WXML 只能调 wxs 模块的函数，不能调 Page 的方法 ——
// 模板里写 {{statusText(item.status)}} 恒渲染成空字符串，
// 店员看到的订单状态那一列一直是空白的（同 pages/merchant/bill 已修过的那条）。
const STATUS_TEXT = { '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' }

Page({
  data: { list: [], loaded: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  load() {
    return api.merchantStaffTodayOrders()
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
        console.error('[merchant order] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  }
})

module.exports = module.exports || {}
module.exports.__test__ = { STATUS_TEXT }
