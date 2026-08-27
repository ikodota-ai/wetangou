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
      { key: 'faceValue', label: '商品面值', required: false, type: 'digit', prefix: '¥', section: 'product' }
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
      { key: 'faceValue', label: '卡片总价值', required: false, type: 'digit', prefix: '¥', section: 'product' },
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
      { key: 'faceValue', label: '面值', required: true, type: 'digit', prefix: '¥', section: 'product' }
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
      { key: 'faceValue', label: '卡片总价值', required: true, type: 'digit', prefix: '¥', section: 'product' },
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
      { key: 'faceValue', label: '组合总价值', required: true, type: 'digit', prefix: '¥', section: 'product' }
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
    // step: 1 = 选类型页, 2 = tab 表单页
    step: 1,
    activeTab: 0,           // 0/1/2/3/4
    tabLabels: ['基础信息', '商家信息', '商品信息', '售卖信息', '交易规则'],
    typeList: TYPE_LIST,

    // 已选
    pickedType: '',
    pickedTypeName: '',
    pickedTypeDesc: '',

    // 弹窗
    categorySheet: false,   // 商品品类弹窗
    typeSheet: false,       // 商品类型弹窗
    categoryList: ['购物·服饰鞋帽·服装', '购物·服饰鞋帽·鞋靴', '购物·服饰鞋帽·箱包', '购物·母婴用品·儿童服饰', '购物·服饰鞋帽·内衣袜子'],
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
    categoryOptions: [{ id: 0, label: '不选' }],
    categoryIdx: 0,
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
      collectMethod: 'PLATFORM',
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
        collectMethod: p.collectMethod || 'PLATFORM',
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
        pickedTypeName: (item && item.typeName) || tc,
        pickedTypeDesc: TYPE_DESC[tc] || '',
        pickedCategory: p.categoryName || '（沿用原品类）',
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
    const opts = [{ id: 0, label: '请选择门店' }]
    if (storeIds && storeIds.length) {
      storeIds.forEach(id => opts.push({ id, label: staff.storeName ? `${staff.storeName} #${id}` : `门店${id}` }))
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

  async _loadCategories() {
    try {
      const data = await api.categoryList()
      const cats = [{ id: 0, label: '不选' }]
      if (data && Array.isArray(data)) data.forEach(c => cats.push({ id: c.categoryId, label: c.categoryName }))
      this.setData({ categoryOptions: cats })
    } catch (e) { /* 静默 */ }
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

  onPickCategoryItem(e) {
    const name = e.currentTarget.dataset.name
    this.setData({ pickedCategory: name, categorySheet: false })
  },

  onPickTypeItem(e) {
    const code = e.currentTarget.dataset.code
    const item = TYPE_LIST.find(t => t.typeCode === code)
    if (!item || item.disabled) return
    this.setData({
      pickedType: code,
      pickedTypeName: item.typeName,
      pickedTypeDesc: TYPE_DESC[code] || '',
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

  // ============ 第 2 页: tab 切换 + 表单 ============
  onTabChange(e) {
    const idx = Number(e.currentTarget.dataset.idx)
    this.setData({ activeTab: idx })
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

  onPickCategory(e) {
    const idx = Number(e.detail.value)
    const opt = this.data.categoryOptions[idx]
    this.setData({ categoryIdx: idx, 'form.categoryId': opt.id })
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

  onPreview() {
    if (!this.data.canSubmit) {
      wx.showToast({ title: '请补全必填项', icon: 'none' }); return
    }
    // 简化版：弹 modal 显示摘要
    const f = this.data.form
    const summary = `【${this.data.pickedTypeName}】${f.productName}\n` +
                    `售价 ¥${f.price}  库存 ${f.stock}  限购 ${f.limitPerUser}  有效期 ${f.validityDays}天\n` +
                    `门店: ${this.data.storeName || f.storeId}\n` +
                    (f.notice ? `\n说明: ${f.notice.slice(0, 50)}` : '')
    wx.showModal({ title: '预览', content: summary, showCancel: false, confirmText: '关闭' })
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
      collectMethod: f.collectMethod || 'PLATFORM',
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
          wx.navigateBack({ delta: 1 })
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
