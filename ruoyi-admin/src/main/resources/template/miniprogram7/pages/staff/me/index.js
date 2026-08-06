const { request, api } = require('../../../utils/request.js')

Page({
  data: {
    userId: '', userName: '', realName: '', avatar: '',
    storeId: null, storeName: '',
    storeIds: [],          // 多门店集合（员工可管理范围）
    showStorePicker: false // 切换门店弹窗
  },
  onShow() { this.load() },
  load() {
    request('/api/store/staff/me')
      .then((res) => {
        const d = res || {}
        const storeIds = Array.isArray(d.storeIds) ? d.storeIds : []
        this.setData({
          userId: d.userId || '',
          userName: d.userName || '',
          realName: d.realName || '',
          avatar: d.avatar || '',
          storeId: d.storeId || null,
          storeName: d.storeName || '',
          storeIds: storeIds,
          // 多门店时在 storeName 后追加「切换」
          hasMultiStore: storeIds.length > 1
        })
      })
      .catch((e) => {
        console.error('[staff me] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
      })
  },
  // 多门店员工点击门店行打开切换器
  onStoreTap() {
    if (!this.data.hasMultiStore) return
    this.setData({ showStorePicker: true })
  },
  onStorePickerClose() {
    this.setData({ showStorePicker: false })
  },
  // 选中目标门店 → 调 switch-store
  onPickStore(e) {
    const target = e.currentTarget.dataset.storeid
    if (!target || target === this.data.storeId) {
      this.setData({ showStorePicker: false })
      return
    }
    request('/api/store/staff/switch-store', {
      method: 'POST',
      data: { storeId: target }
    })
      .then((d) => {
        // 后端已刷新 token 缓存；前端重新拉 /me 拿到新 storeName
        this.setData({ showStorePicker: false })
        wx.showToast({ title: '已切换门店', icon: 'success' })
        this.load()
      })
      .catch((err) => {
        wx.showToast({ title: (err && (err.msg || err.message)) || '切换失败', icon: 'none' })
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
