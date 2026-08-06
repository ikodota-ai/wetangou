const app = getApp()
const { request } = require('../../../utils/request.js')

Page({
  data: {
    username: '',
    password: '',
    loading: false,
    storeName: '',
    storeId: null
  },

  onUsername(e) {
    this.setData({ username: e.detail.value })
  },

  goBackHome() {
    wx.reLaunch({ url: '/pages/home/index' })
  },
  onPassword(e) {
    this.setData({ password: e.detail.value })
  },

  onLogin() {
    const { username, password } = this.data
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' })
      return
    }
    this.setData({ loading: true })
    // 走 /api/store/staff/login，body 直接传 username/password
    request('/api/store/staff/login', { method: 'POST', data: { username: username.trim(), password } })
      .then((res) => {
        const data = res || {}
        const token = data.token
        if (!token) {
          throw new Error('登录返回无 token')
        }
        // 切换 token：把会员 token 备份到 staffTokenBackup，门店 token 写入 wx.storage
        const memberToken = wx.getStorageSync('token')
        if (memberToken) {
          wx.setStorageSync('staffTokenBackup', memberToken)
        }
        wx.setStorageSync('token', token)
        wx.setStorageSync('staffUser', {
          userType: 'store',
          storeId: data.storeId,
          storeName: data.storeName,
          realName: data.realName,
          token
        })
        this.setData({
          storeId: data.storeId,
          storeName: data.storeName || ('门店' + data.storeId)
        })
        wx.showToast({ title: '登录成功', icon: 'success' })
        setTimeout(() => {
          wx.reLaunch({ url: '/pages/staff/home/index' })
        }, 600)
      })
      .catch((err) => {
        console.error('[staff login] err', err)
        const msg = (err && (err.msg || err.message)) || '登录失败'
        wx.showToast({ title: msg, icon: 'none' })
      })
      .finally(() => {
        this.setData({ loading: false })
      })
  }
})
