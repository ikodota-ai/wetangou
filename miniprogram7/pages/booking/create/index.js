const app = getApp();
const { api } = require('../../../utils/request.js');
const { getNextDays, formatDate } = require('../../../utils/util.js');

Page({
  data: {
    store: {},
    distance: '',
    dateSheetVisible: false,
    calendarDays: [],
    calendarMonth: '',
    calendarMonthIndex: 0,
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
        // 异步等 pickNearestStore：传 isCreateBookingCreate=true 强制同步占位优先
        app.pickNearestStore((st) => {
          if (st && st.storeId) this.applyStore(st);
          else wx.showToast({ title: '请先选择门店', icon: 'none' });
        });
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
    // 弹出真日历：未来 60 天可选（今天之前不可选）
    this.setData({ dateSheetVisible: true, pickedDate: this._today() })
    this._buildCalendar(0)
  },
  closeDateSheet() { this.setData({ dateSheetVisible: false }) },
  /**
   * 构造 monthIndex 月的日历 (0=本月, 1=下月)
   */
  _buildCalendar(monthIndex) {
    const now = new Date()
    const target = new Date(now.getFullYear(), now.getMonth() + monthIndex, 1)
    const y = target.getFullYear()
    const m = target.getMonth()
    // 当月第一天是星期几（0=日）
    const firstWeekday = new Date(y, m, 1).getDay()
    // 当月天数
    const lastDay = new Date(y, m + 1, 0).getDate()
    const days = []
    // 上月补位
    for (let i = 0; i < firstWeekday; i++) {
      days.push({ key: 'p' + i, day: '', empty: true })
    }
    // 当月
    for (let d = 1; d <= lastDay; d++) {
      const dateStr = y + '-' + String(m + 1).padStart(2, '0') + '-' + String(d).padStart(2, '0')
      // 过去日期 disabled
      const isPast = (y < now.getFullYear()) ||
        (y === now.getFullYear() && m < now.getMonth()) ||
        (y === now.getFullYear() && m === now.getMonth() && d < now.getDate())
      // 超出 60 天 disabled
      const maxDate = new Date(now.getTime() + 60 * 24 * 60 * 60 * 1000)
      const isOver = (y > maxDate.getFullYear()) ||
        (y === maxDate.getFullYear() && m > maxDate.getMonth()) ||
        (y === maxDate.getFullYear() && m === maxDate.getMonth() && d > maxDate.getDate())
      days.push({
        key: 'd' + d,
        day: String(d),
        date: dateStr,
        empty: false,
        disabled: isPast || isOver
      })
    }
    this.setData({
      calendarDays: days,
      calendarMonth: y + ' 年 ' + (m + 1) + ' 月',
      calendarMonthIndex: monthIndex
    })
  },
  /** 切换月（上/下月按钮） */
  shiftCalendarMonth(e) {
    const dir = e && e.currentTarget && e.currentTarget.dataset && e.currentTarget.dataset.dir
    const cur = this.data.calendarMonthIndex || 0
    const next = dir === 'prev' ? Math.max(0, cur - 1) : cur + 1
    this._buildCalendar(next)
  },
  onPickCalendarDate(e) {
    const date = e && e.currentTarget && e.currentTarget.dataset && e.currentTarget.dataset.date
    if (!date) return
    // 加入 days 列表（若不存在），并选中
    const exists = (this.data.days || []).findIndex((d) => d.date === date)
    if (exists >= 0) {
      this.setData({ dateIdx: exists, dateSheetVisible: false })
    } else {
      const newDay = { label: date.slice(5).replace('-', '/'), date: date }
      const days = [newDay].concat(this.data.days || [])
      this.setData({ days, dateIdx: 0, dateSheetVisible: false })
    }
    this.loadSlots()
  },
  _today() {
    const d = new Date()
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
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
