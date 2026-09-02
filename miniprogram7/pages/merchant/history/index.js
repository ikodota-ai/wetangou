const { api } = require('../../../utils/request.js')

// 日期加减天数，返回 yyyy-MM-dd。
// 用本地时间的年月日拼串而不是 toISOString().slice(0,10) —— 后者按 UTC 切，
// 东八区在 00:00~08:00 之间会切到「昨天」，店长早班打开就看到前一天的记录。
function shiftDate(base, days) {
  const d = base ? new Date(String(base).replace(/-/g, '/')) : new Date()
  d.setDate(d.getDate() + (days || 0))
  const mm = d.getMonth() + 1
  const dd = d.getDate()
  return d.getFullYear() + '-' + (mm < 10 ? '0' + mm : mm) + '-' + (dd < 10 ? '0' + dd : dd)
}

function today() { return shiftDate(null, 0) }

Page({
  data: {
    list: [], loaded: false,
    date: '',
    total: 0, totalAmount: '0.00',
    mine: false,          // 只看自己核的
    canSeeAll: false,     // 老板/店长才有「全店 / 只看我」切换
    isToday: true,        // 今天不允许再往后翻
    noStore: false,
    multiStore: false     // 多店时列表里带上门店名
  },
  onLoad() { this.setData({ date: today() }) },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },

  load() {
    const date = this.data.date || today()
    return api.merchantStaffVerifyRecords({ date, mine: this.data.mine ? 1 : '' })
      .then((res) => {
        const d = res || {}
        const rows = Array.isArray(d.rows) ? d.rows : []
        const multiStore = (d.storeIds || []).length > 1
        // 派生字段全在 js 算好：WXML 里调不到 Page 方法（调了恒渲染成空）
        const list = rows.map((o) => ({
          ...o,
          verifyTimeStr: o.verifyTime ? String(o.verifyTime).slice(11, 16) : '',
          amountStr: o.payAmount == null ? '0.00' : Number(o.payAmount).toFixed(2),
          numStr: o.num > 1 ? ('×' + o.num) : ''
        }))
        this.setData({
          list,
          loaded: true,
          noStore: !!d.noStore,
          total: d.total || 0,
          totalAmount: Number(d.totalAmount || 0).toFixed(2),
          canSeeAll: !!d.canSeeAll,
          multiStore,
          isToday: date === today()
        })
      })
      .catch((e) => {
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  },

  onPrevDay() { this.setData({ date: shiftDate(this.data.date, -1) }, () => this.load()) },
  onNextDay() {
    if (this.data.isToday) return
    this.setData({ date: shiftDate(this.data.date, 1) }, () => this.load())
  },
  onPickDate(e) { this.setData({ date: e.detail.value }, () => this.load()) },
  onToggleMine() { this.setData({ mine: !this.data.mine }, () => this.load()) },

  // 点一条 → 复制订单号，方便和 PC 后台/客人对账时直接粘贴
  onCopyNo(e) {
    const no = e.currentTarget.dataset.no
    if (!no) return
    wx.setClipboardData({ data: String(no) })
  }
})

module.exports = module.exports || {}
module.exports.__test__ = { shiftDate }
