const app = getApp();
const { api } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

// 与 biz_withdraw.withdraw_type 码值一致：0微信 1支付宝 2银行卡
const TYPES = [
  { value: '0', label: '微信零钱', accountLabel: '微信实名', placeholder: '请输入微信实名姓名' },
  { value: '1', label: '支付宝', accountLabel: '支付宝账号', placeholder: '请输入支付宝账号' },
  { value: '2', label: '银行卡', accountLabel: '银行卡号', placeholder: '请输入银行卡卡号' }
];

Page({
  data: {
    types: TYPES,
    typeIdx: 0,
    type: TYPES[0],
    available: '0.00',
    amount: '',
    account: '',
    accountName: '',
    submitting: false
  },
  onLoad(opts) {
    if (opts && opts.available) {
      this.setData({ available: formatMoney(opts.available) });
    } else {
      this.loadAvailable();
    }
    this.setData({ accountName: app.globalData.user.nickName || '' });
  },
  loadAvailable() {
    api.promoterInfo().then((res) => {
      const d = (res && res.data) || {};
      this.setData({ available: formatMoney(d.availableAmount) });
    }).catch(() => {});
  },
  pickType(e) {
    const idx = Number(e.currentTarget.dataset.idx);
    this.setData({ typeIdx: idx, type: TYPES[idx], account: '' });
  },
  onAmount(e) { this.setData({ amount: e.detail.value }); },
  onAccount(e) { this.setData({ account: e.detail.value }); },
  onAccountName(e) { this.setData({ accountName: e.detail.value }); },
  fillAll() { this.setData({ amount: this.data.available }); },
  onSubmit() {
    if (this.data.submitting) return;
    const amount = parseFloat(this.data.amount);
    const available = parseFloat(this.data.available) || 0;
    if (!amount || amount <= 0) return wx.showToast({ title: '请输入提现金额', icon: 'none' });
    // 前端先校验一次余额，避免明知不足还发请求
    if (amount > available) return wx.showToast({ title: '超出可提现余额', icon: 'none' });
    if (!this.data.account) return wx.showToast({ title: '请填写' + this.data.type.accountLabel, icon: 'none' });
    if (!this.data.accountName) return wx.showToast({ title: '请填写收款人姓名', icon: 'none' });

    this.setData({ submitting: true });
    wx.showLoading({ title: '提交中', mask: true });
    api.applyWithdraw({
      amount,
      withdrawType: this.data.type.value,
      account: this.data.account,
      accountName: this.data.accountName
    }).then(() => {
      wx.hideLoading();
      this.setData({ submitting: false });
      wx.showToast({ title: '提现申请已提交', icon: 'success' });
      setTimeout(() => wx.navigateBack(), 900);
    }).catch((err) => {
      wx.hideLoading();
      this.setData({ submitting: false });
      wx.showToast({ title: (err && (err.msg || err.message)) || '提交失败', icon: 'none' });
    });
  }
});
