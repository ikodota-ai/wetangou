const { api } = require('../../../utils/request.js')

Page({
  onScan() {
    wx.scanCode({
      onlyFromCamera: false,
      scanType: ['qrCode'],
      success: (res) => {
        const raw = (res && (res.result || res.path)) || ''
        let scene = raw
        const queryIdx = raw.indexOf('scene=')
        if (raw.indexOf('pages/') === 0 && queryIdx > -1) {
          scene = decodeURIComponent(raw.substring(queryIdx + 6))
        }
        if (scene.indexOf('invite:') !== 0) {
          wx.showToast({ title: '非商家邀请码', icon: 'none' })
          return
        }
        wx.login({
          success: (lr) => {
            if (!lr || !lr.code) { wx.showToast({ title: '微信授权失败', icon: 'none' }); return }
            const profile = wx.getStorageSync('memberProfile') || {}
            wx.showLoading({ title: '加入中...', mask: true })
            api.merchantStaffAcceptInvite({ code: lr.code, scene, nickName: profile.nickName || '', avatarUrl: profile.avatarUrl || '' })
              .then((data) => {
                wx.hideLoading()
                const d = data || {}
                const token = d.token
                if (!token) { wx.showToast({ title: '加入失败：无 token', icon: 'none' }); return }
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
                wx.showToast({ title: (err && (err.msg || err.message)) || '加入失败', icon: 'none' })
              })
          },
          fail: () => wx.showToast({ title: '微信授权失败', icon: 'none' })
        })
      },
      fail: () => {}
    })
  }
})
