// tests/combo.test.js
// 商家端搭配页「几选几」纯函数 —— 锁住动态规则口径，与 PC 端 create.vue 的
// groupPickCount / pickRuleOptions 完全一致，不允许两边算出来不一样。
//
// 反向验证：把 pickRule 从 ALL 改成 'PICK_3'，测试会检查「3 个单品选 3 个
// 应归一成 ALL」—— 如果某天改了这一行为，测试会红。
import { describe, it, expect } from 'vitest'

// 小程序页面依赖 Page()/wx 全局，没桩 require 会直接抛（项目里 pay.test.js 同模式）
globalThis.Page = () => {}
globalThis.wx = {
  showToast: () => {}, showModal: () => {}, navigateBack: () => {}, navigateTo: () => {},
  getStorageSync: () => '', setStorageSync: () => {}, removeStorageSync: () => {}, request: () => {}
}

const { groupSize, groupPickCount, pickRuleText, pickRuleOptions,
  decorateGroups, decorateCombos, sumGroups, sumCombo } = require('../pages/merchant/product/combo/index.js').__test__

// ===== 辅助 =====
function makeGroup(subitems, pickRule) {
  return { groupId: 1, groupName: '测试组', pickRule: pickRule || 'ALL', subitems: subitems || [] }
}

// ===== groupSize =====
describe('groupSize', () => {
  it('空组 → 0', () => expect(groupSize(makeGroup([]))).toBe(0))
  it('3 个子品 → 3', () => {
    const g = makeGroup([{ subitemId: 1 }, { subitemId: 2 }, { subitemId: 3 }])
    expect(groupSize(g)).toBe(3)
  })
  it('quantity 翻倍不影响个数', () => {
    const g = makeGroup([{ subitemId: 1, quantity: 10 }, { subitemId: 2, quantity: 5 }])
    expect(groupSize(g)).toBe(2) // 不是 15
  })
})

// ===== groupPickCount =====
describe('groupPickCount', () => {
  it('无规则 → 全选', () => {
    const g = makeGroup([{},{},{},{}], '')
    expect(groupPickCount(g)).toBe(4)
  })
  it('ALL → 全选', () => {
    const g = makeGroup([{},{},{}], 'ALL')
    expect(groupPickCount(g)).toBe(3)
  })
  it('PICK_2 → 选 2 个', () => {
    const g = makeGroup([{},{},{}], 'PICK_2')
    expect(groupPickCount(g)).toBe(2)
  })
  it('PICK_N > 单品数 → 归一全选', () => {
    const g = makeGroup([{},{},{}], 'PICK_5')
    expect(groupPickCount(g)).toBe(3) // 5 > 3，按全选
  })
  it('兼容历史中文格式 3选2 → 选 2 个', () => {
    const g = makeGroup([{},{},{}], '3选2')
    expect(groupPickCount(g)).toBe(2)
  })
  it('中文格式 N 选 N → 全选', () => {
    const g = makeGroup([{},{},{}], '3选3')
    expect(groupPickCount(g)).toBe(3)
  })
  it('PICK_1 在 1 个单品时 → 全选', () => {
    const g = makeGroup([{}], 'PICK_1')
    expect(groupPickCount(g)).toBe(1) // 1 >= 1，按全选
  })
})

// ===== pickRuleText =====
describe('pickRuleText', () => {
  it('无单品 → 未添加单品', () => {
    expect(pickRuleText(makeGroup([], 'ALL'))).toBe('未添加单品')
  })
  it('3 单品 ALL → 共3个单品：3选3', () => {
    const g = makeGroup([{},{},{}], 'ALL')
    expect(pickRuleText(g)).toBe('共3个单品：3选3')
  })
  it('3 单品 PICK_2 → 共3个单品：3选2', () => {
    const g = makeGroup([{},{},{}], 'PICK_2')
    expect(pickRuleText(g)).toBe('共3个单品：3选2')
  })
  it('2 单品 PICK_1 → 共2个单品：2选1', () => {
    const g = makeGroup([{},{}], 'PICK_1')
    expect(pickRuleText(g)).toBe('共2个单品：2选1')
  })
})

