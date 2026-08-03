const app = getApp()
const { api, BASE_URL, APPID } = require('../../utils/request.js')

Page({
  data: {
    agreed: false,
    submitting: false,
    // 3 步授权态：nick → avatar → phone
    showNickModal: false,
    showAvatarModal: false,
    showPhoneModal: false,
    nickInput: '',
    avatarUrl: '',
    loginCode: ''
  },

  toggleAgree() { this.setData({ agreed: !this.data.agreed }) },

  goAgreement(e) {
    const type = e.currentTarget.dataset.type
    wx.navigateTo({ url: `/pages/agreement/${type}/index` })
  },

  onLogin() {
    if (!this.data.agreed) {
      wx.showToast({ title: '请先阅读并勾选协议', icon: 'none' })
      return
    }
    if (this.data.submitting) return
    this.setData({ submitting: true })
    // 第 1 步：wx.login 拿 jscode，后端用它换 openid
    wx.login({
      success: (res) => {
        if (!res.code) {
          this.setData({ submitting: false })
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }
        this.setData({ loginCode: res.code, showNickModal: true, submitting: false })
      },
      fail: () => {
        this.setData({ submitting: false })
        wx.showToast({ title: '微信登录失败', icon: 'none' })
      }
    })
  },

  onSkip() { wx.switchTab({ url: '/pages/home/index' }) },

  // 昵称弹窗
  onNickInput(e) { this.setData({ nickInput: e.detail.value }) },
  hideNickModal() { this.setData({ showNickModal: false }) },
  onConfirmNick() {
    if (!this.data.nickInput || !this.data.nickInput.trim()) {
      wx.showToast({ title: '请输入昵称', icon: 'none' })
      return
    }
    this.setData({
      nickInput: this.data.nickInput.trim(),
      showNickModal: false,
      showAvatarModal: true
    })
  },

  // 头像弹窗
  hideAvatarModal() { this.setData({ showAvatarModal: false }) },
  onChooseAvatar(e) {
    const url = e.detail.avatarUrl
    if (url) {
      this.setData({ avatarUrl: url, showAvatarModal: false, showPhoneModal: true })
    }
  },

  // 手机号弹窗
  hidePhoneModal() { this.setData({ showPhoneModal: false }) },
  onGetPhoneNumber(e) {
    if (e.detail.errMsg !== 'getPhoneNumber:ok') {
      wx.showModal({ title: '未授权', content: e.detail.errMsg || '用户取消授权', showCancel: false })
      return
    }
    if (!e.detail.code) {
      wx.showModal({ title: '授权失败', content: '微信未返回 code', showCancel: false })
      return
    }
    // 第 4 步：一次性把 4 个信息（code/昵称/头像/手机号 code）提交后端
    this.submitAll(e.detail.code)
  },

  // 一次性把 4 件套提交给 /api/auth/login
  submitAll(phoneCode) {
    this.setData({ showPhoneModal: false, submitting: true })
    wx.showLoading({ title: '绑定中', mask: true })
    // 注意：后端 login 接口目前只收 code / nickName / avatarUrl / appid
    // 手机号通过单独的 /api/member/phone 拿 code 换号（必须登录后）
    // 所以流程是：先 login 拿到 token → 再用 token 调 /api/member/phone 拿手机号
    api.login({
      code: this.data.loginCode,
      nickName: this.data.nickInput,
      avatarUrl: this.data.avatarUrl,
      appid: APPID
    }).then((data) => {
      wx.hideLoading()
      const token = data && (data.token || (data.data && data.data.token))
      const memberId = data && (data.memberId || (data.data && data.data.memberId))
      if (!token) {
        this.setData({ submitting: false })
        wx.showModal({ title: '登录失败', content: '后端未返回 token', showCancel: false })
        return
      }
      // 同步给全局
      wx.setStorageSync('token', token)
      const appInst = getApp() || {}
      appInst.globalData = appInst.globalData || {}
      appInst.globalData.user = appInst.globalData.user || {}
      Object.assign(appInst.globalData.user, {
        memberId: memberId,
        token: token,
        nickName: this.data.nickInput,
        avatarUrl: this.data.avatarUrl,
        logged: true
      })
      // 上传头像到后端（异步，不阻塞）
      if (this.data.avatarUrl && this.data.avatarUrl.startsWith('http://tmp/')) {
        api.uploadAvatar(this.data.avatarUrl).then((res) => {
          const url = res && (res.imgUrl || res.url)
          if (url) {
            const inst = getApp() || {}
            inst.globalData = inst.globalData || {}
            inst.globalData.user = inst.globalData.user || {}
            inst.globalData.user.avatarUrl = url
          }
        }).catch(() => {})
      }
      // 调 /api/member/phone 绑定手机号
      api.updatePhone({ code: phoneCode }).then((res) => {
        const phone = res && (res.phone || (res.data && res.data.phone))
        if (phone) {
          const inst = getApp() || {}
          inst.globalData = inst.globalData || {}
          inst.globalData.user = inst.globalData.user || {}
          inst.globalData.user.phone = phone
        }
      }).catch((err) => {
        console.warn('[login] phone bind failed:', err)
      }).finally(() => {
        this.setData({ submitting: false })
        wx.showToast({ title: '登录成功', icon: 'success' })
        setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 600)
      })
    }).catch((err) => {
      wx.hideLoading()
      this.setData({ submitting: false })
      const msg = (err && (err.msg || err.errMsg || err.message)) || '登录失败'
      wx.showModal({ title: '登录失败', content: msg, showCancel: false })
    })
  }
})
