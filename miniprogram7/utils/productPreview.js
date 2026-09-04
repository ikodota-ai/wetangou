/**
 * 商家端建品「预览」：把编辑中的草稿表单换算成会员端商品详情页认识的结构。
 *
 * 为什么要有这一层：
 * 预览的价值在于「商家看到的就是顾客将看到的」。原先商家端预览是弹一个
 * wx.showModal 文本摘要（类型/售价/库存/门店四行字），既不是顾客看到的排版，
 * 也看不到类型专属说明、购买须知、套餐详情这些真正影响成交的内容 ——
 * 商家没法在上架前发现「有效期写错了」「须知没填」这类问题。
 *
 * 实现选择：不另抄一套详情页 WXML，而是复用会员端 pages/goods/detail 本身，
 * 由它以 preview 态渲染。抄一套的话，两边任何一次改版都会漂移，
 * 预览就会慢慢变成「和顾客看到的不一样」，那还不如没有。
 *
 * 因此这里只负责字段换算，且刻意做成不依赖 wx API 的纯函数，可以直接单测。
 */

/** 建品页的 typeCode → 会员端 productType（与 create/index.js 的 _mapProductType 同口径） */
function mapProductType(typeCode) {
  if (typeCode === 'BILL') return '1'
  if (typeCode === 'BOOKING') return '2'
  return '0'
}

/**
 * @param {Object} draft 建品页 this.data 的相关切片
 *   { form, pickedType, pickedTypeName, storeOptions }
 * @returns {Object} 会员端 goods/detail 的 normalize() 能吃的 product 原始结构
 */
function draftToProduct(draft) {
  const d = draft || {}
  const f = d.form || {}
  const typeCode = d.pickedType || 'GROUPON'
  const num = (v) => {
    if (v === '' || v === null || v === undefined) return null
    const n = Number(v)
    return isNaN(n) ? null : n
  }
  const storeIds = (f.storeIdList && f.storeIdList.length)
    ? f.storeIdList.slice()
    : (f.storeId ? [f.storeId] : [])

  // 门店名：预览里必须显示店名而不是 ID。多店老板看到「门店101」分不清是哪家，
  // 而这正是预览要帮他确认的事情之一。
  const nameOf = {}
  ;(d.storeOptions || []).forEach((o) => {
    if (o && o.id) nameOf[o.id] = o.label
  })
  const storeNames = storeIds.map((id) => nameOf[id] || ('门店' + id)).join('、')

  return {
    // productId 必须给一个非空值：详情页用 `p.productId` 判断「拿到商品了」，
    // 为空会直接落到「商品不存在或已下架」的空态。草稿态用 0 占位，
    // 配合 preview=1 让详情页不去请求后端。
    productId: d.productId || 0,
    productName: (f.productName || '').trim() || '（未填写商品名称）',
    subtitle: (f.subtitle || '').trim(),
    typeCode: typeCode,
    typeName: d.pickedTypeName || typeCode,
    // 类型使用说明：详情页那张「……说明」卡靠 typeTips 决定显不显。
    // 建品页从 /api/product/type/list 拉回字典时一并带上，没拉到就不展（而不是编一个）：
    // 预览宁可少一张卡，也不能让商家看到和顾客不一样的文案。
    typeTips: d.pickedTypeTips || '',
    productType: mapProductType(typeCode),
    categoryId: f.categoryId || null,

    price: num(f.price) === null ? 0 : num(f.price),
    marketPrice: num(f.marketPrice),
    faceValue: num(f.faceValue),
    minConsume: num(f.minConsume),
    totalTimes: num(f.totalTimes),
    totalValue: num(f.faceValue),      // 组合券包的「总价值」建品页用 faceValue 承载
    periodType: typeCode === 'PERIOD_CARD' ? (f.periodType || '') : '',
    periodCount: typeCode === 'PERIOD_CARD' ? num(f.periodCount) : null,

    stock: num(f.stock) === null ? 0 : num(f.stock),
    // 预览是给商家看排版的，销量固定 0：草稿还没卖过，
    // 显示别的数字会让商家以为数据错了。
    sales: 0,
    limitPerUser: num(f.limitPerUser) || 0,
    maxPerOrder: num(f.maxPerOrder) || 0,
    maxPersons: num(f.maxPersons) || 0,
    validityDays: num(f.validityDays) || 0,

    bookingRequired: f.bookingRequired ? 1 : 0,
    requireXiaoxin: f.requireXiaoxin ? 1 : 0,
    refundPolicy: f.refundPolicy || '',
    // 详情页渲染 refundPolicyText（库里存的是 ANYTIME 这种枚举，直接展给顾客不可读）。
    // 会员端 normalize 里会干同一件事，这里不预先翻译，交给 normalize 保证两边一致。
    extraFeeDesc: (f.extraFeeDesc || '').trim(),
    notice: (f.notice || '').trim(),
    otherNotice: (f.otherNotice || '').trim(),
    saleStartDate: f.saleStartDate || '',
    saleEndDate: f.saleEndDate || '',

    cover: f.cover || '',
    images: f.images || '',
    detail: f.detail || '',

    storeId: storeIds.length ? storeIds[0] : null,
    storeIds: storeIds.join(','),
    storeNames: storeNames,
    // 详情页「适用门店」卡的店名走 product.storeName，兑底是 globalData.merchant.merchantName。
    // 商家端预览时那个兑底会显示成「当前商家」，没法确认绑对了店，
    // 所以这里直接给上主门店名。
    storeName: storeIds.length ? (nameOf[storeIds[0]] || ('门店' + storeIds[0])) : '',
    subitemGroups: d.subitemGroups || []
  }
}

module.exports = { draftToProduct: draftToProduct, mapProductType: mapProductType }
