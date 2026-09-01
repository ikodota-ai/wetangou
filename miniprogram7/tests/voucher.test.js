// utils/voucher.js —— 下单页/买单页的代金券挑选逻辑
//
// 背景：后端 placeOrder 一直支持 memberVoucherId 抵扣，但商品下单页
// （含「到店自取」，两者是同一个 pages/order/submit 页，pickup 只是勾选项）
// 既没有选券入口，createOrder 也没传这个参数 —— 所以「领了券不能抵扣」
// 不是抵扣算错，是这张券从来没被带进下单请求。
import { describe, it, expect } from 'vitest'

const { isUsable, usableList, discountOf, payAmountOf, parseTime, storeMatch } = require('../utils/voucher.js')

// 固定"现在"，避免用例随真实时间漂移
const NOW = new Date('2026/09/01 12:00:00').getTime()

const mk = (o) => ({
  id: o.id,
  status: o.status === undefined ? '0' : o.status,
  faceValue: o.faceValue,
  threshold: o.threshold === undefined ? '0.00' : o.threshold,
  expireTime: o.expireTime === undefined ? '2026-12-31 23:59:59' : o.expireTime
})

describe('parseTime', () => {
  it('把后端的横杠格式转成斜杠再解析（iOS 不认带横杠的）', () => {
    expect(parseTime('2026-09-30 23:59:59')).toBe(
      new Date('2026/09/30 23:59:59').getTime()
    )
  })

  it('已经是时间戳的原样返回', () => {
    expect(parseTime(NOW)).toBe(NOW)
  })

  it('空值和非法值返 0，不能返 NaN（NaN 参与比较会让过期判断永远为 false）', () => {
    expect(parseTime('')).toBe(0)
    expect(parseTime(null)).toBe(0)
    expect(parseTime(undefined)).toBe(0)
    expect(parseTime('不是时间')).toBe(0)
  })
})

describe('isUsable', () => {
  it('未使用 + 未过期 + 够门槛 → 可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', threshold: '50.00' }), 60, NOW)).toBe(true)
  })

  it('门槛正好等于订单金额 → 可用（后端是 totalAmount < threshold 才拒）', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', threshold: '50.00' }), 50, NOW)).toBe(true)
  })

  it('差一分钱不够门槛 → 不可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', threshold: '50.00' }), 49.99, NOW)).toBe(false)
  })

  it('status=1 已使用 → 不可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', status: '1' }), 100, NOW)).toBe(false)
  })

  it('status=2 已过期 → 不可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', status: '2' }), 100, NOW)).toBe(false)
  })

  it('status 仍是 0 但 expireTime 已过 → 不可用（定时任务没刷到的券）', () => {
    const v = mk({ id: 1, faceValue: '10.00', expireTime: '2026-08-31 23:59:59' })
    expect(v.status).toBe('0')
    expect(isUsable(v, 100, NOW)).toBe(false)
  })

  it('expireTime 为空表示不限期 → 可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '10.00', expireTime: '' }), 100, NOW)).toBe(true)
  })

  it('券为 null/undefined 不能抛异常', () => {
    expect(isUsable(null, 100, NOW)).toBe(false)
    expect(isUsable(undefined, 100, NOW)).toBe(false)
  })

  it('threshold 为 null 当 0 处理，不能因 NaN 比较把无门槛券判成不可用', () => {
    expect(isUsable(mk({ id: 1, faceValue: '5.00', threshold: null }), 3, NOW)).toBe(true)
  })
})

describe('storeMatch —— 券的门店限制', () => {
  // 背景：biz_voucher.store_id 限定券只能在哪家店用，但下单/买单一直没读过它。
  // 实测领门店 201 的「满 150 减 30」去买门店 200 的 ¥200 商品，抵扣成功并落库
  // —— A 店发的券把 B 店的营业额扣掉了。后端已在 VoucherUsageService 拦住，
  // 前端这层负责提前置灰，不让用户选中后才被打回。
  it('券限门店 200，本次消费也是 200 → 匹配', () => {
    expect(storeMatch({ storeId: 200 }, 200)).toBe(true)
  })

  it('券限门店 201，本次消费是 200 → 不匹配', () => {
    expect(storeMatch({ storeId: 201 }, 200)).toBe(false)
  })

  it('storeId=0 是全门店通用（历史数据里通用券存的就是 0）', () => {
    expect(storeMatch({ storeId: 0 }, 200)).toBe(true)
  })

  it('storeId 为 null / undefined / 空串也当全门店通用（新建数据可能是 NULL）', () => {
    expect(storeMatch({ storeId: null }, 200)).toBe(true)
    expect(storeMatch({}, 200)).toBe(true)
    expect(storeMatch({ storeId: '' }, 200)).toBe(true)
  })

  it('本次消费门店未知时不拦（商品详情还没加载完就渲染过一次）', () => {
    expect(storeMatch({ storeId: 201 }, null)).toBe(true)
    expect(storeMatch({ storeId: 201 }, undefined)).toBe(true)
  })

  it('字符串与数字的门店 id 要能比对上（接口返回类型不稳定）', () => {
    expect(storeMatch({ storeId: '200' }, 200)).toBe(true)
    expect(storeMatch({ storeId: 200 }, '200')).toBe(true)
  })

  it('券为 null 不能抛异常', () => {
    expect(storeMatch(null, 200)).toBe(false)
  })
})

