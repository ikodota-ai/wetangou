// utils/productPreview.js —— 商家端建品「预览」的草稿 → 详情页 product 换算
//
// 背景：商家端预览原先是 wx.showModal 弹四行文本摘要（类型/售价/库存/门店），
// 商家看不到类型专属说明、购买须知、套餐详情这些真正影响成交的内容，
// 也就没法在上架前发现「有效期写错了」「须知没填」。
// 现在改成复用会员端 pages/goods/detail 的 preview 态，本文件锁住换算口径。
//
// 为什么值得单测：这一层是纯函数（刻意不依赖 wx API），一旦某个字段
// 换算错了，预览就会「和顾客看到的不一样」，而那恰恰是预览唯一的价值。
import { describe, it, expect } from 'vitest'

const { draftToProduct, mapProductType } = require('../utils/productPreview.js')

const STORES = [
  { id: 100, label: '旗舰店' },
  { id: 101, label: '万象城店' },
  { id: 200, label: '春熙路餐饮店' }
]

function draft(typeCode, form, extra) {
  return Object.assign({
    pickedType: typeCode,
    pickedTypeName: '测试类型',
    storeOptions: STORES,
    form: Object.assign({ storeIdList: [100] }, form || {})
  }, extra || {})
}

describe('mapProductType：typeCode → 会员端 productType', () => {
  it('BILL → 1，BOOKING → 2，其余 → 0（与 create/index.js 的 _mapProductType 同口径）', () => {
    expect(mapProductType('BILL')).toBe('1')
    expect(mapProductType('BOOKING')).toBe('2')
    expect(mapProductType('GROUPON')).toBe('0')
    expect(mapProductType('VOUCHER')).toBe('0')
    expect(mapProductType('COMBO')).toBe('0')
    expect(mapProductType(undefined)).toBe('0')
  })
})

describe('productId / sales 占位', () => {
  it('新建态 productId 必须是 0 而不是 null —— 详情页用 p.productId 判断「拿到商品了」，为空会落到「商品不存在或已下架」空态', () => {
    const p = draftToProduct(draft('GROUPON', {}))
    expect(p.productId).toBe(0)
    // WXML 顶层 wx:if 是 state==='loaded' && product && product.productId
    expect(!!p.productId || p.productId === 0).toBe(true)
    expect(p.productId).not.toBeNull()
  })

  it('编辑态沿用真实 productId', () => {
    const p = draftToProduct(draft('GROUPON', {}, { productId: 999302 }))
    expect(p.productId).toBe(999302)
  })

  it('销量固定 0：草稿还没卖过，显示别的数字会让商家以为数据错了', () => {
    const p = draftToProduct(draft('GROUPON', { stock: 50 }))
    expect(p.sales).toBe(0)
  })
})

describe('VOUCHER 代金券：面值 / 最低消费', () => {
  it('faceValue 与 minConsume 原样带过去，详情页才会显示「面值 ¥100 / 最低消费 ¥120」两行', () => {
    const p = draftToProduct(draft('VOUCHER', {
      productName: '100元代金券', price: '88', faceValue: '100', minConsume: '120'
    }))
    expect(p.productName).toBe('100元代金券')
    expect(p.price).toBe(88)
    expect(p.faceValue).toBe(100)
    expect(p.minConsume).toBe(120)
    expect(p.typeCode).toBe('VOUCHER')
  })
})

describe('TIMECARD 次卡：总次数', () => {
  it('totalTimes 换算成数字（详情页 wx:if 用 product.totalTimes 判显示）', () => {
    const p = draftToProduct(draft('TIMECARD', { totalTimes: '10', price: '299' }))
    expect(p.totalTimes).toBe(10)
    expect(p.price).toBe(299)
  })
})

describe('PERIOD_CARD 周期卡：只有该类型才带周期', () => {
  it('PERIOD_CARD 带 periodType / periodCount', () => {
    const p = draftToProduct(draft('PERIOD_CARD', { periodType: 'QUARTER', periodCount: '2' }))
    expect(p.periodType).toBe('QUARTER')
    expect(p.periodCount).toBe(2)
  })

  it('非 PERIOD_CARD 即使表单里残留周期值也不带出去 —— 否则详情页会给团购套餐显示「周期 季卡」', () => {
    const p = draftToProduct(draft('GROUPON', { periodType: 'MONTH', periodCount: '3' }))
    expect(p.periodType).toBe('')
    expect(p.periodCount).toBeNull()
  })
})

