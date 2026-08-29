// tests/util.test.js
// 距离格式化 / Haversine 距离公式的纯函数单测
// 目标：今天反复出现的「距离显示未知」类问题，下次改这块代码时立刻能 catch
//
// 重要：本测试锁定的是「当前行为」。如果某天产品决定 "0.05km 应显示 1m 而非 50m"，
// 那应该同时改 util.js 和这里的测试预期，**别悄悄改代码让测试继续过**（那是欺骗测试）。
import { describe, it, expect } from 'vitest'

const { haversineKm, formatDistance, formatMoney, getNextDays } = require('../utils/util.js')

describe('formatDistance', () => {
  it('null/undefined/NaN → 空字符串', () => {
    expect(formatDistance(null)).toBe('')
    expect(formatDistance(undefined)).toBe('')
    expect(formatDistance(NaN)).toBe('')
    expect(formatDistance('abc')).toBe('')
  })

  it('0.2 km → 200m', () => {
    expect(formatDistance(0.2)).toBe('200m')
  })

  it('极小值（< 1m）→ 至少显示 1m（避免出现 0m）', () => {
    // 0.001km = 1m；Math.max(1, Math.round(1)) = 1
    expect(formatDistance(0.001)).toBe('1m')
    // 0.0001km = 0.1m，Math.round 后是 0，Math.max(1, 0) = 1 → 1m
    expect(formatDistance(0.0001)).toBe('1m')
    // 50m 时 Math.max(1, 50) = 50 → 显示 50m
    expect(formatDistance(0.05)).toBe('50m')
  })

  it('< 10 km → 1 位小数（"1.0km" 而非 "1km"）', () => {
    expect(formatDistance(1)).toBe('1.0km')
    expect(formatDistance(1.234)).toBe('1.2km')
    expect(formatDistance(5.5)).toBe('5.5km')
    expect(formatDistance(9.99)).toBe('10.0km')  // 边界：四舍五入进位成 10.0
  })

  it('>= 10 km → 整数（无小数）', () => {
    expect(formatDistance(10)).toBe('10km')
    expect(formatDistance(12.7)).toBe('13km')
    expect(formatDistance(100.4)).toBe('100km')
  })

  it('字符串数字能正确解析（后端 distance 是 string）', () => {
    expect(formatDistance('1.5')).toBe('1.5km')
    expect(formatDistance('0.3')).toBe('300m')
  })
})

describe('haversineKm', () => {
  it('同点 → 0', () => {
    expect(haversineKm(30.5728, 104.0668, 30.5728, 104.0668)).toBe(0)
  })

  it('字符串非数字 → null', () => {
    expect(haversineKm('abc', 104, 30, 104)).toBe(null)
    expect(haversineKm(NaN, NaN, NaN, NaN)).toBe(null)
  })

  it('null → 当作 0（行为锁定：不是 bug，是当前实现）', () => {
    // 注意：Number(null) === 0，所以全 null 时所有点都在 (0,0)，返回 0
    // 如果未来改成 null → null，需要同时改这个测试
    expect(haversineKm(null, null, null, null)).toBe(0)
  })

  it('北京 → 上海 ≈ 1067 km（误差 < 10 km）', () => {
    // 北京天安门 39.9087, 116.3974
    // 上海外滩 31.2397, 121.4993
    const km = haversineKm(39.9087, 116.3974, 31.2397, 121.4993)
    expect(km).toBeGreaterThan(1057)
    expect(km).toBeLessThan(1077)
  })

  it('成都春熙路 → 太古里 < 1 km', () => {
    // 春熙路 30.6595, 104.0817
    // 太古里 30.6570, 104.0830
    const km = haversineKm(30.6595, 104.0817, 30.6570, 104.0830)
    expect(km).toBeGreaterThan(0.2)
    expect(km).toBeLessThan(0.5)
  })

  it('字符串坐标能正确解析', () => {
    const km = haversineKm('30.6595', '104.0817', '30.6570', '104.0830')
    expect(km).toBeGreaterThan(0)
  })

  it('对称性：A→B ≈ B→A（浮点误差 < 1m）', () => {
    const ab = haversineKm(30.5, 104.0, 31.0, 121.0)
    const ba = haversineKm(31.0, 121.0, 30.5, 104.0)
    expect(Math.abs(ab - ba)).toBeLessThan(0.001)
  })
})

describe('formatMoney', () => {
  it('数字 → 保留 2 位小数', () => {
    expect(formatMoney(10)).toBe('10.00')
    expect(formatMoney(10.5)).toBe('10.50')
    expect(formatMoney(10.567)).toBe('10.57')
  })

  it('字符串 → 解析后再格式化', () => {
    expect(formatMoney('10.5')).toBe('10.50')
    expect(formatMoney('99')).toBe('99.00')
  })

  it('null / undefined / NaN → 0.00', () => {
    expect(formatMoney(null)).toBe('0.00')
    expect(formatMoney(undefined)).toBe('0.00')
    expect(formatMoney(NaN)).toBe('0.00')
  })
})

describe('getNextDays', () => {
  it('默认返回 7 个 Date', () => {
    const days = getNextDays()
    expect(days).toHaveLength(7)
    expect(days[0]).toBeInstanceOf(Date)
  })

  it('n=3 → 3 个 Date', () => {
    const days = getNextDays(3)
    expect(days).toHaveLength(3)
  })

  it('n=2, from=2026-08-08 → [2026-08-08, 2026-08-09] (本地日期)', () => {
    // 用 Date(year, month-1, day) 构造避免 ISO 解析的时区歧义
    const days = getNextDays(2, new Date(2026, 7, 8))
    expect(days).toHaveLength(2)
    // toLocaleDateString 返回本地日期，不受时区影响
    expect(days[0].toLocaleDateString('en-CA')).toBe('2026-08-08')  // en-CA 格式 yyyy-mm-dd
    expect(days[1].toLocaleDateString('en-CA')).toBe('2026-08-09')
  })
})
