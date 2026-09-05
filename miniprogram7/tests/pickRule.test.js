// tests/pickRule.test.js
//
// utils/pickRule.js 是「几选几 + 本组合计」的全系统唯一口径
// （商家端编辑页 + 会员端详情页 共用）。口径一漂就是履约纠纷：
// 商家在后台设的是「3选2」、顾客看到的是「3选3」。
//
// combo.test.js 锁的是商家端页面重导出的同名函数，这里直接锁 utils 本体，
// 并补上本轮新增的 groupTotalPrice（商家端那份没有它）。
import { describe, it, expect } from 'vitest'

const { groupSize, groupPickCount, pickRuleText, customerPickText,
  groupTotalPrice, pickRuleOptions } = require('../utils/pickRule.js')

function g(subitems, pickRule) {
  return { groupId: 1, groupName: '测试组', pickRule: pickRule || 'ALL', subitems: subitems || [] }
}
function it3() {
  return [{ subitemName: 'a' }, { subitemName: 'b' }, { subitemName: 'c' }]
}

describe('groupSize / groupPickCount', () => {
  it('只数品种，不看 quantity', () => {
    expect(groupSize(g([{ quantity: 2 }, { quantity: 1 }]))).toBe(2)
  })
  it('ALL / 空规则 / 超过总数 都按全选', () => {
    expect(groupPickCount(g(it3(), 'ALL'))).toBe(3)
    expect(groupPickCount(g(it3(), ''))).toBe(3)
    expect(groupPickCount(g(it3(), 'PICK_9'))).toBe(3)
  })
  it('PICK_N 取 N', () => {
    expect(groupPickCount(g(it3(), 'PICK_2'))).toBe(2)
  })
  it('兼容历史写进库的中文 N选M', () => {
    expect(groupPickCount(g(it3(), '3选2'))).toBe(2)
  })
})

describe('pickRuleText / customerPickText 两套文案各取所需', () => {
  it('商家端带“共N个单品”（他要校对刚加完的数）', () => {
    expect(pickRuleText(g(it3(), 'PICK_2'))).toBe('共3个单品：3选2')
    expect(pickRuleText(g([], 'ALL'))).toBe('未添加单品')
  })
  it('顾客端全选返空串（下面就列着那几行菜，再挂“全部可选”反而让人疑心）', () => {
    expect(customerPickText(g(it3(), 'ALL'))).toBe('')
    expect(customerPickText(g(it3(), 'PICK_2'))).toBe('3选2')
    expect(customerPickText(g([], 'ALL'))).toBe('')
  })
})

// 本轮新增。两个关键行为都是看真库定下来的，不是拍脑袋：
//  1) quantity 必须乘进去——999534 荒菜组 8 个单品 264 元，含多份项；
//  2) 全 0 返空串——999534 锅底组、999742 两组价格全为 0，
//     展一行“小计 ¥0.00”会让顾客以为这组不值钱。
describe('groupTotalPrice', () => {
  it('按 price × quantity 求和，保留两位小数字符串', () => {
    expect(groupTotalPrice(g([{ price: '33.00', quantity: 2 }, { price: '10.00' }]))).toBe('76.00')
  })
  it('quantity 缺失 / 非法 / ≤ 0 都当 1 份', () => {
    expect(groupTotalPrice(g([{ price: 5 }]))).toBe('5.00')
    expect(groupTotalPrice(g([{ price: 5, quantity: 0 }]))).toBe('5.00')
    expect(groupTotalPrice(g([{ price: 5, quantity: 'x' }]))).toBe('5.00')
  })
  it('全组价格都 ≤ 0 时返空串，不返 "0.00"', () => {
    expect(groupTotalPrice(g([{ price: '0.00' }, { price: 0 }]))).toBe('')
    expect(groupTotalPrice(g([]))).toBe('')
    expect(groupTotalPrice(null)).toBe('')
  })
  it('部分未填价时只算填了的那几项', () => {
    expect(groupTotalPrice(g([{ price: 0 }, { price: '12.50', quantity: 2 }]))).toBe('25.00')
  })
})

describe('pickRuleOptions 按实际单品数动态生成', () => {
  it('3 个单品 → 全部可选(3选3) / 3选2 / 3选1', () => {
    const o = pickRuleOptions(g(it3()))
    expect(o.values).toEqual(['ALL', 'PICK_2', 'PICK_1'])
    expect(o.labels[0]).toBe('全部可选（3选3）')
  })
  it('不能硬编码：2 个单品的组不得出现 PICK_2 以上', () => {
    const o = pickRuleOptions(g([{}, {}]))
    expect(o.values).toEqual(['ALL', 'PICK_1'])
  })
})
