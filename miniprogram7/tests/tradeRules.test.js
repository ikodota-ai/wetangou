// tests/tradeRules.test.js
// 交易规则文案口径 + 富文本空值判定。
//
// 为什么必须锁：这 6 个字段（mutex / collectMethod / codeType /
// dailyTime / excludeDates / voucherRules）PC 建品页能填、库里真有值、
// 后端也一直在下发，但会员端详情页从未读过 —— 属于“后台能填、
// 顾客看不到”型缺陷，而其中“不与店内优惠同享”是到店最容易吵架的一条。
// 翻译文案必须跟 PC views/biz/product/create.vue 的选项逐字一致，
// 否则商家在后台看到的和顾客在手机上看到的是两个名字。
import { describe, it, expect } from 'vitest'

const {
  hhmm, dailyTimeText, excludeDatesText, voucherRulesText,
  collectMethodText, codeTypeText, mutexText, hasRichContent
} = require('../utils/tradeRules.js')

describe('hhmm / dailyTimeText 可用时段', () => {
  it('库里存 HH:mm:ss，顾客只看到分钟', () => {
    expect(hhmm('09:00:00')).toBe('09:00')
    expect(hhmm('22:30:00')).toBe('22:30')
  })
  it('单位数小时补 0，不能出现 9:00 这种参差小的展示', () => {
    expect(hhmm('9:00:00')).toBe('09:00')
  })
  it('空值不编造', () => {
    expect(hhmm('')).toBe('')
    expect(hhmm(null)).toBe('')
    expect(hhmm(undefined)).toBe('')
  })
  it('两端齐全 → 区间', () => {
    expect(dailyTimeText({ dailyTimeStart: '09:00:00', dailyTimeEnd: '22:30:00' })).toBe('09:00 至 22:30')
  })
  it('只填一端也要能说清楚，不能因为缺一端就整条不显', () => {
    expect(dailyTimeText({ dailyTimeStart: '09:00:00' })).toBe('09:00 起可用')
    expect(dailyTimeText({ dailyTimeEnd: '22:00:00' })).toBe('22:00 前可用')
  })
  it('ext 缺失 / 字段全空 → 空串（WXML 靠它 wx:if 隐整行）', () => {
    expect(dailyTimeText(null)).toBe('')
    expect(dailyTimeText({})).toBe('')
    expect(dailyTimeText({ dailyTimeStart: '', dailyTimeEnd: '' })).toBe('')
  })
})

describe('excludeDatesText 不可消费日期', () => {
  it('必须列出全部段：PC 表单只用第一段，但库里能存多段，只展一段跟没写一样危险', () => {
    const ext = { excludeDates: JSON.stringify([['2026-01-01', '2026-01-03'], ['2026-02-14', '2026-02-16']]) }
    expect(excludeDatesText(ext)).toBe('2026-01-01～2026-01-03、2026-02-14～2026-02-16')
  })
  it('起止同一天 → 不重复写两遍', () => {
    const ext = { excludeDates: JSON.stringify([['2026-05-01', '2026-05-01']]) }
    expect(excludeDatesText(ext)).toBe('2026-05-01')
  })
  it('只有起日的段也要展，不能整段丢', () => {
    const ext = { excludeDates: JSON.stringify([['2026-05-01', '']]) }
    expect(excludeDatesText(ext)).toBe('2026-05-01')
  })
  it('平铺字符串数组（历史格式）也兼容', () => {
    expect(excludeDatesText({ excludeDates: JSON.stringify(['2026-05-01', '2026-06-01']) }))
      .toBe('2026-05-01、2026-06-01')
  })
  it('非法 JSON 不能报错把整页带倒，只隐这一行', () => {
    expect(excludeDatesText({ excludeDates: 'not-json' })).toBe('')
    expect(excludeDatesText({ excludeDates: '{"a":1}' })).toBe('')
  })
  it('空值 → 空串', () => {
    expect(excludeDatesText(null)).toBe('')
    expect(excludeDatesText({})).toBe('')
    expect(excludeDatesText({ excludeDates: '' })).toBe('')
    expect(excludeDatesText({ excludeDates: '[]' })).toBe('')
  })
})

