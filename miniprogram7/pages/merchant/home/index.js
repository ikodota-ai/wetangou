const app = getApp()
const { api } = require('../../../utils/request.js')

Page({
  data: {
    storeId: null,
    storeName: '',
    realName: '',
    merchantId: null,
    needBindWx: false,
    todayVerifyCount: 0,
    todayVerifyAmount: '0.00',
    todayOrderCount: 0,
    pendingBillCount: 0,
    todayBookingCount: 0,
    recentOrders: []
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
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      wx.redirectTo({ url: '/pages/merchant/login/index' })
      return
    }
    this.setData({
      storeId: staff.storeId,
      storeName: staff.storeName || ('门店' + staff.storeId),
      realName: staff.realName || '',
      merchantId: staff.merchantId,
      needBindWx: !!staff.needBindWx
    })
  },

  loadHome() {
    return Promise.all([api.merchantStaffMe().catch(() => null), api.merchantStaffHome().catch(() => null)])
      .then(([me, home]) => {
        if (me) {
          const staff = wx.getStorageSync('staffUser') || {}
          staff.storeId = me.storeId || staff.storeId
          staff.storeName = me.storeName || staff.storeName
          staff.realName = me.realName || staff.realName
          staff.merchantId = me.merchantId || staff.merchantId
          staff.needBindWx = !me.openidBound
          wx.setStorageSync('staffUser', staff)
        }
        const d = home || {}
        this.setData({
          storeId: d.storeId || this.data.storeId,
          storeName: d.storeName || this.data.storeName,
          realName: (me && (me.realName || me.nickName)) || this.data.realName,
          needBindWx: me ? !me.openidBound : this.data.needBindWx,
          todayVerifyCount: d.todayVerifyCount || 0,
          todayVerifyAmount: (d.todayVerifyAmount || 0).toString(),
          todayOrderCount: d.todayOrderCount || 0,
          pendingBillCount: d.pendingBillCount || 0,
          todayBookingCount: d.todayBookingCount || 0,
          recentOrders: d.recentOrders || []
        })
      })
  },

  orderStatusText(s) {
    return ({ '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' })[s] || s
  },

  goVerify() { wx.navigateTo({ url: '/pages/merchant/verify/index' }) },
  goBill()   { wx.navigateTo({ url: '/pages/merchant/bill/index' }) },
  goBooking(){ wx.navigateTo({ url: '/pages/merchant/booking/index' }) },
  goOrders() { wx.navigateTo({ url: '/pages/merchant/order/index' }) },
  goHistory(){ wx.navigateTo({ url: '/pages/merchant/history/index' }) },
  goMe()     { wx.navigateTo({ url: '/pages/merchant/me/index' }) },
  goSwitchAccount() {
    const memberToken = wx.getStorageSync('memberTokenBackup')
    if (memberToken) {
      wx.setStorageSync('token', memberToken)
    }
    wx.removeStorageSync('staffUser')
    wx.reLaunch({ url: '/pages/home/index' })
  }
})
