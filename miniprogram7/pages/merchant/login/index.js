const app = getApp()
const { request, api, APPID } = require('../../../utils/request.js')
const identity = require('../../../utils/identity.js')

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
    // 静默取 wx code 一并提交：后端若发现该账号未绑微信会自动绑定，之后可免密切换
    this._withWxCode((wxCode) => {
      api.merchantStaffLogin({ username: username.trim(), password, code: wxCode, appid: APPID })
      .then((data) => this.handleLoginSuccess(data))
      .catch((err) => {
        console.error('[merchant login] err', err)
        const code = err && (err.code || (err.data && err.data.code))
        const msg = (err && (err.msg || err.message)) || '登录失败'
        // 601：员工关联待审核，toast 放不下这段说明，用模态框
        if (code === 601 || msg.indexOf('待店长审核') > -1) {
          wx.showModal({
            title: '等待店长审核',
            content: '你的入职申请已提交，店长在后台审核通过后即可登录商家版。',
            showCancel: false,
            confirmText: '我知道了'
          })
          return
        }
        wx.showToast({ title: msg, icon: 'none' })
      })
      .finally(() => this.setData({ loading: false }))
    })
  },

  /** 静默取 wx.login code（失败传空，不阻断登录）*/
  _withWxCode(next) {
    try {
      wx.login({ success: (r) => next((r && r.code) || ''), fail: () => next('') })
    } catch (e) { next('') }
  },

  handleLoginSuccess(data) {
    const d = data || {}
    const token = d.token
    if (!token) {
      wx.showToast({ title: '登录返回无 token', icon: 'none' })
      return
    }
    // 备份会员 token（切回会员版要用），再写 staff token
    const memberToken = wx.getStorageSync('token')
    if (memberToken && identity.current() === 'member') {
      wx.setStorageSync(identity.KEY_MEMBER_TOKEN, memberToken)
    }
    wx.setStorageSync('memberTokenBackup', memberToken || '')
    const userType = d.userType || 'staff'
    const roles = d.roles || []
    const staffInfo = {
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
    }
    // 写 staff token + 身份信息（identity 内部同时置 token / currentIdentity）
    identity.saveStaffSession(token, staffInfo)
    if (d.openidAutoBound) {
      wx.showToast({ title: '已绑定微信，下次可免密', icon: 'none' })
    }
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
