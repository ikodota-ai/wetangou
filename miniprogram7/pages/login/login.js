const app = getApp()
const { api, APPID } = require('../../utils/request.js')

Page({
  data: {
    activeTab: 'wx',      // wx | account | scan
    agreed: false,
    submitting: false,
    merchantName: '',
    username: '',
    password: ''
  },

  onLoad(query) {
    const appInst = getApp() || {}
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    // 支持 ?tab=account|scan|wx 直接打开对应 tab
    const t = query && query.tab
    const activeTab = (t === 'account' || t === 'scan' || t === 'wx') ? t : 'wx'
    this.setData({ merchantName: m.merchantName || '当前商家', activeTab: activeTab })
  },

  onShow() {
    // 处理从扫码加入回来后可能需要的提示
  },

  onSwitchTab(e) {
    const tab = e.currentTarget.dataset.tab
    this.setData({ activeTab: tab, submitting: false })
  },

  onUsername(e) { this.setData({ username: e.detail.value }) },
  onPassword(e) { this.setData({ password: e.detail.value }) },

  toggleAgree() { this.setData({ agreed: !this.data.agreed }) },

  goAgreement(e) {
    const type = e.currentTarget.dataset.type
    wx.navigateTo({ url: `/pages/agreement/${type}/index` })
  },

  onSkip() { wx.switchTab({ url: '/pages/home/index' }) },

  /**
   * 提交登录：按 activeTab 分发
   *  - wx     → 微信一键登录（消费者）
   *  - account → 账号密码登录（员工/商家）
   *  - scan   → 扫一扫（员工邀请码），onScan 自处理
   */
  onSubmit() {
    if (this.data.activeTab === 'wx') {
      return this._doWxLogin()
    }
    if (this.data.activeTab === 'account') {
      return this._doAccountLogin()
    }
  },

  /**
   * 微信一键登录：原会员登录流程
   */
  _doWxLogin() {
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
          const token = data && (data.token || (data.data && data.data.token))
          const memberId = data && (data.memberId || (data.data && data.data.memberId))
          if (!token) {
            wx.showModal({ title: '登录失败', content: '后端未返回 token', showCancel: false })
            return
          }
          wx.setStorageSync('token', token)
          const appInst = getApp() || {}
          appInst.globalData = appInst.globalData || {}
          appInst.globalData.user = Object.assign(appInst.globalData.user || {}, {
            memberId: memberId,
            token: token,
            nickName: (data.nickName) || (data.data && data.data.nickName) || '',
            avatarUrl: (data.avatarUrl) || (data.data && data.data.avatarUrl) || '',
            phone: '',
            logged: true
          })
          appInst.notifyUserUpdate && appInst.notifyUserUpdate()
          wx.showToast({ title: '登录成功', icon: 'success' })
          setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 600)
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
   * 账号密码登录：员工/商家
   * 成功后路由到 /pages/merchant/home/index
   */
  _doAccountLogin() {
    const { username, password, submitting } = this.data
    if (submitting) return
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' })
      return
    }
    this.setData({ submitting: true })
    wx.showLoading({ title: '登录中', mask: true })
    api.merchantStaffLogin({ username, password })
      .then((data) => {
        wx.hideLoading()
        this.setData({ submitting: false })
        const token = data && (data.token || (data.data && data.data.token))
        const staff = data && (data.staff || (data.data && data.data.staff)) || (data && data.data)
        if (!token) {
          wx.showModal({ title: '登录失败', content: '后端未返回 token', showCancel: false })
          return
        }
        // 写 token 到 storage（与会员 token 共享 storage key，靠 userType 区分）
        wx.setStorageSync('staffToken', token)
        wx.setStorageSync('staffInfo', staff)
        const appInst = getApp() || {}
        appInst.globalData = appInst.globalData || {}
        appInst.globalData.staff = Object.assign(appInst.globalData.staff || {}, {
          token: token,
          staffId: staff && (staff.staffId || staff.userId),
          realName: staff && (staff.realName || staff.nickName || staff.username),
          merchantId: staff && staff.merchantId,
          storeId: staff && staff.storeId,
          storeName: staff && staff.storeName,
          roles: staff && staff.roles,
          logged: true
        })
        wx.showToast({ title: '登录成功', icon: 'success' })
        setTimeout(() => {
          wx.reLaunch({ url: '/pages/merchant/home/index' })
        }, 600)
      })
      .catch((err) => {
        wx.hideLoading()
        this.setData({ submitting: false })
        const msg = (err && (err.msg || err.errMsg || err.message)) || '登录失败'
        wx.showModal({ title: '登录失败', content: msg, showCancel: false })
      })
  },

  /**
   * 扫码加入：扫员工邀请码
   * 兼容两种格式：
   *  1) scene 字符串：invite:MID:SID:CODE
   *  2) 小程序码 path：pages/merchant/scan/index?scene=invite%3A...
   */
  onScan() {
    wx.scanCode({
      onlyFromCamera: false,
      scanType: ['qrCode'],
      success: (res) => {
        const raw = (res && (res.result || res.path)) || ''
        if (!raw) {
          wx.showToast({ title: '未识别到内容', icon: 'none' })
          return
        }
        let scene = raw
        const queryIdx = raw.indexOf('scene=')
        if (raw.indexOf('pages/') === 0 && queryIdx > -1) {
          scene = decodeURIComponent(raw.substring(queryIdx + 6))
        }
        if (scene.indexOf('invite:') !== 0) {
          wx.showToast({ title: '非商家邀请码', icon: 'none' })
          return
        }
        this._acceptInvite(scene)
      },
      fail: (err) => {
        console.warn('[login] scan cancel/fail', err)
      }
    })
  },

  _acceptInvite(scene) {
    wx.login({
      success: (lr) => {
        if (!lr || !lr.code) {
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }
        wx.showLoading({ title: '加入中...', mask: true })
        api.merchantStaffAcceptInvite({ code: lr.code, appid: APPID, scene: scene })
          .then((data) => {
            wx.hideLoading()
            const token = data && (data.token || (data.data && data.data.token))
            if (!token) {
              wx.showModal({ title: '加入失败', content: '未返回 token', showCancel: false })
              return
            }
            wx.setStorageSync('staffToken', token)
            wx.showToast({ title: '已加入商家', icon: 'success' })
            setTimeout(() => {
              wx.reLaunch({ url: '/pages/merchant/home/index' })
            }, 600)
          })
          .catch((err) => {
            wx.hideLoading()
            const msg = (err && (err.msg || err.errMsg || err.message)) || '加入失败'
            wx.showModal({ title: '加入失败', content: msg, showCancel: false })
          })
      }
    })
  }
})
