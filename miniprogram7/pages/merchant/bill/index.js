const { api } = require('../../../utils/request.js')

// 状态映射在 js 里算好塞进 list，不放模板。
// 小程序 WXML 只能调 wxs 模块的函数，不能调 Page 的方法 ——
// 原来模板里写 {{statusText(item.status)}} 恒渲染成空字符串，
// 所以这一列的状态一直是空白的。
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
        console.error('[merchant bill] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  }
})