describe('COMBO 组合券包：总价值由 faceValue 承载', () => {
  it('建品页组合券包的「总价值」填在 faceValue 上，详情页读 totalValue —— 不映射的话「总价值」那行永远不显示', () => {
    const p = draftToProduct(draft('COMBO', { faceValue: '360', price: '199' }))
    expect(p.totalValue).toBe(360)
    expect(p.faceValue).toBe(360)
  })
})

describe('适用门店：必须显示店名而不是 ID', () => {
  it('多店拼店名（多店老板看到「门店101」分不清是哪家，而这正是预览要帮他确认的）', () => {
    const p = draftToProduct(draft('GROUPON', { storeIdList: [100, 101] }))
    expect(p.storeNames).toBe('旗舰店、万象城店')
    expect(p.storeIds).toBe('100,101')
    expect(p.storeId).toBe(100)
    // 「适用门店」卡的店名走 product.storeName，兜底会显示成「当前商家」
    expect(p.storeName).toBe('旗舰店')
  })

  it('storeOptions 里没有的 id 退化成「门店{id}」而不是空白', () => {
    const p = draftToProduct(draft('GROUPON', { storeIdList: [777] }))
    expect(p.storeNames).toBe('门店777')
    expect(p.storeName).toBe('门店777')
  })

  it('老单选表单只填了 storeId 也能正常预览（兼容 storeIdList 为空）', () => {
    const p = draftToProduct({
      pickedType: 'GROUPON', storeOptions: STORES,
      form: { storeId: 200, storeIdList: [] }
    })
    expect(p.storeIds).toBe('200')
    expect(p.storeNames).toBe('春熙路餐饮店')
  })

  it('一家店都没选也不能崩 —— 预览不拦 canSubmit，本来就允许必填项没齐就看效果', () => {
    const p = draftToProduct({ pickedType: 'GROUPON', form: {} })
    expect(p.storeIds).toBe('')
    expect(p.storeNames).toBe('')
    expect(p.storeId).toBeNull()
  })
})

describe('空表单兜底', () => {
  it('商品名为空显示占位文案，价格/库存归 0 —— 空字符串会让详情页价格条渲染成「¥」', () => {
    const p = draftToProduct(draft('GROUPON', { productName: '', price: '', stock: '' }))
    expect(p.productName).toBe('（未填写商品名称）')
    expect(p.price).toBe(0)
    expect(p.stock).toBe(0)
  })

  it('整个 draft 是 undefined 也不抛（详情页 _loadPreview 外层还有 try/catch，但这层先兜住）', () => {
    const p = draftToProduct(undefined)
    expect(p.productId).toBe(0)
    expect(p.typeCode).toBe('GROUPON')
    expect(p.price).toBe(0)
  })

  it('非数字字符串不能变成 NaN —— NaN 到了 WXML 会渲染成「NaN」给商家看', () => {
    const p = draftToProduct(draft('VOUCHER', { price: '不填', faceValue: 'abc' }))
    expect(p.price).toBe(0)
    expect(p.faceValue).toBeNull()
    expect(Number.isNaN(p.price)).toBe(false)
  })
})

describe('购买须知相关字段透传', () => {
  it('有效期/限购/退改/使用说明都要带过去，否则「购买须知」整块是空的，预览就查不出须知没填', () => {
    const p = draftToProduct(draft('GROUPON', {
      validityDays: '30', limitPerUser: '2', maxPerOrder: '1',
      refundPolicy: 'ANYTIME', notice: '每桌限用一张', extraFeeDesc: '包间费另付',
      saleStartDate: '2026-09-01', saleEndDate: '2026-12-31'
    }))
    expect(p.validityDays).toBe(30)
    expect(p.limitPerUser).toBe(2)
    expect(p.maxPerOrder).toBe(1)
    expect(p.refundPolicy).toBe('ANYTIME')
    expect(p.notice).toBe('每桌限用一张')
    expect(p.extraFeeDesc).toBe('包间费另付')
    expect(p.saleStartDate).toBe('2026-09-01')
    expect(p.saleEndDate).toBe('2026-12-31')
  })

  it('switch 类字段归一成 0/1（详情页 wx:if 直接判真假）', () => {
    const on = draftToProduct(draft('GROUPON', { bookingRequired: true, requireXiaoxin: 1 }))
    expect(on.bookingRequired).toBe(1)
    expect(on.requireXiaoxin).toBe(1)
    const off = draftToProduct(draft('GROUPON', {}))
    expect(off.bookingRequired).toBe(0)
    expect(off.requireXiaoxin).toBe(0)
  })
})

