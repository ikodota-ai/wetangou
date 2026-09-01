// utils/rating.js —— 门店评分视图
//
// 首页店铺卡片的评分来自后台手填的 biz_store.rating。这段逻辑原先内联在
// pages/home/index.js 的 _compatStoreView 里，单测引用不到 ——
// 而首页那批「后台配了却不显示」的问题已经复发过四次，模式完全相同。
import { describe, it, expect } from 'vitest'

const { toRatingView } = require('../utils/rating.js')

describe('toRatingView：未评分', () => {
  it('null → 不显示', () => {
    expect(toRatingView(null)).toEqual({ hasRating: false, ratingText: '', ratingStars: 0 })
  })
  it('undefined → 不显示（后端没返这个字段的老接口）', () => {
    expect(toRatingView(undefined).hasRating).toBe(false)
  })
  it('空串 → 不显示', () => {
    expect(toRatingView('').hasRating).toBe(false)
  })
})

describe('toRatingView：0 分不等于未评分', () => {
  // 这条锁住 `!rating` 这个错法：0 会被它当成未评分
  it('0 → 显示 0.0（是真实差评，不是没评）', () => {
    const r = toRatingView(0)
    expect(r.hasRating).toBe(true)
    expect(r.ratingText).toBe('0.0')
    expect(r.ratingStars).toBe(0)
  })
  it('数字 0 和字符串 "0" 结果一致', () => {
    expect(toRatingView('0')).toEqual(toRatingView(0))
  })
})

describe('toRatingView：正常取值', () => {
  it('4.8 → "4.8" / 5 颗星', () => {
    expect(toRatingView(4.8)).toEqual({ hasRating: true, ratingText: '4.8', ratingStars: 5 })
  })
  it('整数 5 → "5.0"（补一位小数，避免和 4.8 混排）', () => {
    expect(toRatingView(5).ratingText).toBe('5.0')
  })
  it('3.2 → 3 颗星（四舍五入向下）', () => {
    expect(toRatingView(3.2).ratingStars).toBe(3)
  })
  it('3.5 → 4 颗星（四舍五入向上）', () => {
    expect(toRatingView(3.5).ratingStars).toBe(4)
  })
  it('字符串 "4.8" → 与数字一致（MyBatis decimal 可能序列化成字符串）', () => {
    expect(toRatingView('4.8')).toEqual(toRatingView(4.8))
  })
  it('多余小数位四舍五入到一位：4.86 → "4.9"', () => {
    expect(toRatingView(4.86).ratingText).toBe('4.9')
  })
})

describe('toRatingView：脏数据兜底', () => {
  it('非数字字符串 → 当未评分（不能显示 "NaN"）', () => {
    expect(toRatingView('abc').hasRating).toBe(false)
    expect(toRatingView('abc').ratingText).toBe('')
  })
  it('超过 5 → 夹到 5（6 分会点亮 6 颗星撑坏布局）', () => {
    expect(toRatingView(6)).toEqual({ hasRating: true, ratingText: '5.0', ratingStars: 5 })
  })
  it('负数 → 夹到 0', () => {
    expect(toRatingView(-1)).toEqual({ hasRating: true, ratingText: '0.0', ratingStars: 0 })
  })
  it('Infinity → 当未评分', () => {
    expect(toRatingView(Infinity).hasRating).toBe(false)
  })
})
