/**
 * 商家端商品创建 — 抖音来客复刻
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
    storeIdx: 0,
    categoryOptions: [{ id: 0, label: '不选' }],
    categoryIdx: 0,
    periodOptions: PERIOD_OPTIONS,
    periodIdx: 0,

    form: {
      storeId: 0, categoryId: 0,
      productName: '', subtitle: '',
      marketPrice: '', price: '', faceValue: '', minConsume: '', totalTimes: '',
      periodType: 'MONTH', periodCount: 1,
      stock: 0, limitPerUser: 0, maxPerOrder: 1, validityDays: 30,
      bookingRequired: 0, requireXiaoxin: 0,
      notice: ''
    },

    fields: { base: [], price: [], sale: [], detail: [] },
    sectionMerchant: [],
    sectionProduct: [],
    sectionSale: [],
    sectionTrade: [],

    canSubmit: false,
    submitting: false
  },

  onLoad() {
    this._initMerchantContext()
    this._loadCategories()
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
    const merchant = [{ key: 'storeId', label: '适用门店', required: true, type: 'store-picker', section: 'merchant' }]
    // 应用默认值
    ;[...all.base, ...all.price, ...all.sale, ...all.detail, ...merchant].forEach(f => {
      if (f.default !== undefined && (this.data.form[f.key] === '' || this.data.form[f.key] == null)) {
        this.setData({ ['form.' + f.key]: f.default })
      }
    })
    // 给每个 field 补 isTextarea（基于 type 字段），避免 WXML 调 .indexOf
    const mark = (arr) => arr.map(f => Object.assign({}, f, { isTextarea: f.type === 'textarea' }))
    this.setData({
      fields: all,
      sectionMerchant: mark(merchant),
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
  },

  onPickStore(e) {
    const idx = Number(e.detail.value)
    const opt = this.data.storeOptions[idx]
    this.setData({ storeIdx: idx, 'form.storeId': opt.id })
    this._recomputeSubmit()
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
    const all = [...(f.base || []), ...(f.price || []), ...(f.sale || []), ...(f.detail || []),
                 { key: 'storeId', required: true }]
    const missing = all.filter(x => x.required).filter(x => {
      const v = this.data.form[x.key]
      return v === '' || v == null
    })
    this.setData({ canSubmit: missing.length === 0 })
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
    wx.showLoading({ title: '保存中...', mask: true })
    const f = this.data.form
    const body = {
      storeIds: String(f.storeId),
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
      productType: this._mapProductType(this.data.pickedType),
      status: '0', delFlag: '0', sales: 0, sort: 0
    }
    api.productAdd(body)
      .then(() => {
        wx.hideLoading()
        this.setData({ submitting: false })
        wx.showToast({ title: '已创建', icon: 'success' })
        setTimeout(() => wx.navigateBack({ delta: 1 }), 600)
      })
      .catch((err) => {
        wx.hideLoading()
        this.setData({ submitting: false })
        wx.showModal({ title: '创建失败', content: (err && (err.msg || err.message)) || '未知错误', showCancel: false })
      })
  },

  _mapProductType(typeCode) {
    if (typeCode === 'BILL') return '1'
    if (typeCode === 'BOOKING') return '2'
    return '0'
  }
})
