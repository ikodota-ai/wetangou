// tests/comboItems.test.js
// 组合券包明细解析 + 顾客端「几选几」文案。
//
// 为什么必须锁：这两个点都是「枚举码直接摆给顾客看」型的 bug，
// 而且因为套餐详情卡过去根本没真正显示过（subitemGroups 被 request()
// 解包吃掉 / COMBO 读的是只存在于 mock 的 packages），一直无人发现。
import { describe, it, expect } from 'vitest'

const { parseComboItems } = require('../utils/comboItems.js')
const { groupSize, groupPickCount, pickRuleText, customerPickText, pickRuleOptions } = require('../utils/pickRule.js')

function combo(items) {
  return { ext: { comboItemsJson: JSON.stringify(items) } }
}

// ===== parseComboItems =====
describe('parseComboItems', () => {
  it('空 / 缺字段 → 空数组（不能抛，否则整页白屏）', () => {
    expect(parseComboItems(null)).toEqual([])
    expect(parseComboItems({})).toEqual([])
    expect(parseComboItems({ ext: {} })).toEqual([])
    expect(parseComboItems({ ext: { comboItemsJson: '' } })).toEqual([])
  })

  it('非法 JSON → 空数组而不是抛异常', () => {
    expect(parseComboItems({ ext: { comboItemsJson: '{not json' } })).toEqual([])
  })

  it('JSON 不是数组（历史脏数据）→ 空数组', () => {
    expect(parseComboItems({ ext: { comboItemsJson: '{"a":1}' } })).toEqual([])
    expect(parseComboItems({ ext: { comboItemsJson: '"abc"' } })).toEqual([])
  })

  it('已是数组对象（非字符串）也能吃', () => {
    const r = parseComboItems({ ext: { comboItemsJson: [{ name: 'A', subitemType: 'VOUCHER', pickQuantity: 1, price: 10 }] } })
    expect(r.length).toBe(1)
    expect(r[0].typeText).toBe('代金券')
  })

  it('四种类型码全部翻成中文，与商家端 SUBITEM_TYPE_LABELS 一致', () => {
    const r = parseComboItems(combo([
      { name: 'a', subitemType: 'GROUPON', pickQuantity: 1, price: 1 },
      { name: 'b', subitemType: 'VOUCHER', pickQuantity: 1, price: 1 },
      { name: 'c', subitemType: 'MANJIAN', pickQuantity: 1, price: 1 },
      { name: 'd', subitemType: 'ZHEKOU', pickQuantity: 1, price: 1 }
    ]))
    expect(r.map(x => x.typeText)).toEqual(['团购套餐', '代金券', '满减券', '折扣券'])
  })

  it('未知类型码原样保留（宁可显码也不能静默丢行）', () => {
    const r = parseComboItems(combo([{ name: 'x', subitemType: 'FUTURE_TYPE', pickQuantity: 1, price: 1 }]))
    expect(r.length).toBe(1)
    expect(r[0].typeText).toBe('FUTURE_TYPE')
  })

  it('缺 subitemType → typeText 为空串（WXML 不展那个小标）', () => {
    const r = parseComboItems(combo([{ name: 'x', pickQuantity: 1, price: 5 }]))
    expect(r[0].typeText).toBe('')
  })

  it('小计 = pickQuantity × price，与商家端 sumCombo 同口径', () => {
    const r = parseComboItems(combo([{ name: '50元券', subitemType: 'VOUCHER', pickQuantity: 2, price: 50 }]))
    expect(r[0].quantity).toBe(2)
    expect(r[0].price).toBe('50.00')
    expect(r[0].subtotal).toBe('100.00')
  })

  it('金额一律保留两位小数（顾客看到 ¥99 会以为是整数价）', () => {
    const r = parseComboItems(combo([{ name: 'a', subitemType: 'GROUPON', pickQuantity: 1, price: 99 }]))
    expect(r[0].price).toBe('99.00')
    expect(r[0].subtotal).toBe('99.00')
  })

  it('pickQuantity 缺失 → 当 1；price 缺失 → 当 0', () => {
    const r = parseComboItems(combo([{ name: 'a', subitemType: 'GROUPON' }]))
    expect(r[0].quantity).toBe(1)
    expect(r[0].subtotal).toBe('0.00')
  })

  it('无名字的行丢弃（渲染出来就是一行空白加一个价钱）', () => {
    const r = parseComboItems(combo([
      { name: '', subitemType: 'GROUPON', pickQuantity: 1, price: 10 },
      { name: '正常行', subitemType: 'GROUPON', pickQuantity: 1, price: 20 }
    ]))
    expect(r.length).toBe(1)
    expect(r[0].name).toBe('正常行')
  })

  it('兼容顶层 comboItemsJson（不走 ext 包裹时）', () => {
    const r = parseComboItems({ comboItemsJson: JSON.stringify([{ name: 'a', subitemType: 'VOUCHER', pickQuantity: 1, price: 3 }]) })
    expect(r.length).toBe(1)
  })
})

