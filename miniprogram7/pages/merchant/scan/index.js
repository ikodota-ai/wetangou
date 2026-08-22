const { api } = require('../../../utils/request.js')
const { parseInviteScene } = require('../../../utils/inviteScene.js')
const identity = require('../../../utils/identity.js')

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
    scanning: false,
    // true 表示本页由微信「扫一扫」带 scene 直达（主路径），
    // 此时不渲染「扫码」按钮，避免在自动处理期间闪一下无关入口
    fromScene: false
  },

  /**
   * 入职页入口。
   *
   * <p>主路径：店长在后台生成 getWxaCodeUnlimited 小程序码
   * （page=pages/merchant/scan/index, scene=invite:MID:SID:CODE），
   * 新员工用微信「扫一扫」或相册长按识别 → 微信直接拉起小程序落到本页，
   * options.scene 即邀请码，无需先登录（此时他还没有账号）。</p>
   *
   * <p>注意 scene 在小程序码里是被 URL 编码过的，必须 decodeURIComponent。</p>
   */
  onLoad(options) {
    if (options && options.scene) {
      this.setData({ fromScene: true })
      this._handleScanResult(decodeURIComponent(options.scene))
    }
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
      // 直达场景失败要退回手动扫码态，否则页面会一直停在「正在识别…」
      this.setData({ scanning: false, fromScene: false })
      wx.showToast({ title: REASON_MSG[parsed.reason] || '二维码无效', icon: 'none' })
      return
    }
    const scene = parsed.scene

    // 确认弹窗：避免误扫
    wx.showModal({
      title: '加入该商家？',
      content: '将向该门店提交入职申请，店长审核通过后即可使用商家版。',
      confirmText: '提交申请',
      cancelText: '取消',
      success: (mr) => {
        if (!mr.confirm) { this.setData({ scanning: false, fromScene: false }); return }
        this._doAccept(scene)
      },
      fail: () => this.setData({ scanning: false, fromScene: false })
    })
  },

  _doAccept(scene) {
    wx.login({
      success: (lr) => {
        if (!lr || !lr.code) {
          this.setData({ scanning: false, fromScene: false })
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
            // 待审核：账号与微信已绑定，但未获得商家端登录态，需店长在后台通过
            if (d.pendingAudit || !d.token) {
              // 标记本人已有员工账号，「我的」页可显示商家版入口（点进去会提示待审核）
              try { wx.setStorageSync('hasStaffAccount', true) } catch (e) {}
              wx.showModal({
                title: '申请已提交',
                content: '请联系店长在后台审核通过，通过后即可进入商家版。',
                showCancel: false,
                confirmText: '我知道了',
                success: () => wx.navigateBack({ delta: 1 })
              })
              return
            }
            // 已在职（例如二次扫码/已审核过）→ 直接建立商家端会话
            identity.saveStaffSession(d.token, {
              token: d.token,
              userId: d.userId || d.memberId,
              userType: d.userType || 'staff',
              staffRole: d.staffRole,
              roles: d.roles || [],
              isOwner: !!d.isOwner,
              isManagerOrAbove: !!d.isManagerOrAbove,
              isAgent: !!d.isAgent,
              merchantId: d.merchantId,
              storeId: d.storeId,
              storeIds: d.storeIds || [],
              storeName: d.storeName,
              realName: d.realName,
              needBindWx: !!d.needBindWx,
              logged: true
            })
            try { wx.setStorageSync('hasStaffAccount', true) } catch (e) {}
            wx.showToast({ title: '已加入', icon: 'success' })
            setTimeout(() => wx.reLaunch({ url: '/pages/merchant/home/index' }), 500)
          })
          .catch((err) => {
            wx.hideLoading()
            this.setData({ scanning: false, fromScene: false })
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
            } else if (msg.indexOf('待店长审核') > -1) {
              wx.showModal({
                title: '等待审核',
                content: '你的入职申请已提交，请联系店长在后台审核通过。',
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
        this.setData({ scanning: false, fromScene: false })
        wx.showToast({ title: '微信授权失败', icon: 'none' })
      }
    })
  }
})
