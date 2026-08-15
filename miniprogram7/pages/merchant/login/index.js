const app = getApp()
const { request, api } = require('../../../utils/request.js')

Page({
  data: {
    username: '',
    password: '',
    loading: false
  },

  onUsername(e) {
    this.setData({ username: e.detail.value })
  },
  onPassword(e) {
    this.setData({ password: e.detail.value })
  },

  goBackHome() {
    wx.reLaunch({ url: '/pages/home/index' })
  },

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
        // 兼容两种格式：
        // 1) scene 字符串：invite:MID:SID:CODE
        // 2) 小程序码 path：pages/merchant/scan/index?scene=invite%3AMID%3ASID%3ACODE
        let scene = raw
        const queryIdx = raw.indexOf('scene=')
        if (raw.indexOf('pages/') === 0 && queryIdx > -1) {
          scene = decodeURIComponent(raw.substring(queryIdx + 6))
        }
        if (scene.indexOf('invite:') !== 0) {
          wx.showToast({ title: '非商家邀请码', icon: 'none' })
          return
        }
        // 进入 accept 流程：拉起 wx.login → 拿 code → 调后端 acceptInvite
        this.acceptInvite(scene)
      },
      fail: (err) => {
        console.warn('[merchant scan] cancel/fail', err)
      }
    })
  },

  acceptInvite(scene) {
    wx.login({
      success: (lr) => {
        if (!lr || !lr.code) {
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }
        wx.showLoading({ title: '加入中...', mask: true })
        // 读取用户资料（头像/昵称）作为新建账号初始信息
        const profile = wx.getStorageSync('memberProfile') || {}
        api.merchantStaffAcceptInvite({
          code: lr.code,
          scene: scene,
          nickName: profile.nickName || '',
          avatarUrl: profile.avatarUrl || ''
        }).then((data) => {
          wx.hideLoading()
          this.handleLoginSuccess(data)
        }).catch((err) => {
          wx.hideLoading()
          console.error('[merchant accept] err', err)
          wx.showToast({ title: (err && (err.msg || err.message)) || '加入失败', icon: 'none' })
        })
      },
      fail: () => wx.showToast({ title: '微信授权失败', icon: 'none' })
    })
  },

  onLogin() {
    const { username, password } = this.data
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' })
      return
    }
    this.setData({ loading: true })
    api.merchantStaffLogin({ username: username.trim(), password })
      .then((data) => this.handleLoginSuccess(data))
      .catch((err) => {
        console.error('[merchant login] err', err)
        const msg = (err && (err.msg || err.message)) || '登录失败'
        wx.showToast({ title: msg, icon: 'none' })
      })
      .finally(() => this.setData({ loading: false }))
  },

  handleLoginSuccess(data) {
    const d = data || {}
    const token = d.token
    if (!token) {
      wx.showToast({ title: '登录返回无 token', icon: 'none' })
      return
    }
    // 备份会员 token，登录后写 staff token
    const memberToken = wx.getStorageSync('token')
    if (memberToken) wx.setStorageSync('memberTokenBackup', memberToken)
    wx.setStorageSync('token', token)
    const userType = d.userType || 'staff'
    const roles = d.roles || []
    wx.setStorageSync('staffUser', {
      userType: userType,
      staffRole: d.staffRole,
      roles: roles,
      isOwner: !!d.isOwner,
      isManagerOrAbove: !!d.isManagerOrAbove,
      isAgent: !!d.isAgent,
      merchantId: d.merchantId,
      storeId: d.storeId,
      storeName: d.storeName,
      realName: d.realName,
      token,
      needBindWx: !!d.needBindWx
    })
    // 按身份路由分流
    let homeUrl
    if (userType === 'platform') {
      homeUrl = '/pages/platform/home/index'
    } else if (userType === 'agent') {
      homeUrl = '/pages/agent/home/index'
    } else {
      homeUrl = '/pages/merchant/home/index'
    }
    wx.showToast({ title: '登录成功', icon: 'success' })
    setTimeout(() => {
      wx.reLaunch({ url: homeUrl })
    }, 500)
  }
})
