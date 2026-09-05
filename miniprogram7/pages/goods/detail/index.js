const app = getApp();
const { api, toFullUrl, fixRichText } = require('../../../utils/request.js');
// 交易规则文案 + 富文本空值判定：口径抽到 utils/tradeRules.js，
// 因为这几个翻译表必须跟 PC 建品页的选项文案逐字对齐，得能被单测锁住；
// 商家端预览走的也是本页，口径只能有一份。
const {
  dailyTimeText, excludeDatesText, voucherRulesText,
  collectMethodText, codeTypeText, mutexText, hasRichContent
} = require('../../../utils/tradeRules.js');
const { draftToProduct } = require('../../../utils/productPreview.js');
const { customerPickText } = require('../../../utils/pickRule.js');
const { parseComboItems } = require('../../../utils/comboItems.js');

Page({
  data: {
    id: null,
    product: null,
    canBuyNow: false,
    buyBtnLabel: '加载中…',
    imgIdx: 0,
    showShare: false,
    showAuthPhone: false,
    // 单一状态机：loading / loaded / error / empty
    // 任何时刻只有一个为 true，便于 WXML 用单一 wx:if 判断
    state: 'loading',
    errorMsg: '',
    user: { nickName: '好吃嘴', avatarUrl: '/assets/avatar/default.png' },
    // 分享面板：小程序码 dataUrl（空则显示占位文案），以及原价是否该显示
    shareQr: '',
    shareQrTip: '小程序码加载中',
    showSharePriceOld: false,
    // 预览态：商家端建品页「预览」跳进来，数据是内存里的草稿而不是后端商品。
    // 复用本页而不是另抄一套详情 WXML —— 抄一套的话两边一改版就会漂移，
    // 预览慢慢变成「和顾客看到的不一样」，那还不如没有。
    isPreview: false,
    // 门店服务设施（后端已按 biz_store_service 字典翻译成中文）
    storeServices: [],
    // 商户级展示开关。默认 true（与改造前行为一致）：
    // 假如初值给 false，接口回来前的那一帧会先把销量闪掉再闪回来。
    showSales: true,
    showStock: true,
    // 适用门店完整列表、本店更多商品。
    // 必须在这里给空数组而不是等 setData：WXML 里用 .length 判空，
    // undefined.length 在渲染层会直接报错。
    applicableStores: [],
    moreGoods: []
  },
  onLoad(opts) {
    // 防御：app 异常时给个默认 user，避免 onLoad 内任意 getApp() 失败
    const appInst = (typeof getApp === 'function' ? getApp() : null) || {};
    const m = (appInst.globalData && appInst.globalData.merchant) || {}
    this.setData({
      id: opts.id,
      user: this._normalizeUser(appInst.globalData && appInst.globalData.user),
      merchantName: m.merchantName || '当前商家'
    });
    // 预览态：草稿放在 globalData 里传递（URL 传不下整个表单，且含中文会被截断）
    if (opts.preview === '1' || opts.preview === 1) {
      this._loadPreview(appInst);
      return;
    }
    this.loadProduct(opts.id);
  },

  /**
   * 以预览态渲染商家端建品页的草稿。
   *
   * 走的是和真实商品完全相同的 normalize + WXML，所以商家看到的排版、
   * 类型专属说明、购买须知、套餐详情都与顾客将看到的一致 —— 这才是预览的意义。
   * 差别只有两处：不请求后端，底部购买栏换成「预览中」提示条（见 WXML）。
   */
  _loadPreview(appInst) {
    const draft = (appInst.globalData && appInst.globalData.productPreviewDraft) || null;
    if (!draft) {
      this.setData({ state: 'error', errorMsg: '预览数据丢失，请返回重新点击预览' });
      return;
    }
    try {
      const raw = draftToProduct(draft);
      const normalized = this.normalize(raw, raw.subitemGroups || []);
      this.setData({
        isPreview: true,
        product: normalized,
        state: 'loaded',
        // 预览必须跟会员端一模一样：服务设施和两个展示开关都是顶层字段，
        // 不带的话商家会看到一个没服务设施、却无条件显销量的页面——那不是顾客看到的。
        storeServices: draft.storeServices || [],
        showSales: draft.showSales !== '0' && draft.showSales !== false,
        showStock: draft.showStock !== '0' && draft.showStock !== false,
        canBuyNow: false,
        buyBtnLabel: '预览中，不可购买'
      });
      wx.setNavigationBarTitle({ title: '预览（顾客视角）' });
    } catch (e) {
      console.error('[goods/detail] preview normalize FAIL', e, draft);
      this.setData({ state: 'error', errorMsg: '预览渲染失败：' + e.message });
    }
  },
  onUserUpdate(user) { this.setData({ user: this._normalizeUser(user) }); },
  /**
   * 头像必须过 toFullUrl：后端存的是 /profile/avatar/xxx.png 这种相对路径，
   * 直接塞给 <image src> 会当成小程序包内路径去找，必然裂图 ——
   * 分享面板里显示的就是默认头像而不是用户自己的。
   * pages/mine/index 早就这么处理了，这里漏了。
   */
  _normalizeUser(u) {
    const src = u || {};
    return Object.assign({}, src, {
      nickName: src.nickName || '好吃嘴',
      avatarUrl: src.avatarUrl ? toFullUrl(src.avatarUrl) : '/assets/avatar/default.png'
    });
  },
  // 完全走后端，不做 mock 兜底；接口报错直接把错暴露给用户，便于排查
  loadProduct(id) {
    console.log('[goods/detail] loadProduct start, id=', id);
    if (!id) {
      this.setData({ state: 'error', errorMsg: '商品ID缺失' });
      return;
    }
    this.setData({ state: 'loading', errorMsg: '' });
    // 5s 兜底：避免 setData 被吞掉时一直转圈
    this._loadTimer = setTimeout(() => {
      if (this.data.state === 'loading') {
        console.warn('[goods/detail] loadProduct timeout, force set error');
        this.setData({ state: 'error', errorMsg: '请求超时，请检查网络或后端' });
      }
    }, 5000);
    api.productDetail(id)
      .then((res) => {
        clearTimeout(this._loadTimer);
        console.log('[goods/detail] productDetail response =>', JSON.stringify(res).slice(0, 500));
        // 响应体是 { code, msg, data:{商品}, subitemGroups, typeName, typeTips, storeServices, showSales, showStock }
        // —— data 以外都是兄弟键，所以 api.productDetail 必须用 requestRaw（不解包）。
        const raw = res || {};
        const d = (res && res.data) || res || null;
        const p = (d && (d.data || d)) || null;
        const groups = d && d.subitemGroups ? d.subitemGroups : (p && p.subitemGroups) || []
        if (p && p.productId) {
          let normalized;
          try {
            // 把顶层兄弟键并入商品对象：类型名/说明跟商品一起渲染，
            // 这样 normalize 只面对一个完整对象，预览态也能造出同构数据。
            normalized = this.normalize(Object.assign({}, p, {
              typeName: raw.typeName || p.typeName,
              typeTips: raw.typeTips || p.typeTips,
              storeHours: raw.storeHours || p.storeHours,
              storeRating: raw.storeRating != null ? raw.storeRating : p.storeRating,
              storeNameMain: raw.storeNameMain || p.storeNameMain
            }), groups);
          } catch (e) {
            console.error('[goods/detail] normalize FAIL', e, p);
            this.setData({ state: 'error', errorMsg: '数据规范化失败: ' + e.message });
            return;
          }
          // 购买按钮的可点态和文案必须在这里算好塞进 data。
          // 模板原先写 {{canBuy() ? 'enabled' : 'disabled'}} 和 {{buyBtnDisabledText()}} ——
          // WXML 调不到 Page 方法，前者恒得 undefined（按钮永远是 disabled 灰态），
          // 后者恒渲染成空字符串（按钮上一个字都没有）。也就是说所有商品的
          // 购买按钮都是一个没字的灰块，顾客根本不知道能不能买、买多少钱。
          this.setData({
            product: normalized,
            state: 'loaded',
            // 服务设施 / 展示开关都是顶层兄弟键，不属于商品字段。
            // 开关后端回的是 '1'/'0' 字符串，WXML 里 '0' 是真值，必须在这里归一成 boolean，
            // 否则商家关了开关依旧显示（开关彻底失效）。
            storeServices: raw.storeServices || [],
            showSales: raw.showSales !== '0',
            showStock: raw.showStock !== '0',
            canBuyNow: this.canBuy(normalized),
            buyBtnLabel: this.buyBtnDisabledText(normalized),
            // 适用门店完整列表（后端新增的兄弟键）。
            // 原先这张卡只画主门店一家 + 一行不可点的「N店通用」，
            // 多店商品（实测 999534 三家）顾客根本不知道是哪三家。
            applicableStores: raw.applicableStores || []
          });
          // 本店更多商品单独拉：它不影响主体渲染，失败也不能拖垮详情页，
          // 所以不放进主请求的 then 链里串行等。预览态不拉（草稿没 productId）。
          if (!this.data.isPreview) { this.loadMoreGoods(p.productId); }
        } else if (p && p.code && p.code !== 200) {
          // 后端返回非 200 的业务码
          this.setData({ state: 'error', errorMsg: p.msg || '后端返回业务错误' });
        } else {
          // payload 没有 productId
          this.setData({ state: 'empty', errorMsg: '商品已下架' });
        }
      })
      .catch((err) => {
        clearTimeout(this._loadTimer);
        const msg = (err && (err.errMsg || err.msg)) || (err && err.message) || '网络请求失败';
        console.error('[goods/detail] productDetail FAIL', id, err);
        this.setData({ state: 'error', errorMsg: msg });
      });
  },
  /**
   * 退改政策枚举 → 中文。
   *
   * biz_product.refund_policy 库里两种形态共存：枚举码（ANYTIME）和商家手写的中文
   * （「未核销随时退；已核销不退」）。原先 WXML 直接渲染原值，
   * 枚举那两条商品的「退改政策」就写着一个大写 ANYTIME 给顾客看。
   */
  refundText(v) {
    if (!v) return ''
    return ({
      ANYTIME: '未核销随时退',
      EXPIRED: '过期自动退',
      NEVER: '不支持退款'
    })[v] || v
  },
  normalize(p, groups) {
    const images = p.images
      ? (Array.isArray(p.images) ? p.images : String(p.images).split(','))
      : (p.cover ? [p.cover] : []);
    const typeCode = p.typeCode || (p.productType === '1' ? 'BILL' : p.productType === '2' ? 'BOOKING' : 'GROUPON');
    // 套餐详情的「几选几」必须在这里算成中文再 setData。
    //
    // 原先 WXML 直接写 {{g.pickRule}}，顾客看到的是库里的枚举码 `PICK_2`，
    // 根本不知道自己到店能挑几样 —— 而这是他判断这个套餐值不值的前提。
    // （这张卡因为 subitemGroups 被 request() 解包吃掉而从未真正显示过，
    //   所以它自身这个 bug 也一直没被发现。）
    //
    // 用 utils/pickRule.js 而不是在这里再写一份：商家端编辑页用的是同一份，
    // 两边各算一遍早晚会漂移成履约纠纷。WXML 里一律不写函数调用。
    const subitemGroups = Array.isArray(groups) ? groups.map(g => {
      const subitems = Array.isArray(g.subitems) ? g.subitems.map(s => ({
        subitemId: s.subitemId,
        subitemName: s.subitemName,
        quantity: s.quantity || 1,
        price: s.price != null ? String(s.price) : '0.00'
      })) : [];
      return {
        groupId: g.groupId,
        groupName: g.groupName,
        pickRule: g.pickRule || 'ALL',
        sort: g.sort || 0,
        subitems: subitems,
        pickText: customerPickText({ pickRule: g.pickRule || 'ALL', subitems: subitems })
      };
    }) : [];
    // 组合券包（COMBO）的搭配明细存在 biz_product_ext.combo_items_json，
    // 不走 biz_product_subitem 那张表。原先详情页的 wx:elif 读的是
    // product.packages —— 全库只有 utils/mock.js 造过这个字段，后端零命中，
    // 所以真机上 COMBO 的「套餐详情」永远是空的：顾客买一个券包，
    // 看不到里面到底包了哪几张券。
    const comboItems = parseComboItems(p);
    return {
      ...p,
      name: p.productName || p.name,
      price: p.price != null ? String(p.price) : '0.00',
      typeCode: typeCode,
      // typeName 优先用后端从 biz_product_type 下发的值；typeText() 只作为字典缺行时的兑底。
      // 原先无条件走 typeText()，GROUPON 永远显示「团购套餐」，
      // 而运营早就在后台把它改成了「到店自取」。
      typeName: p.typeName || this.typeText(typeCode),
      typeTips: p.typeTips || '',
      refundPolicyText: this.refundText(p.refundPolicy),
      faceValue: p.faceValue != null ? String(p.faceValue) : '',
      minConsume: p.minConsume != null ? String(p.minConsume) : '',
      totalTimes: p.totalTimes || 0,
      periodType: p.periodType || '',
      periodCount: p.periodCount || 0,
      totalValue: p.totalValue != null ? String(p.totalValue) : '',
      requireXiaoxin: p.requireXiaoxin || 0,
      // V2.6 P1 限制条件字段
      validityDays: p.validityDays || 0,
      limitPerUser: p.limitPerUser || 0,
      maxPerOrder: p.maxPerOrder || 0,
      maxPersons: p.maxPersons || 0,
      refundPolicy: p.refundPolicy || '',
      notice: p.notice || '',
      otherNotice: p.otherNotice || '',
      bookingRequired: p.bookingRequired || 0,
      saleStartDate: p.saleStartDate || '',
      saleEndDate: p.saleEndDate || '',
      extraFeeDesc: p.extraFeeDesc || '',
      saleStartText: p.saleStartDate ? this._fmtDate(p.saleStartDate) : '',
      saleEndText: p.saleEndDate ? this._fmtDate(p.saleEndDate) : '',
      // 折扣文案（X.X 折）
      discountText: (function(){
        const now = Number(p.price), old = Number(p.marketPrice);
        if (!old || old <= now) return '';
        const d = (now / old * 10).toFixed(1);
        return d + ' 折热销中';
      })(),
      // 适用门店信息
      storeCount: (p.storeIds ? String(p.storeIds).split(',').filter(x=>x).length : (p.storeId ? 1 : 0)),
      storeCountText: (p.storeIds ? String(p.storeIds).split(',').filter(x=>x).length : (p.storeId ? 1 : 0)) + '家',
      storeScopeText: p.storeNames || (p.storeId ? '当前门店适用' : '全部门店适用'),
      subitemGroups: subitemGroups,
      comboItems: comboItems,
      sold: p.sales || p.sold || 0,
      cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png',
      images: images.filter((u) => !!u).map((u) => toFullUrl(u)),
      // 图文详情同样过一道空值判定：商家把富文本清空后库里存的是 <p><br></p>，
      // 直接当真会在详情页凭空多出一张只有标题的空卡。
      detail: hasRichContent(p.detail) ? fixRichText(p.detail) : '',
      // 商家手写的补充说明。notice 存的是富文本，得先剔掉“看着有值、
      // 实际没字”的底卡（富文本编辑器清空后会留 <p><br></p>），
      // 否则详情页会凭空多出一张只有标题的空卡。
      noticeRich: hasRichContent(p.notice) ? fixRichText(p.notice) : '',
      // 交易规则：全部在这里算成中文，WXML 只负责展。
      // 这整批字段后端一直在下发（ext 走 association，collectMethod /
      // mutexWithStorePromotion 在 selectProductVo 里），是前端从未读过。
      mutexText: mutexText(p.mutexWithStorePromotion),
      collectMethodText: collectMethodText(p.collectMethod),
      codeTypeText: codeTypeText(p.ext),
      dailyTimeText: dailyTimeText(p.ext),
      excludeDatesText: excludeDatesText(p.ext),
      voucherRulesText: voucherRulesText(p.ext)
    };
  },
  // 顶部大图原先是单张静态 image，可 hero-page 已经在显示「1/3」这种页码 ——
  // 页码存在但翻不动，用户以为图挂了。改 swiper 后 imgIdx 才真跟得上
  onSwiperChange(e) {
    this.setData({ imgIdx: e.detail.current });
  },
  // 本店更多商品。
  //
  // 详情页底部那张卡的 WXML 分支一直存在，读的是 product.moreGoods，
  // 而后端从未下发过这个字段 —— 真机上它永远不可能出现，
  // 连标题里的「3」都是写死的。现在走新端点 /api/product/{id}/more。
  loadMoreGoods(id) {
    if (!id) return;
    api.productMore(id, 6)
      .then((list) => {
        const arr = Array.isArray(list) ? list : [];
        this.setData({
          moreGoods: arr.map((g) => ({
            productId: g.productId,
            name: g.productName || g.name || '',
            price: g.price != null ? String(g.price) : '0.00',
            // 市场价只在真的高于现价时才给前端，否则两个一模一样的数字
            // 并排、后面那个还带删除线，看着像 bug（分享面板踩过同一个坑）。
            marketPrice: (g.marketPrice && Number(g.marketPrice) > Number(g.price)) ? String(g.marketPrice) : '',
            cover: g.cover ? toFullUrl(g.cover) : '/assets/img/RestaurantImg.png'
          }))
        });
      })
      .catch(() => { /* 推荐位拉不到就不展，不弹错 */ });
  },
  // 适用门店逐家的「联系门店」。多店商品下每行都带自己的 phone，
  // 不能像首页那样只拿一个全局号码，否则顶着“万象城店”拨出去的是旗舰店。
  onCallStore(e) {
    const tel = e.currentTarget.dataset.phone;
    if (!tel) return wx.showToast({ title: '暂无联系电话', icon: 'none' });
    wx.makePhoneCall({ phoneNumber: String(tel) });
  },
  onRetry() { this.loadProduct(this.data.id); },
  onBack() {
    // 预览态是从建品页 navigateTo 过来的，必须回到那个还留着草稿的页面。
    // 切到首页会让商家丢掉整张已填的表单。
    if (this.data.isPreview) { wx.navigateBack({ delta: 1 }); return; }
    wx.switchTab({ url: '/pages/home/index', fail: () => wx.navigateBack({ delta: 1 }) });
  },
  onExitPreview() { wx.navigateBack({ delta: 1 }); },
  goDetail(e) { wx.redirectTo({ url: '/pages/goods/detail/index?id=' + e.currentTarget.dataset.id }); },
  goStore() { wx.switchTab({ url: '/pages/home/index' }); },
  goOrderList() { wx.navigateTo({ url: '/pages/order/list/index' }); },
  openShare() {
    const p = this.data.product || {};
    // 原价只在真的比现价高时才显示。原先写死成 sp-old 也绑 product.price，
    // 于是「¥50 ¥50」两个一样的数字并排、还带删除线，看着像 bug。
    const now = Number(p.price), old = Number(p.marketPrice);
    this.setData({
      showShare: true,
      showSharePriceOld: !!(old && now && old > now)
    });
    this._loadShareQr();
  },
  closeShare() { this.setData({ showShare: false }); },
  /**
   * 拉商品小程序码。原先面板里那个「码」是 CSS 渐变拼的假纹理（.qr-circle
   * 用 radial-gradient + conic-gradient 模拟），扫不出任何东西；海报页则调
   * /api/distributor/qrcode，那个端点要求调用者是推客，普通会员必然 403。
   * 现在走 /api/product/{id}/qrcode，与推客身份无关，人人可用。
   */
  _loadShareQr() {
    if (this.data.shareQr) return;          // 同一个商品只拉一次
    if (this._qrLoading) return;
    const id = this.data.id || (this.data.product && this.data.product.productId);
    if (!id) return;
    this._qrLoading = true;
    api.productQrcode(id)
      .then((res) => {
        const d = (res && (res.data || res)) || {};
        const url = d.dataUrl || d.url || '';
        this.setData({ shareQr: url, shareQrTip: url ? '' : '小程序码暂不可用' });
      })
      .catch((err) => {
        console.warn('[goods/detail] productQrcode FAIL', err);
        // 不弹 toast：分享面板已经打开了，这里失败只降级成占位文案，
        // 用户仍可用「发送给朋友」这条不依赖码的路径
        this.setData({ shareQr: '', shareQrTip: '小程序码暂不可用' });
      })
      .finally(() => { this._qrLoading = false; });
  },
  /**
   * 「收藏」点了没反应的根因：<button open-type="favorite"> 只有在页面
   * 实现了 onAddToFavorites 且**当前小程序版本支持收藏**时才有效，
   * 而开发者工具/未发布版本上这个 open-type 是静默失效的 —— 按钮能点、
   * 什么都不发生，用户以为坏了。这里补一个 bindtap 给出明确反馈。
   * 真机已发布版本上 open-type 生效时，微信会直接弹收藏浮层，
   * bindtap 的 toast 也不影响（两者都会走，浮层盖在上面）。
   */
  onFavTap() {
    wx.showToast({ title: '点击右上角「···」可收藏', icon: 'none', duration: 2000 });
  },
  closeAuthPhone() { this.setData({ showAuthPhone: false }); },
  onBuy() {
    if (this.data.isPreview) {
      wx.showToast({ title: '预览中，返回后可保存草稿', icon: 'none' });
      return;
    }
    if (!this.canBuy()) {
      wx.showToast({ title: this.limitText() || '当前不可购买', icon: 'none' });
      return;
    }
    if (!app.globalData.user.logged) {
      wx.navigateTo({ url: '/pages/login/login' });
      return;
    }
    if (!app.globalData.user.phone) {
      this.setData({ showAuthPhone: true });
      return;
    }
    wx.navigateTo({ url: '/pages/order/submit/index?id=' + this.data.id });
  },
  typeText(code) {
    return ({
      GROUPON: '团购套餐', VOUCHER: '代金券', TIMECARD: '次卡',
      STORED_CARD: '储值卡', PERIOD_CARD: '周期卡', HUIXIANG_CARD: '惠享卡',
      COMBO: '组合券包', BILL: '到店买单', BOOKING: '预约服务',
      PRESALE: '预售券', PICKUP_VOUCHER: '提货券'
    })[code] || (code || '团购')
  },
  /**
   * 限制条件展示文案（按优先级）
   *  - 库存售罄 → "已售罄"
   *  - 售卖期外 → "售卖期：xxxx 至 xxxx"
   *  - 否则显示 默认限制
   */
  limitText() {
    const p = this.data.product
    if (!p) return ''
    if (p.stock === 0) return '已售罄'
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) {
      return '售卖期：' + this._fmtDate(p.saleStartDate) + ' 起'
    }
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) {
      return '售卖期已过（' + this._fmtDate(p.saleEndDate) + ' 截止）'
    }
    return '可购买'
  },
  _dateInFuture(s) {
    if (!s) return false
    const t = new Date(String(s).replace(/-/g, '/')).getTime()
    return t > Date.now()
  },
  _dateInPast(s) {
    if (!s) return false
    const t = new Date(String(s).replace(/-/g, '/')).getTime()
    return t < Date.now()
  },
  _fmtDate(s) {
    if (!s) return ''
    const str = String(s)
    return str.length >= 10 ? str.substring(0, 10) : str
  },
  /** 是否允许立即购买 */
  canBuy(prod) {
    const p = prod || this.data.product
    if (!p) return false
    if (p.stock === 0) return false
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) return false
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) return false
    return true
  },
  /** 购买按钮 disabled 文案 */
  buyBtnDisabledText(prod) {
    const p = prod || this.data.product
    if (!p) return '加载中…'
    if (p.stock === 0) return '已售罄'
    if (p.saleStartDate && this._dateInFuture(p.saleStartDate)) return '未到售卖期'
    if (p.saleEndDate && this._dateInPast(p.saleEndDate)) return '已过售卖期'
    return this.buyBtnText(p)
  },
  buyBtnText(prod) {
    const p = prod || this.data.product
    const t = p && p.typeCode
    const price = (p && p.price) || '0.00'
    if (t === 'BILL') return '买单 ¥' + price
    if (t === 'BOOKING') return '立即预约 ¥' + price
    if (t === 'VOUCHER') return '购买代金券 ¥' + price
    if (t === 'TIMECARD') return '购买次卡 ¥' + price
    if (t === 'STORED_CARD') return '充值 ¥' + price
    if (t === 'PERIOD_CARD') return '开通周期卡 ¥' + price
    if (t === 'COMBO') return '购买组合券包 ¥' + price
    return '立即购买 ¥' + price
  },
  onGotPhone(e) {
    if (e.detail.errMsg && e.detail.errMsg.indexOf('ok') !== -1) {
      const phone = e.detail.phoneNumber || '';
      app.globalData.user.phone = phone;
      this.setData({ showAuthPhone: false, user: app.globalData.user });
      api.updatePhone({ code: e.detail.code }).then((res) => {
        const real = res && (res.phone || (res.data && res.data.phone));
        if (real) {
          app.globalData.user.phone = real;
          this.setData({ user: app.globalData.user });
        }
      }).catch(() => {});
      wx.showToast({ title: '已授权', icon: 'success' });
      setTimeout(() => wx.navigateTo({ url: '/pages/order/submit/index?id=' + this.data.id }), 400);
    } else {
      wx.showToast({ title: '已取消授权', icon: 'none' });
      this.setData({ showAuthPhone: false });
    }
  },
  // ====== 分享 / 收藏 / 保存图片 ======
  /**
   * 微信胶囊菜单「转发给朋友」与弹窗中<button open-type="share">都会触发此方法
   * 走自己拼的 path（带 productId），让对方点进来直接定位到该商品详情
   */
  onShareAppMessage() {
    const p = this.data.product;
    const id = (p && (p.productId || p.id)) || this.data.id || '';
    const m = (getApp().globalData && getApp().globalData.merchant) || {};
    const name = (p && (p.name || p.productName)) || '好物';
    const price = (p && p.price) || '';
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    const shareImg = rawImg ? toFullUrl(rawImg) : '';
    return {
      // 商家名拿不到时就只发商品名，不能写死「洞天团购」——
      // 这是多商户平台，每个商户有自己的品牌名，硬编码等于把别家商品
      // 挂上我们的名字发出去
      title: name + (price ? ' ¥' + price : '') + (m.merchantName ? ' | ' + m.merchantName : ''),
      path: '/pages/goods/detail/index?id=' + id,
      imageUrl: shareImg
    };
  },
  /**
   * 微信胶囊菜单「分享到朋友圈」
   * 分享到朋友圈时 imageUrl 必填，否则会触发警告
   */
  onShareTimeline() {
    const p = this.data.product;
    const m = (getApp().globalData && getApp().globalData.merchant) || {};
    const name = (p && (p.name || p.productName)) || '好物';
    const price = (p && p.price) || '';
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    const shareImg = rawImg ? toFullUrl(rawImg) : '';
    return {
      // 商家名拿不到时就只发商品名，不能写死「洞天团购」——
      // 这是多商户平台，每个商户有自己的品牌名，硬编码等于把别家商品
      // 挂上我们的名字发出去
      title: name + (price ? ' ¥' + price : '') + (m.merchantName ? ' | ' + m.merchantName : ''),
      query: 'id=' + ((p && (p.productId || p.id)) || this.data.id || ''),
      imageUrl: shareImg
    };
  },
  /**
   * 微信基础库 2.10.0+ 起的「收藏」按钮（弹窗中<button open-type="favorite">触发）
   * 静默成功，无需做额外处理；保留钩子便于以后打点
   */
  onAddToFavorites() {
    const p = this.data.product;
    const rawImg = (p && (p.images && p.images[0] || p.cover)) || '';
    return {
      title: (p && (p.name || p.productName)) || '好物',
      imageUrl: rawImg ? toFullUrl(rawImg) : '',
      query: 'id=' + ((p && (p.productId || p.id)) || this.data.id || '')
    };
  },
  /**
   * 保存图片：跳到海报页（pages/goods/share/index）让用户在那里点保存按钮
   * 之所以跳页而不是在弹窗里直接画海报：弹窗层 canvas 在很多机型上 z-index/层级有问题
   * 海报页有专门的 canvas 绘制 + 下载 + 保存相册完整流程
   */
  onSavePoster() {
    const id = (this.data.product && (this.data.product.productId || this.data.product.id)) || this.data.id;
    if (!id) {
      wx.showToast({ title: '商品未加载', icon: 'none' });
      return;
    }
    this.setData({ showShare: false });
    wx.navigateTo({ url: '/pages/goods/share/index?id=' + id });
  }
});
