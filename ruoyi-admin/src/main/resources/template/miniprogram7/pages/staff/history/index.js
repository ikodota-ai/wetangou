const HISTORY_KEY = 'staffVerifyHistory'

Page({
  data: {
    list: [],
    totalCount: 0,
    totalAmount: '0.00',
    storeName: ''
  },

  onShow() {
    this.load()
  },

  load() {
    try {
      const list = wx.getStorageSync(HISTORY_KEY) || []
      const totalCount = list.length
      const totalAmount = list.reduce((s, x) => s + (Number(x.payAmount) || 0), 0)
      const staff = wx.getStorageSync('staffUser') || {}
      this.setData({
        list,
        totalCount,
        totalAmount: totalAmount.toFixed(2),
        storeName: staff.storeName || ('门店' + (staff.storeId || ''))
      })
    } catch (e) {}
  },

  onClear() {
    wx.showModal({
      title: '确认清空',
      content: '清空后只能看到本设备之后新的核销记录',
      success: (res) => {
        if (res.confirm) {
          wx.removeStorageSync(HISTORY_KEY)
          this.load()
        }
      }
    })
  }
})
