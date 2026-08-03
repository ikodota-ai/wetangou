const app = getApp()
const { api, APPID } = require('../../utils/request.js')

Page({
  data: {
    agreed: false,
    submitting: false,
    merchantName: ''
  },

  onLoad() {
    // 优先用 app.js bootMerchant 拉到的商家名，没有则回退到一个本地占位
    const appInst = getApp() || {}
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({ merchantName: m.merchantName || '当前商家' })
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
    wx.showLoading({ title: '登录中' })

    wx.login({
      success: (res) => {
        if (!res.code) {
          wx.hideLoading()
          this.setData({ submitting: false })
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }
        // 一次性登录：仅用 wx.login 的 code 换 openid，
        // 昵称/头像/手机号留到「会员资料」页分步完善
        api.login({
          code: res.code,
          appid: APPID
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

  onSkip() { wx.switchTab({ url: '/pages/home/index' }) }
})
