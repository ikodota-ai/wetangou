const app = getApp()
const { api, APPID, toFullUrl } = require('../../../utils/request.js')
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

  // 头像必须过 toFullUrl：后端存的是 /profile/avatar/... 相对路径，
  // 历史脏数据还可能是 http://127.0.0.1:8080/... 这种内网绝对地址，
  // 直接丢给 <image> 都渲染不出来（昵称是纯文本所以看起来"只有头像坏了"）。
  _viewUser(u) {
    const user = u || {}
    return Object.assign({}, user, {
      avatarUrl: user.avatarUrl ? toFullUrl(user.avatarUrl) : ''
    })
  },

  syncUser() {
    // 客服电话与二维码跟随当前门店，避免各页写死同一个号码
    const store = app.globalData.store || {}
    this.setData({
      logged: !!app.globalData.user.logged,
      user: this._viewUser(app.globalData.user),
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
    this.setData({ logged: !!user.logged, user: this._viewUser(user) })
  },

  /**
   * 商家员工登录入口（「我的」页没有商家身份时显示的那一个）。
   *
   * 这里原来并排挂着两个入口：「员工 / 商家登录」走 goStaffLogin，
   * 「商家员工登录」走 goMerchantLogin。两个长得一样、都要账号密码，
   * 但去的是两套不同的商家端 —— 老板拿着店长给的账号，五成概率点中
   * 上面那个，落进旧门店端（/api/store/staff/login），而那个端点要求
   * biz_store_user 里挂过门店，商家版的账号一律没挂，只会看到
   * 「该账号未关联门店，无门店端权限」。实测 owner_c43 / staff_c43 都被拒。
   *
   * 现在只留一个入口，一律进新商家版登录页。旧门店端 8 个页面暂时保留
   * （biz_store_user 里还有 staff001 一个历史账号能登），但不再从这里进 ——
   * 已登录旧门店端的人 onShow 时会被下面 staffActive 分支照常送回工作台。
   */
  goMerchantLogin() {
    // 新员工入职不走这里：店长后台生成的是小程序码，
    // 用微信「扫一扫」直接拉起 pages/merchant/scan/index 提交入职申请。
    wx.navigateTo({ url: '/pages/merchant/login/index' })
  },

  /** 已在旧门店端登录态的历史用户，回工作台（不新增入口，只是别把人锁在外面） */
  goLegacyStoreHome() {
    wx.reLaunch({ url: '/pages/staff/home/index' })
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
