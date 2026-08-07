const app = getApp();
const { api } = require('../../../utils/request.js');
const { getNextDays, formatDate } = require('../../../utils/util.js');

Page({
  data: {
    store: {},
    distance: '',
    days: [],
    dateIdx: 0,
    period: 'day',
    dayRange: '',
    nightRange: '',
    daySlots: [],
    nightSlots: [],
    currentSlots: [],
    slot: '',
    slotLimit: 0,
    contact: '',
    phone: '',
    people: 1,
    remark: '',
    loadingSlots: false,
    submitting: false,
    showSuccess: false
  },
  onLoad(opts) {
    const days = getNextDays(7).map((d) => ({ label: formatDate(d, 'MM-DD'), date: formatDate(d, 'YYYY-MM-DD') }));
    this.setData({
      days,
      contact: app.globalData.user.nickname || '',
      phone: app.globalData.user.phone || ''
    });

    if (opts && opts.storeId) {
      this.loadStore(opts.storeId);
    } else {
      const s = app.globalData.store || (app.globalData.stores && app.globalData.stores[0]);
      if (s && s.storeId) {
        this.applyStore(s);
      } else {
        app.pickNearestStore((st) => this.applyStore(st));
      }
    }
  },
  loadStore(storeId) {
    api.storeDetail(storeId).then((res) => {
      const s = (res && (res.data || res)) || null;
      if (s) this.applyStore(s);
    }).catch(() => {});
  },
  applyStore(s) {
    if (!s || !s.storeId) return;
    this.setData({
      store: {
        storeId: s.storeId,
        name: s.storeName || s.name || '',
        address: s.address || '',
        hours: s.businessHours || s.hours || '',
        phone: s.servicePhone || s.phone || '',
        latitude: Number(s.latitude) || 0,
        longitude: Number(s.longitude) || 0
      },
      distance: s.distanceText || ''
    });
    this.loadSlots();
  },
  // 时段由后端按门店营业时间与已约人数计算，不再用本地模板
  loadSlots() {
    const store = this.data.store;
    const date = (this.data.days[this.data.dateIdx] || {}).date;
    if (!store.storeId || !date) return;
    this.setData({ loadingSlots: true });
    api.bookingSlots({ storeId: store.storeId, date }).then((res) => {
      const d = (res && (res.data || res)) || {};
      const daySlots = d.day || [];
      const nightSlots = d.night || [];
      const period = this.data.period === 'night' && nightSlots.length ? 'night' : 'day';
      const currentSlots = period === 'night' ? nightSlots : daySlots;
      this.setData({
        daySlots,
        nightSlots,
        period,
        currentSlots,
        dayRange: d.dayRange || '',
        nightRange: d.nightRange || '',
        slotLimit: d.slotLimit || 0,
        slot: this.firstAvailable(currentSlots),
        loadingSlots: false
      });
    }).catch((err) => {
      this.setData({ loadingSlots: false, daySlots: [], nightSlots: [], currentSlots: [], slot: '' });
      wx.showToast({ title: (err && (err.msg || err.message)) || '时段加载失败', icon: 'none' });
    });
  },
  // 默认选中第一个可约时段；全部约满/过时则不预选，避免用户误以为已选
  firstAvailable(slots) {
    const hit = (slots || []).find((s) => s.available);
    return hit ? hit.time : '';
  },
  pickDate(e) {
    const idx = Number(e.currentTarget.dataset.idx);
    if (idx === this.data.dateIdx) return;
    this.setData({ dateIdx: idx, slot: '' });
    this.loadSlots();
  },
  switchPeriod(e) {
    const p = e.currentTarget.dataset.p;
    const slots = p === 'day' ? this.data.daySlots : this.data.nightSlots;
    this.setData({ period: p, currentSlots: slots, slot: this.firstAvailable(slots) });
  },
  pickSlot(e) {
    const ds = e.currentTarget.dataset;
    if (ds.available !== true && ds.available !== 'true') {
      wx.showToast({ title: ds.expired === true || ds.expired === 'true' ? '该时段已过' : '该时段已约满', icon: 'none' });
      return;
    }
    this.setData({ slot: ds.s });
  },
  openCalendar() {
    // 弹出真日历选择：默认只能选今天到 30 天后
    const now = new Date()
    const min = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0')
    const maxDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000)
    const max = maxDate.getFullYear() + '-' + String(maxDate.getMonth() + 1).padStart(2, '0') + '-' + String(maxDate.getDate()).padStart(2, '0')
    // 用 actionSheet 模拟日历选择：列出未来 30 天
    const items = []
    const labels = []
    for (let i = 0; i <= 30; i++) {
      const d = new Date(now.getTime() + i * 24 * 60 * 60 * 1000)
      const date = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
      const week = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
      const label = (date + ' 周' + week) + (i === 0 ? ' (今天)' : '')
      items.push(date)
      labels.push(label)
    }
    wx.showActionSheet({
      itemList: labels,
      success: (r) => {
        const idx = r.tapIndex
        const pickedDate = items[idx]
        // 把 pickedDate 插入到 days 顶部（如果不是已有），并选中
        const exists = (this.data.days || []).findIndex((d) => d.date === pickedDate)
        if (exists >= 0) {
          this.setData({ dateIdx: exists })
        } else {
          const newDay = { label: pickedDate.slice(5).replace('-', '/'), date: pickedDate, picked: true }
          const days = [newDay].concat(this.data.days || [])
          this.setData({ days, dateIdx: 0 })
        }
        this.loadSlots()
      }
    })
  },
  onContact(e) { this.setData({ contact: e.detail.value }); },
  onPhone(e) { this.setData({ phone: e.detail.value }); },
  onRemark(e) { this.setData({ remark: e.detail.value }); },
  minusPeople() { this.setData({ people: Math.max(1, this.data.people - 1) }); },
  plusPeople() { this.setData({ people: Math.min(20, this.data.people + 1) }); },
  goLocation() {
    const s = this.data.store;
    if (!s.latitude || !s.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: s.latitude, longitude: s.longitude, name: s.name, address: s.address });
  },
  callService() {
    const phone = this.data.store.phone;
    if (!phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: phone });
  },
  onSubmit() {
    if (this.data.submitting) return;
    if (!this.data.store.storeId) return wx.showToast({ title: '门店信息未加载', icon: 'none' });
    if (!this.data.slot) return wx.showToast({ title: '请选择预约时段', icon: 'none' });
    if (!/^1\d{10}$/.test(this.data.phone)) return wx.showToast({ title: '请输入正确的手机号', icon: 'none' });
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }

    const date = (this.data.days[this.data.dateIdx] || {}).date;
    this.setData({ submitting: true });
    wx.showLoading({ title: '提交中', mask: true });
    api.createBooking({
      storeId: this.data.store.storeId,
      serviceName: '堂食预约',
      bookingDate: date,
      timeSlot: this.data.slot,
      contact: this.data.contact,
      phone: this.data.phone,
      people: this.data.people,
      remark: this.data.remark
    }).then(() => {
      wx.hideLoading();
      this.setData({ submitting: false, showSuccess: true });
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ submitting: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '预约失败', icon: 'none' });
      // 报名失败多半是时段被占满，刷新时段让用户改选
      this.loadSlots();
    });
  },
  noop() {},
  closeSuccess() { this.setData({ showSuccess: false }); },
  goList() {
    this.setData({ showSuccess: false });
    wx.redirectTo({ url: '/pages/booking/list/index' });
  }
});
