const { api } = require('../../../utils/request.js')
const identity = require('../../../utils/identity.js')
const HISTORY_KEY = 'merchantVerifyHistory'

Page({
  data: {
    storeId: null, storeName: '', realName: '',
    verifyCode: '', orderNo: '',
    submitting: false, history: []
  },
  /**
   * 外部 Scheme 跳入：扫桌上的台卡二维码 → 微信唤起小程序
   * URL 形如 pages/merchant/verify/index?code=138F31FA1271&sid=200
   *
   * 注意：onLoad 时 wx.storage 可能还没拿到 staffUser（因为是 fresh open）
   * 所以先 setData code/sid，等 onShow 拿到 staff 后再决定是否自动核销。
   */
  onLoad(options) {
    if (options && (options.code || options.sid)) {
      this._schemeCode = options.code || ''
      this._schemeSid = options.sid ? Number(options.sid) : null
      this.setData({
        verifyCode: this._schemeCode,
        orderNo: ''
      })
      wx.showLoading({ title: '正在核销...', mask: true })
    }
  },

  onShow() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      // staff 还没登录，但有外部 scheme code → 跳到登录页带 redirect
      if (this._schemeCode) {
        wx.redirectTo({ url: '/pages/login/login?showMore=1&redirect=verify&code=' + encodeURIComponent(this._schemeCode) })
      } else {
        wx.redirectTo({ url: '/pages/login/login?showMore=1' })
      }
      return
    }
    this.setData({ storeId: staff.storeId, storeName: staff.storeName || ('门店' + staff.storeId), realName: staff.realName || '' })
    this.loadHistory()

    // 外部 Scheme 进来 + 当前 staff.storeId 与 sid 不一致 → 切到 sid 对应的店
    if (this._schemeSid && staff.storeId !== this._schemeSid) {
      this._switchStoreThenVerify(this._schemeSid, this._schemeCode)
      return
    }

    // 已经在对门店 → 自动核销
    if (this._schemeCode) {
      this.setData({ verifyCode: this._schemeCode })
      // 延迟一帧确保 setData 完成
      setTimeout(() => {
        this.onSubmit()
        // 用完清掉
        this._schemeCode = ''
        this._schemeSid = null
      }, 50)
    }
  },

  /**
   * 切到目标门店后再核销（适用于店员扫了非当前 store 的台卡）
   *
   * 原来打的是 /api/store/staff/switch-store，那个端点第一行就要求
   * userType === 'store'，而商家端登录发的是 owner/manager/staff，
   * 于是这条路径必然返回「此操作仅限门店端员工」—— 整段是死代码。
   * 改打商家端专属的 /api/merchant/staff/switch-store。
   */
  _switchStoreThenVerify(targetSid, code) {
    api.merchantStaffSwitchStore(targetSid).then((d) => {
      const staff = wx.getStorageSync('staffUser') || {}
      staff.storeId = targetSid
      staff.storeName = (d && d.storeName) || ('门店' + targetSid)
      wx.setStorageSync('staffUser', staff)
      this.setData({ storeId: targetSid, storeName: staff.storeName, verifyCode: code })
      setTimeout(() => {
        this.onSubmit()
        this._schemeCode = ''
        this._schemeSid = null
      }, 50)
    }).catch((err) => {
      wx.hideLoading()
      wx.showToast({ title: (err && err.msg) || '切店失败', icon: 'none' })
    })
  },
  /**
   * 「核销记录」/「切换回会员」两个入口，以及「最近核销」里点一条的回填。
   *
   * 这三个 bindtap 在 WXML 上一直挂着，但这个文件里从来没有对应方法 ——
   * 点了完全没反应、控制台也不报错。其中「核销记录」还是刚做出来的
   * verify/records 那个功能在核销页的唯一入口，店员点进不去就等于没做。
   */
  goHistory() { wx.navigateTo({ url: '/pages/merchant/history/index' }) },

  /**
   * 切回会员版。与首页 goSwitchAccount 同口径：保留商家会话
   * （不删 staffUser/staffToken），从「我的」再切回来是零请求。
   */
  goSwitchAccount() {
    const r = identity.switchToMember()
    if (r.ok) { wx.reLaunch({ url: '/pages/home/index' }); return }
    wx.showModal({
      title: '尚未登录会员',
      content: '当前微信还没有会员登录记录，去用微信登录一次即可在两端来回切换。',
      confirmText: '去登录',
      success: (m) => { if (m.confirm) wx.reLaunch({ url: '/pages/login/login' }) }
    })
  },

  /**
   * 点「最近核销」里的一条：把核销码回填到输入框，不重新发起核销。
   *
   * 已核销的单再提交必然被后端拒（「该订单已核销」），弹个错误 toast 只会
   * 让店员以为系统出问题。真实场景是客人说「刚那单是不是没核上」，
   * 店员想把码填回去再确认一次 —— 所以这里只回填 + 提示，按不按确认由人决定。
   */
  onRepeat(e) {
    const idx = Number((e && e.currentTarget && e.currentTarget.dataset && e.currentTarget.dataset.idx) || 0)
    const item = (this.data.history || [])[idx]
    if (!item) return
    this.setData({ verifyCode: item.verifyCode || item.orderNo || '', orderNo: '' })
    wx.showToast({ title: '已回填核销码', icon: 'none' })
  },

  onCode(e) { this.setData({ verifyCode: e.detail.value }) },
  onOrderNo(e) { this.setData({ orderNo: e.detail.value }) },
  onScan() {
    wx.scanCode({ scanType: ['qrCode'], success: (res) => {
      const text = (res && (res.result || res.path)) || ''
      const m = text.match(/(verifyCode|orderNo)=([^&]+)/)
      this.setData({ verifyCode: m ? m[2] : text })
    } })
  },
  loadHistory() {
    try { this.setData({ history: (wx.getStorageSync(HISTORY_KEY) || []).slice(0, 10) }) } catch(e) { this.setData({ history: [] }) }
  },
  saveHistory(item) {
    try {
      const list = wx.getStorageSync(HISTORY_KEY) || []
      list.unshift(item)
      wx.setStorageSync(HISTORY_KEY, list.slice(0, 20))
      this.setData({ history: list.slice(0, 10) })
    } catch(e) {}
  },
  /**
   * 核销提交。
   *
   * 这里原来是手拼 wx.request，绕开了 utils/request.js 的统一封装，代价有三个：
   *  1) 取 token 直接读 storage 的 'token'。会员端和商家端是两个 token
   *     （memberToken / staffToken），封装里按 currentIdentity 选；裸读 'token'
   *     在「会员版 → 切到商家版」之后如果 current 指向没同步好，就会拿会员 token
   *     去打商家端接口，必然 401。
   *  2) 401 不走 _clearAuth(authScope)，两个 token 该清哪个无人处理，
   *     店员会卡在「点一次核销弹一次未登录」的死循环里，只能删小程序重进。
   *  3) BASE_URL 是启动时的静态值，request.js 的 probeBaseUrl 探测到可用地址后
   *     更新的是内部 _activeBaseUrl，这里读不到 —— 换网络环境就打到废弃地址。
   *
   * storeId 也不再传：门店本来就在员工 token 里，后端已按 token 兜底。
   * 之前传的是 `storeId || 0`，页面刚进来还没 syncStaff 时就是 0，
   * 后端 hasStore(0) 不匹配 → 抛「无权操作其他门店」，店员完全看不懂。
   */
  onSubmit() {
    const { verifyCode, orderNo, submitting } = this.data
    if (submitting) return
    if (!verifyCode && !orderNo) { wx.showToast({ title: '请填写核销码或订单号', icon: 'none' }); return }
    this.setData({ submitting: true })
    wx.showLoading({ title: '核销中...', mask: true })
    api.verifyOrder({ verifyCode: verifyCode || '', orderNo: orderNo || '' })
      .then((o) => {
        wx.showToast({ title: '核销成功', icon: 'success' })
        // 后端返的是 AjaxResult.success(order)，封装已剥掉 data 层，o 就是订单本身。
        // 原代码取 d.data.order —— 那层 order 包装根本不存在，恒 undefined，
        // 于是每次都落到 || 后面的占位对象：历史记录里全是「团购券 / ¥0 / 无 orderId」。
        const order = o || {}
        this.saveHistory({
          orderId: order.orderId,
          orderNo: order.orderNo || orderNo || verifyCode,
          productName: order.productName || '团购券',
          payAmount: order.payAmount == null ? 0 : order.payAmount,
          verifyCode: order.verifyCode || verifyCode,
          verifyTimeStr: order.verifyTime ? String(order.verifyTime).slice(0, 16)
                                          : new Date().toISOString().slice(0, 16)
        })
        this.setData({ verifyCode: '', orderNo: '' })
      })
      .catch((err) => {
        wx.showToast({ title: (err && (err.msg || err.errMsg)) || '核销失败', icon: 'none' })
      })
      .finally(() => {
        wx.hideLoading()
        this.setData({ submitting: false })
      })
  }
})