describe('voucherRulesText 代金券适用范围', () => {
  it('码值翻成中文，文案与 PC create.vue 的 checkbox 逐字一致', () => {
    expect(voucherRulesText({ voucherRules: 'ALL_CATEGORY' })).toBe('全部品类适用')
    expect(voucherRulesText({ voucherRules: 'ALL_BRAND' })).toBe('全部品牌适用')
  })
  it('多选 → 顶号拼接', () => {
    expect(voucherRulesText({ voucherRules: 'ALL_CATEGORY,ALL_BRAND' }))
      .toBe('全部品类适用、全部品牌适用')
  })
  it('空段 / 空格不能拼出多余顶号', () => {
    expect(voucherRulesText({ voucherRules: 'ALL_CATEGORY, ,ALL_BRAND,' }))
      .toBe('全部品类适用、全部品牌适用')
  })
  it('未知码值原样透出（宁可看到码，不能默默吐掉让规则消失）', () => {
    expect(voucherRulesText({ voucherRules: 'SOME_NEW_RULE' })).toBe('SOME_NEW_RULE')
  })
  it('空值 → 空串', () => {
    expect(voucherRulesText(null)).toBe('')
    expect(voucherRulesText({})).toBe('')
    expect(voucherRulesText({ voucherRules: '' })).toBe('')
  })
})

describe('collectMethodText / codeTypeText 核销与收款', () => {
  it('HEAD / STORE 两个取值', () => {
    expect(collectMethodText('HEAD')).toBe('总部统一收款')
    expect(collectMethodText('STORE')).toBe('门店独立收款')
  })
  it('collect_method 的库表 comment 历史上把券码语义写错过，PLATFORM 不是它的合法值', () => {
    expect(collectMethodText('PLATFORM')).toBe('')
  })
  it('空值 → 空串', () => {
    expect(collectMethodText('')).toBe('')
    expect(collectMethodText(null)).toBe('')
  })
  it('券码类型说的是“到店找谁核”，不能把枚举名摊给顾客', () => {
    expect(codeTypeText({ codeType: 'PLATFORM' })).toBe('平台券（平台统一发码）')
    expect(codeTypeText({ codeType: 'MERCHANT' })).toBe('商家券（门店自行核销）')
  })
  it('ext 缺失 / 未知值 → 空串', () => {
    expect(codeTypeText(null)).toBe('')
    expect(codeTypeText({})).toBe('')
    expect(codeTypeText({ codeType: 'XX' })).toBe('')
  })
})

describe('mutexText 与店内优惠是否同享', () => {
  it('1 = 不同享，0 = 可同享', () => {
    expect(mutexText(1)).toBe('不与店内优惠同享')
    expect(mutexText(0)).toBe('可与店内优惠同享')
  })
  it('字符串 「1」/「0」 同样要识——旧写法用 === 0/1 严格比较，后端一旦以字符串下发整条就消失', () => {
    expect(mutexText('1')).toBe('不与店内优惠同享')
    expect(mutexText('0')).toBe('可与店内优惠同享')
  })
  it('null / undefined / 空串 = 商家没填，一个字也不能编', () => {
    expect(mutexText(null)).toBe('')
    expect(mutexText(undefined)).toBe('')
    expect(mutexText('')).toBe('')
  })
})

describe('hasRichContent 富文本是不是真的有内容', () => {
  it('真有字 → true', () => {
    expect(hasRichContent('<p>到店出示券码</p>')).toBe(true)
  })
  it('富文本编辑器清空后的底湣 → false（否则详情页多出一张只有标题的空卡）', () => {
    expect(hasRichContent('<p><br></p>')).toBe(false)
    expect(hasRichContent('<p>&nbsp;</p>')).toBe(false)
    expect(hasRichContent('<div>\n  <p>\n  </p>\n</div>')).toBe(false)
  })
  it('纯图片 / 表格 / 视频算有内容——图文详情很常见就是长图一个字也没', () => {
    expect(hasRichContent('<p><img src="/x.png"></p>')).toBe(true)
    expect(hasRichContent('<table><tr><td></td></tr></table>')).toBe(true)
    expect(hasRichContent('<video src="/x.mp4"></video>')).toBe(true)
  })
  it('空值 → false', () => {
    expect(hasRichContent('')).toBe(false)
    expect(hasRichContent(null)).toBe(false)
    expect(hasRichContent(undefined)).toBe(false)
  })
})
