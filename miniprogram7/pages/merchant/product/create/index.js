/**
 * 商家端商品创建 / 编辑 — 抖音来客复刻
 *
 * ⚠️ 本页原先只能新增，不能编辑：列表页 onEdit 会带 ?productId=xxx 跳过来，
 * 但这里的 onLoad() 完全没读这个参数，整个文件也只有 productAdd 没有 productUpdate。
 * 结果是商家点「编辑」打开的是一张空表单，填完保存又新建了一个重复商品 ——
 * 是会污染数据的真实缺陷。本轮补齐编辑态（回填 + PUT + 类型锁定）。
 *
 * 第 1 页 /pick：选「商品品类」+「商品类型」（底部弹窗）
 * 第 2 页 /form：tab 切换的 5 tab 长表单
 *   - 基础信息：只读展示已选品类+类型
 *   - 商家信息：门店（必选）
 *   - 商品信息：名称/副标题/价格/头图
 *   - 售卖信息：库存/限购/有效期
 *   - 交易规则：使用说明
 * 底部固定双按钮：预览 | 创建
 *
 * 设计规范：蓝色 #1677FF 主题，白卡片，浅灰 #F5F5F7 背景
 */
const { api } = require('../../../../utils/request.js')

const TYPE_DESC = {
  GROUPON: '套餐商品，搭配自由，快速吸引顾客',
  VOUCHER: '现金抵扣券，出单快，便于引流增收',
  TIMECARD: '一次购买分次核销，增加用户粘性',
  STORED_CARD: '通过存储金额，引导顾客多次到店消费',
  PERIOD_CARD: '月/季/年卡等长周期商品，方便锁客',
  HUIXIANG_CARD: '大额分次核销，提前锁客',
  PRESALE: '先买后约，方便用户直播及短视频囤货',
  PICKUP_VOUCHER: '支持多规格管理和门店库存设置',
  COMBO: '团购、代金券、实物自由组合',
  BOOKING: '预约类商品'
}

const PERIOD_OPTIONS = [
  { value: 'MONTH', label: '月' },
  { value: 'QUARTER', label: '季' },
  { value: 'YEAR', label: '年' }
]

/** 11 种 typeCode + 展示顺序（用于弹窗） */
const TYPE_LIST = [
  { typeCode: 'GROUPON', typeName: '团购套餐' },
  { typeCode: 'VOUCHER', typeName: '代金券' },
  { typeCode: 'TIMECARD', typeName: '次卡' },
  { typeCode: 'STORED_CARD', typeName: '储值卡' },
  { typeCode: 'PERIOD_CARD', typeName: '周期卡' },
  { typeCode: 'HUIXIANG_CARD', typeName: '惠享卡' },
  { typeCode: 'PRESALE', typeName: '预售券', disabled: true, disabledTip: '暂不支持在抖音来客App创建，请前往抖音来客网页端进行操作' },
  { typeCode: 'PICKUP_VOUCHER', typeName: '提货券', disabled: true, disabledTip: '暂不支持在抖音来客App创建，请前往抖音来客网页端进行操作' },
  { typeCode: 'COMBO', typeName: '组合券包' },
  { typeCode: 'BILL', typeName: '到店买单', disabled: true, disabledTip: '到店买单无需创建商品' },
  { typeCode: 'BOOKING', typeName: '预约服务' }
]

/**
 * 字段定义 - 按 typeCode 分组，每组有 sections
 * sections 顺序: 商家信息 → 商品信息 → 售卖信息 → 交易规则
 * 实际显示顺序由 4 个 tab 决定
 */
