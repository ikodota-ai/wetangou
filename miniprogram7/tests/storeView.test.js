// utils/storeView.js —— 门店视图（距离 + 星级 + 名称/营业时间）
//
// 为何要有这个文件：这套口径原先内联在 pages/home/index.js 的 _compatStoreView，
// 而商品详情页顶部也要展同一家门店的距离和星级。如果详情页再拄一份，
// 两边早晚会漂移（首页 1.2km / 详情页 1200m、一边除了1000一边没除）。
import { describe, it, expect } from 'vitest'

const { toStoreView } = require('../utils/storeView.js')

describe('toStoreView：名称/营业时间兼容两套字段名', () => {
  it('后端 storeName/businessHours → name/hours', () => {
    const v = toStoreView({ storeName: '旗舰店', businessHours: '10:00-22:00' }, null)
    expect(v.name).toBe('旗舰店')
    expect(v.hours).toBe('10:00-22:00')
  })
  it('已经是视图模型的 name/hours 也能回流（_applyStore 可能传第二遍）', () => {
    const v = toStoreView({ name: '万象城店', hours: '09:00-21:00' }, null)
    expect(v.name).toBe('万象城店')
    expect(v.hours).toBe('09:00-21:00')
  })
  it('传 null → 空对象（WXML 直读 .name，不能返 null）', () => {
    expect(toStoreView(null, null)).toEqual({})
  })
})

describe('toStoreView：后端 distance 单位是米，必须 /1000', () => {
  // 这条锁住「直接把米传给 formatDistance」这个错法：
  // 850 米当成 850km 会显示“850km”
  it('distance=850（米）→ 850m', () => {
    const v = toStoreView({ storeName: 'A', distance: 850 }, null)
    expect(v.distanceText).toBe('850m')
    expect(v.hasDistance).toBe(true)
  })
  it('distance=1200 → 1.2km', () => {
    expect(toStoreView({ distance: 1200 }, null).distanceText).toBe('1.2km')
  })
  it('distance 是字符串 "2500"（JSON 可能给字符串）→ 2.5km', () => {
    expect(toStoreView({ distance: '2500' }, null).distanceText).toBe('2.5km')
  })
  it('distance=0（就在店里）→ 1m 而不是空 —— 0 不能被当成“无距离”', () => {
    const v = toStoreView({ distance: 0 }, null)
    expect(v.hasDistance).toBe(true)
    expect(v.distanceText).toBe('1m')
  })
  it('distance 为空串 → 降级去算经纬度，而不是当成 0', () => {
    const v = toStoreView({ distance: '', latitude: 22.5, longitude: 114.05 }, { lat: 22.5, lng: 114.05 })
    expect(v.distanceText).toBe('1m')   // 同点 haversine=0 → formatDistance 下限 1m
  })
  it('distance 是非数字脏数据 → 不显示距离而不是 NaN', () => {
    const v = toStoreView({ distance: 'abc' }, null)
    expect(v.hasDistance).toBe(false)
    expect(v.distanceText).toBe('')
  })
})

describe('toStoreView：没 distance 时用经纬度算', () => {
  it('深圳两点约 1.5km 量级', () => {
    // (22.5,114.05) → (22.51,114.06) 实测约 1.5km
    const v = toStoreView({ latitude: 22.51, longitude: 114.06 }, { lat: 22.5, lng: 114.05 })
    expect(v.hasDistance).toBe(true)
    expect(v.distanceKm).toBeGreaterThan(1)
    expect(v.distanceKm).toBeLessThan(2)
    expect(v.distanceText).toMatch(/km$/)
  })
  it('没位置（未授权）→ hasDistance=false，页面据此显「查看距离」', () => {
    const v = toStoreView({ latitude: 22.51, longitude: 114.06 }, null)
    expect(v.hasDistance).toBe(false)
    expect(v.distanceText).toBe('')
    expect(v.distanceKm).toBe(null)
  })
  it('有位置但门店没经纬度（后台未选点）→ hasDistance=false', () => {
    const v = toStoreView({ storeName: 'B' }, { lat: 22.5, lng: 114.05 })
    expect(v.hasDistance).toBe(false)
  })
})

describe('toStoreView：星级走 rating.js 同一口径', () => {
  it('rating=4.8 → 5 颗星 / "4.8"', () => {
    const v = toStoreView({ rating: 4.8 }, null)
    expect(v.hasRating).toBe(true)
    expect(v.ratingText).toBe('4.8')
    expect(v.ratingStars).toBe(5)
  })
  // 这条锁住「先用 store.rating 做真值判断再调 toRatingView」这个错法：
  // 0 分是真实差评，不是“未评分”。rating.js 内部已经按 == null 判了，
  // 调用方再包一层 ? : 就把这个区分废掉了。
  it('rating=0 → 仍然 hasRating=true（不能被 !rating 短路掉）', () => {
    const v = toStoreView({ rating: 0 }, null)
    expect(v.hasRating).toBe(true)
    expect(v.ratingText).toBe('0.0')
  })
  it('rating 为字符串 "0" → 同样 hasRating=true', () => {
    expect(toStoreView({ rating: '0' }, null).hasRating).toBe(true)
  })
  it('rating 未填 → hasRating=false（页面整块不渲染，不能出五颗灰星）', () => {
    expect(toStoreView({ storeName: 'C' }, null).hasRating).toBe(false)
  })
})

describe('toStoreView：不丢原字段', () => {
  it('storeId / address / phone 等原字段全部保留', () => {
    const v = toStoreView({ storeId: 100, address: '深圳市xx', phone: '0755-1', rating: 4 }, null)
    expect(v.storeId).toBe(100)
    expect(v.address).toBe('深圳市xx')
    expect(v.phone).toBe('0755-1')
  })
  it('视图字段优先于原字段：原对象带了 distanceText 也要被重算结果覆盖', () => {
    // 防止上一轮算出的旧 distanceText（如占位店的）泄到新视图里
    const v = toStoreView({ distanceText: '99km', distance: 500 }, null)
    expect(v.distanceText).toBe('500m')
  })
})
