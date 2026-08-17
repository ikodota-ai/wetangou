const { api } = require('../../../utils/request.js')

Page({
  data: {
    userType: '',
    realName: '',
    todayOrderCount: 0,
    loading: false
  },

  onShow() {
    this.syncStaff()
    this.loadHome()
  },

  onPullDownRefresh() {
    this.loadHome().then(() => wx.stopPullDownRefresh()).catch(() => wx.stopPullDownRefresh())
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    if (!staff || staff.userType !== 'agent') {
      wx.redirectTo({ url: '/pages/login/login?tab=account' })
      return
    }
    this.setData({
      userType: staff.userType,
      realName: staff.realName || '代理商'
    })
  },

  loadHome() {
    // 占位：未来接 /api/agent/dashboard
    this.setData({ loading: false })
  }
})
