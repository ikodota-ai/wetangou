const { request, api } = require('../../../utils/request.js')

Page({
  data: {
    userId: '', userName: '', realName: '', avatar: '',
    storeId: null, storeName: ''
  },
  onShow() { this.load() },
  load() {
    request('/api/store/staff/me')
      .then((res) => {
        const d = res || {}
        this.setData({
          userId: d.userId || '',
          userName: d.userName || '',
          realName: d.realName || '',
          avatar: d.avatar || '',
          storeId: d.storeId || null,
          storeName: d.storeName || ''
        })
      })
      .catch((e) => {
        console.error('[staff me] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
      })
  },
  goHistory() {
    wx.navigateTo({ url: '/pages/staff/history/index' })
  },
  onLogout() {
    wx.showModal({
      title: '退出登录',
      content: '退出后将无法核销 / 确认买单，确定？',
      success: (res) => {
        if (!res.confirm) return
        request('/api/store/staff/logout', { method: 'POST' })
          .catch(() => {})
          .finally(() => {
            const memberToken = wx.getStorageSync('staffTokenBackup')
            if (memberToken) {
              wx.setStorageSync('token', memberToken)
              wx.removeStorageSync('staffTokenBackup')
            } else {
              wx.removeStorageSync('token')
            }
            wx.removeStorageSync('staffUser')
            wx.reLaunch({ url: '/pages/home/index' })
          })
      }
    })
  }
})