// ===== pickRuleOptions =====
describe('pickRuleOptions', () => {
  it('1 单品 → 1 项（全部可选）', () => {
    const g = makeGroup([{}], 'ALL')
    const opts = pickRuleOptions(g)
    expect(opts.labels.length).toBe(1)
    expect(opts.values[0]).toBe('ALL')
  })
  it('3 单品 → 3 项：全部可选、3选2、3选1', () => {
    const g = makeGroup([{},{},{}], 'ALL')
    const opts = pickRuleOptions(g)
    expect(opts.labels).toEqual(['全部可选（3选3）', '3选2', '3选1'])
    expect(opts.values).toEqual(['ALL', 'PICK_2', 'PICK_1'])
  })
  it('2 单品 → 2 项：全部可选、2选1', () => {
    const g = makeGroup([{},{}], 'ALL')
    const opts = pickRuleOptions(g)
    expect(opts.labels).toEqual(['全部可选（2选2）', '2选1'])
    expect(opts.values).toEqual(['ALL', 'PICK_1'])
  })
})

// ===== decorateGroups =====
describe('decorateGroups', () => {
  it('空 → 空数组', () => expect(decorateGroups(null)).toEqual([]))
  it('3 单品 ALL → _pickText + _ruleLabels + _ruleIdx=0', () => {
    const raw = [makeGroup([{},{},{}], 'ALL')]
    const out = decorateGroups(raw)
    expect(out[0]._pickText).toBe('共3个单品：3选3')
    expect(out[0]._ruleLabels.length).toBe(3)
    expect(out[0]._ruleValues[0]).toBe('ALL')
    expect(out[0]._ruleIdx).toBe(0) // ALL 在第一项
  })
})

// ===== sumGroups =====
describe('sumGroups', () => {
  it('空 → {totalCount:0, pickCount:0}', () => {
    expect(sumGroups([])).toEqual({ totalCount: 0, pickCount: 0 })
  })
  it('两组 3+2 单品，ALL + PICK_1 → 5 个总，3+1=4 个可选', () => {
    const groups = decorateGroups([
      makeGroup([{},{},{}], 'ALL'),
      makeGroup([{},{}], 'PICK_1')
    ])
    const r = sumGroups(groups)
    expect(r.totalCount).toBe(5)
    expect(r.pickCount).toBe(4) // 3+1
  })
})

// ===== decorateCombos / sumCombo =====
describe('decorateCombos', () => {
  it('空 → 空数组', () => expect(decorateCombos(null)).toEqual([]))
  it('VOUCHER+PICK_1 → _typeIdx=1 _ruleIdx=1', () => {
    const raw = [{ subitemType: 'VOUCHER', pickRule: 'PICK_1' }]
    const out = decorateCombos(raw)
    expect(out[0]._typeIdx).toBe(1)
    expect(out[0]._ruleIdx).toBe(1)
    expect(out[0].subitemTypeLabel).toBe('代金券')
    expect(out[0].pickRuleLabel).toBe('1选1')
  })
  it('unknown type → 降级 0', () => {
    const raw = [{ subitemType: 'UNKNOWN', pickRule: 'UNKNOWN' }]
    const out = decorateCombos(raw)
    expect(out[0]._typeIdx).toBe(0)
    expect(out[0]._ruleIdx).toBe(0)
  })
})

describe('sumCombo', () => {
  it('空 → 0', () => expect(sumCombo([])).toBe(0))
  it('1 项 × ¥20 → 20', () => {
    expect(sumCombo([{ pickQuantity: 1, price: 20 }])).toBe(20)
  })
  it('3 项 × ¥15 + 2 项 × ¥10 → 65', () => {
    expect(sumCombo([{ pickQuantity: 3, price: 15 }, { pickQuantity: 2, price: 10 }])).toBe(65)
  })
})
