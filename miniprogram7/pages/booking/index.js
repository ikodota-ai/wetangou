const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');
const { haversineKm, formatDistance } = require('../../utils/util.js');
const { resolveContact } = require('../../utils/contact.js');

// 首屏先用缓存门店拉一次预约项目，避免等 pickNearestStore 回调造成空窗
function cachedStoreId() {
  const g = getApp().globalData || {};
  return (g.store && g.store.storeId) || null;
}

Page({
  // 预约项目 = 后台上架的 typeCode='BOOKING' 商品，和首页「预约服务」tab 同一个数据源。
  //
  // 原先这一页读的是字典 biz_booking_type（「堂食预约」这种类型名），而首页读的是
  // /api/product/list?typeCode=BOOKING（真实商品，带价格、有商品详情页）—— 同一个
  // 「预约」入口两套模型：首页点进去是商品详情能下单，这一页点进去是空白填表页，
  // 商家在后台上架的预约商品在这一页一个都看不到。统一到商品侧，字典类型不再用。
  //
  // itemsLoaded 区分「还没拉到」和「后台真没上架」——前者不该显示空态。
  data: { statusBarHeight: 20, store: {}, bookingItems: [], itemsLoaded: false },
  onLoad() {
    try { this.setData({ statusBarHeight: wx.getSystemInfoSync().statusBarHeight || 20 }); } catch (e) {}
    this.loadItems(cachedStoreId());
    // 立即用缓存的 store 渲染一次（避免空窗期）
    const cached = (getApp().globalData && getApp().globalData.store) || null
    if (cached && cached.storeId) {
      this.setData({ store: this._compatStore(cached) });
    } else {
      this.setData({ _storeLoadTimedOut: false });
    }
    // 门店从占位升级成最近门店时刷新（回调现在每次都会触发，见 app.js useStore 注释）
    app.pickNearestStore((s) => {
      if (s && s.storeId) {
        this.setData({ store: this._compatStore(s), _storeLoadTimedOut: false });
        // 首屏那次 loadItems 可能还没有 merchantId（bootMerchant 是异步的），
        // 拿到门店后补一次，否则商户级的预约商品拉不到
        if (!this.data.bookingItems.length) this.loadItems(s.storeId);
      }
    });
    // 5 秒兜底：仍未拿到则显示重试按钮
    if (this._storeTimer) clearTimeout(this._storeTimer);
    this._storeTimer = setTimeout(() => {
      const cur = this.data.store;
      if (!cur || !cur.storeId) this.setData({ _storeLoadTimedOut: true });
    }, 5000);
  },
  onUnload() { if (this._storeTimer) { clearTimeout(this._storeTimer); this._storeTimer = null; } },

  // 预约项目：后台上架的 BOOKING 商品。取数口径与首页 loadBookingGoods 一致
  // （merchantId 优先，预约服务通常跨店可约；拿不到才退回 storeId），
  // 否则同一个门店在两个入口会看到不一样的列表。
  loadItems(storeId) {
    const mid = app.globalData && app.globalData.merchant && app.globalData.merchant.merchantId;
    const params = { typeCode: 'BOOKING' };
    if (mid) {
      params.merchantId = mid;
    } else if (storeId) {
      params.storeId = storeId;
    }
    api.productList(params).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      const list = Array.isArray(rows) ? rows.map((p) => ({
        productId: p.productId || p.id,
        name: p.productName || p.name,
        price: p.price != null ? String(p.price) : '',
        cover: p.cover ? toFullUrl(p.cover) : ''
      })) : [];
      this.setData({ bookingItems: list, itemsLoaded: true });
    }).catch((err) => {
      console.warn('[booking] loadItems FAIL', err);
      this.setData({ bookingItems: [], itemsLoaded: true });
    });
  },

  retryStore() {
    this.setData({ _storeLoadTimedOut: false });
    app.pickNearestStore((s) => {
      if (s && s.storeId) this.setData({ store: this._compatStore(s), _storeLoadTimedOut: false });
    }, { force: true });
  },

  // 兼容后端字段：storeName → name，businessHours → hours
  //
  // 距离必须走 formatDistance，和首页保持一致：后端 distance 单位是米，
  // 原来 wxml 直接渲染 {{store.distance}}，屏幕上就是「距您1234.5678」这种裸数字。
  _compatStore(s) {
    if (!s) return {};
    const loc = (app.globalData && app.globalData.location) || null
    let _distKm = null
    if (s.distance != null && s.distance !== '') {
      _distKm = Number(s.distance) / 1000
    } else if (loc && loc.lat != null && loc.lng != null && s.latitude != null && s.longitude != null) {
      _distKm = haversineKm(loc.lat, loc.lng, s.latitude, s.longitude)
    }
    const _dist = formatDistance(_distKm)
    return Object.assign({}, s, {
      name: s.storeName || s.name || '',
      hours: s.businessHours || s.hours || '',
      address: s.address || '',
      distanceText: _dist,
      hasDistance: !!_dist
    });
  },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) this.getTabBar().setData({ selected: 2 });
  },
  // 后台没上架任何预约商品时的兜底入口：直接填表发起预约（不挂商品）
  goCreate() {
    this._toCreate(this.data.store.storeId, null, '');
  },
  // 点某个预约项目：把商品带进 create 页，落库时 product_id 才有值。
  // 不直接跳商品详情 —— 预约商品要选日期/时段，商品详情页那套「立即购买」
  // 没有时段选择，跳过去用户拿不到可约时间。
  goItem(e) {
    const ds = (e && e.currentTarget && e.currentTarget.dataset) || {};
    this._toCreate(this.data.store.storeId, ds.id || null, ds.name || '');
  },
  _toCreate(storeId, productId, name) {
    const q = [];
    if (storeId) q.push('storeId=' + storeId);
    if (productId) q.push('productId=' + productId);
    // 项目名一起带过去，create 页顶部直接显示，省掉再拉一次商品详情
    if (name) q.push('itemName=' + encodeURIComponent(name));
    wx.navigateTo({ url: '/pages/booking/create/index' + (q.length ? '?' + q.join('&') : '') });
  },
  goList() { wx.navigateTo({ url: '/pages/booking/list/index' }); },
  goHome() { wx.switchTab({ url: '/pages/home/index' }); },
  goLocation() {
    const s = this.data.store;
    if (!s.latitude || !s.longitude) return wx.showToast({ title: '暂无门店坐标', icon: 'none' });
    wx.openLocation({ latitude: s.latitude, longitude: s.longitude, name: s.name, address: s.address });
  },
  // 客服电话必须走统一降级（utils/contact.js）：门店 -> 商家。
  // 原先这里自己写 `store.servicePhone || store.phone`，少了商家兜底那一级 ——
  // 门店没填客服/门店电话时直接提示「暂无客服电话」，而后台商家客服是配了的。
  // 首页「在线咨询」和 store/service 页都已收口到 resolveContact，这里是漏的一处。
  goService() {
    const merchant = (app.globalData && app.globalData.merchant) || {};
    const phone = resolveContact(this.data.store, merchant).servicePhone;
    if (!phone) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.showActionSheet({
      itemList: ['拨打电话'],
      success: (r) => { if (r.tapIndex === 0) wx.makePhoneCall({ phoneNumber: phone }); }
    });
  }
});
