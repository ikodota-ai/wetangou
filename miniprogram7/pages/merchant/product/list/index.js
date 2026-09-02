const { api } = require('../../../../utils/request.js')

// 类型中文名。必须在 js 里映射好塞进每条商品，不能在 WXML 里调 Page 方法 ——
// 小程序模板只认 wxs 模块的函数，{{typeNameOf(item.typeCode)}} 恒渲染成空，
// 于是列表里每条商品的类型标签一直是个空色块（同 merchant/bill 已修过的那条）。
const TYPE_NAMES = {
  GROUPON: '团购', VOUCHER: '代金券', TIMECARD: '次卡',
  STORED_CARD: '储值卡', PERIOD_CARD: '周期卡', HUIXIANG_CARD: '惠享卡',
  PRESALE: '预售券', PICKUP_VOUCHER: '提货券',
  COMBO: '组合券包', BOOKING: '预约服务', BILL: '到店买单'
}

// 「筛选」用的类型清单：只列本系统真实支持的 11 种，顺序与后台字典一致
const FILTER_TYPES = [
  { code: '', name: '全部类型' },
  { code: 'GROUPON', name: '团购' },
  { code: 'VOUCHER', name: '代金券' },
  { code: 'TIMECARD', name: '次卡' },
  { code: 'STORED_CARD', name: '储值卡' },
  { code: 'PERIOD_CARD', name: '周期卡' },
  { code: 'HUIXIANG_CARD', name: '惠享卡' },
  { code: 'PRESALE', name: '预售券' },
  { code: 'PICKUP_VOUCHER', name: '提货券' },
  { code: 'COMBO', name: '组合券包' },
  { code: 'BOOKING', name: '预约服务' },
  { code: 'BILL', name: '到店买单' }
]

function typeNameOf(code) { return TYPE_NAMES[code] || code || '其他' }

/**
 * 给列表每条挂上模板要用的派生字段。
 *
 * _picked 也必须在这里算：WXML 表达式不支持调数组方法，
 * 模板里写 {{selectedIds.indexOf(item.productId) >= 0}} 恒得 undefined，
 * 勾选框永远不会显示选中态（和 typeNameOf 是同一类坑）。
 */
function decorate(list, selectedIds) {
  const picked = (selectedIds || []).map(String)
  return (list || []).map(p => Object.assign({}, p, {
    typeName: typeNameOf(p.typeCode),
    stockText: p.stock === -1 ? '不限库存' : p.stock,
    _picked: picked.indexOf(String(p.productId)) >= 0
  }))
}

