const { api } = require('../../../../utils/request.js')

const SUBITEM_TYPE_LABELS = ['团购套餐', '代金券', '满减券', '折扣券']
const SUBITEM_TYPE_VALUES = ['GROUPON', 'VOUCHER', 'MANJIAN', 'ZHEKOU']
const COMBO_RULE_LABELS = ['全部可享', '1选1', '2选2']
const COMBO_RULE_VALUES = ['ALL', 'PICK_1', 'PICK_2']

// ===== 「几选几」口径 =====
// 全系统统一用 'ALL'（全部可选）或 'PICK_N'（可选 N 个），与 PC 端
// views/biz/product/create.vue 的 groupPickCount / pickRuleOptions 完全一致。
// 这个页面原来往库里写的是中文 '1选1' / '3选2'，后端新的 PUT 校验只认
// ALL / PICK_N，中文值会被判成「选择规则格式不正确」。而且同一个组在手机上
// 存成 '3选2'、在 PC 上读出来要靠正则兜底才认得 —— 一份数据两种写法。
//
// 「个数」按单品品种数算，不看 quantity：一组里「红烧肉 ×2」「可乐 ×1」
// 是 2 个单品而不是 3 个，quantity 是这道菜给几份，跟顾客能挑几样是两回事。

function groupSize(g) {
  return ((g && g.subitems) || []).length
}

/** 解析 pickRule 得到「可选几个」；无规则 / ALL / 超出范围都按全选 */
function groupPickCount(g) {
  const size = groupSize(g)
  const rule = g && g.pickRule
  if (!rule || rule === 'ALL') return size
  const m = String(rule).match(/^PICK_(\d+)$/)
  let n = m ? Number(m[1]) : null
  if (n == null) {
    // 兼容本页历史写进去的中文 'N选M'，取「选」后面那个数
    const cn = String(rule).match(/选\s*(\d+)$/)
    if (cn) n = Number(cn[1])
  }
  if (n == null || n <= 0 || n >= size) return size
  return n
}

/** 标签文案：3 个单品全选 → 「共3个单品：3选3」 */
function pickRuleText(g) {
  const size = groupSize(g)
  if (size === 0) return '未添加单品'
  return '共' + size + '个单品：' + size + '选' + groupPickCount(g)
}

/**
 * 可选规则按本组实际单品数动态生成：3 个单品 → 全部可选(3选3) / 3选2 / 3选1。
 * 原来是硬编码「1选1 / 2选2 / 3选2」，跟本组单品数完全脱节 ——
 * 2 个单品的组也能设成「3选2」，存进去就是永远履约不了的脏数据。
 */
function pickRuleOptions(g) {
  const size = groupSize(g)
  const labels = ['全部可选（' + size + '选' + size + '）']
  const values = ['ALL']
  for (let n = size - 1; n >= 1; n--) {
    labels.push(size + '选' + n)
    values.push('PICK_' + n)
  }
  return { labels, values }
}

/**
 * 给每个组挂上渲染要用的派生字段。
 *
 * 为什么必须在 js 里算完再 setData：小程序 WXML 只能调 wxs 模块的函数，
 * 不能调 Page 的方法。这个页面原来在 wxml 里写 {{totalCount}}、
 * {{pickCount}}、{{typeIdxOf(item.subitemType)}}、{{ruleIdxOf(item.pickRule)}}，
 * 而它们都是 Page 上的方法 —— 一律渲染成空：底部汇总行是空白，
 * 两个 picker 的 value 恒为空导致每次打开都回到第一项而不是当前值。
 */
function decorateGroups(list) {
  return (list || []).map(g => {
    const opts = pickRuleOptions(g)
    const cur = groupPickCount(g)
    const size = groupSize(g)
    const curValue = cur >= size ? 'ALL' : 'PICK_' + cur
    let idx = opts.values.indexOf(curValue)
    if (idx < 0) idx = 0
    return Object.assign({}, g, {
      _size: size,
      _pickText: pickRuleText(g),
      _ruleLabels: opts.labels,
      _ruleValues: opts.values,
      _ruleIdx: idx
    })
  })
}

function decorateCombos(list) {
  return (list || []).map(c => {
    const tIdx = SUBITEM_TYPE_VALUES.indexOf(c.subitemType)
    const rIdx = COMBO_RULE_VALUES.indexOf(c.pickRule)
    return Object.assign({}, c, {
      _typeIdx: tIdx < 0 ? 0 : tIdx,
      _ruleIdx: rIdx < 0 ? 0 : rIdx,
      subitemTypeLabel: SUBITEM_TYPE_LABELS[tIdx < 0 ? 0 : tIdx],
      pickRuleLabel: COMBO_RULE_LABELS[rIdx < 0 ? 0 : rIdx]
    })
  })
}

function sumGroups(groups) {
  let totalCount = 0
  let pickCount = 0
  for (const g of groups || []) {
    totalCount += groupSize(g)
    pickCount += groupPickCount(g)
  }
  return { totalCount, pickCount }
}

