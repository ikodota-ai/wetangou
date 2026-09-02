const app = getApp()
const { api } = require('../../../utils/request.js')

// 首页「最近订单」的状态文案。必须在 js 里映射好塞进 recentOrders，
// 不能在 WXML 里调 Page 方法 —— 小程序模板只认 wxs 模块的函数，
// {{orderStatusText(item.status)}} 恒渲染成空，首页最近订单那一列一直空白。
const ORDER_STATUS_TEXT = { '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' }
const role = require('../../../utils/role.js')
const identity = require('../../../utils/identity.js')

Page({
  data: {
    storeId: null,
    storeName: '',
    realName: '',
    merchantId: null,
    stores: [],
    canSwitchStore: false,
    noStore: false,
    noStoreTip: '',
    needBindWx: false,
    todayVerifyCount: 0,
    todayVerifyAmount: '0.00',
    todayOrderCount: 0,
    pendingBillCount: 0,
    todayBookingCount: 0,
    recentOrders: [],
    showGmv: false,
    showCreateProduct: false,
    showTeam: false,
    pendingStaffCount: 0,
    showBill: true,
    isStaffOnly: false
  },

  onShow() {
    this.syncStaff()
    this.loadHome()
    if (getApp() && getApp().consumeVerifyScene) getApp().consumeVerifyScene()
  },

  onPullDownRefresh() {
    this.loadHome().then(() => wx.stopPullDownRefresh()).catch(() => wx.stopPullDownRefresh())
  },

  syncStaff() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      wx.redirectTo({ url: '/pages/login/login?showMore=1' })
      return
    }
    const stores = staff.stores || []
    this.setData({
      storeId: staff.storeId,
      storeName: staff.storeName || ('门店' + staff.storeId),
      realName: staff.realName || '',
      merchantId: staff.merchantId,
      stores: stores,
      canSwitchStore: stores.length > 1,
      needBindWx: !!staff.needBindWx,
      showGmv: role.isManagerOrAbove(),
      showCreateProduct: role.isManagerOrAbove(),
      showBill: role.isManagerOrAbove(),
      // 不能用 isManagerOrAbove()：它含 PLATFORM，而平台账号已被后端禁入商家端，
      // 用它控制入口会给平台账号显示一个点进去必然 403 的按钮
      showTeam: role.canManageStaff(),
      isStaffOnly: role.isStaff() && !role.isManager() && !role.isOwner()
    })
  },

  loadHome() {
    return Promise.all([api.merchantStaffMe().catch(() => null), api.merchantStaffHome().catch(() => null)])
      .then(([me, home]) => {
        if (me) {
          const staff = wx.getStorageSync('staffUser') || {}
          staff.storeId = me.storeId || staff.storeId
          staff.storeName = me.storeName || staff.storeName
          staff.realName = me.realName || staff.realName
          staff.merchantId = me.merchantId || staff.merchantId
          staff.needBindWx = !me.openidBound
          // stores 只有 /me 返，缓存起来给切店选择器用（老板 store_id=0 已在后端展开成真实门店）
          if (me.stores && me.stores.length) staff.stores = me.stores
          // 当前门店名以 storeId 为准取，不能取 stores[0]，否则切店后名字不跟着变
          const cur = (staff.stores || []).filter(x => x.storeId === staff.storeId)[0]
          if (cur) staff.storeName = cur.storeName
          wx.setStorageSync('staffUser', staff)
        }
        const d = home || {}
        this.setData({
          storeId: d.storeId || this.data.storeId,
          storeName: d.storeName || this.data.storeName,
          realName: (me && (me.realName || me.nickName)) || this.data.realName,
          needBindWx: me ? !me.openidBound : this.data.needBindWx,
          todayVerifyCount: d.todayVerifyCount || 0,
          todayVerifyAmount: (d.todayVerifyAmount || 0).toString(),
          todayOrderCount: d.todayOrderCount || 0,
          pendingBillCount: d.pendingBillCount || 0,
          todayBookingCount: d.todayBookingCount || 0,
          recentOrders: (d.recentOrders || []).map(o => Object.assign({}, o, {
            statusText: ORDER_STATUS_TEXT[o.status] || o.status
          })),
          // 商户还没建门店：后端返 noStore=true + 引导文案，首页显示提示而不是一屏 0
          noStore: !!d.noStore,
          noStoreTip: d.noStoreTip || '',
          stores: (me && me.stores && me.stores.length) ? me.stores : this.data.stores,
          canSwitchStore: ((me && me.stores) || this.data.stores || []).length > 1,
          showGmv: role.isManagerOrAbove(),
          showCreateProduct: role.isManagerOrAbove(),
          showBill: role.isManagerOrAbove(),
          showTeam: role.canManageStaff(),
          isStaffOnly: role.isStaff() && !role.isManager() && !role.isOwner()
        })
        // 待审核角标：让店长一进首页就知道有人在等入职，不必主动点进去翻
        if (role.canManageStaff()) this.loadPendingStaff()
      })
  },

  /** 待审核入职数量（失败静默：这只是个角标，不该拖垮首页） */
  loadPendingStaff() {
    return api.merchantStaffAuditList()
      .then((res) => {
        const list = (res && res.data) || res || []
        this.setData({ pendingStaffCount: (list && list.length) || 0 })
      })
      .catch(() => {})
  },

  /**
   * 切换当前门店。
   *
   * 商家端此前没有任何全局切店入口：老板/多店店员登录后只能操作 storeIds[0]，
   * 其余门店的订单、买单、预约、核销全都看不到也管不了。
   */
  onSwitchStore() {
    const stores = this.data.stores || []
    if (stores.length < 2) return
    wx.showActionSheet({
      itemList: stores.map(s => (s.storeId === this.data.storeId ? '✓ ' : '') + s.storeName),
      success: (res) => {
        const target = stores[res.tapIndex]
        if (!target || target.storeId === this.data.storeId) return
        wx.showLoading({ title: '切换中', mask: true })
        api.merchantStaffSwitchStore(target.storeId).then((d) => {
          const staff = wx.getStorageSync('staffUser') || {}
          staff.storeId = target.storeId
          staff.storeName = (d && d.storeName) || target.storeName
          wx.setStorageSync('staffUser', staff)
          this.setData({ storeId: staff.storeId, storeName: staff.storeName })
          return this.loadHome()
        }).then(() => {
          wx.hideLoading()
          wx.showToast({ title: '已切换门店', icon: 'success' })
        }).catch((err) => {
          wx.hideLoading()
          wx.showToast({ title: (err && err.msg) || '切换失败', icon: 'none' })
        })
      }
    })
  },

  goVerify() { wx.navigateTo({ url: '/pages/merchant/verify/index' }) },
  goBill()   { wx.navigateTo({ url: '/pages/merchant/bill/index' }) },
  goBooking(){ wx.navigateTo({ url: '/pages/merchant/booking/index' }) },
  goCreateProduct() {
    wx.navigateTo({ url: '/pages/merchant/product/create/index' })
  },
  /** 商品管理：列表页才有上下架按钮，建品也从列表页底部进 */
  goProductList() {
    wx.navigateTo({ url: '/pages/merchant/product/list/index' })
  },

  goOrders() { wx.navigateTo({ url: '/pages/merchant/order/index' }) },
  goHistory(){ wx.navigateTo({ url: '/pages/merchant/history/index' }) },
  goTeam()   { wx.navigateTo({ url: '/pages/merchant/team/index' }) },
  goMe()     { wx.navigateTo({ url: '/pages/merchant/me/index' }) },
  /**
   * 切回会员版。
   *
   * 保留商家会话（不删 staffUser / staffToken），这样从「我的」再切回来是零请求。
   * 只有真正「退出商家账号」时才清 —— 那是另一个动作。
   */
  goSwitchAccount() {
    const r = identity.switchToMember()
    if (r.ok) {
      wx.reLaunch({ url: '/pages/home/index' })
      return
    }
    // 没有会员登录态（例如直接用账号密码进的商家端）→ 引导去会员登录
    wx.showModal({
      title: '尚未登录会员',
      content: '当前微信还没有会员登录记录，去用微信登录一次即可在两端来回切换。',
      confirmText: '去登录',
      success: (m) => {
        if (m.confirm) wx.reLaunch({ url: '/pages/login/login' })
      }
    })
  },

  /** 退出商家账号：清商家会话，回到会员版（会员登录态保留）*/
  onLogoutStaff() {
    wx.showModal({
      title: '退出商家账号',
      content: '退出后需重新登录才能进入商家版，会员身份不受影响。',
      success: (m) => {
        if (!m.confirm) return
        identity.clearStaff()
        wx.reLaunch({ url: '/pages/home/index' })
      }
    })
  }
})