const FIELDS_BY_TYPE = {
  GROUPON: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, placeholder: '商品名称需与商品内容保持一致，不得含有错别字及特殊符号', section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', placeholder: '0', section: 'product' },
      { key: 'marketPrice', label: '市场价', required: false, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'faceValue', label: '划线价（原价）', required: false, type: 'digit', prefix: '¥', placeholder: '不填则不展示划线价', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, placeholder: '0', section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, placeholder: '0 = 不限', section: 'sale' },
      { key: 'maxPerOrder', label: '单次最多使用', required: true, type: 'number', default: 1, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'bookingRequired', label: '需要预约', type: 'switch', default: 0, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, placeholder: '使用规则 / 退改政策', section: 'trade' }
    ]
  },
  VOUCHER: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'minConsume', label: '起用金额', required: false, type: 'digit', prefix: '满 ¥', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'maxPerOrder', label: '单次最多使用', required: true, type: 'number', default: 1, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  TIMECARD: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'faceValue', label: '次卡总价值', required: false, type: 'digit', prefix: '¥', placeholder: '单次价 × 总次数', section: 'product' },
      { key: 'totalTimes', label: '总次数', required: true, type: 'number', placeholder: '可核销次数', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'requireXiaoxin', label: '冷静期（防退款）', type: 'switch', default: 1, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  STORED_CARD: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'faceValue', label: '代金券面值', required: true, type: 'digit', prefix: '¥', placeholder: '可抵扣金额', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'requireXiaoxin', label: '冷静期（防退款）', type: 'switch', default: 1, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  PERIOD_CARD: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'periodType', label: '周期类型', required: true, type: 'period-picker', section: 'product' },
      { key: 'periodCount', label: '周期数', required: true, type: 'number', default: 1, section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'requireXiaoxin', label: '冷静期（防退款）', type: 'switch', default: 1, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  HUIXIANG_CARD: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'faceValue', label: '次卡总价值', required: true, type: 'digit', prefix: '¥', placeholder: '单次价 × 总次数', section: 'product' },
      { key: 'totalTimes', label: '总次数', required: true, type: 'number', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'requireXiaoxin', label: '冷静期（防退款）', type: 'switch', default: 1, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  COMBO: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' },
      { key: 'faceValue', label: '组合总价值', required: true, type: 'digit', prefix: '¥', placeholder: '各子项原价之和', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'maxPerOrder', label: '单次最多使用', required: true, type: 'number', default: 1, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'requireXiaoxin', label: '冷静期（防退款）', type: 'switch', default: 1, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  },
  BOOKING: {
    base: [
      { key: 'productName', label: '商品名称', required: true, type: 'text', max: 40, section: 'product' },
      { key: 'subtitle', label: '副标题', required: false, type: 'text', max: 60, section: 'product' }
    ],
    price: [
      { key: 'price', label: '售价', required: true, type: 'digit', prefix: '¥', section: 'product' }
    ],
    sale: [
      { key: 'stock', label: '库存数量', required: true, type: 'number', default: 0, section: 'sale' },
      { key: 'limitPerUser', label: '每人限购', required: false, type: 'number', default: 0, section: 'sale' },
      { key: 'validityDays', label: '有效期', required: true, type: 'number', default: 30, suffix: '天', section: 'trade' }
    ],
    detail: [
      { key: 'bookingRequired', label: '需要预约', type: 'switch', default: 1, disabled: true, section: 'trade' },
      { key: 'notice', label: '使用说明', type: 'textarea', max: 500, section: 'trade' }
    ]
  }
}

