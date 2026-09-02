const { api } = require('../../../utils/request.js')

Page({
  data: {
    userId: '',
    realName: '',
    storeName: '',
    role: '',
    openid: '',
    openidBound: false,
    showTeam: false
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
          // 取当前 storeId 对应的门店名：多店员工切店后取 stores[0] 会一直显示第一个店
          storeName: this.pickStoreName(data),
          role: data.role || '员工',
          openid: data.openid || '',
          openidBound: !!data.openidBound,
          // 用 /me 返的 role 判，而不是本地缓存的 roles：换账号登录时缓存可能还是上一个人的。
          // 平台账号不在此列 —— 后端已禁止平台访问整片商家端。
          showTeam: data.role === 'OWNER' || data.role === 'MANAGER'
        })
      })
      .catch((err) => {
        if (err && err.code === 401) {
          wx.redirectTo({ url: '/pages/login/login?showMore=1' })
        } else {
          console.warn('[merchant me] err', err)
        }
      })
  },

  pickStoreName(data) {
    const stores = (data && data.stores) || []
    const cur = stores.filter(x => x.storeId === data.storeId)[0]
    if (cur) return cur.storeName
    return data && data.storeId ? ('门店' + data.storeId) : ''
  },

  goTeam() {
    wx.navigateTo({ url: '/pages/merchant/team/index' })
  },
  /** 商品管理（与首页同一个入口，店长在「我的」里也找得到） */
  goProductList() {
    wx.navigateTo({ url: '/pages/merchant/product/list/index' })
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
            try { getApp().logout() } catch (e) { console.warn('[me] logout fail', e) }
            wx.reLaunch({ url: '/pages/login/login?showMore=1' })
          })
      }
    })
  }
})
