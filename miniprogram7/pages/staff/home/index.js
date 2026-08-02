const app = getApp()
const { request, api } = require('../../../utils/request.js')

Page({
  data: {
    storeId: null,
    storeName: '',
    realName: '',
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
    this.syncStaff()
    this.loadHome().then(() => wx.stopPullDownRefresh())
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || staff.userType !== 'store' || !token) {
      wx.redirectTo({ url: '/pages/staff/login/index' })
      return
    }
    this.setData({
      storeId: staff.storeId,
      storeName: staff.storeName || ('门店' + staff.storeId),
      realName: staff.realName || ''
    })
  },

  loadHome() {
    return request('/api/store/staff/home')
      .then((res) => {
        const d = res || {}
        this.setData({
          storeName: d.storeName || this.data.storeName,
          todayVerifyCount: d.todayVerifyCount || 0,
          todayVerifyAmount: (d.todayVerifyAmount || 0).toString(),
          todayOrderCount: d.todayOrderCount || 0,
          pendingBillCount: d.pendingBillCount || 0,
          todayBookingCount: d.todayBookingCount || 0,
          recentOrders: d.recentOrders || []
        })
      })
      .catch((err) => {
        console.error('[staff home] err', err)
        wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' })
      })
  },

  orderStatusText(s) {
    return ({ '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' })[s] || s
  },

  goVerify() {
    wx.navigateTo({ url: '/pages/staff/verify/index' })
  },
  goBill() {
    wx.navigateTo({ url: '/pages/staff/bill/index' })
  },
  goBooking() {
    wx.navigateTo({ url: '/pages/staff/booking/index' })
  },
  goOrders() {
    wx.navigateTo({ url: '/pages/staff/order/index' })
  },
  goHistory() {
    wx.navigateTo({ url: '/pages/staff/history/index' })
  },
  goMe() {
    wx.navigateTo({ url: '/pages/staff/me/index' })
  },
  goStatDetail(e) {
    const i = (e && e.currentTarget && e.currentTarget.dataset && e.currentTarget.dataset.i) || '1'
    const map = { '1': 'verify', '2': 'orders', '3': 'bill', '4': 'booking' }
    const dest = map[i] || 'verify'
    if (dest === 'verify') return this.goVerify()
    if (dest === 'orders') return this.goOrders()
    if (dest === 'bill') return this.goBill()
    if (dest === 'booking') return this.goBooking()
  },
  goSwitchAccount() {
    wx.showModal({
      title: '切换回会员',
      content: '退出员工工作台，回到 C 端会员身份？',
      success: (res) => {
        if (!res.confirm) return
        const memberToken = wx.getStorageSync('staffTokenBackup')
        if (memberToken) {
          wx.setStorageSync('token', memberToken)
          wx.removeStorageSync('staffTokenBackup')
        } else {
          wx.removeStorageSync('token')
        }
        wx.removeStorageSync('staffUser')
        wx.reLaunch({ url: '/pages/home/index' })
      }
    })
  }
})
