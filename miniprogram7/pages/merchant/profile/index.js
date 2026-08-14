const { api } = require('../../../utils/request.js')

Page({
  data: {
    realName: '',
    phone: '',
    staffNo: '',
    loading: false
  },

  onShow() {
    api.merchantStaffMe().then((d) => {
      if (d) this.setData({
        realName: d.realName || '',
        phone: d.phone || '',
        staffNo: d.staffNo || ''
      })
    }).catch(() => {})
  },

  onRealName(e) { this.setData({ realName: e.detail.value }) },
  onPhone(e) { this.setData({ phone: e.detail.value }) },
  onStaffNo(e) { this.setData({ staffNo: e.detail.value }) },

  onSave() {
    const { realName, phone, staffNo } = this.data
    if (!realName && !phone && !staffNo) {
      wx.showToast({ title: '请填写要更新的内容', icon: 'none' })
      return
    }
    if (phone && !/^1[3-9]\d{9}$/.test(phone)) {
      wx.showToast({ title: '手机号格式错误', icon: 'none' })
      return
    }
    this.setData({ loading: true })
    api.merchantStaffProfile({ realName, phone, staffNo })
      .then(() => {
        wx.showToast({ title: '已保存', icon: 'success' })
        setTimeout(() => wx.navigateBack(), 600)
      })
      .catch((err) => {
        wx.showToast({ title: (err && (err.msg || err.message)) || '保存失败', icon: 'none' })
      })
      .finally(() => this.setData({ loading: false }))
  }
})
