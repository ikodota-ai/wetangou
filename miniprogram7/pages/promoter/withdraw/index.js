const app = getApp();
const { api } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

// 与 biz_withdraw.withdraw_type 码值一致：0微信 1支付宝 2银行卡
const TYPES = [
  { value: '0', label: '微信零钱', accountLabel: '微信实名', placeholder: '请输入微信实名姓名' },
  { value: '1', label: '支付宝', accountLabel: '支付宝账号', placeholder: '请输入支付宝账号' },
  { value: '2', label: '银行卡', accountLabel: '银行卡号', placeholder: '请输入银行卡卡号' }
];

// 接口拿不到规则时的兜底，与后端 WithdrawRuleService 的默认值保持一致。
// 提现页必须始终有规则可展示（微信审核要求），不能因为一次网络抖动就变成白板。
const FALLBACK_RULE = {
  minAmount: 10,
  maxAmount: 5000,
  dailyTimes: 3,
  remainingTimes: 3,
  serviceHours: '每日 9:00-21:00',
  withinServiceHours: true,
  feeRate: 0,
  arrivalDesc: '审核通过后 1-3 个工作日到账',
  rules: [
    '可提现额度：仅「可提现余额」内的金额可申请，佣金需经订单冷静期结算后才会转入可提现余额。',
    '单笔额度：单笔最低 10 元，单笔最高 5000 元。',
    '每日次数：每个账号每日最多可提现 3 次，次日 00:00 重置。',
    '提现时间：每日 9:00-21:00 受理提现申请，非受理时段可先查询余额，次日受理。',
    '到账时间：审核通过后 1-3 个工作日到账，具体到账以收款渠道（微信零钱 / 支付宝 / 银行卡）实际处理时间为准。',
    '手续费：本平台不收取提现手续费。',
    '提现审核：申请提交后对应金额立即冻结并进入平台审核；审核通过后按上述时效打款，若被驳回，冻结金额将全额退回可提现余额。',
    '收款信息：请确保收款账号与收款人姓名真实一致，因信息填写错误导致的打款失败或转账至他人账户，需重新发起申请。'
  ]
};

// 去掉无意义小数尾零：10.00 -> 10，2.50 -> 2.5
function trimNum(v) {
  const n = Number(v);
  if (!isFinite(n)) return '0';
  return String(parseFloat(n.toFixed(2)));
}

Page({
  data: {
    types: TYPES,
    typeIdx: 0,
    type: TYPES[0],
    available: '0.00',
    amount: '',
    account: '',
    accountName: '',
    submitting: false,
    rule: FALLBACK_RULE,
    amountPlaceholder: '请输入提现金额',
    minAmountText: '',
    maxAmountText: '',
    dailyTimesText: '',
    feeText: ''
  },
  onLoad(opts) {
    if (opts && opts.available) {
      this.setData({ available: formatMoney(opts.available) });
    } else {
      this.loadAvailable();
    }
    this.setData({ accountName: app.globalData.user.nickName || '' });
    this.applyRule(FALLBACK_RULE);
    this.loadRule();
  },
  loadAvailable() {
    api.promoterInfo().then((res) => {
      const d = (res && res.data) || {};
      this.setData({ available: formatMoney(d.availableAmount) });
    }).catch(() => {});
  },
  loadRule() {
    api.withdrawRules().then((res) => {
      const d = (res && res.data) || null;
      if (d && d.rules && d.rules.length) this.applyRule(d);
    }).catch(() => {});
  },
  // 规则拿到后统一算派生文案，避免在 wxml 里做运算（项目约定 wxml 不写函数调用）
  applyRule(rule) {
    const maxAmount = Number(rule.maxAmount) || 0;
    const dailyTimes = Number(rule.dailyTimes) || 0;
    const remaining = rule.remainingTimes;
    const minText = '¥' + trimNum(rule.minAmount);
    const maxText = maxAmount > 0 ? '¥' + trimNum(maxAmount) : '不限';
    let timesText = '不限';
    if (dailyTimes > 0) {
      timesText = (remaining === undefined || remaining === null || remaining < 0)
        ? dailyTimes + ' 次'
        : '剩余 ' + remaining + '/' + dailyTimes + ' 次';
    }
    const feeRate = Number(rule.feeRate) || 0;
    this.setData({
      rule,
      minAmountText: minText,
      maxAmountText: maxText,
      dailyTimesText: timesText,
      amountPlaceholder: '单笔 ' + minText + ' 起' + (maxAmount > 0 ? '，最高 ' + maxText : ''),
      feeText: feeRate > 0 ? '按提现金额收取 ' + trimNum(feeRate) + '%' : ''
    });
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
    const rule = this.data.rule || FALLBACK_RULE;
    if (!amount || amount <= 0) return wx.showToast({ title: '请输入提现金额', icon: 'none' });
    // 前端按同一套规则先拦一次，省掉一次必然失败的请求；
    // 服务端 WithdrawRuleService.validate 才是真正的关卡，这里只是体验层。
    const min = Number(rule.minAmount) || 0;
    if (min > 0 && amount < min) {
      return wx.showToast({ title: '单笔最低提现 ' + trimNum(min) + ' 元', icon: 'none' });
    }
    const max = Number(rule.maxAmount) || 0;
    if (max > 0 && amount > max) {
      return wx.showToast({ title: '单笔最高提现 ' + trimNum(max) + ' 元', icon: 'none' });
    }
    if (amount > available) return wx.showToast({ title: '超出可提现余额', icon: 'none' });
    if (rule.withinServiceHours === false) {
      return wx.showToast({ title: '提现受理时间为' + (rule.serviceHours || ''), icon: 'none' });
    }
    if (rule.remainingTimes === 0) {
      return wx.showToast({ title: '今日提现次数已用完', icon: 'none' });
    }
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