function sumCombo(items) {
  return (items || []).reduce((s, c) => s + (Number(c.pickQuantity) || 0) * (Number(c.price) || 0), 0)
}

Page({
  data: {
    productId: 0,
    typeCode: '',
    isCombo: false,
    tipText: '',
    // 团购
    groups: [],
    totalCount: 0,
    pickCount: 0,
    // 组合券包
    comboItems: [],
    totalValue: 0,
    // 弹窗
    showGroupModal: false,
    showSubModal: false,
    newGroup: { groupName: '', sort: 0 },
    newSub: { _groupName: '', subitemName: '', quantity: 1, price: 0 },
    subitemTypeLabels: SUBITEM_TYPE_LABELS,
    comboRuleLabels: COMBO_RULE_LABELS,
    saving: false
  },
  onLoad(query) {
    const productId = Number(query.productId) || 0
    const typeCode = query.typeCode || 'GROUPON'
    const isCombo = typeCode === 'COMBO'
    this.setData({
      productId,
      typeCode,
      isCombo,
      tipText: isCombo
        ? '每条搭配可选 团购套餐/代金券/满减券/折扣券'
        : '先加商品组和单品，再在组内设置几选几'
    })
    if (!productId) {
      wx.showToast({ title: '缺少商品参数', icon: 'none' })
      return
    }
    if (isCombo) this.loadCombo()
    else this.loadGroups()
  },
  async loadGroups() {
    try {
      const res = await api.productSubitemGroups({ productId: this.data.productId })
      const raw = (res && res.data) || res || []
      const groups = decorateGroups(Array.isArray(raw) ? raw : [])
      this.setData(Object.assign({ groups }, sumGroups(groups)))
    } catch (e) {
      wx.showToast({ title: (e && e.msg) || '加载失败', icon: 'none' })
    }
  },
  /**
   * 组合券包的搭配明细存在 biz_product_ext.combo_items_json 里，
   * 进页面必须拉详情回填 —— 原来 onLoad 只调 loadGroups（那查的是子品组，
   * COMBO 根本不用），comboItems 永远初始为空数组：
   * 上次配好的搭配再进来看不见，一保存还会把原有明细整个覆盖掉。
   */
  async loadCombo() {
    try {
      const res = await api.productDetail(this.data.productId)
      const d = (res && res.data) || res || {}
      const json = (d.ext && d.ext.comboItemsJson) || ''
      let arr = []
      if (json) {
        try { arr = JSON.parse(json) } catch (e) { arr = [] }
      }
      const comboItems = decorateCombos(Array.isArray(arr) ? arr : [])
      this.setData({ comboItems, totalValue: sumCombo(comboItems) })
    } catch (e) {
      wx.showToast({ title: (e && e.msg) || '加载失败', icon: 'none' })
    }
  },
  // ===== 团购：商品组 =====
  onAddGroup() {
    this.setData({ showGroupModal: true, newGroup: { groupName: '', sort: 0 } })
  },
  onCloseGroup() { this.setData({ showGroupModal: false }) },
  onGroupName(e) { this.setData({ 'newGroup.groupName': e.detail.value }) },
  async onConfirmGroup() {
    if (!this.data.newGroup.groupName) { wx.showToast({ title: '请输入组名称', icon: 'none' }); return }
    if (this.data.saving) return
    this.setData({ saving: true })
    try {
      // 新建一律 ALL：几选几的选项要按本组实际单品数生成，此刻组里还没单品，
      // 让用户先选「3选2」只会存出履约不了的规则（后端 PUT 也会拒）。
      await api.productSubitemGroupAdd({
        productId: this.data.productId,
        groupName: this.data.newGroup.groupName,
        pickRule: 'ALL',
        sort: Number(this.data.newGroup.sort) || 0
      })
      wx.showToast({ title: '已添加' })
      this.setData({ showGroupModal: false })
      this.loadGroups()
    } catch (e) {
      wx.showToast({ title: (e && e.msg) || '添加失败', icon: 'none' })
    } finally {
      this.setData({ saving: false })
    }
  },
  /** 组内「几选几」，改完立即落库，避免用户以为改了其实没保存 */
  async onGroupRule(e) {
    const gid = e.currentTarget.dataset.gid
    const g = this.data.groups.find(x => String(x.groupId) === String(gid))
    if (!g) return
    const val = (g._ruleValues || [])[Number(e.detail.value)]
    if (!val || val === (g.pickRule || 'ALL')) return
    try {
      await api.productSubitemGroupUpdate({ groupId: g.groupId, pickRule: val })
      this.loadGroups()
    } catch (err) {
      wx.showToast({ title: (err && err.msg) || '设置失败', icon: 'none' })
      this.loadGroups()
    }
  },
  onDelGroup(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({ title: '确认删除', content: '该组内子品将一起删除', success: async r => {
      if (!r.confirm) return
      try { await api.productSubitemGroupDel(id); this.loadGroups() }
      catch (err) { wx.showToast({ title: (err && err.msg) || '删除失败', icon: 'none' }) }
    }})
  },
  // ===== 团购：单品 =====
  onAddSub(e) {
    this.setData({
      showSubModal: true,
      newSub: {
        _groupName: e.currentTarget.dataset.gname,
        groupId: e.currentTarget.dataset.gid,
        subitemName: '', quantity: 1, price: 0
      }
    })
  },
  onCloseSub() { this.setData({ showSubModal: false }) },
  onSubName(e) { this.setData({ 'newSub.subitemName': e.detail.value }) },
  onSubQty(e) { this.setData({ 'newSub.quantity': Number(e.detail.value) || 1 }) },
  onSubPrice(e) { this.setData({ 'newSub.price': Number(e.detail.value) || 0 }) },
  async onConfirmSub() {
    if (!this.data.newSub.subitemName) { wx.showToast({ title: '请输入名称', icon: 'none' }); return }
    if (this.data.saving) return
    this.setData({ saving: true })
    try {
      const s = this.data.newSub
      await api.productSubitemAdd({
        groupId: s.groupId,
        subitemName: s.subitemName,
        quantity: Number(s.quantity) || 1,
        price: Number(s.price) || 0
      })
      wx.showToast({ title: '已添加' })
      this.setData({ showSubModal: false })
      this.loadGroups()
    } catch (e) {
      wx.showToast({ title: (e && e.msg) || '添加失败', icon: 'none' })
    } finally {
      this.setData({ saving: false })
    }
  },
  onDelSub(e) {
    const sid = e.currentTarget.dataset.sid
    wx.showModal({ title: '确认删除', success: async r => {
      if (!r.confirm) return
      try { await api.productSubitemDel(sid); this.loadGroups() }
      catch (err) { wx.showToast({ title: (err && err.msg) || '删除失败', icon: 'none' }) }
    }})
  },
  // ===== 组合券包 =====
  onAddCombo() {
    const items = decorateCombos(this.data.comboItems.concat([{
      name: '', subitemType: 'GROUPON', pickQuantity: 1, pickRule: 'ALL', price: 0
    }]))
    this.setData({ comboItems: items, totalValue: sumCombo(items) })
  },
  onDelCombo(e) {
    const items = this.data.comboItems.slice()
    items.splice(Number(e.currentTarget.dataset.idx), 1)
    this.setData({ comboItems: items, totalValue: sumCombo(items) })
  },
  _patchCombo(idx, patch) {
    const items = this.data.comboItems.slice()
    items[idx] = Object.assign({}, items[idx], patch)
    const decorated = decorateCombos(items)
    this.setData({ comboItems: decorated, totalValue: sumCombo(decorated) })
  },
  onComboName(e) { this._patchCombo(Number(e.currentTarget.dataset.idx), { name: e.detail.value }) },
  onComboType(e) {
    this._patchCombo(Number(e.currentTarget.dataset.idx), { subitemType: SUBITEM_TYPE_VALUES[Number(e.detail.value)] })
  },
  onComboQty(e) { this._patchCombo(Number(e.currentTarget.dataset.idx), { pickQuantity: Number(e.detail.value) || 1 }) },
  onComboRule(e) {
    this._patchCombo(Number(e.currentTarget.dataset.idx), { pickRule: COMBO_RULE_VALUES[Number(e.detail.value)] })
  },
  onComboPrice(e) { this._patchCombo(Number(e.currentTarget.dataset.idx), { price: Number(e.detail.value) || 0 }) },
  // ===== 共用 =====
  onSave() {
    if (!this.data.isCombo) {
      // 团购的组和单品每一步都已经落库了，这里没有待提交的表单，
      // 不能再弹「已保存」—— 那会让用户以为刚才某步没生效、需要点这里补一次。
      wx.navigateBack()
      return
    }
    if (this.data.saving) return
    this.setData({ saving: true })
    // 只回传落库字段，去掉 _typeIdx / _ruleIdx / 两个 Label 这些纯渲染派生值，
    // 否则它们会一起写进 combo_items_json 变成脏数据。
    const items = this.data.comboItems.map(c => ({
      name: c.name,
      subitemType: c.subitemType,
      pickQuantity: Number(c.pickQuantity) || 1,
      pickRule: c.pickRule || 'ALL',
      price: Number(c.price) || 0
    }))
    // 搭配明细存 ext.comboItemsJson（对应 biz_product_ext.combo_items_json）。
    // typeCode 必须一起带上：后端按类型做必填校验，缺了会被判成商品类型为空。
    api.productUpdate({
      productId: this.data.productId,
      typeCode: this.data.typeCode || 'COMBO',
      totalValue: sumCombo(items),
      ext: { comboItemsJson: JSON.stringify(items) }
    })
      .then(() => { wx.showToast({ title: '已保存' }); setTimeout(() => wx.navigateBack(), 600) })
      .catch(e => wx.showToast({ title: (e && e.msg) || '保存失败', icon: 'none' }))
      .then(() => this.setData({ saving: false }))
  }
})

module.exports = module.exports || {}
module.exports.__test__ = {
  groupSize, groupPickCount, pickRuleText, pickRuleOptions,
  decorateGroups, decorateCombos, sumGroups, sumCombo
}
