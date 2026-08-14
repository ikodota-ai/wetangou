const { api } = require('../../../../utils/request.js')

// 11 种 typeCode → 移动端可自助创建的范围（MVP 仅放 GROUPON / VOUCHER）
// 其它类型（次卡/储值卡/期间卡/汇享卡/预售/自提券/套餐/买单/预约/月季年卡）需在 admin 端后台配置
const APP_CREATABLE = { GROUPON: true, VOUCHER: true }

const TYPE_DESC = {
  GROUPON: '套餐型，到店核销',
  VOUCHER: '代金券，满减使用',
  TIMECARD: '次卡（暂未开放）',
  STORED_CARD: '储值卡（暂未开放）',
  PERIOD_CARD: '期间卡（暂未开放）',
  HUIXIANG_CARD: '汇享卡（暂未开放）',
  PRESALE: '预售券（暂未开放）',
  PICKUP_VOUCHER: '自提券（暂未开放）',
  COMBO: '组合套餐（暂未开放）',
  BILL: '买单（暂未开放）',
  BOOKING: '预约（暂未开放）'
}

Page({
  data: {
    storeName: '',
    storeId: null,
    storeIds: [],
    storeOptions: [{ id: 0, label: '请选择门店' }],
    storeIdx: 0,
    categoryOptions: [{ id: 0, label: '不选' }],
    categoryIdx: 0,
    typeList: [],
    pickedType: '',
    pickedTypeDesc: '',
    form: {
      typeCode: '',
      productName: '',
      subtitle: '',
      categoryId: null,
      price: '',
      marketPrice: '',
      faceValue: '',
      minConsume: '',
      validityDays: '30',
      bookingRequired: 0,
      stock: '0',
      limitPerUser: '0',
      maxPerOrder: '1',
      notice: ''
    },
    submitting: false,
    canSubmit: false
  },

  onShow() {
    this.checkAuth()
    this.loadTypes()
    this.loadMe()
  },

  checkAuth() {
    const staff = wx.getStorageSync('staffUser') || {}
    const token = wx.getStorageSync('token') || ''
    if (!staff || !token) {
      wx.redirectTo({ url: '/pages/merchant/login/index' })
      return
    }
    this.setData({ storeName: staff.storeName || ('门店' + staff.storeId) })
  },

  loadMe() {
    return api.merchantStaffMe()
      .then((d) => {
        const data = d || {}
        // 门店下拉
        const stores = (data.stores || []).filter(s => s && s.storeId)
        const storeOptions = stores.length
          ? stores.map(s => ({ id: s.storeId, label: s.storeName || ('门店' + s.storeId) }))
          : [{ id: data.storeId || 0, label: data.storeName || ('门店' + (data.storeId || '')) }]
        this.setData({
          storeId: data.storeId,
          storeIds: stores.map(s => s.storeId),
          storeOptions: storeOptions.length ? storeOptions : [{ id: 0, label: '请选择门店' }],
          storeIdx: 0
        })
        // 分类下拉（按主门店）
        return api.categoryList({ storeId: data.storeId }).catch(() => [])
      })
      .then((cats) => {
        const list = (cats || []).filter(c => c && c.categoryId)
        this.setData({
          categoryOptions: [{ id: 0, label: '不选' }].concat(list.map(c => ({
            id: c.categoryId, label: c.categoryName || ('分类' + c.categoryId)
          }))),
          categoryIdx: 0
        })
      })
      .catch((err) => {
        if (err && err.code === 401) {
          wx.redirectTo({ url: '/pages/merchant/login/index' })
        } else {
          console.warn('[product/create] loadMe err', err)
        }
      })
  },

  loadTypes() {
    return api.productTypeAppCreatable()
      .then((rows) => {
        const list = (rows || []).filter(r => r && r.typeCode && APP_CREATABLE[r.typeCode])
        const fullList = (rows || []).map(r => ({
          typeCode: r.typeCode,
          typeName: r.typeName || r.typeCode,
          shortDesc: TYPE_DESC[r.typeCode] || r.typeDesc || '',
          enabled: !!APP_CREATABLE[r.typeCode]
        }))
        this.setData({ typeList: fullList })
      })
      .catch((err) => {
        console.warn('[product/create] loadTypes err', err)
        this.setData({ typeList: [] })
      })
  },

  onPickType(e) {
    const code = e.currentTarget.dataset.code
    const cell = (this.data.typeList || []).find(t => t.typeCode === code)
    if (!cell || !cell.enabled) {
      wx.showToast({ title: '该类型暂未开放，请联系平台', icon: 'none' })
      return
    }
    const form = Object.assign({}, this.data.form, {
      typeCode: code,
      // 切类型时重置
      price: '',
      marketPrice: '',
      faceValue: '',
      minConsume: '',
      bookingRequired: 0
    })
    this.setData({
      form,
      pickedType: code,
      pickedTypeDesc: cell.typeName + ' · ' + cell.shortDesc,
      canSubmit: this._checkCanSubmit(form)
    })
  },

  onPickStore(e) {
    const idx = Number(e.detail.value) || 0
    this.setData({ storeIdx: idx })
  },

  onPickCategory(e) {
    const idx = Number(e.detail.value) || 0
    this.setData({ categoryIdx: idx })
  },

  onField(e) {
    const key = e.currentTarget.dataset.key
    const val = e.detail.value
    const form = Object.assign({}, this.data.form)
    form[key] = val
    this.setData({ form, canSubmit: this._checkCanSubmit(form) })
  },

  onSwitch(e) {
    const key = e.currentTarget.dataset.key
    const form = Object.assign({}, this.data.form)
    form[key] = e.detail.value ? 1 : 0
    this.setData({ form })
  },

  _checkCanSubmit(form) {
    if (!form.typeCode) return false
    if (!form.productName || !form.productName.trim()) return false
    const price = parseFloat(form.price)
    if (!form.price || isNaN(price) || price < 0) return false
    return true
  },

  onSubmit() {
    if (this.data.submitting) return
    const { form, storeOptions, storeIdx, categoryOptions, categoryIdx } = this.data
    if (!this._checkCanSubmit(form)) {
      wx.showToast({ title: '请填写商品名称、类型与售价', icon: 'none' })
      return
    }
    const storeOpt = storeOptions[storeIdx] || {}
    if (!storeOpt.id) {
      wx.showToast({ title: '请选择所属门店', icon: 'none' })
      return
    }
    const catOpt = categoryOptions[categoryIdx] || {}

    const payload = {
      typeCode: form.typeCode,
      productName: form.productName.trim(),
      subtitle: form.subtitle ? form.subtitle.trim() : '',
      storeId: storeOpt.id,
      storeIds: String(storeOpt.id),
      categoryId: catOpt.id || null,
      price: parseFloat(form.price) || 0,
      marketPrice: form.marketPrice ? parseFloat(form.marketPrice) : null,
      faceValue: form.faceValue ? parseFloat(form.faceValue) : null,
      minConsume: form.minConsume ? parseFloat(form.minConsume) : null,
      validityDays: form.validityDays ? parseInt(form.validityDays, 10) : 30,
      bookingRequired: form.bookingRequired ? 1 : 0,
      stock: form.stock ? parseInt(form.stock, 10) : 0,
      limitPerUser: form.limitPerUser ? parseInt(form.limitPerUser, 10) : 0,
      maxPerOrder: form.maxPerOrder ? parseInt(form.maxPerOrder, 10) : 1,
      notice: form.notice || ''
    }

    this.setData({ submitting: true })
    api.productAdd(payload)
      .then((d) => {
        const id = d && (d.productId || (d.data && d.data.productId))
        wx.showToast({ title: '已创建', icon: 'success' })
        setTimeout(() => {
          wx.redirectTo({ url: id ? `/pages/merchant/order/index` : '/pages/merchant/home/index' })
        }, 600)
      })
      .catch((err) => {
        console.warn('[product/create] submit err', err)
        const msg = (err && (err.msg || err.message)) || '保存失败'
        wx.showToast({ title: msg, icon: 'none' })
        this.setData({ submitting: false })
      })
  }
})