describe('套餐搭配透传', () => {
  it('subitemGroups 原样带过去，详情页「套餐详情」才有内容（GROUPON/COMBO 的核心卖点）', () => {
    const groups = [{ groupId: 1, groupName: '主菜', pickRule: 'PICK_2', subitems: [
      { subitemId: 11, subitemName: '红烧肉', quantity: 1, price: 38 },
      { subitemId: 12, subitemName: '水煮鱼', quantity: 1, price: 58 }
    ] }]
    const p = draftToProduct(draft('GROUPON', {}, { subitemGroups: groups }))
    expect(p.subitemGroups).toHaveLength(1)
    expect(p.subitemGroups[0].subitems).toHaveLength(2)
  })

  it('没有搭配时是空数组而不是 undefined（详情页 Array.isArray(groups) 判断）', () => {
    const p = draftToProduct(draft('GROUPON', {}))
    expect(Array.isArray(p.subitemGroups)).toBe(true)
    expect(p.subitemGroups).toHaveLength(0)
  })
})

describe('类型名与类型说明走字典', () => {
  it('typeTips 从草稿的 pickedTypeTips 带出来 —— 详情页那张「××说明」卡靠它决定显不显', () => {
    const p = draftToProduct(draft('GROUPON', {}, {
      pickedTypeName: '到店自取',
      pickedTypeTips: '下单后凭核销码到店使用'
    }))
    expect(p.typeName).toBe('到店自取')
    expect(p.typeTips).toBe('下单后凭核销码到店使用')
  })

  it('拉不到字典时 typeTips 为空而不是自己编一句 —— 宁可少一张卡，也不能让商家看到和顾客不一样的文案', () => {
    const p = draftToProduct(draft('GROUPON', {}))
    expect(p.typeTips).toBe('')
  })

  it('类型名不再写死「团购套餐」：运营已把 GROUPON 改成「到店自取」，预览必须跟着变', () => {
    const p = draftToProduct(draft('GROUPON', {}, { pickedTypeName: '到店自取' }))
    expect(p.typeName).not.toBe('团购套餐')
    expect(p.typeName).toBe('到店自取')
  })
})

describe('副标题', () => {
  it('subtitle 必须带出去：它原先在整个详情页上压根没渲染，商家认真填了却从没有顾客看到过', () => {
    const p = draftToProduct(draft('GROUPON', { subtitle: '含 2 人份锅底' }))
    expect(p.subtitle).toBe('含 2 人份锅底')
  })

  it('副标题未填时是空串（WXML 用 wx:if 判，空串不渲染空行）', () => {
    const p = draftToProduct(draft('GROUPON', {}))
    expect(p.subtitle).toBe('')
  })
})

