const app = getApp();
const { api, toFullUrl } = require('../../utils/request.js');
const { haversineKm, formatDistance } = require('../../utils/util.js');
const { resolveContact } = require('../../utils/contact.js');

Page({
  data: {
    statusBarHeight: 20,
    banners: [],  // 不设兜底图；后端无 banner 数据时由调用方显式报错
    facilities: [],    // 门店设施及服务全量（详情抽屉用）
    facilityTags: [],  // 卡片上展示的前 2 个
    store: {},
    goods: [],
    bookingGoods: [],      // 「预约服务」tab：typeCode=BOOKING 的真实商品
    bookingLoaded: false,  // 区分「还没拉」和「拉完是 0 条」，空态文案不一样
    tab: 'pickup',
    showConsult: false,
    showFacility: false,
    // 拨打电话和客服电话是两条独立的降级链，不能共用一个字段：
    // callPhone    门店电话 -> 商家电话（打过去是店里）
    // servicePhone 门店客服 -> 商家客服（可能是总部 400）
    callPhone: '',
    phone: '',
    qrcode: '',
    serviceHours: '',
    isStoreService: false,
    hasStaff: false
  },
  onShow() {
    // 身份切换入口统一放在「我的」页，首页不再显示
  },
  _bannerToastShown: false,
  _firstLoadDone: false,
  _slowTimer: null,
  onLoad() {
    // 3.5s 内还没拿到 store → 触发降级 + 主动再 fetch 一次（避免白板卡死）
    this._slowTimer = setTimeout(() => {
      if (!this.data.store || !this.data.store.storeId) {
        console.warn('[home] 3.5s 仍无 store，触发降级');
        this.setData({
          store: {
            name: '门店加载中…',
            hours: '',
            address: '',
            distanceText: '距离未知'
          }
        });
        // 主动兜底：直接调 storeList 拿一个店（不走位置），保证有真实店名
        api.storeList({ page: 1, pageSize: 1 }).then((res) => {
          const rows = (res && (res.rows || res.data || res)) || [];
          if (Array.isArray(rows) && rows.length && rows[0].storeId) {
            const viewStore = this._compatStoreView(rows[0]);
            this.setData({ store: viewStore });
          }
        }).catch(() => {});
      }
    }, 3500);
    try {
      const sys = wx.getSystemInfoSync();
      this.setData({ statusBarHeight: sys.statusBarHeight || 20 });
    } catch (e) {}
    // banner 是平台/商户级资源，与门店无关，直接在 onLoad 拉。
    //
    // 原先它挂在 loadData 的 pickNearestStore 回调里，而那个 callback 只在
    // 门店「变化」时才触发（app.js useStore: if (changed) callback(s)）。
    // app.js onLaunch 的 bootDefaultStore() 已经先把 globalData.store 填好了，
    // 于是首页 onLoad 再调 pickNearestStore 时走 globalData_placeholder 分支，
    // prev.storeId === s.storeId → changed=false → 回调一次都不执行
    // → loadBanners 根本没被调用，banner 位恒空白（后台配了也不显示）。
    this.loadBanners();
    // 始终调 pickNearestStore：
    //   - 有缓存 → 立刻 callback 渲染（占位）
    //   - 同时异步取位 + 查最近门店，nearest 拿到后 callback 升级 store
    // 两种情况都走 loadData，统一收口
    this.loadData();
  },
  onUnload() { if (this._slowTimer) { clearTimeout(this._slowTimer); this._slowTimer = null; } },
  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 0 });
    }
  },
  // 把后端 store 字段转成 wxml 用的视图模型（name/hours/distanceText）
  _compatStoreView(s) {
    if (!s) return {}
    const loc = (app.globalData && app.globalData.location) || null
    let _distKm = null
    if (s.distance != null && s.distance !== '') {
      // 后端字段单位约定为米；统一转成 km 传给 formatDistance
      const d = Number(s.distance)
      _distKm = d / 1000
    } else if (loc && loc.lat != null && loc.lng != null && s.latitude != null && s.longitude != null) {
      _distKm = haversineKm(loc.lat, loc.lng, s.latitude, s.longitude)
    } else {
      // 没有位置时不主动取位（懒加载策略：避免频繁弹系统授权框）
    }
    // 这里不能用 `formatDistance(_distKm) || '计算中…'`：
    // 没授权定位时 _distKm 恒为 null、formatDistance 恒返 ''，
    // 于是永久停在「计算中…」—— 而它根本不会再算，因为不主动取位。
    // 区分两种状态：算出来了就显示，没位置就明说需要授权。
    const _dist = formatDistance(_distKm)
    // 评分：后台手工维护的 0.0-5.0。用 == null 判断而不是 !s.rating ——
    // 后者会把合法的 0 分也当成未评分（虽然 0 分罕见，但语义上是两回事）。
    const _rawRating = s.rating
    const _ratingNum = _rawRating == null || _rawRating === '' ? null : Number(_rawRating)
    const _hasRating = _ratingNum != null && Number.isFinite(_ratingNum)
    return Object.assign({}, s, {
      name: s.storeName || s.name || '',
      hours: s.businessHours || s.hours || '',
      logo: s.logo ? toFullUrl(s.logo) : '',
      distanceText: _dist,
      // wxml 用它决定是显示「距您 x km」还是「查看距离」按钮
      hasDistance: !!_dist,
      hasRating: _hasRating,
      // 4.8 → 显示 "4.8"，5 → 显示 "5.0"（统一一位小数，避免 4.8 和 5 混排）
      ratingText: _hasRating ? _ratingNum.toFixed(1) : '',
      // 点亮几颗星：4.8 分点亮 5 颗（四舍五入），3.2 点亮 3 颗
      ratingStars: _hasRating ? Math.round(_ratingNum) : 0
    })
  },

  /**
   * 用户点「查看距离」时才取位（而不是进首页就弹授权框）。
   * 取到后写回 globalData.location，并就地重算当前门店距离。
   */
  requestDistance() {
    const done = (loc) => {
      if (!loc) {
        wx.showToast({ title: '未获取到位置，可在右上角「···」→ 设置里开启位置权限', icon: 'none', duration: 3000 })
        return
      }
      app.globalData.location = { lat: loc.latitude, lng: loc.longitude }
      try { wx.setStorageSync('lastUserLocation', { lat: loc.latitude, lng: loc.longitude, ts: Date.now() }) } catch (e) {}
      // 重算当前门店距离（不重新选店，避免用户正在看的店被换掉）
      const cur = app.globalData.store
      if (cur && cur.storeId) this.setData({ store: this._compatStoreView(cur) })
    }
    // getFuzzyLocation 精度到 1~5km，够算门店距离，且授权门槛比 getLocation 低
    const fn = typeof wx.getFuzzyLocation === 'function' ? wx.getFuzzyLocation : wx.getLocation
    try {
      fn({ type: 'wgs84', success: done, fail: () => done(null) })
    } catch (e) { done(null) }
  },

  loadData() {
    // 门店相关的数据（设施标签、可预约商品）不能只等 pickNearestStore 的回调 ——
    // 那个 callback 只在门店「变化」时才触发（app.js useStore: if (changed) cb(s)），
    // 而 app.onLaunch 的 bootDefaultStore 通常已经把 globalData.store 填好了，
    // 于是首页 onLoad 再调时 prev.storeId === s.storeId → changed=false → 回调一次都不执行，
    // 表现就是「设施标签恒显示暂无服务标签」（和之前 banner 恒空白是同一个根因）。
    // 所以这里先用已有的 store 主动拉一次。
    const booted = (app.globalData && app.globalData.store) || null
    let lastStoreId = null
    if (booted && booted.storeId) {
      lastStoreId = booted.storeId
      this.loadFacilities(booted.storeId)
      this.loadBookingGoods(booted.storeId)
      // 客服信息也要在这里先算一次，理由同上：pickNearestStore 的回调
      // 只在门店变化时触发，onLaunch 已经填好 store 的情况下压根不会跑，
      // 于是「拨打电话」永远读到空的 data.phone → 提示「暂无客服电话」。
      this.setData(this._contactPatch(booted))
    }
    app.pickNearestStore((store) => {
      if (!store) {
        console.warn('[home] pickNearestStore returned null')
        return
      }
      console.log('[home] pickNearestStore =>', JSON.stringify(store).slice(0, 300))
      // 距离计算走 _compatStoreView（包含「计算中…」占位 + 缺位置时后台异步补位）
      const viewStore = this._compatStoreView(store)
      this.setData(Object.assign({
        store: viewStore,
        goods: app.globalData.goods || []
      }, this._contactPatch(store)))
      // 「到店自取」tab 用的是跨店商品，globalData.goods 是按 storeId 拉的，可能为空
      // 这里主动按 merchantId 再拉一次补齐（不论 pickNearestStore 有没有先填过）
      app.loadAllPickupGoods().then((list) => {
        if (Array.isArray(list) && list.length && this.data.tab === 'pickup') {
          this.setData({ goods: list })
        }
      })
      // 只在 storeId 变化时重拉 facilities（占位 → 真实最近切换时才刷）。
      // banner 不在这里 —— 它与门店无关，已在 onLoad 拉过；放这里会因为
      // callback 只在门店变化时触发而永远不执行。
      // 门店真的换了才重拉（避免和上面的首拉重复请求）
      if (store.storeId !== lastStoreId) {
        lastStoreId = store.storeId
        this.loadFacilities(store.storeId)
        this.loadBookingGoods(store.storeId)
      }
    });
  },

  // 拉后端 banner；不兜底：无数据 / 失败 / 缺 imageUrl 都视为错误并提示
  //
  // merchantId 不传 0：bootMerchant 是异步的（且 /api/merchant/info 依赖
  // X-App-Id 解析租户，失败时 globalData.merchant 一直是空），首屏很可能还没拿到。
  // 传 0 会让 merchantId 出现在请求里，一旦后端没有「>0 才过滤」的 guard
  // 就变成 merchant_id=0 精确匹配 → 恒 0 条。省掉这个参数让后端返平台+商户全量，
  // 比传一个假的 0 安全。
  loadBanners() {
    const mid = app.globalData && app.globalData.merchant && app.globalData.merchant.merchantId
    const params = { position: 'home' }
    if (mid) params.merchantId = mid
    api.bannerList(params).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || [];
      if (!Array.isArray(rows) || rows.length === 0) {
        throw new Error('当前商户未配置首页 banner（position=home 0 条），请在后台【门店商品 → 轮播图管理】新增')
      }
      // 微信小程序的 <image> 不支持 http（只允许 https / 本地路径），
      // http 图片会静默显示空白 —— 表现就是「banner 位一片空白」。
      // 后端存量里混着 http://example.com 这类测试数据，且 mapper 按 sort asc 排，
      // sort=0 的测试数据恰好排在最前面把真实 banner 挤到后面几屏。
      // 所以这里直接丢掉非法协议的图，而不是让它占位。
      const dropped = []
      const banners = rows
        .filter((b) => b.imageUrl)
        .map((b) => ({ id: b.bannerId, src: toFullUrl(b.imageUrl), link: b.linkUrl || '' }))
        .filter((b) => {
          if (/^http:\/\//i.test(b.src)) { dropped.push(b.id); return false }
          return true
        });
      if (dropped.length) {
        console.warn('[home] banner 因 http 协议被丢弃（小程序只允许 https）:', dropped.join(','))
      }
      if (banners.length === 0) {
        throw new Error('当前商户 banner 均不可用（缺 imageUrl 或图片是 http，小程序只允许 https），请在后台【门店商品 → 轮播图管理】检查')
      }
      this._bannerToastShown = false
      this.setData({ banners });
    }).catch((err) => {
      console.error('[home] loadBanners FAIL', err)
      if (!this._bannerToastShown) {
        this._bannerToastShown = true
        wx.showToast({ title: '首页 banner 加载失败：' + ((err && (err.msg || err.message)) || '网络异常'), icon: 'none', duration: 4000 })
      }
      // 保持 banners=[]（空数组），让 swiper 显示空白以便排查
      this.setData({ banners: [] });
    });
  },
  /**
   * 「预约服务」tab 的真实商品。
   *
   * 原先这个 tab 是一张写死的本地图 + 写死的「堂食预约」文案，点进去只会跳
   * 预约列表页 —— 商家在后台建了几个 BOOKING 商品，顾客端一个都看不到。
   * 根因是 /api/product/list 早先只收老字段 productType（'0'/'1'），
   * 没有 typeCode 入参，前端根本没法按 v2 类型筛（后端本轮已补 typeCode）。
   *
   * merchantId 优先（预约服务通常跨店可约），拿不到才退回 storeId。
   */
  loadBookingGoods(storeId) {
    const mid = app.globalData && app.globalData.merchant && app.globalData.merchant.merchantId
    const params = { typeCode: 'BOOKING' }
    if (mid) {
      params.merchantId = mid
    } else if (storeId) {
      params.storeId = storeId
    }
    api.productList(params).then((res) => {
      const rows = (res && (res.data || res.rows || res)) || []
      const list = Array.isArray(rows) ? rows.map((p) => ({
        productId: p.productId || p.id,
        name: p.productName || p.name,
        price: p.price != null ? String(p.price) : '0.00',
        marketPrice: p.marketPrice != null ? String(p.marketPrice) : '',
        desc: p.subtitle || '在线选择时段，到店免排队',
        sold: p.sales || p.sold || 0,
        cover: p.cover ? toFullUrl(p.cover) : '/assets/img/BookTypeImg.jpg'
      })) : []
      this.setData({ bookingGoods: list, bookingLoaded: true })
    }).catch((err) => {
      console.warn('[home] loadBookingGoods FAIL', err)
      this.setData({ bookingGoods: [], bookingLoaded: true })
    })
  },
  // 设施标签由后端翻译字典，前端不再硬编码中文
  loadFacilities(storeId) {
    api.storeServices(storeId).then((res) => {
      const rows = (res && (res.data || res)) || [];
      const list = Array.isArray(rows) ? rows : []
      this.setData({
        facilities: list,
        // 卡片上只放前 2 个，第 3 个起靠「详情」抽屉看 ——
        // 标签行宽度有限，全放会把「详情 >」挤到换行
        facilityTags: list.slice(0, 2)
      });
    }).catch((err) => {
      console.warn('[home] loadFacilities FAIL', err)
      this.setData({ facilities: [], facilityTags: [] });
    });
  },
  onBannerChange() {},
  onBannerTap(e) {
    // 跳 banner.linkUrl；没 linkUrl 就不响应点击
    const item = (e && e.currentTarget && e.currentTarget.dataset) || {};
    const link = item.link;
    if (!link) { wx.showToast({ title: '该 banner 未配置跳转链接', icon: 'none' }); return; }
    if (/^https?:\/\//.test(link)) { wx.setClipboardData({ data: link }); return; }
    wx.navigateTo({ url: link, fail: (err) => { console.error('[home] banner navigate FAIL', err); wx.showToast({ title: '跳转失败：' + (err && err.errMsg) || '', icon: 'none' }); } });
  },
  switchTab(e) { this.setData({ tab: e.currentTarget.dataset.t }); },
  goDetail(e) { wx.navigateTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  // 带上当前门店，买单必须落到用户实际所在门店
  goPay() {
    const id = this.data.store && this.data.store.storeId;
    wx.navigateTo({ url: '/pages/pay/index' + (id ? '?storeId=' + id : '') });
  },
  goBooking() { wx.switchTab({ url: '/pages/booking/index' }); },
  goLocation() {
    const s = this.data.store;
    wx.openLocation({
      latitude: s.latitude || 23.405,
      longitude: s.longitude || 113.227,
      name: s.name,
      address: s.address
    });
  },
  goService() {
    wx.showActionSheet({
      itemList: ['拨打电话', '在线咨询'],
      success: (res) => {
        if (res.tapIndex === 0) this.callStore();
        else this.openConsult();
      }
    });
  },
  // 把「门店优先、商家兜底」的结果整理成 setData 用的补丁。
  // 抽出来是因为要在两个地方调（首拉 + pickNearestStore 回调），
  // 降级规则本身在 utils/contact.js 里，纯函数好测。
  _contactPatch(store) {
    const merchant = (app.globalData && app.globalData.merchant) || {}
    const c = resolveContact(store, merchant)
    return {
      callPhone: c.callPhone,
      phone: c.servicePhone,
      // 二维码可能是 /profile/... 相对路径，必须补成绝对地址，
      // 否则 <image> 加载不出来（且 http 的会被小程序静默拒绝）
      qrcode: c.qrcode ? toFullUrl(c.qrcode) : '',
      serviceHours: c.serviceHours,
      isStoreService: c.isStoreService
    }
  },
  // 门店座机：给「联系商家 → 拨打电话」用
  callStore() {
    const tel = this.data.callPhone || this.data.phone;
    if (!tel) return wx.showToast({ title: '暂无联系电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: tel });
  },
  // 客服热线：给「在线咨询」弹窗里的号码用
  callService() {
    const tel = this.data.phone || this.data.callPhone;
    if (!tel) return wx.showToast({ title: '暂无客服电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: tel });
  },
  previewQrcode() {
    if (!this.data.qrcode) return;
    wx.previewImage({ urls: [this.data.qrcode] });
  },
  goVoucher() {
    const id = this.data.store && this.data.store.storeId;
    wx.navigateTo({ url: '/pages/voucher/index/index' + (id ? '?storeId=' + id : '') });
  },
  openConsult() { this.setData({ showConsult: true }); },
  closeConsult() { this.setData({ showConsult: false }); },
  openFacility() { this.setData({ showFacility: true }); },
  closeFacility() { this.setData({ showFacility: false }); }
});
