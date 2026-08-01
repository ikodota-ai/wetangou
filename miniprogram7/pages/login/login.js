const app = getApp()

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
        
        wx.request({
          url: app.globalData.baseUrl + '/api/auth/login',
          method: 'POST',
          // 多商户：带上 appid，后端据此确定会员所属商户
          data: { code: res.code, appid: require('../../utils/config.js').APPID },
          success: (resp) => {
            wx.hideLoading()
            if (resp.data.code === 200) {
              const data = resp.data.data || resp.data
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
              app.notifyUserUpdate()
              wx.showToast({ title: '登录成功', icon: 'success' })
              setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 600)
            } else {
              wx.showToast({ title: resp.data.msg || '登录失败', icon: 'none' })
            }
          },
          fail: (err) => {
            wx.hideLoading()
            // mock 兜底
            wx.setStorageSync('token', 'mock-' + Date.now())
            app.globalData.user = {
              ...app.globalData.user,
              memberId: 10001,
              openid: '',
              nickName: '',
              avatarUrl: '',
              phone: '',
              logged: true
            }
            app.notifyUserUpdate()
            wx.showToast({ title: '登录成功', icon: 'success' })
            setTimeout(() => wx.switchTab({ url: '/pages/home/index' }), 600)
          }
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