// 预览的全部价值就在「商家看到的 == 顾客将看到的」，
// 所以任何会员端详情页读的字段，预览都必须摆成同构形状。
// 组合券包明细就是一例：它不在子品表而在 ext.comboItemsJson，
// 漏了就会 COMBO 预览没明细、顾客那边却有。
describe('组合券包明细预览同构', () => {
  const ITEMS = JSON.stringify([
    { name: '火锅双人餐', subitemType: 'GROUPON', pickQuantity: 1, price: 99 },
    { name: '50元代金券', subitemType: 'VOUCHER', pickQuantity: 2, price: 50 }
  ])

  it('草稿带了 comboItemsJson → 摆到 ext.comboItemsJson（会员端读的就是这个路径）', () => {
    const p = draftToProduct(draft('COMBO', { productName: '券包' }, { comboItemsJson: ITEMS }))
    expect(p.ext).toBeTruthy()
    expect(p.ext.comboItemsJson).toBe(ITEMS)
  })

  it('没带也必须有 ext 对象（会员端 parseComboItems 读 p.ext.comboItemsJson，不能因为 undefined 报错）', () => {
    const p = draftToProduct(draft('COMBO', { productName: '券包' }))
    expect(p.ext).toBeTruthy()
    expect(p.ext.comboItemsJson).toBe('')
  })

  it('预览路径与会员端真实路径算出完全相同的明细（同一个 parseComboItems）', () => {
    const { parseComboItems } = require('../utils/comboItems.js')
    const p = draftToProduct(draft('COMBO', { productName: '券包' }, { comboItemsJson: ITEMS }))
    const fromPreview = parseComboItems(p)
    // 会员端真实形状：后端 /api/product/{id} 的 data.ext.comboItemsJson
    const fromServer = parseComboItems({ ext: { comboItemsJson: ITEMS } })
    expect(fromPreview).toEqual(fromServer)
    expect(fromPreview.length).toBe(2)
    expect(fromPreview[1].typeText).toBe('代金券')
    expect(fromPreview[1].subtotal).toBe('100.00')
  })

  it('子品组也要能透传（团购套餐的「几选几」预览靠它）', () => {
    const groups = [{ groupId: 1, groupName: '主菜', pickRule: 'PICK_2', subitems: [{ subitemId: 1 }, { subitemId: 2 }, { subitemId: 3 }] }]
    const p = draftToProduct(draft('GROUPON', { productName: '套餐' }, { subitemGroups: groups }))
    expect(p.subitemGroups.length).toBe(1)
    expect(p.subitemGroups[0].pickRule).toBe('PICK_2')
    const { customerPickText } = require('../utils/pickRule.js')
    expect(customerPickText(p.subitemGroups[0])).toBe('3选2')
  })
})

// 交易规则 + 适用门店的预览同构。
//
// 为什么必须锁：这批字段刚在会员端详情页被补上（之前后台能填、顾客看不到）。
// 预览走的是同一张详情页，如果这里不透传，就变成“顾客看得到、商家预览看不到”——
// 同样是预览与现场不一致，只是方向相反。
describe('交易规则预览同构', () => {
  const { mutexText, collectMethodText, codeTypeText } = require('../utils/tradeRules.js')

  it('collectMethod / mutex / ext.codeType 三个字段透传（建品表单真的在收这三个）', () => {
    const p = draftToProduct(draft('GROUPON', {
      productName: '套餐',
      collectMethod: 'STORE',
      mutexWithStorePromotion: 0,
      codeType: 'PLATFORM'
    }))
    expect(p.collectMethod).toBe('STORE')
    expect(p.mutexWithStorePromotion).toBe(0)
    expect(p.ext.codeType).toBe('PLATFORM')
  })

  it('透传后经详情页同一批纯函数算出的文案，与真实态逐字一致', () => {
    const p = draftToProduct(draft('VOUCHER', {
      productName: '代金券',
      collectMethod: 'HEAD',
      mutexWithStorePromotion: 1,
      codeType: 'MERCHANT'
    }))
    expect(collectMethodText(p.collectMethod)).toBe('总部统一收款')
    expect(mutexText(p.mutexWithStorePromotion)).toBe('不与店内优惠同享')
    expect(codeTypeText(p.ext)).toBe('商家券（门店自行核销）')
  })

  it('建品表单默认不同享：mutex 未填时不能算成“可同享”（会误导商家）', () => {
    const p = draftToProduct(draft('GROUPON', { productName: 'x' }))
    expect(p.mutexWithStorePromotion).toBe(1)
    expect(mutexText(p.mutexWithStorePromotion)).toBe('不与店内优惠同享')
  })

  it('ext 必须始终存在（详情页读 p.ext.codeType，undefined 会报错）', () => {
    const p = draftToProduct({})
    expect(p.ext).toBeTruthy()
    expect(codeTypeText(p.ext)).toBe('')
  })
})

