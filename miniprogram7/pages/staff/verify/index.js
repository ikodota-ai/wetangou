const app = getApp()
const { request } = require('../../../utils/request.js')

const HISTORY_KEY = 'staffVerifyHistory'

Page({
  data: {
    storeId: null,
    storeName: '',
    realName: '',
    verifyCode: '',
    orderNo: '',
    submitting: false,
    history: []
  },

  onLoad() {
    this.syncStaff()
  },

  onShow() {
    this.syncStaff()
    this.loadHistory()
  },

  onPullDownRefresh() {
    this.syncStaff()
    this.loadHistory()
    wx.stopPullDownRefresh()
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || staff.userType !== 'store' || !token) {
      // 没登录态：跳回登录
      wx.redirectTo({ url: '/pages/login/login?showMore=1' })
      return
    }
    this.setData({
      storeId: staff.storeId,
      storeName: staff.storeName || ('门店' + staff.storeId),
      realName: staff.realName || ''
    })
  },

  loadHistory() {
    try {
      const list = wx.getStorageSync(HISTORY_KEY) || []
      // 只保留前 10 条
      this.setData({ history: list.slice(0, 10) })
    } catch (e) {}
  },

  saveHistory(item) {
    try {
      const list = wx.getStorageSync(HISTORY_KEY) || []
      // 去重（orderId 相同则提到最前）
      const filtered = list.filter((x) => x.orderId !== item.orderId)
      filtered.unshift(item)
      wx.setStorageSync(HISTORY_KEY, filtered.slice(0, 20))
      this.setData({ history: filtered.slice(0, 10) })
    } catch (e) {}
  },

  onCode(e) { this.setData({ verifyCode: e.detail.value }) },
  onOrderNo(e) { this.setData({ orderNo: e.detail.value }) },

  onScan() {
    // 仅当用户已配置 wx.scanCode 时才允许扫码
    if (!wx.scanCode) {
      wx.showToast({ title: '当前客户端不支持扫码', icon: 'none' })
      return
    }
    wx.scanCode({
      onlyFromCamera: false,
      scanType: ['qrCode', 'barCode'],
      success: (res) => {
        const txt = (res && res.result) || ''
        if (!txt) return
        // 12 位纯字母数字视为核销码
        const clean = txt.trim()
        if (/^[A-Z0-9]{8,32}$/i.test(clean)) {
          this.setData({ verifyCode: clean.toUpperCase() })
        } else {
          this.setData({ orderNo: clean })
        }
      },
      fail: () => {}
    })
  },

  onRepeat(e) {
    const idx = e.currentTarget.dataset.idx
    const item = (this.data.history || [])[idx]
    if (!item) return
    this.setData({
      verifyCode: item.verifyCode || '',
      orderNo: item.orderNo || ''
    })
  },

  onSubmit() {
    const code = (this.data.verifyCode || '').trim()
    const no = (this.data.orderNo || '').trim()
    if (!code && !no) {
      wx.showToast({ title: '请填写核销码或订单编号', icon: 'none' })
      return
    }
    const payload = { storeId: this.data.storeId }
    if (code) payload.verifyCode = code
    if (no) payload.orderNo = no

    this.setData({ submitting: true })
    request('/api/order/verify', { method: 'POST', data: payload })
      .then((res) => {
        const o = res || {}
        wx.showToast({ title: '核销成功', icon: 'success' })
        this.saveHistory({
          orderId: o.orderId,
          orderNo: o.orderNo,
          productName: o.productName,
          payAmount: o.payAmount,
          verifyCode: o.verifyCode,
          verifyTimeStr: o.verifyTime ? String(o.verifyTime).slice(0, 16) : ''
        })
        this.setData({ verifyCode: '', orderNo: '' })
      })
      .catch((err) => {
        const msg = (err && (err.msg || err.message)) || '核销失败'
        wx.showToast({ title: msg, icon: 'none' })
      })
      .finally(() => {
        this.setData({ submitting: false })
      })
  },

  goHistory() {
    wx.navigateTo({ url: '/pages/staff/history/index' })
  },

  goSwitchAccount() {
    wx.showModal({
      title: '切换回会员',
      content: '退出员工工作台，回到 C 端会员身份？',
      success: (res) => {
        if (!res.confirm) return
        const memberToken = wx.getStorageSync('staffTokenBackup')
        if (memberToken) {
          // 之前是会员 → 恢复会员 token
          wx.setStorageSync('token', memberToken)
          wx.removeStorageSync('staffTokenBackup')
        } else {
          // 之前没登录过会员 → 彻底清空 token，让前端用匿名浏览
          wx.removeStorageSync('token')
        }
        wx.removeStorageSync('staffUser')
        // 直接 reLaunch 到 C 端首页（小程序重启），清空栈
        wx.reLaunch({ url: '/pages/home/index' })
      }
    })
  }
})
