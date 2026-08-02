const app = getApp()

Page({
  data: {
    logged: false,
    user: {},
    showProfileTip: false,
    showService: false,
    hasShowTip: false,
    servicePhone: '',
    serviceQrcode: '',
    businessHours: '',
    // 员工身份标识：true=当前是员工 token
    staffActive: false
  },

  onLoad() {
    this.syncUser()
  },

  onShow() {
    const staff = wx.getStorageSync('staffUser') || {}
    this.setData({ staffActive: !!(staff && staff.userType === 'store') })
    this.syncUser()

    // 已登录 + 资料不完整 + 未弹过提示 → 弹完善资料
    if (this.data.logged && !this.data.hasShowTip && !this.isProfileComplete()) {
      this.setData({ showProfileTip: true, hasShowTip: true })
    }
  },

  syncUser() {
    // 客服电话与二维码跟随当前门店，避免各页写死同一个号码
    const store = app.globalData.store || {}
    this.setData({
      logged: !!app.globalData.user.logged,
      user: app.globalData.user,
      servicePhone: store.servicePhone || store.phone || '',
      serviceQrcode: store.serviceQrcode || '',
      businessHours: store.businessHours || store.hours || ''
    })
  },

  isProfileComplete() {
    const u = app.globalData.user
    return !!(u.avatarUrl && u.nickName && u.phone)
  },

  onUserUpdate(user) {
    this.setData({ logged: !!user.logged, user })
  },

  goStaffLogin() {
    // 已登录员工：直接进工作台；否则进登录页
    const staff = wx.getStorageSync('staffUser') || {}
    if (staff && staff.userType === 'store' && wx.getStorageSync('token')) {
      wx.navigateTo({ url: '/pages/staff/verify/index' })
    } else {
      wx.navigateTo({ url: '/pages/staff/login/index' })
    }
  },
  goLogin() {
    wx.navigateTo({ url: '/pages/login/login' })
  },

  goProfile() {
    this.setData({ showProfileTip: false })
    wx.navigateTo({ url: '/pages/mine/profile/index' })
  },

  closeProfileTip() {
    this.setData({ showProfileTip: false })
  },

  goOrder(e) {
    if (!this.data.logged) {
      wx.navigateTo({ url: '/pages/login/login' })
      return
    }
    wx.navigateTo({ url: `/pages/order/list/index?type=${e.currentTarget.dataset.type}` })
  },

  goPromoter() {
    if (!this.data.logged) {
      wx.navigateTo({ url: '/pages/login/login' })
      return
    }
    wx.navigateTo({ url: '/pages/promoter/index/index' })
  },

  goBookingList() {
    if (!this.data.logged) {
      wx.navigateTo({ url: '/pages/login/login' })
      return
    }
    wx.navigateTo({ url: '/pages/booking/list/index' })
  },

  goVoucher() {
    const tab = this.data.logged ? 'mine' : 'get'
    wx.navigateTo({ url: `/pages/voucher/index/index?tab=${tab}` })
  },

  goAgreement(e) {
    wx.navigateTo({ url: `/pages/agreement/${e.currentTarget.dataset.type}/index` })
  },

  callService() {
    this.setData({ showService: true })
  },

  closeService() {
    this.setData({ showService: false })
  },

  callPhone() {
    if (!this.data.servicePhone) {
      wx.showToast({ title: '暂无客服电话', icon: 'none' })
      return
    }
    wx.makePhoneCall({ phoneNumber: this.data.servicePhone })
  },

  previewQrcode() {
    if (!this.data.serviceQrcode) return
    wx.previewImage({ urls: [this.data.serviceQrcode] })
  },

  onLogout() {
    wx.showModal({
      title: '提示',
      content: '确定要退出登录吗？',
      success: (res) => {
        if (res.confirm) {
          app.logout()
          this.setData({ logged: false, user: {}, hasShowTip: false })
          wx.showToast({ title: '已退出', icon: 'success' })
        }
      }
    })
  },

  noop() {}
})
