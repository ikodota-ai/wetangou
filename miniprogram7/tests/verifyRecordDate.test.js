// tests/verifyRecordDate.test.js
// 商家端核销记录页的日期加减 —— 锁住「必须按本地时区算」这一条。
//
// 为什么单独测：最省事的写法是 new Date().toISOString().slice(0,10)，
// 但 toISOString 按 UTC 切。东八区在 00:00~08:00 之间，UTC 还停在前一天，
// 于是店长早班（比如 07:30）打开核销记录，默认日期是「昨天」，
// 当天核的单一笔都看不到，只会以为系统丢数据。
//
// 反向验证：把 shiftDate 改成 d.toISOString().slice(0,10)，
// 下面「早上 7 点的今天仍是当天」那条会红。
import { describe, it, expect, afterEach, vi } from 'vitest'

globalThis.Page = () => {}
globalThis.wx = {
  showToast: () => {}, setClipboardData: () => {}, stopPullDownRefresh: () => {},
  getStorageSync: () => '', setStorageSync: () => {}
}

const { shiftDate } = require('../pages/merchant/history/index.js').__test__

afterEach(() => { vi.useRealTimers() })

describe('shiftDate', () => {
  it('不传基准日期时返回今天（本地时区）', () => {
    const now = new Date()
    const mm = String(now.getMonth() + 1).padStart(2, '0')
    const dd = String(now.getDate()).padStart(2, '0')
    expect(shiftDate(null, 0)).toBe(`${now.getFullYear()}-${mm}-${dd}`)
  })

  it('早上 7 点算「今天」仍是当天，不能被 UTC 切到昨天', () => {
    // 用本地时间构造当天 07:30，避免依赖运行机器的实际时区偏移
    vi.useFakeTimers()
    vi.setSystemTime(new Date(2026, 8, 2, 7, 30, 0)) // 2026-09-02 07:30 本地
    expect(shiftDate(null, 0)).toBe('2026-09-02')
  })

  it('半夜 00:10 算「今天」也不能退回前一天', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date(2026, 8, 2, 0, 10, 0))
    expect(shiftDate(null, 0)).toBe('2026-09-02')
  })

  it('往前翻一天', () => {
    expect(shiftDate('2026-09-02', -1)).toBe('2026-09-01')
  })

  it('往后翻一天', () => {
    expect(shiftDate('2026-09-01', 1)).toBe('2026-09-02')
  })

  it('跨月往前翻', () => {
    expect(shiftDate('2026-09-01', -1)).toBe('2026-08-31')
  })

  it('跨年往前翻', () => {
    expect(shiftDate('2026-01-01', -1)).toBe('2025-12-31')
  })

  it('闰年 2 月 29 存在', () => {
    expect(shiftDate('2028-03-01', -1)).toBe('2028-02-29')
  })

  it('平年 3 月 1 往前是 2 月 28', () => {
    expect(shiftDate('2026-03-01', -1)).toBe('2026-02-28')
  })

  it('月日补零到两位（后端只认 yyyy-MM-dd）', () => {
    expect(shiftDate('2026-01-10', -1)).toBe('2026-01-09')
    expect(shiftDate('2026-02-01', 0)).toBe('2026-02-01')
  })

  it('days 缺省视为 0', () => {
    expect(shiftDate('2026-09-02')).toBe('2026-09-02')
  })

  it('带横杠的日期串能被 Safari/iOS 解析（内部换成斜杠）', () => {
    // iOS 上 new Date('2026-09-02') 在部分版本会得到 Invalid Date，
    // 所以实现里把 '-' 换成 '/'。这条锁住这个替换没被删掉。
    expect(shiftDate('2026-09-02', 0)).toBe('2026-09-02')
  })
})
