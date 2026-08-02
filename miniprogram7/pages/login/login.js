const app = getApp()
const { api } = require('../../utils/request.js')

Page({
  data: {
    agreed: false
  },

  toggleAgree() {
    this.setData({ agreed: !this.data.agreed })
  },

  goAgreement(e) {
    const type = e.currentTarget.dataset.type
    wx.navigateTo({ url: `/pages/agreement/${type}/index` })
  },

  onLogin() {
    if (!this.data.agreed) {
      wx.showToast({ title: '请先阅读并勾选协议', icon: 'none' })
      return
    }

    wx.showLoading({ title: '登录中' })

    wx.login({
      success: (res) => {
        if (!res.code) {
          wx.hideLoading()
          wx.showToast({ title: '微信登录失败', icon: 'none' })
          return
        }

        // 调后端登录（只传 code，不强制头像昵称）
        app.globalData.user.wxCode = res.code

        // 走统一的 api.login()，BASE_URL / X-App-Id 都在 utils/request.js 里集中管理
        api.login({ code: res.code, appid: require('../../utils/config.js').APPID })
          .then((data) => {
            wx.hideLoading()
            wx.setStorageSync('token', data.token)
            app.globalData.user = {
              ...app.globalData.user,
              memberId: data.memberId,
              openid: data.openid,
              nickName: data.nickName || '',
              avatarUrl: data.avatarUrl || '',
              phone: data.phone || '',
              logged: true
            }
            app.notifyUserUpdate && app.notifyUserUpdate()
            wx.showToast({ title: '登录成功', icon: 'success' })
            setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 600)
          })
          .catch((err) => {
            wx.hideLoading()
            const msg = (err && (err.msg || err.errMsg || err.message)) || '登录失败'
            wx.showToast({ title: msg, icon: 'none' })
          })
      },
      fail: () => {
        wx.hideLoading()
        wx.showToast({ title: '微信登录失败', icon: 'none' })
      }
    })
  },

  onSkip() {
    wx.switchTab({ url: '/pages/home/index' })
  }
})
