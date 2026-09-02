const { api } = require('../../../utils/request.js')

// 状态映射在 js 里算好塞进 list，不放模板。
// 小程序 WXML 只能调 wxs 模块的函数，不能调 Page 的方法 ——
// 模板里写 {{statusText(item.status)}} 恒渲染成空字符串，
// 店员看到的订单状态那一列一直是空白的（同 pages/merchant/bill 已修过的那条）。
const STATUS_TEXT = { '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' }

Page({
  data: { list: [], loaded: false, verifying: false },
  onShow() { this.load() },
  onPullDownRefresh() { this.load().then(() => wx.stopPullDownRefresh()) },
  /**
   * 列表里「待使用」那条右下角的核销按钮。
   *
   * 模板上一直有这个按钮（bindtap="onVerify"），但这个文件里从来没有 onVerify ——
   * 店员在今日订单里看到客人那单是「待使用」，点核销毫无反应，也不报错，
   * 只能退出去改走核销页手抄一遍核销码。这是商家端最高频的动作之一。
   *
   * 同时模板里 data-store="{{storeId}}" 也取不到值（data 里压根没这个字段），
   * 索性不传：门店在员工 token 里，后端已按 token 兜底（见 ApiOrderController.verify）。
   * 传 `storeId || 0` 反而会撞 hasStore(0) 抛「无权操作其他门店」，
   * 核销页那次就是这么踩的。
   */
  onVerify(e) {
    if (this.data.verifying) return
    const ds = (e && e.currentTarget && e.currentTarget.dataset) || {}
    const code = ds.code || ''
    const orderNo = ds.no || ''
    if (!code && !orderNo) {
      wx.showToast({ title: '该订单没有核销码，请到核销页手工处理', icon: 'none' })
      return
    }
    wx.showModal({
      title: '确认核销？',
      content: '核销后订单立即转为已完成，无法撤销。',
      confirmText: '确认核销',
      success: (m) => {
        if (!m.confirm) return
        this.doVerify(code, orderNo)
      }
    })
  },

  // 返回 promise（与 load 同风格）：调用方要能等它跑完，
  // 否则外部拿不到「核销 + 刷新列表」这条链的结束时机
  doVerify(code, orderNo) {
    this.setData({ verifying: true })
    wx.showLoading({ title: '核销中...', mask: true })
    return api.verifyOrder({ verifyCode: code, orderNo: orderNo })
      .then(() => {
        wx.showToast({ title: '核销成功', icon: 'success' })
        // 核销成功后订单状态由 1 变 2，重新拉一次列表，
        // 否则那颗按钮还挂在原处，店员会以为没成功而重复点。
        return this.load()
      })
      .catch((err) => {
        wx.showToast({ title: (err && (err.msg || err.errMsg)) || '核销失败', icon: 'none' })
      })
      .finally(() => {
        wx.hideLoading()
        this.setData({ verifying: false })
      })
  },

  load() {
    return api.merchantStaffTodayOrders()
      .then((res) => {
        const rows = (res && (res.data || res.rows || res)) || []
        const list = (Array.isArray(rows) ? rows : []).map((o) => ({
          ...o,
          createTimeStr: o.createTime ? String(o.createTime).slice(0, 16) : '',
          statusText: STATUS_TEXT[o.status] || o.status
        }))
        this.setData({ list, loaded: true })
      })
      .catch((e) => {
        console.error('[merchant order] err', e)
        wx.showToast({ title: (e && (e.msg || e.message)) || '加载失败', icon: 'none' })
        this.setData({ loaded: true })
      })
  }
})

module.exports = module.exports || {}
module.exports.__test__ = { STATUS_TEXT }