// ===== customerPickText（顾客端） =====
describe('customerPickText', () => {
  const g = (n, rule) => ({ pickRule: rule, subitems: Array.from({ length: n }, (_, i) => ({ subitemId: i })) })

  it('永不返回枚举码 —— 这正是本轮修的 bug（顾客看到 PICK_2）', () => {
    expect(customerPickText(g(3, 'PICK_2'))).toBe('3选2')
    expect(customerPickText(g(3, 'PICK_2'))).not.toContain('PICK')
  })

  it('全选 → 空串，WXML 不展标签（列出每道都给，再挂一个反而让人疑心要选）', () => {
    expect(customerPickText(g(3, 'ALL'))).toBe('')
    expect(customerPickText(g(3, ''))).toBe('')
    expect(customerPickText(g(3, null))).toBe('')
  })

  it('N 超出子品数 → 当全选（脉经不上的脏规则不能展成 3选5）', () => {
    expect(customerPickText(g(3, 'PICK_5'))).toBe('')
    expect(customerPickText(g(3, 'PICK_3'))).toBe('')
  })

  it('空组 → 空串', () => {
    expect(customerPickText(g(0, 'PICK_1'))).toBe('')
    expect(customerPickText(null)).toBe('')
  })

  it('兼容历史中文规则 3选2', () => {
    expect(customerPickText(g(3, '3选2'))).toBe('3选2')
  })

  it('4选1 正常展', () => {
    expect(customerPickText(g(4, 'PICK_1'))).toBe('4选1')
  })
})

// ===== 两端口径必须一致（共用同一份） =====
describe('商家端与顾客端口径一致', () => {
  const g = (n, rule) => ({ pickRule: rule, subitems: Array.from({ length: n }, (_, i) => ({ subitemId: i })) })

  it('商家端设 PICK_2 → 两边都是「选 2」，不允许一边 3选2 一边 3选3', () => {
    expect(groupPickCount(g(3, 'PICK_2'))).toBe(2)
    expect(pickRuleText(g(3, 'PICK_2'))).toBe('共3个单品：3选2')
    expect(customerPickText(g(3, 'PICK_2'))).toBe('3选2')
  })

  it('个数按品种数算，quantity 不参与', () => {
    const grp = { pickRule: 'ALL', subitems: [{ quantity: 10 }, { quantity: 5 }] }
    expect(groupSize(grp)).toBe(2)
    expect(pickRuleText(grp)).toBe('共2个单品：2选2')
  })

  it('pickRuleOptions 按实际单品数生成', () => {
    const o = pickRuleOptions(g(3, 'ALL'))
    expect(o.values).toEqual(['ALL', 'PICK_2', 'PICK_1'])
    expect(o.labels[0]).toBe('全部可选（3选3）')
  })
})
