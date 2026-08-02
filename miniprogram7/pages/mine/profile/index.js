const app = getApp()
const { api } = require('../../../utils/request.js')

Page({
  data: {
    user: {},
    showAvatar: false,
    showNick: false,
    editingNick: '',
    editingPhone: '',
    phoneFocus: false,
    wxNickName: ''
  },

  onLoad() {
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {}
    const user = (appInst.globalData && appInst.globalData.user) || {}
    this.setData({
      user: user,
      editingNick: user.nickName || '',
      editingPhone: user.phone || ''
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

  // 手机号：默认走文本输入，11 位校验；编辑态展示 input
  onEditPhone() {
    this.setData({ editingPhone: this.data.user.phone || '', phoneFocus: true })
  },
  onClearPhone() {
    const appInst = getApp() || {}
    appInst.globalData = appInst.globalData || {}
    appInst.globalData.user = appInst.globalData.user || {}
    appInst.globalData.user.phone = ''
    this.setData({ user: appInst.globalData.user, editingPhone: '' })
    appInst.notifyUserUpdate && appInst.notifyUserUpdate()
  },
  onPhoneInput(e) {
    this.setData({ editingPhone: e.detail.value })
  },

  // 微信新版 getPhoneNumber：把 e.detail.code 交给后端换号
  onGetPhone(e) {
    if (e.detail.errMsg !== 'getPhoneNumber:ok') {
      wx.showToast({ title: '取消授权', icon: 'none' })
      return
    }
    if (!e.detail.code) {
      wx.showToast({ title: '授权失败，请重试', icon: 'none' })
      return
    }
    wx.showLoading({ title: '授权中' })
    api.updatePhone({ code: e.detail.code }).then((res) => {
      wx.hideLoading()
      const phone = res && (res.phone || (res.data && res.data.phone))
      if (!phone) {
        wx.showToast({ title: '绑定失败，请重试', icon: 'none' })
        return
      }
      const appInst = getApp() || {}
      appInst.globalData = appInst.globalData || {}
      appInst.globalData.user = appInst.globalData.user || {}
      appInst.globalData.user.phone = phone
      this.setData({ user: appInst.globalData.user, editingPhone: '' })
      appInst.notifyUserUpdate && appInst.notifyUserUpdate()
      wx.showToast({ title: '授权成功', icon: 'success' })
    }).catch((err) => {
      wx.hideLoading()
      wx.showToast({ title: (err && err.msg) || '绑定失败，请重试', icon: 'none' })
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
    // 优先用正在编辑的 phone（editingPhone）；空时回退已存的 user.phone
    const phone = (this.data.editingPhone || u.phone || '').trim()
    if (phone) {
      // 校验格式
      if (!/^1\d{10}$/.test(phone)) {
        wx.showToast({ title: '手机号格式不正确', icon: 'none' })
        return
      }
      // 与已存的不同就同步到后端
      if (phone !== u.phone) {
        appInst.globalData = appInst.globalData || {}
        appInst.globalData.user = appInst.globalData.user || {}
        appInst.globalData.user.phone = phone
        this.setData({ user: appInst.globalData.user, editingPhone: '' })
        appInst.notifyUserUpdate && appInst.notifyUserUpdate()
        api.updateMember({ phone }).then(() => {
          wx.showToast({ title: '已保存', icon: 'success' })
          setTimeout(() => wx.navigateBack(), 600)
        }).catch((err) => {
          wx.showToast({ title: (err && err.msg) || '保存失败，请重试', icon: 'none' })
        })
        return
      }
    } else {
      // 没手机号也允许保存（不强求），只提示一下
      wx.showToast({ title: '已保存（未填手机号）', icon: 'success' })
      setTimeout(() => wx.navigateBack(), 600)
      return
    }
    wx.showToast({ title: '已保存', icon: 'success' })
    setTimeout(() => wx.navigateBack(), 600)
  },

  noop() {}
})
