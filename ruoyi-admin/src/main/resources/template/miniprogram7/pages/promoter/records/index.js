const app = getApp();
const { api } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

// 后端提现状态：0处理中 1成功 2失败；页面 tab 在此基础上区分待审核/待打款
const STATUS_TEXT = { '0': '处理中', '1': '已完成', '2': '已驳回' };

Page({
  data: {
    tab: 'all',
    list: [],
    shown: [],
    stat: {
      totalCommission: '0.00',
      withdrawAmount: '0.00',
      waitAmount: '0.00',
      doneAmount: '0.00',
      rejectAmount: '0.00',
      availableAmount: '0.00'
    },
    loading: false,
    loaded: false
  },
  onLoad() { this.loadAll(); },
  onPullDownRefresh() { this.loadAll(() => wx.stopPullDownRefresh()); },
  loadAll(done) {
    if (!app.globalData.user.logged) {
      this.setData({ list: [], shown: [], loaded: true });
      if (done) done();
      return;
    }
    this.setData({ loading: true });
    Promise.all([
      api.promoterInfo().catch(() => null),
      api.withdrawList().catch(() => null)
    ]).then((res) => {
      const center = (res[0] && res[0].data) || {};
      const rows = (res[1] && (res[1].data || res[1].rows)) || [];
      const list = (Array.isArray(rows) ? rows : []).map((w) => ({
        id: w.withdrawId,
        withdrawNo: w.withdrawNo || '',
        amount: formatMoney(w.amount),
        amountNum: Number(w.amount) || 0,
        status: w.status,
        statusText: STATUS_TEXT[w.status] || '处理中',
        account: w.account || '',
        accountName: w.accountName || '',
        applyTime: w.applyTime ? String(w.applyTime).slice(0, 10) : '',
        finishTime: w.finishTime ? String(w.finishTime).slice(0, 10) : '',
        failReason: w.failReason || '',
        group: w.status === '1' ? 'done' : (w.status === '2' ? 'reject' : 'wait')
      }));

      const sum = (fn) => list.filter(fn).reduce((a, b) => a + b.amountNum, 0);
      this.setData({
        list,
        loading: false,
        loaded: true,
        stat: {
          totalCommission: formatMoney(center.totalCommission),
          withdrawAmount: formatMoney(center.withdrawAmount),
          availableAmount: formatMoney(center.availableAmount),
          waitAmount: formatMoney(sum((x) => x.status === '0')),
          doneAmount: formatMoney(sum((x) => x.status === '1')),
          rejectAmount: formatMoney(sum((x) => x.status === '2'))
        }
      });
      this.applyTab(this.data.tab);
      if (done) done();
    }).catch((err) => {
      this.setData({ loading: false, loaded: true });
      wx.showToast({ title: (err && (err.msg || err.message)) || '加载失败', icon: 'none' });
      if (done) done();
    });
  },
  switchTab(e) { this.applyTab(e.currentTarget.dataset.t); },
  applyTab(tab) {
    const shown = tab === 'all' ? this.data.list : this.data.list.filter((x) => x.group === tab);
    this.setData({ tab, shown });
  }
});
