const { api } = require('../../../../utils/request.js')

const SUBITEM_TYPE_LABELS = ['团购套餐', '代金券', '满减券', '折扣券']
const SUBITEM_TYPE_VALUES = ['GROUPON', 'VOUCHER', 'MANJIAN', 'ZHEKOU']
const RULE_LABELS = ['全部可享', '1选1', '2选2', '3选2']
const RULE_VALUES = ['ALL', 'PICK_1', 'PICK_2', 'PICK_3']
const GROUP_RULE_LABELS = ['全部可享', '1选1', '2选2', '3选2']
const GROUP_RULE_VALUES = ['ALL', '1选1', '2选2', '3选2']

function pickRuleCount(rule) {
  if (rule === 'PICK_1' || rule === '1选1') return 1
  if (rule === 'PICK_2' || rule === '2选2') return 2
  if (rule === 'PICK_3' || rule === '3选2') return 2
  return 0 // ALL = 全部可享，调用方按 subitems.length 处理
}

Page({
  data: {
    productId: 0,
    typeCode: '',
    isCombo: false,
    tipText: '',
    // 团购
    groups: [],
    // 组合券包
    comboItems: [],
    // 弹窗
    showGroupModal: false,
    showSubModal: false,
    newGroup: { groupName: '', pickRule: 'ALL', sort: 0 },
    newSub: { _groupName: '', subitemName: '', quantity: 1, price: 0 },
    groupRuleIdx: 0,
    groupRuleLabels: GROUP_RULE_LABELS,
    subitemTypeLabels: SUBITEM_TYPE_LABELS,
    ruleLabels: RULE_LABELS
  },
  onLoad(query) {
    const productId = Number(query.productId) || 0
    const typeCode = query.typeCode || 'GROUPON'
    this.setData({
      productId,
      typeCode,
      isCombo: typeCode === 'COMBO',
      tipText: typeCode === 'COMBO'
        ? '每条搭配可选 团购套餐/代金券/满减券/折扣券'
        : '添加单品和商品组（组内子品 N 选 1）'
    })
    if (productId) this.loadGroups()
  },
  async loadGroups() {
    try {
      const res = await api.productSubitemGroups({ productId: this.data.productId })
      const list = (res && res.data) || res || []
      this.setData({ groups: Array.isArray(list) ? list : [] })
    } catch (e) {
      console.error('loadGroups', e)
    }
  },
  // ===== 团购：商品组 =====
  onAddGroup() {
    this.setData({
      showGroupModal: true,
      newGroup: { groupName: '', pickRule: 'ALL', sort: 0 },
      groupRuleIdx: 0
    })
  },
  onCloseGroup() { this.setData({ showGroupModal: false }) },
  onGroupName(e) { this.setData({ 'newGroup.groupName': e.detail.value }) },
  onGroupRule(e) {
    const idx = Number(e.detail.value)
    this.setData({ groupRuleIdx: idx, 'newGroup.pickRule': GROUP_RULE_VALUES[idx] })
  },
  async onConfirmGroup() {
    if (!this.data.newGroup.groupName) { wx.showToast({ title: '请输入组名称', icon: 'none' }); return }
    try {
      await api.productSubitemGroupAdd({ productId: this.data.productId, ...this.data.newGroup })
      wx.showToast({ title: '已添加' })
      this.setData({ showGroupModal: false })
      this.loadGroups()
    } catch (e) { wx.showToast({ title: (e && e.msg) || '添加失败', icon: 'none' }) }
  },
  onDelGroup(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({ title: '确认删除', content: '该组内子品将一起删除', success: async r => {
      if (!r.confirm) return
      try { await api.productSubitemGroupDel(id); this.loadGroups() }
      catch (e) { wx.showToast({ title: (e && e.msg) || '删除失败', icon: 'none' }) }
    }})
  },
  // ===== 团购：单品 =====
  onAddSub(e) {
    this.setData({
      showSubModal: true,
      newSub: { _groupName: e.currentTarget.dataset.gname, groupId: e.currentTarget.dataset.gid, subitemName: '', quantity: 1, price: 0 }
    })
  },
  onCloseSub() { this.setData({ showSubModal: false }) },
  onSubName(e) { this.setData({ 'newSub.subitemName': e.detail.value }) },
  onSubQty(e) { this.setData({ 'newSub.quantity': Number(e.detail.value) || 1 }) },
  onSubPrice(e) { this.setData({ 'newSub.price': Number(e.detail.value) || 0 }) },
  async onConfirmSub() {
    if (!this.data.newSub.subitemName) { wx.showToast({ title: '请输入名称', icon: 'none' }); return }
    try {
      await api.productSubitemAdd(this.data.newSub)
      wx.showToast({ title: '已添加' })
      this.setData({ showSubModal: false })
      this.loadGroups()
    } catch (e) { wx.showToast({ title: (e && e.msg) || '添加失败', icon: 'none' }) }
  },
  onDelSub(e) {
    const { sid } = e.currentTarget.dataset
    wx.showModal({ title: '确认删除', success: async r => {
      if (!r.confirm) return
      try { await api.productSubitemDel(sid); this.loadGroups() }
      catch (e) { wx.showToast({ title: (e && e.msg) || '删除失败', icon: 'none' }) }
    }})
  },
  // ===== 组合券包 =====
  onAddCombo() {
    const items = this.data.comboItems.slice()
    items.push({ name: '', subitemType: 'GROUPON', subitemTypeLabel: '团购套餐', pickQuantity: 1, pickRule: 'ALL', pickRuleLabel: '全部可享', price: 0 })
    this.setData({ comboItems: items })
  },
  onDelCombo(e) {
    const idx = e.currentTarget.dataset.idx
    const items = this.data.comboItems.slice()
    items.splice(idx, 1)
    this.setData({ comboItems: items })
  },
  onComboName(e) { const idx = e.currentTarget.dataset.idx; const items = this.data.comboItems.slice(); items[idx].name = e.detail.value; this.setData({ comboItems: items }) },
  onComboType(e) {
    const idx = e.currentTarget.dataset.idx
    const v = SUBITEM_TYPE_VALUES[Number(e.detail.value)]
    const items = this.data.comboItems.slice()
    items[idx].subitemType = v
    items[idx].subitemTypeLabel = SUBITEM_TYPE_LABELS[Number(e.detail.value)]
    this.setData({ comboItems: items })
  },
  onComboQty(e) { const idx = e.currentTarget.dataset.idx; const items = this.data.comboItems.slice(); items[idx].pickQuantity = Number(e.detail.value) || 1; this.setData({ comboItems: items }) },
  onComboRule(e) {
    const idx = e.currentTarget.dataset.idx
    const v = RULE_VALUES[Number(e.detail.value)]
    const items = this.data.comboItems.slice()
    items[idx].pickRule = v
    items[idx].pickRuleLabel = RULE_LABELS[Number(e.detail.value)]
    this.setData({ comboItems: items })
  },
  onComboPrice(e) { const idx = e.currentTarget.dataset.idx; const items = this.data.comboItems.slice(); items[idx].price = Number(e.detail.value) || 0; this.setData({ comboItems: items }) },
  typeIdxOf(code) { return SUBITEM_TYPE_VALUES.indexOf(code) },
  ruleIdxOf(rule) { return RULE_VALUES.indexOf(rule) },
  // ===== 共用 =====
  onSave() {
    if (this.data.isCombo) {
      const total = this.data.comboItems.reduce((s, c) => s + (c.pickQuantity || 0) * (c.price || 0), 0)
      // 搭配明细存 ext.comboItemsJson（对应 biz_product_ext.combo_items_json）。
      // 原来传的 subitemPickRuleJson 后端 Product 上没有这个属性，会被直接忽略，
      // 表现是「提示已保存但下次进来还是空的」。typeCode 必须一起带上：
      // 后端按类型做必填校验，缺了会被判成商品类型为空。
      api.productUpdate({
        productId: this.data.productId,
        typeCode: this.data.typeCode || 'COMBO',
        totalValue: total,
        ext: { comboItemsJson: JSON.stringify(this.data.comboItems) }
      })
        .then(() => { wx.showToast({ title: '已保存' }); setTimeout(() => wx.navigateBack(), 600) })
        .catch(e => wx.showToast({ title: (e && e.msg) || '保存失败', icon: 'none' }))
    } else {
      wx.showToast({ title: '已保存' })
      setTimeout(() => wx.navigateBack(), 600)
    }
  },
  // 计算属性
  totalCount() { return this.data.groups.reduce((s, g) => s + (g.subitems || []).length, 0) },
  pickCount() {
    let total = 0
    for (const g of this.data.groups) {
      const all = (g.subitems || []).length
      if (!g.pickRule || g.pickRule === 'ALL') total += all
      else if (g.pickRule === '1选1') total += 1
      else if (g.pickRule === '2选2') total += 2
      else if (g.pickRule === '3选2') total += 2
      else total += all
    }
    return total
  }
})
