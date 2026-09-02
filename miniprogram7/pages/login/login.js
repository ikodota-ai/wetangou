const app = getApp()
const { api, APPID, pickHasStaffAccount } = require('../../utils/request.js')
const identity = require('../../utils/identity.js')

/**
 * 合并登录页（V2.6.2 设计）
 *  - 主页：一键微信登录（基于 openid 身份识别）
 *      - 普通会员 → 用户端首页
 *      - 已绑 openid 的员工/店长/商家 → 直接进商家端
 *  - 「更多登录方式」折叠区（仅当 hasStaffAccount=true 时显示）：
 *      - 账号密码登录：用于没绑 openid 的商家账号
 *  - 用户端右上角有「切换到商家端」入口（仅当该 openid 命中 staff 时显示）
 */
Page({
  data: {
    submitting: false,
    agreed: false,
    showMore: false,           // 折叠区是否展开
    showAccountLogin: false,  // 账号密码登录（折叠区中切换）
    merchantName: '',
    username: '',
    password: '',
    hasStaffAccount: false    // 后端识别：当前 openid 是否绑了商家账号
  },

  onLoad(query) {
    const appInst = getApp() || {}
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    // 支持 ?showMore=1 直接展开折叠区（用于商家未绑 openid 场景）
    const showMore = query && (query.showMore === '1' || query.showMore === 1)
    this.setData({ merchantName: m.merchantName || '当前商家', showMore: !!showMore })
  },

  onShow() {
    // 处理从扫码加入回来后可能需要的提示
  },

  toggleAgree() { this.setData({ agreed: !this.data.agreed }) },

  toggleMore() { this.setData({ showMore: !this.data.showMore }) },

  toggleAccountLogin() {
    this.setData({
      showAccountLogin: !this.data.showAccountLogin,
      showMore: !this.data.showMore
    })
  },

  onUsername(e) { this.setData({ username: e.detail.value }) },
  onPassword(e) { this.setData({ password: e.detail.value }) },

  goAgreement(e) {
    const type = e.currentTarget.dataset.type
    wx.navigateTo({ url: `/pages/agreement/${type}/index` })
  },

  /**
   * 登录成功 / 跳过后回到用户来的那一页。
   *
   * 之前无论从哪进来都写死 switchTab('/pages/home/index')：用户在
   * 订单列表 / 优惠券 / 买单 / 预约 页点登录，登完被甩回首页，
   * 之前在干的事全丢了，得自己再点回去。
   *
   * 这些页面都是用 navigateTo 打开登录页的（见 order/list、voucher、pay、
   * booking/create 等），所以页面栈里有上一页，navigateBack 能原样回去。
   * 只有栈深 <= 1（比如用户直接从分享链接进登录页）才回首页兜底。
   */
  backOrHome() {
    const pages = getCurrentPages() || []
    if (pages.length > 1) {
      const prev = pages[pages.length - 2]
      // tabBar 页不能用 navigateBack 之后再刷新数据，这里统一让上一页自己在
      // onShow 里重读 globalData.user（各页已有 onShow → syncUser 的写法）
      wx.navigateBack({ delta: 1 })
      return
    }
    wx.switchTab({ url: '/pages/home/index' })
  },

  onSkip() { this.backOrHome() },

  /**
   * 一键微信登录：openid 优先身份识别
   *  - 普通会员 → 用户端首页 /pages/home/index
   *  - 员工/店长/商家（openid 已绑）→ 商家端首页 /pages/merchant/home/index
   */
  onWxLogin() {
    if (!this.data.agreed) {
      wx.showToast({ title: '请先阅读并勾选协议', icon: 'none' })
      return
    }
    if (this.data.submitting) return
    this.setData({ submitting: true })
    wx.showLoading({ title: '登录中' })

    wx.login({
      success: (res) => {
        if (!res.code) {
          wx.hideLoading()
          this.setData({ submitting: false })
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }
        const appInst0 = getApp() || {}
        const inviteBy0 = (appInst0.globalData && appInst0.globalData.inviteBy) || wx.getStorageSync('inviteBy') || null
        api.login({
          code: res.code,
          appid: APPID,
          inviteBy: inviteBy0
        }).then((data) => {
          wx.hideLoading()
          this.setData({ submitting: false })
          this._handleLoginResult(data)
        }).catch((err) => {
          wx.hideLoading()
          this.setData({ submitting: false })
          const msg = (err && (err.msg || err.errMsg || err.message)) || '登录失败'
          wx.showModal({ title: '登录失败', content: msg, showCancel: false })
        })
      },
      fail: () => {
        wx.hideLoading()
        this.setData({ submitting: false })
        wx.showToast({ title: '微信登录失败', icon: 'none' })
      }
    })
  },

  /**
   * 按身份决定登录后落在哪个首页。
   *
   * <p>为什么必须分流：这里和 pages/merchant/login 调的是同一个
   * /api/merchant/staff/login，而那个端点明确放行「平台/代理商可无员工关联」，
   * 所以平台和代理商账号从会员登录页展开的「账号密码登录」也能登进来。
   * 但 RoleAuthInterceptor 收口后，整片 /api/merchant/staff/** 对 PLATFORM /
   * AGENT 一律 403 —— 无条件 reLaunch 到商家端首页的结果是：首页那两个请求全
   * 被 catch 吞掉，渲染成一屏 0，看着像系统坏了而不是「你不该来这」。
   * pages/merchant/login 早就按 userType 分流到各自的专属首页了，这里漏了。</p>
   */
  _homeUrlByUserType(userType) {
    if (userType === 'platform') return '/pages/platform/home/index'
    if (userType === 'agent') return '/pages/agent/home/index'
    return '/pages/merchant/home/index'
  },

  /**
   * 处理登录结果：按 loginType 分发
   */
  _handleLoginResult(data) {
    if (!data) {
      wx.showModal({ title: '登录失败', content: '后端无响应', showCancel: false })
      return
    }
    const token = data.token || (data.data && data.data.token)
    if (!token) {
      wx.showModal({ title: '登录失败', content: '后端未返回 token', showCancel: false })
      return
    }
    const loginType = data.loginType || (data.data && data.data.loginType) || 'member'
    const isStaff = data.isStaff === true || (data.data && data.data.isStaff === true)
    const hasStaffAccount = pickHasStaffAccount(data)
    const appInst = getApp() || {}
    appInst.globalData = appInst.globalData || {}
    // 写 token 到 storage
    wx.setStorageSync('token', token)
    if (loginType === 'staff') {
      // 员工身份：写 staffUser
      const staffInfo = {
        token: token,
        staffId: data.staffUserId || data.memberId,
        userId: data.staffUserId || data.memberId,
        realName: data.realName || data.nickName,
        nickName: data.nickName,
        avatarUrl: data.avatarUrl,
        phone: data.phone,
        merchantId: data.merchantId,
        storeId: data.storeId,
        storeIds: data.storeIds || [],
        roles: data.roles || [],
        userType: data.userType,
        isOwner: data.isOwner,
        isManagerOrAbove: data.isManagerOrAbove,
        isAgent: data.isAgent,
        staffRole: data.staffRole,
        logged: true
      }
      wx.setStorageSync('staffUser', staffInfo)
      identity.saveStaffSession(token, staffInfo)
      appInst.globalData.staff = staffInfo
      appInst.globalData.user = Object.assign(appInst.globalData.user || {}, {
        memberId: staffInfo.userId,
        token: token,
        nickName: staffInfo.realName,
        avatarUrl: staffInfo.avatarUrl,
        phone: staffInfo.phone,
        logged: true
      })
      wx.showToast({ title: '商家端登录成功', icon: 'success' })
      const dest1 = this._homeUrlByUserType(staffInfo.userType)
      setTimeout(() => wx.reLaunch({ url: dest1 }), 600)
    } else {
      // 会员身份
      const memberId = data.memberId || (data.data && data.data.memberId)
      appInst.globalData.user = Object.assign(appInst.globalData.user || {}, {
        memberId: memberId,
        token: token,
        nickName: data.nickName || '',
        avatarUrl: data.avatarUrl || '',
        phone: data.phone || '',
        logged: true
      })
      // 副身份提醒：hasStaffAccount → 该 openid 绑过员工，首页可显示「切到商家端」并静默免密
      identity.saveMemberToken(token)
      try { wx.setStorageSync('hasStaffAccount', !!hasStaffAccount) } catch (e) {}
      this.setData({ hasStaffAccount: hasStaffAccount })
      wx.showToast({ title: '登录成功', icon: 'success' })
      setTimeout(() => this.backOrHome(), 600)
    }
    appInst.notifyUserUpdate && appInst.notifyUserUpdate()
  },

  /**
   * 账号密码登录：员工/商家（用于没绑 openid 的账号）
   * 成功后路由到 /pages/merchant/home/index
   */
  onAccountLogin() {
    const { username, password, submitting } = this.data
    if (submitting) return
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' })
      return
    }
    this.setData({ submitting: true })
    wx.showLoading({ title: '登录中', mask: true })
    // 静默取 wx code 一并提交：后端若发现该账号未绑微信会自动绑定，
    // 之后这个微信就能免密切换到商家端。拿不到 code 也不阻断登录。
    this._withWxCode((wxCode) => {
      api.merchantStaffLogin({ username, password, code: wxCode, appid: APPID })
      .then((data) => {
        wx.hideLoading()
        this.setData({ submitting: false })
        const token = data && (data.token || (data.data && data.data.token))
        if (!token) {
          wx.showModal({ title: '登录失败', content: '后端未返回 token', showCancel: false })
          return
        }
        // 写 staffUser
        const staffInfo = {
          token: token,
          userId: data.userId,
          realName: data.realName,
          nickName: data.nickName,
          avatarUrl: data.avatarUrl,
          phone: data.phone,
          merchantId: data.merchantId,
          storeId: data.storeId,
          storeIds: data.storeIds || [],
          roles: data.roles || [],
          userType: data.userType,
          isOwner: data.isOwner,
          isManagerOrAbove: data.isManagerOrAbove,
          isAgent: data.isAgent,
          staffRole: data.staffRole,
          logged: true
        }
        wx.setStorageSync('staffUser', staffInfo)
        identity.saveStaffSession(token, staffInfo)
        const appInst = getApp() || {}
        appInst.globalData = appInst.globalData || {}
        appInst.globalData.staff = staffInfo
        const bound = data && data.openidAutoBound
        wx.showToast({ title: bound ? '已绑定微信，下次可免密' : '商家端登录成功', icon: 'success' })
        const dest2 = this._homeUrlByUserType(staffInfo.userType)
        setTimeout(() => wx.reLaunch({ url: dest2 }), 600)
      })
      .catch((err) => {
        wx.hideLoading()
        this.setData({ submitting: false })
        const msg = (err && (err.msg || err.errMsg || err.message)) || '登录失败'
        wx.showModal({ title: '登录失败', content: msg, showCancel: false })
      })
    })
  },

  /** 静默取 wx.login code（失败传空，不阻断主流程）*/
  _withWxCode(next) {
    try {
      wx.login({
        success: (r) => next((r && r.code) || ''),
        fail: () => next('')
      })
    } catch (e) {
      next('')
    }
  }
})
