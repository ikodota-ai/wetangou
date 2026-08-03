const app = getApp()
const { api } = require('../../../utils/request.js')

Page({
  data: {
    user: {},
    showAvatar: false,
    showNick: false,
    showPhone: false,
    editingNick: '',
    wxNickName: ''
  },

  onLoad() {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {}
    const user = (appInst.globalData && appInst.globalData.user) || {}
    this.setData({
      user: user,
      editingNick: user.nickName || ''
    })

    const userInfo = wx.getStorageSync('userInfo')
    if (userInfo && userInfo.nickName) {
      this.setData({ wxNickName: userInfo.nickName })
    }
  },

  showAvatarSheet() {
    this.setData({ showAvatar: true })
  },

  hideAvatarSheet() {
    this.setData({ showAvatar: false })
  },

  chooseImage() {
    this.hideAvatarSheet()
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath
        this.uploadAvatar(tempFilePath)
      }
    })
  },

  onChooseWxAvatar(e) {
    this.hideAvatarSheet()
    const avatarUrl = e.detail.avatarUrl
    if (avatarUrl) {
      this.uploadAvatar(avatarUrl)
    }
  },

  uploadAvatar(filePath) {
    wx.showLoading({ title: '上传中' })
    const appInst = getApp() || {}
    appInst.globalData = appInst.globalData || {}
    appInst.globalData.user = appInst.globalData.user || {}
    appInst.globalData.user.avatarUrl = filePath
    this.setData({ user: appInst.globalData.user })
    appInst.notifyUserUpdate && appInst.notifyUserUpdate()

    api.uploadAvatar(filePath).then((res) => {
      wx.hideLoading()
      const url = res && (res.imgUrl || res.url)
      if (url) {
        appInst.globalData.user.avatarUrl = url
        this.setData({ user: appInst.globalData.user })
        appInst.notifyUserUpdate && appInst.notifyUserUpdate()
      }
      wx.showToast({ title: '已更新', icon: 'success' })
    }).catch((err) => {
      wx.hideLoading()
      wx.showToast({ title: (err && err.msg) || '上传失败，请重试', icon: 'none' })
    })
  },

  showNickSheet() {
    this.setData({
      showNick: true,
      editingNick: (getApp() && getApp().globalData && getApp().globalData.user && getApp().globalData.user.nickName) || ''
    })
  },

  hideNickSheet() {
    this.setData({ showNick: false })
  },

  onNickInput(e) {
    this.setData({ editingNick: e.detail.value })
  },

  useWxNick() {
    if (this.data.wxNickName) {
      this.setData({ editingNick: this.data.wxNickName })
    }
  },

  saveNick() {
    if (!this.data.editingNick) {
      wx.showToast({ title: '请输入昵称', icon: 'none' })
      return
    }

    const appInst = getApp() || {}
    appInst.globalData = appInst.globalData || {}
    appInst.globalData.user = appInst.globalData.user || {}
    appInst.globalData.user.nickName = this.data.editingNick
    this.setData({ user: appInst.globalData.user, showNick: false })
    appInst.notifyUserUpdate && appInst.notifyUserUpdate()

    api.updateMember({ nickname: this.data.editingNick }).then(() => {
      wx.showToast({ title: '已更新', icon: 'success' })
    }).catch((err) => {
      wx.showToast({ title: (err && err.msg) || '保存失败，请重试', icon: 'none' })
    })
  },

  // 微信新版 getPhoneNumber：e.detail.code 交给后端换号，成功后 user.phone 立刻可见
  showPhoneSheet() { this.setData({ showPhone: true }) },
  hidePhoneSheet() { this.setData({ showPhone: false }) },
  onGetPhone(e) {
    // 调试日志：完整 dump 微信回调，便于排查
    console.log('[profile] onGetPhone detail =>', JSON.stringify(e.detail))
    if (e.detail.errMsg !== 'getPhoneNumber:ok') {
      // 拒绝 / 取消 / 工具模拟都会进这里
      wx.showModal({ title: '未授权', content: e.detail.errMsg || '用户取消授权', showCancel: false })
      return
    }
    if (!e.detail.code) {
      wx.showModal({ title: '授权失败', content: '微信未返回 code。errMsg=' + e.detail.errMsg, showCancel: false })
      return
    }
    wx.showLoading({ title: '授权中' })
    console.log('[profile] POST /api/member/phone code=', e.detail.code)
    api.updatePhone({ code: e.detail.code }).then((res) => {
      wx.hideLoading()
      console.log('[profile] /api/member/phone response =>', JSON.stringify(res))
      const phone = res && (res.phone || (res.data && res.data.phone))
      if (!phone) {
        // 后端 200 但没回 phone —— 可能是 getuserphonenumber 报错被吞了
        const msg = (res && (res.msg || (res.data && res.data.msg))) || '后端未返回 phone 字段'
        wx.showModal({ title: '绑定失败', content: '后端响应: ' + JSON.stringify(res).slice(0, 300), showCancel: false })
        return
      }
      const appInst = getApp() || {}
      appInst.globalData = appInst.globalData || {}
      appInst.globalData.user = appInst.globalData.user || {}
      appInst.globalData.user.phone = phone
      this.setData({ user: appInst.globalData.user, showPhone: false })
      appInst.notifyUserUpdate && appInst.notifyUserUpdate()
      wx.showToast({ title: '已绑定', icon: 'success' })
    }).catch((err) => {
      wx.hideLoading()
      console.error('[profile] /api/member/phone FAIL =>', err)
      // 区分网络层失败 vs 后端 4xx/5xx
      const content = (err && err.errMsg) ? '网络层失败: ' + err.errMsg
                    : (err && err.msg) ? '后端报错: ' + err.msg
                    : (err && err.statusCode) ? 'HTTP ' + err.statusCode + '：' + JSON.stringify(err.data || {}).slice(0, 200)
                    : '未知错误: ' + JSON.stringify(err).slice(0, 200)
      wx.showModal({ title: '请求 /api/member/phone 失败', content: content, showCancel: false })
    })
  },

  onSave() {
    const appInst = getApp() || {}
    const u = (appInst.globalData && appInst.globalData.user) || {}
    if (!u.avatarUrl) {
      wx.showToast({ title: '请设置头像', icon: 'none' })
      return
    }
    if (!u.nickName) {
      wx.showToast({ title: '请设置昵称', icon: 'none' })
      return
    }
    // 手机号可选（已通过 onGetPhone 同步给后端）
    wx.showToast({ title: '已保存', icon: 'success' })
    setTimeout(() => wx.navigateBack(), 600)
  },

  noop() {}
})
