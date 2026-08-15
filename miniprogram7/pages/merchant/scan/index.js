const { api } = require('../../../utils/request.js')
const { parseInviteScene } = require('../../../utils/inviteScene.js')

const REASON_MSG = {
  empty: '二维码内容为空',
  no_query: '小程序码格式错误（缺 query）',
  no_scene: '小程序码格式错误（缺 scene）',
  not_invite: '非商家邀请码',
  bad_format: '邀请码格式错误（段数不对）',
  bad_nums: '邀请码格式错误（数字段非法）',
  bad_code_len: '邀请码格式错误（短码长度不对）'
}

Page({
  data: {
    scanning: false
  },

  onScan() {
    if (this.data.scanning) return  // 防重
    this.setData({ scanning: true })
    wx.scanCode({
      onlyFromCamera: false,
      scanType: ['qrCode'],
      success: (res) => this._handleScanResult((res && (res.result || res.path)) || ''),
      fail: (err) => {
        this.setData({ scanning: false })
        if (err && err.errMsg && err.errMsg.indexOf('cancel') === -1) {
          wx.showToast({ title: '扫码失败', icon: 'none' })
        }
      }
    })
  },

  _handleScanResult(raw) {
    const parsed = parseInviteScene(raw)
    if (!parsed.ok) {
      this.setData({ scanning: false })
      wx.showToast({ title: REASON_MSG[parsed.reason] || '二维码无效', icon: 'none' })
      return
    }
    const scene = parsed.scene

    // 确认弹窗：避免误扫
    wx.showModal({
      title: '加入该商家？',
      content: '扫描成功后将以员工身份登录该门店。',
      confirmText: '加入',
      cancelText: '取消',
      success: (mr) => {
        if (!mr.confirm) { this.setData({ scanning: false }); return }
        this._doAccept(scene)
      },
      fail: () => this.setData({ scanning: false })
    })
  },

  _doAccept(scene) {
    wx.login({
      success: (lr) => {
        if (!lr || !lr.code) {
          this.setData({ scanning: false })
          wx.showToast({ title: '微信授权失败', icon: 'none' })
          return
        }
        const profile = wx.getStorageSync('memberProfile') || {}
        wx.showLoading({ title: '加入中...', mask: true })
        api.merchantStaffAcceptInvite({
          code: lr.code, scene,
          nickName: profile.nickName || '',
          avatarUrl: profile.avatarUrl || ''
        })
          .then((data) => {
            wx.hideLoading()
            this.setData({ scanning: false })
            const d = data || {}
            const token = d.token
            if (!token) { wx.showToast({ title: '加入失败：无 token', icon: 'none' }); return }
            // 备份原 C 端 token（员工端覆盖了 C 端 session）
            const memberToken = wx.getStorageSync('token')
            if (memberToken) wx.setStorageSync('memberTokenBackup', memberToken)
            wx.setStorageSync('token', token)
            wx.setStorageSync('staffUser', {
              userType: d.userType || 'merchant',
              merchantId: d.merchantId, storeId: d.storeId,
              storeName: d.storeName, realName: d.realName, token,
              needBindWx: !!d.needBindWx
            })
            wx.showToast({ title: '已加入', icon: 'success' })
            setTimeout(() => wx.reLaunch({ url: '/pages/merchant/home/index' }), 500)
          })
          .catch((err) => {
            wx.hideLoading()
            this.setData({ scanning: false })
            const msg = (err && (err.msg || err.message)) || '加入失败'
            // 业务错误码细分
            if (msg.indexOf('已过期') > -1) {
              wx.showModal({
                title: '邀请码已过期',
                content: '请向店长索取最新邀请码',
                showCancel: false,
                confirmText: '我知道了'
              })
            } else if (msg.indexOf('已失效') > -1) {
              wx.showModal({
                title: '邀请码已使用',
                content: '该邀请码已被其他员工使用',
                showCancel: false,
                confirmText: '我知道了'
              })
            } else if (msg.indexOf('与门店不匹配') > -1) {
              wx.showModal({
                title: '邀请码与门店不匹配',
                content: '请确认是本店长分享的二维码',
                showCancel: false,
                confirmText: '我知道了'
              })
            } else {
              wx.showToast({ title: msg, icon: 'none' })
            }
          })
      },
      fail: () => {
        this.setData({ scanning: false })
        wx.showToast({ title: '微信授权失败', icon: 'none' })
      }
    })
  }
})
