const { api } = require('../../../utils/request.js')

Page({
  data: {
    userId: '',
    realName: '',
    storeName: '',
    role: '',
    openid: '',
    openidBound: false
  },

  onShow() {
    this.loadMe()
  },

  loadMe() {
    return api.merchantStaffMe()
      .then((d) => {
        const data = d || {}
        this.setData({
          userId: data.userId,
          realName: data.realName || data.nickName || '',
          storeName: (data.stores && data.stores[0] && data.stores[0].storeName) || ('门店' + data.storeId),
          role: data.role || '员工',
          openid: data.openid || '',
          openidBound: !!data.openidBound
        })
      })
      .catch((err) => {
        if (err && err.code === 401) {
          wx.redirectTo({ url: '/pages/login/login?tab=account' })
        } else {
          console.warn('[merchant me] err', err)
        }
      })
  },

  goProfile() {
    wx.navigateTo({ url: '/pages/merchant/profile/index' })
  },

  goBindWx() {
    wx.showModal({
      title: '绑定微信',
      content: '需要重新登录以完成微信绑定（暂未实现快捷绑定流程）',
      showCancel: false
    })
  },

  onLogout() {
    wx.showModal({
      title: '确认退出？',
      success: (r) => {
        if (!r.confirm) return
        api.merchantStaffLogout()
          .catch(() => {})
          .finally(() => {
            wx.removeStorageSync('staffUser')
            const backup = wx.getStorageSync('memberTokenBackup')
            if (backup) wx.setStorageSync('token', backup)
            wx.reLaunch({ url: '/pages/login/login?tab=account' })
          })
      }
    })
  }
})
