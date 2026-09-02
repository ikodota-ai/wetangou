const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');
const { formatMoney } = require('../../../utils/util.js');

Page({
  data: {
    user: {},
    joined: false,
    stat: {
      totalCommission: '0.00',
      withdrawAmount: '0.00',
      availableAmount: '0.00',
      withdrawingAmount: '0.00',
      frozenAmount: '0.00'
    },
    // 商户级推客总开关（后台「商户管理 → 编辑 → 推客功能」）。
    // 默认 true：接口没回来时不误报「未开通」。
    promoterEnabled: true,
    tab: 'order',
    orderCount: 0,
    fanCount: 0,
    orders: [],
    fans: [],
    loading: false,
    joining: false,
    showAgreement: false,
    agreement: ''
  },
  onLoad() {
    this.setData({ user: app.globalData.user });
    this.syncPromoterSwitch();
  },
  onShow() {
    this.syncPromoterSwitch();
    // 提现后返回需刷新余额
    this.loadCenter();
  },
  onUserUpdate(user) { this.setData({ user }); },
  // bootMerchant 异步：冷启动直接落到本页时 globalData.merchant 还是空对象
  onMerchantUpdate() { this.syncPromoterSwitch(); },
  /**
   * 「我的」页已经用 wx:if 隐了入口，这里仍要再判一次 ——
   * 本页可以被绕过入口直达：分享卡片 / 扫码 / 海报里的 path、
   * 以及开关刚关掉但用户小程序还停在旧页面栈上的场景。
   * 关闭时整页替换成「未开通」占位，不能让「成为推客」按钮还点得动
   * （点了后端 join 会真的建推客记录）。
   */
  syncPromoterSwitch() {
    const m = (app.globalData && app.globalData.merchant) || {};
    if (m.promoterEnabled === undefined || m.promoterEnabled === null) return;
    const enabled = String(m.promoterEnabled) !== '0';
    if (enabled !== this.data.promoterEnabled) this.setData({ promoterEnabled: enabled });
  },
  loadCenter() {
    // 开关关闭时不打 /api/distributor/center：那个端点挂 @DistributorRequired，
    // 非推客一律 403，白跑一次请求还会在控制台刷错误日志。
    if (!this.data.promoterEnabled) {
      this.setData({ loading: false });
      return;
    }
    if (!app.globalData.user.logged) {
      this.setData({ joined: false });
      return;
    }
    this.setData({ loading: true });
    api.promoterInfo().then((res) => {
      // 未成为推客时后端不返回 data，据此展示加入入口
      const d = res && res.data;
      if (!d || !d.distributorId) {
        // 兜底：如果是 onJoin 后立即触发，d 可能还是旧快照（中心接口异步、缓存或 join 与 center 跨 token）
        // 任何情况下都不强行清 joined（后端可能临时没返回 distributorId，但 join 已成功）
        this.setData({ loading: false });
        return;
      }
      this.setData({
        joined: true,
        loading: false,
        orderCount: d.orderCount || 0,
        stat: {
          totalCommission: formatMoney(d.totalCommission),
          withdrawAmount: formatMoney(d.withdrawAmount),
          availableAmount: formatMoney(d.availableAmount),
          withdrawingAmount: formatMoney(d.withdrawingAmount),
          frozenAmount: formatMoney(d.frozenAmount)
        }
      });
      this.loadOrders();
      this.loadFans();
    }).catch((err) => {
      // 网络/接口失败：保留已设的 joined 状态，仅清 loading
      this.setData({ loading: false });
      console.warn('[loadCenter] FAIL =>', JSON.stringify(err));
    });
  },
  loadOrders() {
    api.commissionList().then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const orders = (Array.isArray(rows) ? rows : []).map((c) => ({
        id: c.commissionId,
        orderNo: c.orderNo || '',
        storeName: c.storeName || '',
        memberName: c.memberName || '',
        amount: formatMoney(c.amount),
        rate: c.rate ? (Number(c.rate) * 100).toFixed(0) + '%' : '',
        statusText: c.status === '1' ? '已结算' : (c.status === '2' ? '已失效' : '待结算'),
        settleTime: c.settleTime ? String(c.settleTime).slice(0, 10) : ''
      }));
      this.setData({ orders, orderCount: orders.length });
    }).catch(() => {});
  },
  loadFans() {
    // 已登录但未成为推客时跳过，避免无意义请求
    if (!this.data.joined) {
      this.setData({ fans: [], fanCount: 0 });
      return;
    }
    api.promoterFans().then((res) => {
      const rows = (res && (Array.isArray(res) ? res : (res.data || res.rows || res))) || [];
      const list = (Array.isArray(rows) ? rows : []).map((f) => ({
        memberId: f.memberId,
        nickname: f.nickname,
        avatar: f.avatar ? toFullUrl(f.avatar) : '',
        inviteTime: f.inviteTime || '',
        lastLoginTime: f.lastLoginTime || ''
      }));
      this.setData({ fans: list, fanCount: list.length });
    }).catch(() => {
      this.setData({ fans: [], fanCount: 0 });
    });
  },
  goPoster() {
    let joined = this.data.joined;
    if (!joined) {
      // fallback：onShow → loadCenter 可能没拉到 distributorId 但 join 已成功
      try { joined = !!wx.getStorageSync('promoterJoinedFlag'); } catch (e) {}
    }
    if (!joined) {
      return wx.showToast({ title: '请先成为推客', icon: 'none' });
    }
    wx.navigateTo({ url: '/pages/promoter/poster/index' });
  },
  onJoin() {
    if (this.data.joining) return;
    if (!this.data.promoterEnabled) {
      wx.showModal({ title: '未开通', content: '该商家暂未开通推客功能', showCancel: false });
      return;
    }
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    this.setData({ joining: true });
    wx.showLoading({ title: '提交中', mask: true });
    console.log('[onJoin] start, token=', wx.getStorageSync('token'));
    api.joinPromoter().then((res) => {
      console.log('[onJoin] success =>', JSON.stringify(res));
      wx.hideLoading();
      this.setData({ joining: false });
      wx.showToast({ title: '已成为推客', icon: 'success' });
      // 立即 setData 强制刷新界面（不依赖 loadCenter 异步返回 + 不依赖 distributorId 字段）
      // 后端 join 接口通常只返 {code:200}，distributorId 要等 loadCenter 拉
      this.setData({ joined: true });
      // 持久化标志：即便 loadCenter 后续被 onShow 触发且没拉到 distributorId，
      // 也能保证 goPoster 允许进入（避免「已成为推客」后仍被「请先成为推客」挡）
      try { wx.setStorageSync('promoterJoinedFlag', true); } catch (e) {}
      const d = res && (res.data || res);
      if (d && d.distributorId) {
        this.setData({
          stat: {
            totalCommission: formatMoney(d.totalCommission),
            withdrawAmount: formatMoney(d.withdrawAmount),
            availableAmount: formatMoney(d.availableAmount),
            withdrawingAmount: formatMoney(d.withdrawingAmount),
            frozenAmount: formatMoney(d.frozenAmount)
          }
        });
      }
      // 200ms 后再调 loadCenter 拉详细数据（避免 onJoin 的 setData 被 loadCenter 的 false 覆盖）
      setTimeout(() => this.loadCenter(), 200);
    }).catch((err) => {
      console.error('[onJoin] FAIL =>', JSON.stringify(err));
      wx.hideLoading();
      this.setData({ joining: false });
      const msg = (err && (err.msg || err.message || err.errMsg)) || '加入失败';
      // 完整 dump 到弹窗便于排查
      wx.showModal({
        title: '加入推客失败',
        content: msg + '\n\n' + JSON.stringify(err).slice(0, 400),
        showCancel: false
      });
    });
  },
  switchTab(e) { this.setData({ tab: e.currentTarget.dataset.t }); },
  goRecords() { wx.navigateTo({ url: '/pages/promoter/records/index' }); },
  goWithdraw() {
    if (!this.data.joined) return wx.showToast({ title: '请先成为推客', icon: 'none' });
    if (parseFloat(this.data.stat.availableAmount) <= 0) {
      return wx.showToast({ title: '暂无可提现余额', icon: 'none' });
    }
    wx.navigateTo({ url: '/pages/promoter/withdraw/index?available=' + this.data.stat.availableAmount });
  },
  openAgreement() {
    this.setData({ showAgreement: true });
    if (this.data.agreement) return;
    // 推客协议复用协议接口，后台的类型码值是 distributor
    api.agreement('distributor').then((res) => {
      const d = (res && (res.data || res)) || {};
      this.setData({ agreement: d.content || '' });
    }).catch(() => {});
  },
  closeAgreement() { this.setData({ showAgreement: false }); },
  noop() {},
  onBubble() { wx.showToast({ title: '分享商品给好友即可赚佣金', icon: 'none' }); }
});
