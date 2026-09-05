// tests/productListFilter.test.js
// 商家端商品列表页：类型名映射 + 派生字段 + 勾选态
//
// 锁的是「WXML 调不到 Page 方法」这条反复复发的坑：所有模板要用的值都必须
// 在 js 里算好塞进 setData。decorate() 就是这一层，它一旦漏字段，界面上
// 表现为静默空白（不报错、不白屏），所以必须有单测钉住。
import { describe, it, expect } from 'vitest'

globalThis.Page = () => {}
globalThis.wx = {
  showToast: () => {}, showModal: () => {}, showActionSheet: () => {},
  showLoading: () => {}, hideLoading: () => {},
  navigateTo: () => {}, navigateBack: () => {}, switchTab: () => {},
  redirectTo: () => {}, stopPullDownRefresh: () => {},
  getStorageSync: () => '', setStorageSync: () => {}, removeStorageSync: () => {},
  request: () => {}
}

const { TYPE_NAMES, FILTER_TYPES, typeNameOf, decorate } =
  require('../pages/merchant/product/list/index.js').__test__

describe('typeNameOf', () => {
  // 兑底表必须跟 biz_product_type.type_name 的现值一致。
  // 原先这里锁的是「团购」，而字典早被运营改成「到店自取」：
  // 商家在小程序列表看到「团购」、后台和顾客端看到「到店自取」。
  // 单测把错值锁住了，反而让这个不一致看起来「符合预期」。
  it('GROUPON → 到店自取（与字典一致）', () => expect(typeNameOf('GROUPON')).toBe('到店自取'))
  it('不能再回到写死的旧名「团购」/「团购套餐」', () => {
    expect(typeNameOf('GROUPON')).not.toBe('团购')
    expect(typeNameOf('GROUPON')).not.toBe('团购套餐')
  })
  it('COMBO → 组合券包', () => expect(typeNameOf('COMBO')).toBe('组合券包'))
  it('BILL → 到店买单', () => expect(typeNameOf('BILL')).toBe('到店买单'))
  it('未知 code → 原样返回（不吞掉信息）', () => expect(typeNameOf('WHAT')).toBe('WHAT'))
  it('空 → 其他', () => expect(typeNameOf('')).toBe('其他'))
  it('undefined → 其他', () => expect(typeNameOf(undefined)).toBe('其他'))
})

describe('FILTER_TYPES', () => {
  it('第一项是「全部类型」且 code 为空（用于回落到 tab 语义）', () => {
    expect(FILTER_TYPES[0].code).toBe('')
    expect(FILTER_TYPES[0].name).toBe('全部类型')
  })
  it('覆盖 TYPE_NAMES 里全部 11 种类型，一个不漏', () => {
    const codes = FILTER_TYPES.filter(t => t.code).map(t => t.code).sort()
    expect(codes).toEqual(Object.keys(TYPE_NAMES).sort())
  })
  it('每个 code 的名称与 TYPE_NAMES 一致（避免筛选项和列表标签叫法不同）', () => {
    FILTER_TYPES.filter(t => t.code).forEach(t => {
      expect(t.name).toBe(TYPE_NAMES[t.code])
    })
  })
})

describe('decorate', () => {
  it('空/null → 空数组', () => {
    expect(decorate(null, [])).toEqual([])
    expect(decorate([], [])).toEqual([])
  })

  it('挂上 typeName —— 模板 {{item.typeName}} 靠它，缺了类型标签就是空色块', () => {
    const out = decorate([{ productId: 1, typeCode: 'GROUPON' }], [])
    expect(out[0].typeName).toBe('到店自取')
  })

  it('stock=-1 → 不限库存', () => {
    const out = decorate([{ productId: 1, stock: -1 }], [])
    expect(out[0].stockText).toBe('不限库存')
  })

  it('stock=0 → 显示 0（不能被当成「不限」）', () => {
    const out = decorate([{ productId: 1, stock: 0 }], [])
    expect(out[0].stockText).toBe(0)
  })

  it('stock=50 → 原样', () => {
    const out = decorate([{ productId: 1, stock: 50 }], [])
    expect(out[0].stockText).toBe(50)
  })

  it('_picked 按 selectedIds 判定，数字/字符串 id 混用也要认得', () => {
    const list = [{ productId: 11 }, { productId: 22 }, { productId: 33 }]
    const out = decorate(list, ['11', 33])
    expect(out.map(p => p._picked)).toEqual([true, false, true])
  })

  it('selectedIds 为空 → 全部未勾选', () => {
    const out = decorate([{ productId: 1 }, { productId: 2 }], [])
    expect(out.every(p => p._picked === false)).toBe(true)
  })

  it('不改原对象（避免 setData 后引用互相污染）', () => {
    const src = [{ productId: 1, typeCode: 'GROUPON', stock: -1 }]
    decorate(src, ['1'])
    expect(src[0].typeName).toBeUndefined()
    expect(src[0]._picked).toBeUndefined()
  })

  it('保留原有业务字段', () => {
    const out = decorate([{ productId: 7, productName: '双人餐', price: 99, status: '1' }], [])
    expect(out[0].productName).toBe('双人餐')
    expect(out[0].price).toBe(99)
    expect(out[0].status).toBe('1')
  })
})
