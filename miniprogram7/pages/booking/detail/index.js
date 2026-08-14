const { api } = require('../../../utils/request.js');

const BOOKING_STATUS = { '0': '待确认', '1': '已确认', '2': '已完成', '3': '已取消' };

Page({
  data: {
    signupId: null,
    info: {},
    canCancel: false,
    loading: true
  },
  onLoad(opts) {
    if (!opts || !opts.signupId) {
      wx.showToast({ title: '缺少预约编号', icon: 'none' });
      this.setData({ loading: false });
      return;
    }
    this.setData({ signupId: opts.signupId });
    this.loadDetail();
  },
  loadDetail() {
    api.bookingSignupDetail(this.data.signupId).then((res) => {
      console.log('[booking/detail] raw =>', JSON.stringify(res).slice(0, 400));
      const r = (res && (res.data || res)) || {};
      const cancelled = r.status === '1' || r.bookingStatus === '3';
      this.setData({
        info: {
          storeName: r.storeName || '',
          storeAddress: r.storeAddress || '',
          storePhone: r.storePhone || '',
          latitude: Number(r.storeLatitude) || 0,
          longitude: Number(r.storeLongitude) || 0,
          serviceName: r.serviceName || '堂食预约',
          bookingTime: (r.bookingDate ? String(r.bookingDate).slice(0, 10) : '') + (r.timeSlot ? ' ' + r.timeSlot : ''),
          createTime: r.createTime || '-',
          contact: r.contact || '-',
          phone: r.phone || '-',
          people: r.people || 1,
          remark: r.remark || '-',
          bookingNo: r.bookingNo || r.id,
          statusText: cancelled ? '已取消' : (BOOKING_STATUS[r.bookingStatus] || '待确认')
        },
        // 仅未取消、未完成的预约允许取消
        canCancel: !cancelled && r.bookingStatus !== '2',
        loading: false
      });
    }).catch((err) => {
      this.setData({ loading: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' });
    });
  },
  onCancel() {
    if (!this.data.canCancel) return;
    wx.showModal({
      title: '取消预约',
      content: '确定要取消此次预约吗？',
      success: (r) => {
        if (!r.confirm) return;
        wx.showLoading({ title: '处理中', mask: true });
        api.cancelBooking(this.data.signupId).then(() => {
          wx.hideLoading();
          wx.showToast({ title: '已取消', icon: 'success' });
          setTimeout(() => wx.navigateBack(), 800);
        }).catch((err) => {
          wx.hideLoading();
          wx.showToast({ title: (err && (err.msg || err.message)) || '取消失败', icon: 'none' });
        });
      }
    });
  },
  goLocation() {
    const s = this.data.info;
    if (!s.latitude || !s.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: s.latitude, longitude: s.longitude, name: s.storeName, address: s.storeAddress });
  },
  callService() {
    const phone = this.data.info.storePhone;
    if (!phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: phone });
  }
});
