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
    statusTab: 0,       // 0=已上架 1=审核中 2=待商家审核 3=审核驳回 4=已下架
    counts: { onShelf: 0, offShelf: 0 },
    products: [],
    loading: false
  },
  onShow() { this.loadList() },
  onPullDownRefresh() { this.loadList().then(() => wx.stopPullDownRefresh()) },
  loadList() {
    const staff = wx.getStorageSync('staffUser') || {}
    if (!staff.merchantId) {
      wx.showToast({ title: '请先登录', icon: 'none' })
      setTimeout(() => wx.redirectTo({ url: '/pages/merchant/login/index' }), 800)
      return Promise.resolve()
    }
    this.setData({ loading: true })
    const statusMap = ['0', '', '', '', '1']  // 0/1/2/3/4 状态
    const params = {
      pageNum: 1,
      pageSize: 20,
      merchantId: staff.merchantId,
      storeId: staff.storeId || undefined,
      typeCode: this.data.mainTab === 0 ? 'GROUPON' : undefined  // 团购=GROUPON
    }
    const st = statusMap[this.data.statusTab]
    if (st) params.status = st
    return api.productList(params).then(res => {
      const list = (res && res.rows) || []
      // 统计 上架/下架
      const onShelf = list.filter(p => p.status === '0').length
      const offShelf = list.filter(p => p.status === '1').length
      this.setData({ products: list, loading: false, counts: { onShelf, offShelf } })
    }).catch(err => {
      console.error('list err', err)
      this.setData({ loading: false, products: [] })
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
  onEditTime(e) { wx.showToast({ title: '改时间（待实现）', icon: 'none' }) },
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