Page({
  data: {
    // 编辑态：productId 有值就是改已有商品，走 PUT；否则 POST 新建
    productId: null,
    isEdit: false,
    // 收款方式只读展示文案（跟随 form.collectMethod，HEAD/STORE 两种）
    collectMethodLabel: '总部统一收款',
    // step: 1 = 选类型页, 2 = tab 表单页
    step: 1,
    activeTab: 0,           // 0/1/2/3/4：当前高亮的锚点（不再控制渲染）
    scrollIntoView: '',     // 点标题时置为 sec-N 触发定位，滚动同步后清空
    tabLabels: ['基础信息', '商家信息', '商品信息', '售卖信息', '交易规则'],
    typeList: TYPE_LIST,

    // 已选
    pickedType: '',
    pickedTypeName: '',
    pickedTypeDesc: '',

    // 弹窗
    categorySheet: false,   // 商品品类弹窗
    typeSheet: false,       // 商品类型弹窗
    // 品类来自 biz_product_category（/api/product/category/list），不写死中文串：
    // 原先这里硬编码 5 条「购物·服饰鞋帽·服装」之类，和库里真实品类（美食/丽人/
    // 住宿…）完全对不上，商家只能在 5 个不相干的服饰品类里挑一个。
    categoryList: [],
    categoryLoaded: false,
    pickedCategory: '',

    // 表单
    storeName: '',
    storeId: null,
    storeIds: [],
    storeOptions: [{ id: 0, label: '请选择门店' }],
    // 适用门店改多选（后台一直是多选，商家端原先只能单选，
    // 同一个套餐在连锁的第 2 家店就没法卖）
    storePickList: [],        // [{ id, label, checked }]
    storeSheet: false,
    // 投放渠道字典（平台级配置，按 channelGroup 分组展示）
    channelGroups: [],
    channelSheet: false,
    channelSummary: '',
    periodOptions: PERIOD_OPTIONS,
    periodIdx: 0,

    form: {
      storeId: 0, categoryId: 0,
      storeIdList: [],
      productName: '', subtitle: '',
      marketPrice: '', price: '', faceValue: '', minConsume: '', totalTimes: '',
      periodType: 'MONTH', periodCount: 1,
      stock: 0, limitPerUser: 0, maxPerOrder: 1, validityDays: 30,
      bookingRequired: 0, requireXiaoxin: 0,
      notice: '',
      // 与后台对齐的字段（原先商家端 21 个字段，后台 33 个）
      saleChannels: [],
      staffPromote: 0,
      codeType: 'MERCHANT',
      refundPolicy: 'ANYTIME',
      // 收款方式跟随商家支付配置，HEAD=总部统一收款（与 wxml 展示的文案一致）。
      // 原先写 'PLATFORM' 是把「券码类型」语义误用到这一列，导致
      // wxml 显示「总部统一收款」而库里存 PLATFORM —— 显示与落库不一致。
      collectMethod: 'HEAD',
      mutexWithStorePromotion: 1,
      extraFeeDesc: ''
    },

    fields: { base: [], price: [], sale: [], detail: [] },
    sectionProduct: [],
    sectionSale: [],
    sectionTrade: [],

    canSubmit: false,
    submitting: false
  },

  onLoad(query) {
    this._initMerchantContext()
    this._loadCategories()
    this._loadChannels()
    this._loadTypes()
    // 列表页「编辑」带过来的 productId。原先这里没读，导致编辑变新增。
    const pid = query && query.productId ? Number(query.productId) : null
    if (pid) {
      this.setData({ productId: pid, isEdit: true })
      wx.setNavigationBarTitle({ title: '编辑商品' })
      this._loadProduct(pid)
    }
  },

  /**
   * 编辑态回填。
   *
   * 直接跳到第 2 步：品类和类型都已经定了，不能再让商家重选 ——
   * 换类型等于换一套必填字段和核销逻辑，已卖出的券会对不上。
   * 所以编辑时第 1 步整个跳过，类型在 tab0 里只读展示。
   */
  _loadProduct(pid) {
    wx.showLoading({ title: '加载中...', mask: true })
    api.productDetail(pid).then(res => {
      wx.hideLoading()
      const p = (res && (res.data || res)) || {}
      const ext = p.ext || {}
      const tc = p.typeCode || 'GROUPON'
      const item = TYPE_LIST.find(t => t.typeCode === tc)
      // _loadTypes 是并行发的，这里可能还没回来；回来后 _loadTypes 会再修正一次
      const dictType = (this._typeDict || {})[tc]
      const num = (v) => (v === null || v === undefined ? '' : String(v))

      const form = Object.assign({}, this.data.form, {
        storeId: p.storeId || 0,
        storeIdList: p.storeIds ? String(p.storeIds).split(',').filter(v => v).map(Number) : (p.storeId ? [p.storeId] : []),
        categoryId: p.categoryId || 0,
        productName: p.productName || '',
        subtitle: p.subtitle || '',
        price: num(p.price),
        marketPrice: num(p.marketPrice),
        faceValue: num(p.faceValue),
        minConsume: num(p.minConsume),
        totalTimes: num(p.totalTimes),
        periodType: p.periodType || 'MONTH',
        periodCount: p.periodCount || 1,
        stock: p.stock == null ? 0 : p.stock,
        limitPerUser: p.limitPerUser == null ? 0 : p.limitPerUser,
        maxPerOrder: p.maxPerOrder == null ? 1 : p.maxPerOrder,
        validityDays: p.validityDays == null ? 30 : p.validityDays,
        bookingRequired: p.bookingRequired ? 1 : 0,
        requireXiaoxin: p.requireXiaoxin ? 1 : 0,
        notice: p.notice || '',
        refundPolicy: p.refundPolicy || 'ANYTIME',
        collectMethod: p.collectMethod || 'HEAD',
        mutexWithStorePromotion: p.mutexWithStorePromotion === 0 ? 0 : 1,
        extraFeeDesc: p.extraFeeDesc || '',
        saleChannels: ext.saleChannels ? String(ext.saleChannels).split(',').filter(v => v) : [],
        staffPromote: ext.staffPromote ? 1 : 0,
        codeType: ext.codeType || 'MERCHANT'
      })
      // 字数计数器：WXML 用 form[key + '__len']，不补的话编辑态计数全是 0
      ;['productName', 'subtitle', 'notice'].forEach(k => { form[k + '__len'] = String(form[k] || '').length })

      this.setData({
        pickedType: tc,
        pickedTypeName: (dictType && dictType.typeName) || (item && item.typeName) || tc,
        pickedTypeDesc: (dictType && dictType.typeDesc) || TYPE_DESC[tc] || '',
        pickedCategory: p.categoryName || '（沿用原品类）',
        collectMethodLabel: form.collectMethod === 'STORE' ? '门店独立收款' : '总部统一收款',
        form,
        step: 2,
        activeTab: 0
      })
      this._rebuildFields()
      this._syncStorePickList()
      this._syncChannelSummary()
      this._recomputeSubmit()
    }).catch(err => {
      wx.hideLoading()
      wx.showModal({
        title: '加载失败',
        content: (err && (err.msg || err.message)) || '商品不存在或无权访问',
        showCancel: false,
        success: () => wx.navigateBack({ delta: 1 })
      })
    })
  },

  /** 拉投放渠道字典。默认勾选由服务端算，新建才套默认；编辑以商品已存的为准 */
  _loadChannels() {
    api.saleChannelEnabled().then(res => {
      const list = (res && res.data) || []
      const labels = { SELF: '自有渠道', SOCIAL: '社交分享', OFFLINE: '线下物料' }
      const map = {}
      const order = []
      list.forEach(c => {
        const g = c.channelGroup || 'OTHER'
        if (!map[g]) { map[g] = []; order.push(g) }
        map[g].push(c)
      })
      const groups = order.map(g => ({ name: g, label: labels[g] || g, items: map[g] }))
      const patch = { channelGroups: groups }
      if (!this.data.isEdit && !(this.data.form.saleChannels || []).length) {
        const def = (res && res.defaultCodes) || ''
        patch['form.saleChannels'] = def ? def.split(',').filter(v => v) : []
      }
      this.setData(patch, () => this._syncChannelSummary())
    }).catch(() => { this.setData({ channelGroups: [] }) })
  },

  _initMerchantContext() {
    const staff = wx.getStorageSync('staffUser') || {}
    const storeId = staff.storeId || null
    const storeIds = staff.storeIds && staff.storeIds.length ? staff.storeIds : (storeId ? [storeId] : [])
    // 优先用带门店名的 stores（登录/切店接口返的），没有才退回「门店{id}」。
    // 多店老板靠编号根本分不清是哪家店，勾错了保存时才被服务端拦下。
    const nameOf = {}
    ;(staff.stores || []).forEach(st => {
      const sid = st && (st.storeId !== undefined ? st.storeId : st.id)
      if (sid !== undefined && sid !== null) nameOf[sid] = st.storeName || st.label
    })
    const opts = [{ id: 0, label: '请选择门店' }]
    if (storeIds && storeIds.length) {
      storeIds.forEach(id => opts.push({
        id,
        label: nameOf[id] || (storeIds.length === 1 && staff.storeName ? staff.storeName : `门店${id}`)
      }))
    }
    this.setData({
      storeName: staff.storeName || '',
      storeId, storeIds, storeOptions: opts,
      'form.storeId': storeIds && storeIds.length ? storeIds[0] : 0
    }, () => {
      // 新建时默认勾上当前门店，省掉一次点击；编辑态由 _loadProduct 覆盖
      if (!this.data.isEdit && storeIds && storeIds.length) {
        this.setData({ 'form.storeIdList': [storeIds[0]] })
      }
      this._syncStorePickList()
    })
  },

  /** 把 form.storeIdList 同步成弹窗要的 [{id,label,checked}] */
  _syncStorePickList() {
    const chosen = this.data.form.storeIdList || []
    const list = (this.data.storeIds || []).map(id => {
      const opt = (this.data.storeOptions || []).find(o => o.id === id)
      return { id, label: (opt && opt.label) || ('门店' + id), checked: chosen.indexOf(id) >= 0 }
    })
    this.setData({ storePickList: list })
  },

  onOpenStoreSheet() {
    if (!(this.data.storeIds || []).length) {
      wx.showToast({ title: '当前账号未绑定门店', icon: 'none' }); return
    }
    this._syncStorePickList()
    this.setData({ storeSheet: true })
  },
  onCloseStoreSheet() { this.setData({ storeSheet: false }) },

  onToggleStore(e) {
    const id = Number(e.currentTarget.dataset.id)
    const cur = (this.data.form.storeIdList || []).slice()
    const i = cur.indexOf(id)
    if (i >= 0) cur.splice(i, 1); else cur.push(id)
    this.setData({ 'form.storeIdList': cur }, () => {
      this._syncStorePickList()
      this._recomputeSubmit()
    })
  },

  onOpenChannelSheet() { this.setData({ channelSheet: true }) },
  onCloseChannelSheet() { this.setData({ channelSheet: false }) },

  onToggleChannel(e) {
    const code = e.currentTarget.dataset.code
    const cur = (this.data.form.saleChannels || []).slice()
    const i = cur.indexOf(code)
    if (i >= 0) cur.splice(i, 1); else cur.push(code)
    this.setData({ 'form.saleChannels': cur }, () => this._syncChannelSummary())
  },

  /** 渠道行的摘要文案 + 每个渠道的勾选态（WXML 里没法直接算 indexOf） */
  _syncChannelSummary() {
    const chosen = this.data.form.saleChannels || []
    const groups = (this.data.channelGroups || []).map(g => ({
      name: g.name,
      label: g.label,
      items: g.items.map(c => Object.assign({}, c, { checked: chosen.indexOf(c.channelCode) >= 0 }))
    }))
    const names = []
    groups.forEach(g => g.items.forEach(c => { if (c.checked) names.push(c.channelName) }))
    this.setData({
      channelGroups: groups,
      channelSummary: names.length ? names.join('、') : '未选择'
    })
  },

  /**
   * 拉真实品类给第 1 步的品类弹窗用。
   *
   * 这里不能再「静默 catch」：品类是必填项，拉失败时弹窗会是空的，商家点不动
   * 「下一步」却看不到任何原因。
   * label 优先 full_path（「美食·套餐」比单独一个「套餐」可读），叶子优先排前面
   * （level 大的更具体）。
   */
  /**
   * 拉商品类型字典，用库里的 type_name / type_desc / type_tips 覆盖 TYPE_LIST 的硬编码。
   *
   * 为什么不直接把 TYPE_LIST 删了全靠接口：它还携带了 disabled / disabledTip
   * （预售券、提货券在手机上不让建）和展示顺序，那是前端产品规则；
   * 而库里的 app_can_create 只能表达能/不能，说不出「请去网页端操作」这句提示。
   * 所以保留本地结构，只把「叫什么名字」交给字典 —— 名字才是会与顾客端不一致的部分。
   *
   * 拉失败就继续用硬编码名（总比建品页打不开好）。
   */
  async _loadTypes() {
    try {
      const data = await api.productTypeList()
      const rows = Array.isArray(data) ? data : []
      if (!rows.length) return
      const byCode = {}
      rows.forEach(r => { if (r && r.typeCode) byCode[r.typeCode] = r })
      const typeList = TYPE_LIST.map(t => {
        const dict = byCode[t.typeCode]
        return dict ? Object.assign({}, t, { typeName: dict.typeName || t.typeName }) : t
      })
      this._typeDict = byCode
      const patch = { typeList }
      // 已选好类型（编辑态回填比字典到达得早）时同步修正已展示的名字与说明
      const cur = this.data.pickedType
      if (cur && byCode[cur]) {
        patch.pickedTypeName = byCode[cur].typeName || this.data.pickedTypeName
        patch.pickedTypeDesc = byCode[cur].typeDesc || this.data.pickedTypeDesc
      }
      this.setData(patch)
    } catch (e) {
      console.warn('[create] _loadTypes FAIL, 沿用本地硬编码类型名', e)
    }
  },

  async _loadCategories() {
    try {
      const data = await api.categoryList()
      const rows = Array.isArray(data) ? data : []
      const cats = rows
        .map(c => ({
          id: c.categoryId,
          label: c.fullPath || c.categoryName,
          level: c.level || 1
        }))
        .filter(c => c.id && c.label)
        .sort((a, b) => (b.level - a.level) || (a.id - b.id))
      this.setData({ categoryList: cats, categoryLoaded: true })
    } catch (e) {
      console.warn('[create] _loadCategories FAIL', e)
      this.setData({ categoryList: [], categoryLoaded: true })
      wx.showToast({ title: '品类加载失败：' + ((e && (e.msg || e.errMsg)) || '网络异常'), icon: 'none', duration: 3000 })
    }
  },

  _rebuildFields() {
    const t = this.data.pickedType
    const all = FIELDS_BY_TYPE[t]
    if (!all) return
    // 应用默认值
    ;[...all.base, ...all.price, ...all.sale, ...all.detail].forEach(f => {
      if (f.default !== undefined && (this.data.form[f.key] === '' || this.data.form[f.key] == null)) {
        this.setData({ ['form.' + f.key]: f.default })
      }
    })
    // 给每个 field 补 isTextarea（基于 type 字段），避免 WXML 调 .indexOf
    const mark = (arr) => arr.map(f => Object.assign({}, f, { isTextarea: f.type === 'textarea' }))
    this.setData({
      fields: all,
      sectionProduct: mark([...all.base, ...all.price]),
      sectionSale: mark(all.sale.filter(f => f.section === 'sale')),
      sectionTrade: mark([...all.detail, ...all.sale.filter(f => f.section === 'trade')])
    })
    this._recomputeSubmit()
  },

  // ============ 第 1 页: 选类型 ============
  onTapCategory() { this.setData({ categorySheet: true }) },
  onTapType() { this.setData({ typeSheet: true }) },
  onCloseCategorySheet() { this.setData({ categorySheet: false }) },
  onCloseTypeSheet() { this.setData({ typeSheet: false }) },

  /**
   * 选品类。
   *
   * 原先只写 pickedCategory（展示用的中文串），form.categoryId 一直是初始值 0，
   * 提交时 `categoryId: f.categoryId === 0 ? null : f.categoryId` 把它变成 null
   * —— 商家端建出来的商品品类全是空的。真正该写的是 categoryId。
   */
  onPickCategoryItem(e) {
    const ds = e.currentTarget.dataset
    const id = Number(ds.id)
    this.setData({
      pickedCategory: ds.name,
      'form.categoryId': id > 0 ? id : 0,
      categorySheet: false
    })
  },

  onPickTypeItem(e) {
    const code = e.currentTarget.dataset.code
    // 从 this.data.typeList 取而不是常量 TYPE_LIST：_loadTypes 已用字典名覆盖过它，
    // 读常量会把硬编码名（「团购套餐」）写回去，商家又和顾客端对不上。
    const item = (this.data.typeList || TYPE_LIST).find(t => t.typeCode === code)
    if (!item || item.disabled) return
    const dict = (this._typeDict || {})[code]
    this.setData({
      pickedType: code,
      pickedTypeName: item.typeName,
      pickedTypeDesc: (dict && dict.typeDesc) || TYPE_DESC[code] || '',
      typeSheet: false
    })
  },

  onNext() {
    if (!this.data.pickedCategory) {
      wx.showToast({ title: '请先选择商品品类', icon: 'none' }); return
    }
    if (!this.data.pickedType) {
      wx.showToast({ title: '请先选择商品类型', icon: 'none' }); return
    }
    this._rebuildFields()
    this.setData({ step: 2, activeTab: 0 })
  },

  onBack() {
    // 编辑态不允许回到第 1 步改品类/类型：换类型等于换一套必填字段和核销规则，
    // 已卖出的券会对不上
    if (this.data.isEdit) {
      wx.showToast({ title: '编辑商品不能修改品类和类型', icon: 'none' }); return
    }
    this.setData({ step: 1 })
  },

  // ============ 第 2 页: 锚点导航 + 连续表单 ============
  //
  // 原先 5 个区块用 wx:if="{{activeTab === N}}" 互斥渲染，等于 5 个独立页面：
  // 填完「商品信息」要回到顶部点一次「售卖信息」才能继续，一次创建要点 4 次 tab；
  // 而且未激活的区块根本没渲染，商家没法把整张表从头翻到尾核对一遍。
  // 现在改成一整篇连续表单：点标题只做锚点定位，滚动时反过来同步高亮。

  /** 点标题 → 滚到对应区块（不再切换渲染） */
  onTabChange(e) {
    const idx = Number(e.currentTarget.dataset.idx)
    // 先把高亮切过去，避免等 onFormScroll 回调才变（点了没反应的观感）；
    // _anchorLock 期间忽略滚动回传，否则动画滚动过程中会被中间经过的区块反复改写
    this._anchorLock = true
    this.setData({ activeTab: idx, scrollIntoView: 'sec-' + idx })
    setTimeout(() => { this._anchorLock = false }, 400)
  },

  /**
   * 滚动 → 同步高亮当前区块。
   *
   * 用 createSelectorQuery 拿各区块相对滚动容器的位置，取「顶部已越过判定线
   * 的最后一个区块」。判定线取容器高度的 1/3，而不是 0 —— 取 0 的话区块刚
   * 冒头就切高亮，和肉眼看到的「当前正在填哪一段」对不上。
   *
   * 节流到 100ms：bindscroll 触发非常密，每次都跑 SelectorQuery 会明显掉帧。
   */
  onFormScroll() {
    if (this._anchorLock) return
    if (this._scrollTimer) return
    this._scrollTimer = setTimeout(() => {
      this._scrollTimer = null
      this._syncActiveByScroll()
    }, 100)
  },

  _syncActiveByScroll() {
    const q = wx.createSelectorQuery().in(this)
    q.select('.form-scroll').boundingClientRect()
    q.selectAll('.form-section').boundingClientRect()
    q.exec((res) => {
      const box = res && res[0]
      const list = (res && res[1]) || []
      if (!box || !list.length) return
      const line = box.top + box.height / 3
      let idx = 0
      for (let i = 0; i < list.length; i++) {
        if (list[i].top <= line) idx = i
      }
      // 滚到底时强制高亮最后一段：最后一个区块可能比 2/3 屏还短，
      // 永远越不过判定线，不特判的话「交易规则」这一栏点不亮
      if (box.height && list.length) {
        const last = list[list.length - 1]
        if (last.bottom <= box.bottom + 2) idx = list.length - 1
      }
      if (idx !== this.data.activeTab) {
        // scrollIntoView 必须清掉：留着上一次的值，下次 setData 会把页面又拽回那个锚点
        this.setData({ activeTab: idx, scrollIntoView: '' })
      }
    })
  },

  onField(e) {
    const key = e.currentTarget.dataset.key
    const val = e.detail.value
    // 同步写入 __len 字段，避免 WXML 用 (form[key] || '').length 这种不支持的语法
    const len = (val == null) ? 0 : String(val).length
    this.setData({ ['form.' + key]: val, ['form.' + key + '__len']: len })
    this._recomputeSubmit()
  },

  onSwitch(e) {
    const key = e.currentTarget.dataset.key
    if (e.currentTarget.dataset.disabled === 'true') return
    this.setData({ ['form.' + key]: e.detail.value ? 1 : 0 })
    this._recomputeSubmit()
  },

  /** 券码类型：商家券 / 平台券 */
  onPickCodeType(e) {
    this.setData({ 'form.codeType': e.currentTarget.dataset.code })
  },

  /** 售后政策 */
  onPickRefundPolicy(e) {
    this.setData({ 'form.refundPolicy': e.currentTarget.dataset.code })
  },

  /** 是否可与店内其他优惠同享（库里存的是「互斥」，取值要反过来） */
  onToggleMutex(e) {
    this.setData({ 'form.mutexWithStorePromotion': e.detail.value ? 0 : 1 })
  },

  onPickPeriod(e) {
    const idx = Number(e.detail.value)
    const opt = PERIOD_OPTIONS[idx]
    this.setData({ periodIdx: idx, 'form.periodType': opt.value })
  },

  _recomputeSubmit() {
    const f = this.data.fields
    if (!f) { this.setData({ canSubmit: false }); return }
    const all = [...(f.base || []), ...(f.price || []), ...(f.sale || []), ...(f.detail || [])]
    const missing = all.filter(x => x.required).filter(x => {
      const v = this.data.form[x.key]
      return v === '' || v == null
    })
    // 适用门店改多选后，「选了至少一家」才算填了
    const noStore = !(this.data.form.storeIdList || []).length
    this.setData({ canSubmit: missing.length === 0 && !noStore })
  },

  /**
   * 预览：跳到会员端商品详情页（pages/goods/detail）的 preview 态。
   *
   * 原先这里弹一个 wx.showModal 文本摘要（类型/售价/库存/门店四行字），
   * 商家看不到类型专属说明、购买须知、套餐详情这些真正影响成交的内容，
   * 也就无法在上架前发现「有效期写错了」「须知没填」这类问题。
   *
   * 两个刻意的选择：
   * 1) 复用会员端详情页本体而不另抄一套 WXML，否则两边任何一次改版都会漂移，
   *    预览会慢慢变成「和顾客看到的不一样」，那就失去意义了。
   * 2) 不再拦 canSubmit。预览的价值恰恰在于「必填项还没齐时先看看效果」，
   *    原来填不齐就 toast 拦住，等于只能在快提交时才能预览，那时候发现问题已经晚了。
   *    缺字段的展示由 utils/productPreview.js 兜底（如「（未填写商品名称）」）。
   *
   * 草稿走 globalData 传：URL query 装不下整张表单，且使用说明这种长中文会被截断。
   */
  onPreview() {
    // 套餐子品不在本页维护（在 pages/merchant/product/combo），而详情页的「套餐详情」
    // 是顾客判断值不值的主要依据，漏了就预览不出来。
    //
    // 这里刻意调 productDetail 而不是 productSubitemGroups：
    // 会员端详情页本身就是从 productDetail 的 subitemGroups 取数的，走同一个源
    // 才能保证「商家预览到的就是顾客会看到的」；productSubitemGroups 只查子品组，
    // 组合券包（COMBO）的明细存在 ext.comboItemsJson，用那个接口会永远拿到空。
    //
    // 新建态还没有 productId，自然也还没法配搭子品（子品要先存草稿再去 combo 页维护）。
    // 拉失败不能卡住预览（预览只是看排版），失败当空数组继续。
    if (!this.data.productId) { this._gotoPreview([], ''); return }
    wx.showLoading({ title: '加载中...', mask: true })
    api.productDetail(this.data.productId)
      .then((res) => {
        wx.hideLoading()
        const d = (res && res.data) || res || {}
        const p = d.data || d
        const groups = (d.subitemGroups || p.subitemGroups) || []
        // 组合券包的搭配明细不在子品表，存 ext.comboItemsJson。
        // 不带的话 COMBO 商品预览出来是没明细的，而顾客那边能看到 ——
        // 那就又变成「预览和顾客看到的不一样」。
        const comboJson = (p.ext && p.ext.comboItemsJson) || (d.ext && d.ext.comboItemsJson) || ''
        this._gotoPreview(Array.isArray(groups) ? groups : [], comboJson)
      })
      .catch(() => { wx.hideLoading(); this._gotoPreview([], '') })
  },

  _gotoPreview(groups, comboItemsJson) {
    // 服务设施和销量/库存开关都不在这张表单里，但顾客的详情页上有。
    // 不拉的话，商家预览到的是一个没服务设施、却无条件显销量的页面，
    // 而那不是顾客会看到的 —— 预览就失去意义了。
    // 两个请求任何一个挂了都不能卡住预览（预览只是看排版），所以各自 catch 兑底。
    const stores = this.data.form.storeIdList || []
    const mainStore = stores.length ? stores[0] : this.data.form.storeId
    const svcP = mainStore
      ? api.storeServices(mainStore).then(d => (Array.isArray(d) ? d : [])).catch(() => [])
      : Promise.resolve([])
    const mchP = api.merchantInfo().then(d => d || {}).catch(() => ({}))
    Promise.all([svcP, mchP]).then(([svc, mch]) => {
      this._writeDraftAndGo(groups, svc, mch, comboItemsJson)
    })
  },

  _writeDraftAndGo(groups, storeServices, merchant, comboItemsJson) {
    const appInst = getApp() || {}
    appInst.globalData = appInst.globalData || {}
    const dict = (this._typeDict || {})[this.data.pickedType] || {}
    appInst.globalData.productPreviewDraft = {
      form: this.data.form,
      pickedType: this.data.pickedType,
      pickedTypeName: this.data.pickedTypeName,
      // 类型说明卡靠它决定显不显。拉不到字典就不展，而不是自己编一个：
      // 宁可少一张卡，也不能让商家看到和顾客不一样的文案。
      pickedTypeTips: dict.typeTips || '',
      storeOptions: this.data.storeOptions,
      storeServices: storeServices || [],
      showSales: merchant && merchant.showSales !== undefined ? merchant.showSales : '1',
      showStock: merchant && merchant.showStock !== undefined ? merchant.showStock : '1',
      productId: this.data.productId,
      subitemGroups: Array.isArray(groups) ? groups : [],
      comboItemsJson: comboItemsJson || ''
    }
    wx.navigateTo({
      url: '/pages/goods/detail/index?preview=1',
      fail: (e) => {
        console.error('[create] preview navigateTo FAIL', e)
        wx.showToast({ title: '预览页打开失败', icon: 'none' })
      }
    })
  },

  onSubmit() {
    if (this.data.submitting) return
    if (!this.data.canSubmit) {
      wx.showToast({ title: '请补全必填项', icon: 'none' }); return
    }
    this._doSubmit()
  },

  _doSubmit() {
    this.setData({ submitting: true })
    const isEdit = this.data.isEdit
    wx.showLoading({ title: '保存中...', mask: true })
    const f = this.data.form
    const stores = (f.storeIdList || []).length ? f.storeIdList : (f.storeId ? [f.storeId] : [])
    const body = {
      // 适用门店：多选逗号串，与后台一致（后端 syncPrimaryStore 会取第一个当主门店，
      // 并且 ProductServiceImpl.assertStoresBelongToMerchant 会校验都属于本商户）
      storeIds: stores.join(','),
      categoryId: f.categoryId === 0 ? null : f.categoryId,
      typeCode: this.data.pickedType,
      productName: (f.productName || '').trim(),
      subtitle: (f.subtitle || '').trim(),
      price: Number(f.price),
      marketPrice: f.marketPrice ? Number(f.marketPrice) : null,
      faceValue: f.faceValue ? Number(f.faceValue) : null,
      minConsume: f.minConsume ? Number(f.minConsume) : null,
      totalTimes: f.totalTimes ? Number(f.totalTimes) : null,
      periodType: this.data.pickedType === 'PERIOD_CARD' ? f.periodType : null,
      periodCount: this.data.pickedType === 'PERIOD_CARD' ? Number(f.periodCount) : null,
      stock: Number(f.stock || 0),
      limitPerUser: Number(f.limitPerUser || 0),
      maxPerOrder: Number(f.maxPerOrder || 1),
      validityDays: Number(f.validityDays || 30),
      bookingRequired: f.bookingRequired ? 1 : 0,
      requireXiaoxin: f.requireXiaoxin ? 1 : 0,
      notice: (f.notice || '').trim(),
      // 与后台对齐的字段（原先商家端不传，主表 DEFAULT 顶上，运营在后台看到的是默认值）
      refundPolicy: f.refundPolicy || 'ANYTIME',
      collectMethod: f.collectMethod || 'HEAD',
      mutexWithStorePromotion: f.mutexWithStorePromotion === 0 ? 0 : 1,
      extraFeeDesc: (f.extraFeeDesc || '').trim(),
      productType: this._mapProductType(this.data.pickedType),
      delFlag: '0',
      // 落 biz_product_ext（后端 saveExtByTypeCode 会以这个为基础补类型默认值）
      ext: {
        saleChannels: (f.saleChannels || []).join(','),
        staffPromote: f.staffPromote ? 1 : 0,
        codeType: f.codeType || 'MERCHANT'
      }
    }

    if (isEdit) {
      body.productId = this.data.productId
      // 编辑不带 status：后端 admin 端的局部 PUT 语义是「null 表示这次没提交，保留原值」，
      // 带上 status 会把商家已上架的商品意外改成草稿
    } else {
      // 新建落草稿（下架态），与后台一致。
      // 原先商家端直接写 status:'0' 上架 —— 但商家端字段比后台少，
      // 常常缺必填项就直接对顾客可见了，点进去下不了单。
      // 现在统一走「先存草稿 → 补齐 → 上架」，上架时后端跑完整校验。
      body.status = '1'
      body.sales = 0
      body.sort = 0
    }

    const req = isEdit ? api.productUpdate(body) : api.productAdd(body)
    req.then(() => {
      wx.hideLoading()
      this.setData({ submitting: false })
      if (isEdit) {
        wx.showToast({ title: '已保存', icon: 'success' })
        setTimeout(() => wx.navigateBack({ delta: 1 }), 600)
        return
      }
      wx.showModal({
        title: '已保存为草稿',
        content: '商品已创建但尚未上架。确认信息无误后可在商品列表中上架。',
        confirmText: '知道了',
        showCancel: false,
        success: () => {
          // 让列表页知道刚建了草稿，回去要切到「未上架」tab，
          // 否则商家停在「已上架」tab 一条都看不到，会以为没保存成功
          wx.setStorageSync('productDraftCreated', 1)
          // 弹窗写的是「可在商品列表中上架」，那就必须真的把人送到列表页。
          // 原先无条件 navigateBack：从首页直接进建品页时会退回首页，而上架按钮
          // 只在列表页上 —— 提示指了一个用户到不了的地方。
          // 栈里有列表页就退回去（保留它的滚动位置和 tab），没有则 redirect 过去。
          const stack = getCurrentPages() || []
          const hasList = stack.some(pg => pg && pg.route &&
            pg.route.indexOf('pages/merchant/product/list') > -1)
          if (hasList) {
            wx.navigateBack({ delta: 1 })
          } else {
            wx.redirectTo({ url: '/pages/merchant/product/list/index' })
          }
        }
      })
    }).catch((err) => {
      wx.hideLoading()
      this.setData({ submitting: false })
      wx.showModal({
        title: isEdit ? '保存失败' : '创建失败',
        content: (err && (err.msg || err.message)) || '未知错误',
        showCancel: false
      })
    })
  },

  _mapProductType(typeCode) {
    if (typeCode === 'BILL') return '1'
    if (typeCode === 'BOOKING') return '2'
    return '0'
  }
})
