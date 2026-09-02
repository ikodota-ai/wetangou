const { api } = require('../../../../utils/request.js')

const TYPE_NAMES = {
  GROUPON: '团购', VOUCHER: '代金券', TIMECARD: '次卡',
  STORED_CARD: '储值卡', PERIOD_CARD: '周期卡', HUIXIANG_CARD: '惠享卡',
  PRESALE: '预售券', PICKUP_VOUCHER: '提货券',
  COMBO: '组合券包', BOOKING: '预约服务', BILL: '到店买单'
}

Page({
  data: {
    mainTab: 0,         // 0=团购 1=品牌
    statusTab: 0,       // 0=全部 1=已上架 2=未上架（本系统 status 只有 0/1，无审核流）
    counts: { total: 0, onShelf: 0, offShelf: 0 },
    products: [],
    loading: false
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
    const params = {
      pageNum: 1,
      pageSize: 20,
      storeId: staff.storeId || undefined,
      typeCode: this.data.mainTab === 0 ? 'GROUPON' : undefined  // 团购=GROUPON
    }
    const st = ['', '0', '1'][this.data.statusTab]
    if (st) params.status = st
    // 用商家端专属端点：顾客端的 /api/product/list 写死 status=0，
    // 拿它做商家列表会一条草稿都看不到，而且没有 total 做角标。
    // merchantId 由后端从 token 取，前端不用传（传了也会被忽略）。
    return api.merchantProductList(params).then(res => {
      const list = (res && res.rows) || []
      this.setData({ products: list, loading: false })
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
  typeNameOf(code) { return TYPE_NAMES[code] || code || '其他' },
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
  onSearch() { wx.showToast({ title: '搜索（待实现）', icon: 'none' }) },
  onFilter() { wx.showToast({ title: '筛选（待实现）', icon: 'none' }) },
  onBatch() { wx.showToast({ title: '批量改品（待实现）', icon: 'none' }) },
  onMore() { wx.showActionSheet({ itemList: ['刷新', '去上品教程'], success: r => r.tapIndex === 0 && this.loadList() }) },
  onPickStore() { wx.showToast({ title: '门店切换（待实现）', icon: 'none' }) },
  goBack() { wx.navigateBack({ fail: () => wx.switchTab({ url: '/pages/merchant/home/index' }) }) },
  goCreate() { wx.navigateTo({ url: '/pages/merchant/product/create/index' }) }
})
