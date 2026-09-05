// tests/productMedia.test.js
//
// 锁 cover / images 两个字段的职责划分。
//
// 为什么必需：列名误导性极强 —— cover 的库表注释就写着「封面图」，
// 看起来就是单张 URL，而 PC 建品页给的是 image-upload :limit=5（头图），
// 落库是逗号串。于是全仓 20+ 处直接把它塞进 <image src>：
// 商品列表 / 订单列表 / 下单页 / 分享封面 / 海报。
//
// 本地库当下 cover 含逗号的是 0 条，所以这批位置看着都是好的 ——
// 一旦哪个商家传了第二张头图，src 就变成 "urlA,urlB" 全部白图。
// 它是定时炸弹，而定时炸弹只能靠单测看着。
import { describe, it, expect } from 'vitest'

const { splitUrls, firstCover, heroImages, contentImages } = require('../utils/productMedia.js')

const A = '/profile/a.jpg'
const B = '/profile/b.jpg'
const C = '/profile/c.jpg'

describe('splitUrls：逗号串 → 数组', () => {
  it('多张拆开，与 PC detail.vue 的 splitUrls 同口径', () => {
    expect(splitUrls(A + ',' + B)).toEqual([A, B])
  })

  it('数组直接过（后端有时下发数组）', () => {
    expect(splitUrls([A, B])).toEqual([A, B])
  })

  it('空值 / null / 纯逗号 → 空数组（WXML 靠 .length 判空，undefined 会在渲染层报错）', () => {
    expect(splitUrls('')).toEqual([])
    expect(splitUrls(null)).toEqual([])
    expect(splitUrls(undefined)).toEqual([])
    expect(splitUrls(',,')).toEqual([])
  })

  it('去首尾空白：商家手填/导入的串常带空格，带空格的 URL 小程序加载不出', () => {
    expect(splitUrls(A + ', ' + B)).toEqual([A, B])
  })
})

describe('firstCover：只能放一张图的位置', () => {
  it('头图多张时取第 1 张 —— 整串当 src 就是白图', () => {
    expect(firstCover({ cover: A + ',' + B + ',' + C })).toBe(A)
  })

  it('头图为空时回落环境图首张：老商品（本地 1001/1002）只有其中一个字段有值', () => {
    expect(firstCover({ cover: '', images: B + ',' + C })).toBe(B)
  })

  it('两个字段都空 → 空串（调用方靠它判断要不要上占位图）', () => {
    expect(firstCover({})).toBe('')
    expect(firstCover(null)).toBe('')
  })
})

describe('heroImages：详情页顶部可翻动那组', () => {
  it('用头图全部，而不是环境图 —— 商家在「商品头图」选的就是主图', () => {
    expect(heroImages({ cover: A + ',' + B, images: C })).toEqual([A, B])
  })

  it('头图为空才回落环境图：老数据里真有只填了 images 的', () => {
    expect(heroImages({ images: B + ',' + C })).toEqual([B, C])
  })

  it('都空 → 空数组（WXML swiper 靠 .length 判是否循环）', () => {
    expect(heroImages({})).toEqual([])
  })
})

describe('contentImages：图文详情里的环境图', () => {
  it('剔掉与头图重复的：本地这批商品 cover 与 images 首张相同，不剔会一屏内看两遍', () => {
    expect(contentImages({ cover: A, images: A + ',' + B })).toEqual([B])
  })

  it('完全重复 → 空数组（那张卡不应该凭空多出来）', () => {
    expect(contentImages({ cover: A + ',' + B, images: B + ',' + A })).toEqual([])
  })

  it('没头图时环境图已被 heroImages 拿去上顶，contentImages 不能再重展', () => {
    // 这是一个已知取舍：无 cover 时 heroImages 回落到 images，
    // 此时 contentImages 拿不到 hero 集合会把同一批图再列一遍。
    // 所以详情页那张卡必须在 hero 回落时也能去重 —— 下面锁住行为。
    expect(contentImages({ images: A + ',' + B })).toEqual([])
  })
})
