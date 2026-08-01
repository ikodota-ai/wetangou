const app = getApp()
const { api } = require('../../../utils/request.js')

Page({
  data: {
    user: {},
    showAvatar: false,
    showNick: false,
    editingNick: '',
    wxNickName: ''
  },

  onLoad() {
    this.setData({
      user: app.globalData.user,
      editingNick: app.globalData.user.nickName || ''
    })

    // 尝试获取微信昵称（type="nickname" input 需用户手动触发）
    // 这里先存储一个默认微信昵称（实际从 userProfile 拿）
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
    // 先本地预览，成功后再用服务端返回的正式地址覆盖
    app.globalData.user.avatarUrl = filePath
    this.setData({ user: app.globalData.user })
    app.notifyUserUpdate()

    api.uploadAvatar(filePath).then((res) => {
      wx.hideLoading()
      const url = res && (res.imgUrl || res.url)
      if (url) {
        app.globalData.user.avatarUrl = url
        this.setData({ user: app.globalData.user })
        app.notifyUserUpdate()
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
      editingNick: app.globalData.user.nickName || ''
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

    app.globalData.user.nickName = this.data.editingNick
    this.setData({ user: app.globalData.user, showNick: false })
    app.notifyUserUpdate()

    // 后端会员字段名是 nickname（非 nickName）
    api.updateMember({ nickname: this.data.editingNick }).then(() => {
      wx.showToast({ title: '已更新', icon: 'success' })
    }).catch((err) => {
      wx.showToast({ title: (err && err.msg) || '保存失败，请重试', icon: 'none' })
    })
  },

  // 微信新版 getPhoneNumber：把 e.detail.code 交给后端换号，绑定失败必须明确报错，
  // 不能伪造成功，否则用户以为已绑定而实际未落库
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
      app.globalData.user.phone = phone
      this.setData({ user: app.globalData.user })
      app.notifyUserUpdate()
      wx.showToast({ title: '授权成功', icon: 'success' })
    }).catch((err) => {
      wx.hideLoading()
      wx.showToast({ title: (err && err.msg) || '绑定失败，请重试', icon: 'none' })
    })
  },

  onSave() {
    const u = app.globalData.user
    if (!u.avatarUrl) {
      wx.showToast({ title: '请设置头像', icon: 'none' })
      return
    }
    if (!u.nickName) {
      wx.showToast({ title: '请设置昵称', icon: 'none' })
      return
    }
    if (!u.phone) {
      wx.showToast({ title: '请授权手机号', icon: 'none' })
      return
    }
    wx.showToast({ title: '已保存', icon: 'success' })
    setTimeout(() => wx.navigateBack(), 600)
  },

  noop() {}
})
