const { api } = require('../../../utils/request.js')

Page({
  data: {
    userType: '',
    realName: '',
    scope: 'ALL',
    agentId: null,
    totalRevenue: 0,
    totalOrders: 0,
    loading: false
  },

  onShow() {
    this.syncStaff()
    this.loadSummary()
  },

  onPullDownRefresh() {
    this.loadSummary().then(() => wx.stopPullDownRefresh()).catch(() => wx.stopPullDownRefresh())
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    if (!staff || staff.userType !== 'platform') {
      wx.redirectTo({ url: '/pages/merchant/login/index' })
      return
    }
    this.setData({
      userType: staff.userType,
      realName: staff.realName || '平台账号'
    })
  },

  loadSummary() {
    this.setData({ loading: true })
    const { scope, agentId } = this.data
    return api.platformFinanceSummary({ scope, agentId: agentId || '' })
      .then((resp) => {
        this.setData({
          totalRevenue: resp.totalRevenue || 0,
          totalOrders: resp.totalOrders || 0,
          loading: false
        })
      })
      .catch((err) => {
        console.error('[platform home] loadSummary err', err)
        this.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  onScopeChange(e) {
    const scope = e.currentTarget.dataset.scope
    this.setData({ scope, agentId: null })
    this.loadSummary()
  },

  onAgentIdInput(e) {
    this.setData({ agentId: e.detail.value })
  },

  onAgentQuery() {
    if (!this.data.agentId) {
      wx.showToast({ title: '请输入代理ID', icon: 'none' })
      return
    }
    this.setData({ scope: 'AGENT' })
    this.loadSummary()
  }
})
