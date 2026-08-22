const app = getApp()
const { api, APPID } = require('../../../utils/request.js')
const identity = require('../../../utils/identity.js')

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
    staffActive: false,
    // 是否可一键切到商家版（本地已有商家会话，或该微信绑过员工账号）
    canSwitchStaff: false,
    switchHint: ''
  },

  onLoad() {
    this.syncUser()
  },

  onShow() {
    // 同步 tabBar 选中态
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 3 });
    }
    const staff = wx.getStorageSync('staffUser') || {}
    this.setData({ staffActive: !!(staff && staff.userType === 'store') })
    this.refreshSwitchEntry()
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
    // 已登录员工：直接进工作台首页；否则进登录页
    const staff = wx.getStorageSync('staffUser') || {}
    if (staff && staff.userType === 'store' && wx.getStorageSync('token')) {
      wx.reLaunch({ url: '/pages/staff/home/index' })
    } else {
      wx.navigateTo({ url: '/pages/login/login?showMore=1' })
    }
  },
  goMerchantLogin() {
    // 扫码加入新员工（首次入职场景）：走商家登录页的扫码入口
    wx.navigateTo({ url: '/pages/merchant/login/index' })
  },

  /**
   * 刷新「切换到商家版」入口的可见性与提示文案。
   *
   * 两种情况都算「可切」：
   *  a) 本地已有商家 token（切过去零请求，秒进）
   *  b) 会员登录时后端返 hasStaffAccount=true（该 openid 绑过员工，可静默免密换 token）
   */
  refreshSwitchEntry() {
    const staff = wx.getStorageSync('staffUser') || {}
    const hasLocal = identity.hasStaffSession() || !!(staff && staff.logged)
    const hasStaffAccount = !!wx.getStorageSync('hasStaffAccount')
    const can = hasLocal || hasStaffAccount
    let hint = ''
    if (hasLocal) {
      hint = staff.realName ? ('当前身份：' + staff.realName) : '已登录商家账号'
    } else if (hasStaffAccount) {
      hint = '该微信已关联商家，可免密进入'
    }
    this.setData({ canSwitchStaff: can, switchHint: hint })
  },

  /**
   * 切到商家版：优先复用本地商家会话，否则静默 wx.login 用 openid 免密登录。
   * wx.login 只换 code，不弹授权框，用户全程无感。
   */
  onSwitchToStaff() {
    if (this._switching) return
    this._switching = true
    identity.switchToStaff({ api: api, appid: APPID })
      .then((r) => {
        if (r.ok) {
          const url = r.userType === 'platform' ? '/pages/platform/home/index'
                    : r.userType === 'agent'    ? '/pages/agent/home/index'
                    : '/pages/merchant/home/index'
          wx.reLaunch({ url: url })
          return
        }
        if (r.reason === 'PENDING_AUDIT') {
          wx.showModal({
            title: '等待店长审核',
            content: '你的入职申请已提交，店长在后台审核通过后即可进入商家版。',
            showCancel: false,
            confirmText: '我知道了'
          })
          return
        }
        if (r.reason === 'NOT_BOUND') {
          wx.showModal({
            title: '未绑定商家身份',
            content: '当前微信还没有关联商家员工。用账号密码登录一次后会自动绑定，之后即可免密切换。',
            confirmText: '去登录',
            success: (m) => {
              if (m.confirm) wx.navigateTo({ url: '/pages/login/login?showMore=1' })
            }
          })
          return
        }
        wx.showToast({ title: r.reason || '切换失败', icon: 'none' })
      })
      .finally(() => { this._switching = false })
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
          try { app.logout() } catch (e) { console.warn('[mine] app.logout fail', e) }
          this.setData({ logged: false, user: {}, hasShowTip: false, staffActive: false })
          wx.showToast({ title: '已退出', icon: 'success' })
          setTimeout(() => wx.reLaunch({ url: '/pages/login/login' }), 400)
        }
      }
    })
  },

  noop() {}
})
