const app = getApp()
const { request, api, APPID } = require('../../../utils/request.js')
const identity = require('../../../utils/identity.js')

/**
 * 商家员工登录页 —— 只负责「已有账号」的账号密码登录。
 *
 * 刻意不提供扫码入职入口：店长在后台生成的是小程序码
 * （page=pages/merchant/scan/index, scene=invite:MID:SID:CODE），
 * 新员工应用微信「扫一扫」或相册长按识别直接拉起小程序落到入职页 ——
 * 此时他还没有账号，先让他面对一个登录页是反直觉的。
 *
 * 原来这里有一份 onScan + acceptInvite 实现，与 pages/merchant/scan 重复，
 * 且 scene 校验更弱（只判前缀，不校验段数/数字/短码长度）、无防重、无确认弹窗，
 * 已删除。入职链路统一走 pages/merchant/scan（复用 utils/inviteScene.js 纯函数）。
 */
Page({
  data: {
    username: '',
    password: '',
    loading: false
  },

  onUsername(e) {
    this.setData({ username: e.detail.value })
  },
  onPassword(e) {
    this.setData({ password: e.detail.value })
  },

  goBackHome() {
    wx.reLaunch({ url: '/pages/home/index' })
  },

  onLogin() {
    const { username, password } = this.data
    if (!username || !password) {
      wx.showToast({ title: '请输入账号和密码', icon: 'none' })
      return
    }
    this.setData({ loading: true })
    // 静默取 wx code 一并提交：后端若发现该账号未绑微信会自动绑定，之后可免密切换
    this._withWxCode((wxCode) => {
      api.merchantStaffLogin({ username: username.trim(), password, code: wxCode, appid: APPID })
      .then((data) => this.handleLoginSuccess(data))
      .catch((err) => {
        console.error('[merchant login] err', err)
        const code = err && (err.code || (err.data && err.data.code))
        const msg = (err && (err.msg || err.message)) || '登录失败'
        // 601：员工关联待审核，toast 放不下这段说明，用模态框
        if (code === 601 || msg.indexOf('待店长审核') > -1) {
          wx.showModal({
            title: '等待店长审核',
            content: '你的入职申请已提交，店长在后台审核通过后即可登录商家版。',
            showCancel: false,
            confirmText: '我知道了'
          })
          return
        }
        wx.showToast({ title: msg, icon: 'none' })
      })
      .finally(() => this.setData({ loading: false }))
    })
  },

  /** 静默取 wx.login code（失败传空，不阻断登录）*/
  _withWxCode(next) {
    try {
      wx.login({ success: (r) => next((r && r.code) || ''), fail: () => next('') })
    } catch (e) { next('') }
  },

  handleLoginSuccess(data) {
    const d = data || {}
    const token = d.token
    if (!token) {
      wx.showToast({ title: '登录返回无 token', icon: 'none' })
      return
    }
    // 备份会员 token（切回会员版要用），再写 staff token
    const memberToken = wx.getStorageSync('token')
    if (memberToken && identity.current() === 'member') {
      wx.setStorageSync(identity.KEY_MEMBER_TOKEN, memberToken)
    }
    wx.setStorageSync('memberTokenBackup', memberToken || '')
    const userType = d.userType || 'staff'
    const roles = d.roles || []
    const staffInfo = {
      userType: userType,
      staffRole: d.staffRole,
      roles: roles,
      isOwner: !!d.isOwner,
      isManagerOrAbove: !!d.isManagerOrAbove,
      isAgent: !!d.isAgent,
      merchantId: d.merchantId,
      storeId: d.storeId,
      // storeIds / stores 必须存：商家端「新建商品 → 适用门店」读的是 staffUser.storeIds。
      // 这里原先只存了单个 storeId，那边取不到 storeIds 就退化成 [storeId] ——
      // 两个后果：① 多店老板只能勾到一家门店；② 更隐蔽的是，storeId 若是上一个
      // 账号残留的旧值（切商户账号时 staffUser 只被覆盖不被清空），提交时就会带上
      // 别家商户的门店，被服务端 assertStoresBelongToMerchant 拦下，
      // 报「门店 X 不属于该商家」—— 而商家看着后台明明是自己的门店，无从下手。
      // 另外三条登录链路（会员授权识别、identity 静默切换、扫码入职）一直都存了
      // storeIds，唯独账号密码登录这条漏了，而这恰恰是老板/店长最常用的入口。
      storeIds: d.storeIds || [],
      stores: d.stores || [],
      storeName: d.storeName,
      realName: d.realName,
      token,
      needBindWx: !!d.needBindWx
    }
    // 写 staff token + 身份信息（identity 内部同时置 token / currentIdentity）
    identity.saveStaffSession(token, staffInfo)
    if (d.openidAutoBound) {
      wx.showToast({ title: '已绑定微信，下次可免密', icon: 'none' })
    }
    // 按身份路由分流
    let homeUrl
    if (userType === 'platform') {
      homeUrl = '/pages/platform/home/index'
    } else if (userType === 'agent') {
      homeUrl = '/pages/agent/home/index'
    } else {
      homeUrl = '/pages/merchant/home/index'
    }
    wx.showToast({ title: '登录成功', icon: 'success' })
    setTimeout(() => {
      wx.reLaunch({ url: homeUrl })
    }, 500)
  }
})