describe('预览的适用门店列表', () => {
  it('多选几家就摆出几家（真实态由后端 applicableStores 下发）', () => {
    const p = draftToProduct(draft('GROUPON', { productName: 'x', storeIdList: [100, 101, 200] }))
    expect(p.applicableStores.length).toBe(3)
    expect(p.applicableStores.map(s => s.storeName))
      .toEqual(['旗舰店', '万象城店', '春熙路餐饮店'])
  })

  it('店名而不是 ID：多店老板看「门店101」分不清是哪家', () => {
    const p = draftToProduct(draft('GROUPON', { productName: 'x', storeIdList: [999] }))
    expect(p.applicableStores[0].storeName).toBe('门店999')
  })

  it('一家都没选 → 空数组（WXML 靠 .length 判空，undefined 会在渲染层报错）', () => {
    const p = draftToProduct(draft('GROUPON', { productName: 'x', storeIdList: [], storeId: 0 }))
    expect(Array.isArray(p.applicableStores)).toBe(true)
    expect(p.applicableStores.length).toBe(0)
  })
})

// 交易规则那 5 组 ext 字段的预览透传。
//
// 背景：这 5 组（可消费日期 / 不可消费日期 / 每日时段 / 适用规则 /
// 适用范围）原先只有 PC 能填，而商品创建主战场是商家端。
// 顶客端详情页（utils/tradeRules.js）早就在渲染它们，但只读 ext 这个路径 ——
// 预览不透传，商家刚填完去预览会发现那几行是空的，以为没生效。
describe('预览必须透传交易规则的 ext 字段', () => {
  const FORM = {
    productName: 'x券',
    consumeStartDate: '2026-09-10',
    consumeEndDate: '2026-12-31',
    excludeStartDate: '2026-10-01',
    excludeEndDate: '2026-10-07',
    dailyTimeStart: '09:00',
    dailyTimeEnd: '22:30',
    voucherRules: ['ALL_CATEGORY', 'ALL_BRAND'],
    scopeType: 'STORE',
    voucherType: 'CATEGORY',
    codeType: 'PLATFORM'
  }

  it('日期 / 时段 / 适用规则 全部落在 ext 下（顾客端只读这个路径）', () => {
    const p = draftToProduct(draft('VOUCHER', FORM))
    expect(p.ext.consumeStartDate).toBe('2026-09-10')
    expect(p.ext.consumeEndDate).toBe('2026-12-31')
    expect(p.ext.dailyTimeStart).toBe('09:00')
    expect(p.ext.dailyTimeEnd).toBe('22:30')
    expect(p.ext.voucherRules).toBe('ALL_CATEGORY,ALL_BRAND')
  })

  it('excludeDates 必须包成 [[起,止]] 二级数组，否则顾客端 excludeDatesText 解不出', () => {
    const p = draftToProduct(draft('VOUCHER', FORM))
    expect(JSON.parse(p.ext.excludeDates)).toEqual([['2026-10-01', '2026-10-07']])
  })

  it('只填一端日期 → 不拼半截的区间（宁可不显，不能显一个残区间）', () => {
    const p = draftToProduct(draft('VOUCHER', Object.assign({}, FORM, { excludeEndDate: '' })))
    expect(p.ext.excludeDates).toBe('')
  })

  it('voucherScopeType 双语义：代金券取 scopeType，其余类型取 voucherType', () => {
    // 同一列 ext.voucher_scope_type 两个控件共用（与 PC packFormToExt 一致）。
    // CATEGORY 这个值两边都有，分流错了会把「单品类券」误写成「按品类适用」。
    expect(draftToProduct(draft('VOUCHER', FORM)).ext.voucherScopeType).toBe('STORE')
    expect(draftToProduct(draft('GROUPON', FORM)).ext.voucherScopeType).toBe('CATEGORY')
  })

  it('什么都不填时这几个键仍存在且为空串（undefined 会让 tradeRules 报错）', () => {
    const p = draftToProduct(draft('GROUPON', { productName: 'x' }))
    expect(p.ext.consumeStartDate).toBe('')
    expect(p.ext.excludeDates).toBe('')
    expect(p.ext.dailyTimeStart).toBe('')
    expect(p.ext.voucherRules).toBe('')
  })
})

// 商品图片：预览要和顾客端同口径（cover=头图、images=环境图）
describe('预览的商品图片', () => {
  it('cover / images 原串透传，由详情页 normalize 统一拆串', () => {
    // 不在这里先拆：拆两遍早晚漂，预览就不再等于顾客看到的。
    const p = draftToProduct(draft('GROUPON', {
      productName: 'x', cover: '/a.jpg,/b.jpg', images: '/c.jpg'
    }))
    expect(p.cover).toBe('/a.jpg,/b.jpg')
    expect(p.images).toBe('/c.jpg')
  })
})