Page({
  data: {
    mainTab: 0,         // 0=团购 1=品牌
    statusTab: 0,       // 0=全部 1=已上架 2=未上架（本系统 status 只有 0/1，无审核流）
    counts: { total: 0, onShelf: 0, offShelf: 0 },
    products: [],
    loading: false,
    // ===== 筛选条件（后端 /api/product/merchant/list 早就支持 keyword/typeCode/storeId，
    //       前端这几个按钮一直是「待实现」toast，商品一多就只能一页页翻）=====
    keyword: '',            // 搜索：商品名模糊匹配
    filterType: '',         // 筛选：typeCode
    filterTypeName: '',
    pickedStoreId: null,    // 门店筛选（只改本页视图，不动全局当前门店）
    pickedStoreName: '全部门店',
    // 批量改品
    batchMode: false,
    selectedIds: [],
    filterTypes: FILTER_TYPES
  },
  onShow() {
    // 建品页存草稿后回来：默认停在「已上架」tab 会一条都看不到，
    // 商家会以为刚才没保存成功。所以由建品页留个标记，回来直接切到「未上架」。
    const flag = wx.getStorageSync('productDraftCreated')
    if (flag) {
      wx.removeStorageSync('productDraftCreated')
      this.setData({ statusTab: 2 })
    }
    this.loadList()
  },
  onPullDownRefresh() { this.loadList().then(() => wx.stopPullDownRefresh()) },
  loadList() {
    const staff = wx.getStorageSync('staffUser') || {}
    if (!staff.merchantId) {
      wx.showToast({ title: '请先登录', icon: 'none' })
      setTimeout(() => wx.redirectTo({ url: '/pages/login/login?showMore=1' }), 800)
      return Promise.resolve()
    }
    this.setData({ loading: true })
    // 「筛选」里选了具体类型就以它为准；没选时沿用顶部 团购/品牌 tab 的语义
    const typeCode = this.data.filterType
      ? this.data.filterType
      : (this.data.mainTab === 0 ? 'GROUPON' : undefined)
    // 门店：优先本页筛选选中的，其次当前登录门店；选了「全部门店」则不传
    const storeId = this.data.pickedStoreId === 0
      ? undefined
      : (this.data.pickedStoreId || staff.storeId || undefined)
    const params = {
      pageNum: 1,
      pageSize: 20,
      storeId,
      typeCode,
      keyword: this.data.keyword || undefined
    }
    const st = ['', '0', '1'][this.data.statusTab]
    if (st) params.status = st
    // 用商家端专属端点：顾客端的 /api/product/list 写死 status=0，
    // 拿它做商家列表会一条草稿都看不到，而且没有 total 做角标。
    // merchantId 由后端从 token 取，前端不用传（传了也会被忽略）。
    return api.merchantProductList(params).then(res => {
      const rows = (res && res.rows) || []
      // 刷新后把已勾选里已不在当前结果集的清掉，避免批量操作打到看不见的商品
      const visible = rows.map(p => String(p.productId))
      const selectedIds = this.data.selectedIds.filter(id => visible.indexOf(String(id)) >= 0)
      this.setData({ products: decorate(rows, selectedIds), selectedIds, loading: false })
      this._loadCounts(params, (res && res.total) || 0)
    }).catch(err => {
      console.error('list err', err)
      this.setData({ loading: false, products: [] })
    })
  },

  /**
   * tab 上的角标数量必须单独查。
   *
   * 原先是拿当前这一页的 20 条自己 filter 出来的 —— 结果：站在「已上架」tab 时
   * 请求带了 status=0，返回的全是上架商品，「已下架」角标永远显示 0；
   * 而且商品超过 20 条时上架角标也是错的（只数了第一页）。
   * 这里改成用 pageSize=1 各查一次，只取 total。
   */
  _loadCounts(baseParams, currentTotal) {
    const q = (status) => api.merchantProductList(
      Object.assign({}, baseParams, { pageNum: 1, pageSize: 1, status })
    ).then(r => (r && r.total) || 0).catch(() => 0)
    Promise.all([q('0'), q('1')]).then(([onShelf, offShelf]) => {
      this.setData({
        counts: {
          total: this.data.statusTab === 0 ? currentTotal : onShelf + offShelf,
          onShelf, offShelf
        }
      })
    })
  },
  onMainTab(e) {
    this.setData({ mainTab: Number(e.currentTarget.dataset.idx) })
    this.loadList()
  },
  onStatusTab(e) {
    this.setData({ statusTab: Number(e.currentTarget.dataset.idx) })
    this.loadList()
  },
  onEdit(e) { wx.navigateTo({ url: '/pages/merchant/product/create/index?productId=' + e.currentTarget.dataset.id }) },

  /**
   * 编辑商品搭配（子品分组 / 组合券包明细）。
   *
   * product/combo 页是唯一能编搭配的界面，onLoad 要 productId + typeCode 两个参数，
   * 但此前全项目零引用 —— 团购建出来配不了套餐内容，只能去 PC 后台的高级编辑。
   */
  onEditCombo(e) {
    const ds = e.currentTarget.dataset
    wx.navigateTo({
      url: '/pages/merchant/product/combo/index?productId=' + ds.id + '&typeCode=' + (ds.type || 'GROUPON')
    })
  },

  /**
   * 上下架。
   *
   * 为什么必须有：商家端建品现在统一落草稿（status=1，与后台「商品高级编辑」一致），
   * 之前列表页只有「改时间/改库存/编辑」三个按钮，商家在小程序里建完商品后
   * 没有任何上架入口，必须跑去 PC 后台点一次 —— 而商品维护主场景就在商家端。
   *
   * 上架失败一般是必填项没齐（后端 ProductValidator 会指明缺哪个字段），
   * 所以用 showModal 而不是 toast：toast 只显示两行，字段名会被截断看不见。
   */
  onToggleShelf(e) {
    const ds = e.currentTarget.dataset
    const id = ds.id
    const toOn = ds.status !== '0'
    wx.showModal({
      title: toOn ? '确认上架' : '确认下架',
      content: toOn
        ? `「${ds.name || '该商品'}」上架后顾客即可下单。`
        : `「${ds.name || '该商品'}」下架后顾客不再可见，已售出的券不受影响。`,
      success: async r => {
        if (!r.confirm) return
        wx.showLoading({ title: toOn ? '上架中…' : '下架中…', mask: true })
        try {
          await api.productToggle({ productId: id, status: toOn ? '0' : '1' })
          wx.hideLoading()
          wx.showToast({ title: toOn ? '已上架' : '已下架' })
          this.loadList()
        } catch (err) {
          wx.hideLoading()
          wx.showModal({
            title: toOn ? '上架失败' : '下架失败',
            content: (err && (err.msg || err.message)) || '未知错误',
            confirmText: toOn ? '去补全' : '知道了',
            showCancel: toOn,
            success: rr => {
              if (toOn && rr.confirm) {
                wx.navigateTo({ url: '/pages/merchant/product/create/index?productId=' + id })
              }
            }
          })
        }
      }
    })
  },

  onEditStock(e) {
    wx.showModal({ title: '修改库存', editable: true, placeholderText: '请输入新库存', success: async r => {
      if (!r.confirm || !r.content) return
      const id = e.currentTarget.dataset.id
      try {
        await api.productUpdate({ productId: id, stock: Number(r.content) })
        wx.showToast({ title: '已更新' }); this.loadList()
      } catch (err) { wx.showToast({ title: (err && err.msg) || '更新失败', icon: 'none' }) }
    }})
  },

  // ===== 搜索 / 筛选 / 门店 / 批量：后端 /api/product/merchant/list 一直支持
  //       keyword + typeCode + storeId，前端这四个按钮此前全是「待实现」toast，
  //       商品多起来只能一页页翻、也没法批量上下架。=====

  /** 搜索：按商品名模糊匹配（后端 productName like %kw%） */
  onSearch() {
    wx.showModal({
      title: '搜索商品',
      editable: true,
      placeholderText: '输入商品名称关键词',
      content: this.data.keyword,
      confirmText: '搜索',
      success: r => {
        if (!r.confirm) return
        this.setData({ keyword: (r.content || '').trim() })
        this.loadList()
      }
    })
  },

  /** 清掉搜索词 */
  onClearKeyword() {
    if (!this.data.keyword) return
    this.setData({ keyword: '' })
    this.loadList()
  },

  /** 筛选：按商品类型。选「全部类型」时回落到顶部 tab 的语义 */
  onFilter() {
    const types = this.data.filterTypes
    wx.showActionSheet({
      itemList: types.map(t => (t.code === this.data.filterType ? '✓ ' : '') + t.name),
      success: r => {
        const t = types[r.tapIndex]
        if (!t) return
        this.setData({ filterType: t.code, filterTypeName: t.code ? t.name : '' })
        this.loadList()
      }
    })
  },

  /**
   * 门店筛选。
   *
   * 只改本页看哪个门店的商品，不调 switch-store 改全局当前门店 ——
   * 全局切店会连带影响核销/买单/预约的作用门店，在商品列表里顺手改掉太意外。
   * 多店老板还能选「全部门店」看本商户全部商品（storeId 不传即全商户）。
   */
  onPickStore() {
    const staff = wx.getStorageSync('staffUser') || {}
    const stores = staff.stores || []
    if (!stores.length) {
      wx.showToast({ title: '当前账号没有可选门店', icon: 'none' })
      return
    }
    const opts = [{ storeId: 0, storeName: '全部门店' }].concat(stores)
    const cur = this.data.pickedStoreId === null ? staff.storeId : this.data.pickedStoreId
    wx.showActionSheet({
      itemList: opts.map(s => (s.storeId === cur ? '✓ ' : '') + s.storeName),
      success: r => {
        const t = opts[r.tapIndex]
        if (!t) return
        this.setData({ pickedStoreId: t.storeId, pickedStoreName: t.storeName })
        this.loadList()
      }
    })
  },

  /** 批量改品：进出多选模式 */
  onBatch() {
    const on = !this.data.batchMode
    if (on) this.setData({ batchMode: true })
    else { this.setData({ batchMode: false }); this._applySelection([]) }
  },

  onToggleSelect(e) {
    const id = String(e.currentTarget.dataset.id)
    const cur = this.data.selectedIds.slice()
    const i = cur.indexOf(id)
    if (i >= 0) cur.splice(i, 1)
    else cur.push(id)
    this._applySelection(cur)
  },

  onSelectAll() {
    const all = this.data.products.map(p => String(p.productId))
    const done = this.data.selectedIds.length === all.length
    this._applySelection(done ? [] : all)
  },

  /** 勾选变化要同时刷新每条的 _picked，否则界面上勾不动 */
  _applySelection(ids) {
    this.setData({ selectedIds: ids, products: decorate(this.data.products, ids) })
  },

  /**
   * 批量上下架。
   *
   * 逐条调 /api/product/status（没有批量端点，也不该为此新开一个 ——
   * 上架要跑每个商品自己的必填校验，批量端点做不到逐条给出「缺哪个字段」）。
   * 所以这里统计成功/失败条数，失败的把商品名和原因列出来，让商家知道去补哪个。
   */
  onBatchShelf(e) {
    const toOn = e.currentTarget.dataset.on === '1'
    const ids = this.data.selectedIds.slice()
    if (!ids.length) { wx.showToast({ title: '请先勾选商品', icon: 'none' }); return }
    wx.showModal({
      title: toOn ? '批量上架' : '批量下架',
      content: '将对已勾选的 ' + ids.length + ' 个商品执行' + (toOn ? '上架' : '下架'),
      success: async r => {
        if (!r.confirm) return
        wx.showLoading({ title: '处理中…', mask: true })
        const nameOf = (id) => {
          const hit = this.data.products.filter(p => String(p.productId) === String(id))[0]
          return (hit && hit.productName) || ('#' + id)
        }
        let okN = 0
        const fails = []
        for (const id of ids) {
          try {
            await api.productToggle({ productId: id, status: toOn ? '0' : '1' })
            okN++
          } catch (err) {
            fails.push(nameOf(id) + '：' + ((err && (err.msg || err.message)) || '失败'))
          }
        }
        wx.hideLoading()
        this._applySelection([])
        this.loadList()
        if (!fails.length) {
          wx.showToast({ title: '已' + (toOn ? '上架' : '下架') + ' ' + okN + ' 个' })
        } else {
          wx.showModal({
            title: '完成 ' + okN + ' 个，失败 ' + fails.length + ' 个',
            content: fails.slice(0, 5).join('\n') + (fails.length > 5 ? '\n…' : ''),
            showCancel: false
          })
        }
      }
    })
  },

  onMore() { wx.showActionSheet({ itemList: ['刷新', '去上品教程'], success: r => r.tapIndex === 0 && this.loadList() }) },
  goBack() { wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/merchant/home/index' }) }) },
  goCreate() { wx.navigateTo({ url: '/pages/merchant/product/create/index' }) }
})

module.exports = module.exports || {}
module.exports.__test__ = { TYPE_NAMES, FILTER_TYPES, typeNameOf, decorate }
