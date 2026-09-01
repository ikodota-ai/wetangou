const app = getApp();
const { api } = require('../../../utils/request.js');

// 报名状态(0已报名/1已取消) 需叠加场次状态(0待确认/1已确认/2已完成/3已取消)后再归组到 tab
Page({
  data: { tab: 'all', list: [], shown: [], loading: false, loaded: false },
  onLoad() { this.loadList(); },
  onShow() {
    // 取消预约后返回列表需刷新
    if (this.data.loaded) this.loadList();
  },
  onPullDownRefresh() {
    this.loadList(() => wx.stopPullDownRefresh());
  },
  loadList(done) {
    if (!app.globalData.user.logged) {
      this.setData({ list: [], shown: [], loaded: true });
      if (done) done();
      return;
    }
    this.setData({ loading: true });
    api.bookingList({}).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const list = (Array.isArray(rows) ? rows : []).map((r) => this.format(r));
      this.setData({ list, loading: false, loaded: true });
      this.applyTab(this.data.tab);
      if (done) done();
    }).catch((err) => {
      this.setData({ loading: false, loaded: true });
      wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' });
      if (done) done();
    });
  },
  format(r) {
    const cancelled = r.status === '1' || r.bookingStatus === '3';
    const finished = !cancelled && r.bookingStatus === '2';
    const confirmed = !cancelled && !finished && r.bookingStatus === '1';
    let statusText = '待确认';
    let group = 'wait';
    if (cancelled) { statusText = '已取消'; group = 'cancel'; }
    else if (finished) { statusText = '已完成'; group = 'done'; }
    else if (confirmed) { statusText = '已确认'; group = 'wait'; }
    return {
      id: r.id,
      bookingId: r.bookingId,
      // 同 detail 页：兜底文案不能写死某一种类型
      title: r.serviceName || '在线预约',
      time: (r.bookingDate ? String(r.bookingDate).slice(0, 10) : '') + (r.timeSlot ? ' ' + r.timeSlot : ''),
      address: r.storeAddress || r.storeName || '',
      storeName: r.storeName || '',
      phone: r.storePhone || '',
      latitude: Number(r.storeLatitude) || 0,
      longitude: Number(r.storeLongitude) || 0,
      people: r.people || 1,
      statusText,
      group
    };
  },
  switchTab(e) { this.applyTab(e.currentTarget.dataset.t); },
  applyTab(tab) {
    const base = tab === 'all' ? this.data.list : this.data.list.filter((x) => x.group === tab);
    // 单条时占满整行（避免 1 条占半宽空着难看），多条时半宽 2 列
    const span = base.length === 1 ? 'full' : 'half';
    const shown = base.map((it) => Object.assign({}, it, { _span: span }));
    this.setData({ tab, shown });
  },
  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: '/pages/booking/detail/index?signupId=' + id });
  },
  goCreate() { wx.navigateTo({ url: '/pages/booking/create/index' }); },
  goLocation(e) {
    const item = this.data.list.find((x) => String(x.id) === String(e.currentTarget.dataset.id));
    if (!item || !item.latitude || !item.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: item.latitude, longitude: item.longitude, name: item.storeName, address: item.address });
  },
  callService(e) {
    const item = this.data.list.find((x) => String(x.id) === String(e.currentTarget.dataset.id));
    if (!item || !item.phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: item.phone });
  },
  goLogin() { wx.navigateTo({ url: '/pages/login/login' }); }
});