describe('isUsable 带门店参数', () => {
  it('金额够门槛但门店不符 → 不可用', () => {
    const v = mk({ id: 1, faceValue: '30.00', threshold: '150.00' })
    v.storeId = 201
    expect(isUsable(v, 200, NOW)).toBe(true)          // 不传门店时按老行为
    expect(isUsable(v, 200, NOW, 201)).toBe(true)     // 门店相符
    expect(isUsable(v, 200, NOW, 200)).toBe(false)    // 门店不符
  })

  it('通用券在任意门店都可用', () => {
    const v = mk({ id: 1, faceValue: '30.00', threshold: '150.00' })
    v.storeId = 0
    expect(isUsable(v, 200, NOW, 999)).toBe(true)
  })
})

describe('usableList 带门店参数', () => {
  it('只统计本店能用的券（跨店券不能计入「N 张可用」）', () => {
    const a = mk({ id: 1, faceValue: '30.00', threshold: '0.00' }); a.storeId = 200
    const b = mk({ id: 2, faceValue: '50.00', threshold: '0.00' }); b.storeId = 201
    const c = mk({ id: 3, faceValue: '10.00', threshold: '0.00' }); c.storeId = 0
    const out = usableList([a, b, c], 200, NOW, 200)
    expect(out.map((x) => x.id)).toEqual([1, 3])
  })
})

describe('usableList', () => {
  // 沙盘：4 张券对一笔订单的四种结局
  const list = [
    mk({ id: 1, faceValue: '10.00', threshold: '50.00' }),                                  // 够门槛
    mk({ id: 2, faceValue: '30.00', threshold: '100.00' }),                                 // 门槛不够
    mk({ id: 3, faceValue: '20.00', threshold: '10.00', expireTime: '2026-08-01 00:00:00' }), // 已过期
    mk({ id: 4, faceValue: '15.00', threshold: '10.00', status: '1' })                      // 已使用
  ]

  it('60 元订单只有 1 号券可用', () => {
    expect(usableList(list, 60, NOW).map((v) => v.id)).toEqual([1])
  })

  it('120 元订单 1、2 号都可用，按面值从大到小排（30 在 10 前）', () => {
    expect(usableList(list, 120, NOW).map((v) => v.id)).toEqual([2, 1])
  })

  it('面值相同时先用快过期的，避免用户手里的券白白过期', () => {
    const same = [
      mk({ id: 'late', faceValue: '10.00', expireTime: '2026-12-31 23:59:59' }),
      mk({ id: 'soon', faceValue: '10.00', expireTime: '2026-09-10 23:59:59' })
    ]
    expect(usableList(same, 100, NOW).map((v) => v.id)).toEqual(['soon', 'late'])
  })

  it('不是数组时返空数组，不能抛异常（接口异常返 null 时会走到这）', () => {
    expect(usableList(null, 100, NOW)).toEqual([])
    expect(usableList(undefined, 100, NOW)).toEqual([])
    expect(usableList({}, 100, NOW)).toEqual([])
  })

  it('不改动原数组顺序（sort 会原地改，必须先拷贝）', () => {
    const before = list.map((v) => v.id)
    usableList(list, 120, NOW)
    expect(list.map((v) => v.id)).toEqual(before)
  })
})

describe('discountOf / payAmountOf', () => {
  it('正常抵扣：60 元订单用 10 元券，抵 10 实付 50', () => {
    const v = mk({ id: 1, faceValue: '10.00' })
    expect(discountOf(v, 60)).toBe(10)
    expect(payAmountOf(60, v)).toBe('50.00')
  })

  it('券面值超过订单金额时封顶到订单金额，实付 0 不为负（后端同样封顶）', () => {
    const v = mk({ id: 1, faceValue: '5.00' })
    expect(discountOf(v, 3)).toBe(3)
    expect(payAmountOf(3, v)).toBe('0.00')
  })

  it('没选券时抵扣 0，实付等于订单金额', () => {
    expect(discountOf(null, 60)).toBe(0)
    expect(payAmountOf(60, null)).toBe('60.00')
  })

  it('券面值正好等于订单金额，实付 0.00', () => {
    expect(payAmountOf(20, mk({ id: 1, faceValue: '20.00' }))).toBe('0.00')
  })

  it('返回两位小数字符串，直接给界面用', () => {
    expect(payAmountOf(59.9, mk({ id: 1, faceValue: '10.00' }))).toBe('49.90')
  })
})
