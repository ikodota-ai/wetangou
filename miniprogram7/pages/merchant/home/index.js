const app = getApp()
const { api } = require('../../../utils/request.js')
const role = require('../../../utils/role.js')
const identity = require('../../../utils/identity.js')

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
    recentOrders: [],
    showGmv: false,
    showCreateProduct: false,
    showBill: true,
    isStaffOnly: false
  },

  onShow() {
    this.syncStaff()
    this.loadHome()
    if (getApp() && getApp().consumeVerifyScene) getApp().consumeVerifyScene()
  },

  onPullDownRefresh() {
    this.loadHome().then(() => wx.stopPullDownRefresh()).catch(() => wx.stopPullDownRefresh())
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      wx.redirectTo({ url: '/pages/login/login?showMore=1' })
      return
    }
    this.setData({
      storeId: staff.storeId,
      storeName: staff.storeName || ('门店' + staff.storeId),
      realName: staff.realName || '',
      merchantId: staff.merchantId,
      needBindWx: !!staff.needBindWx,
      showGmv: role.isManagerOrAbove(),
      showCreateProduct: role.isManagerOrAbove(),
      showBill: role.isManagerOrAbove(),
      isStaffOnly: role.isStaff() && !role.isManager() && !role.isOwner()
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
          recentOrders: d.recentOrders || [],
          showGmv: role.isManagerOrAbove(),
          showCreateProduct: role.isManagerOrAbove(),
          showBill: role.isManagerOrAbove(),
          isStaffOnly: role.isStaff() && !role.isManager() && !role.isOwner()
        })
      })
  },

  orderStatusText(s) {
    return ({ '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' })[s] || s
  },

  goVerify() { wx.navigateTo({ url: '/pages/merchant/verify/index' }) },
  goBill()   { wx.navigateTo({ url: '/pages/merchant/bill/index' }) },
  goBooking(){ wx.navigateTo({ url: '/pages/merchant/booking/index' }) },
  goCreateProduct() {
    wx.navigateTo({ url: '/pages/merchant/product/create/index' })
  },

  goOrders() { wx.navigateTo({ url: '/pages/merchant/order/index' }) },
  goHistory(){ wx.navigateTo({ url: '/pages/merchant/history/index' }) },
  goMe()     { wx.navigateTo({ url: '/pages/merchant/me/index' }) },
  /**
   * 切回会员版。
   *
   * 保留商家会话（不删 staffUser / staffToken），这样从「我的」再切回来是零请求。
   * 只有真正「退出商家账号」时才清 —— 那是另一个动作。
   */
  goSwitchAccount() {
    const r = identity.switchToMember()
    if (r.ok) {
      wx.reLaunch({ url: '/pages/home/index' })
      return
    }
    // 没有会员登录态（例如直接用账号密码进的商家端）→ 引导去会员登录
    wx.showModal({
      title: '尚未登录会员',
      content: '当前微信还没有会员登录记录，去用微信登录一次即可在两端来回切换。',
      confirmText: '去登录',
      success: (m) => {
        if (m.confirm) wx.reLaunch({ url: '/pages/login/login' })
      }
    })
  },

  /** 退出商家账号：清商家会话，回到会员版（会员登录态保留）*/
  onLogoutStaff() {
    wx.showModal({
      title: '退出商家账号',
      content: '退出后需重新登录才能进入商家版，会员身份不受影响。',
      success: (m) => {
        if (!m.confirm) return
        identity.clearStaff()
        wx.reLaunch({ url: '/pages/home/index' })
      }
    })
  }
})
