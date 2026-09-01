// utils/orderParam.js —— 订单页入参解析
//
// 背景：微信支付「商品订单详情path」只能填一条，形式是
//   pages/order/detail/index?id=${商品订单号}
// 占位符由微信替换成 out_trade_no（本项目即 biz_order.order_no）。
// 参数名是我们自己写的 id，和站内跳转的 ?id=主键 撞在同一个键上，
// 所以必须按「值的形态」分流，不能按键名。
import { describe, it, expect } from 'vitest'
const { parseOrderParam } = require('../utils/orderParam.js')

describe('站内跳转：值是主键', () => {
  it('纯数字识别为 id', () => {
    expect(parseOrderParam({ id: '999451' })).toEqual({ id: '999451', orderNo: '' })
  })
  it('数字类型也认', () => {
    expect(parseOrderParam({ id: 999451 })).toEqual({ id: '999451', orderNo: '' })
  })
})

describe('微信回跳：同一个 id 键里装的是订单号', () => {
  it('D 前缀的商品订单号识别为 orderNo', () => {
    expect(parseOrderParam({ id: 'D1787398679265359' }))
      .toEqual({ id: null, orderNo: 'D1787398679265359' })
  })
  it('P 前缀的买单号同样识别为 orderNo', () => {
    expect(parseOrderParam({ id: 'P1787398679265359' }))
      .toEqual({ id: null, orderNo: 'P1787398679265359' })
  })
  it('关键回归：订单号绝不能被当成主键', () => {
    // 按键名分流的旧写法会返回 id='D178...'，
    // 拿它去打 /api/order/{id} 会 500
    const r = parseOrderParam({ id: 'D1787398679265359' })
    expect(r.id).toBe(null)
  })
})

describe('兼容其它参数名', () => {
  it('orderNo', () => {
    expect(parseOrderParam({ orderNo: 'D123A' }).orderNo).toBe('D123A')
  })
  it('order_no 下划线写法', () => {
    expect(parseOrderParam({ order_no: 'D123A' }).orderNo).toBe('D123A')
  })
  it('out_trade_no（微信侧原始字段名）', () => {
    expect(parseOrderParam({ out_trade_no: 'D123A' }).orderNo).toBe('D123A')
  })
  it('id 优先级最高（微信配置用的就是 id）', () => {
    expect(parseOrderParam({ id: '999451', orderNo: 'D123A' }))
      .toEqual({ id: '999451', orderNo: '' })
  })
})

describe('异常入参', () => {
  it('空对象', () => {
    expect(parseOrderParam({})).toEqual({ id: null, orderNo: '' })
  })
  it('undefined 不抛异常', () => {
    expect(parseOrderParam(undefined)).toEqual({ id: null, orderNo: '' })
  })
  it('纯空格视为没传', () => {
    expect(parseOrderParam({ id: '   ' })).toEqual({ id: null, orderNo: '' })
  })
  it('带空格的数字去空格后仍按主键走', () => {
    // 用正则而不是 isNaN：isNaN(' 12 ') 是 false，容易把脏值误判成合法主键
    expect(parseOrderParam({ id: ' 999451 ' })).toEqual({ id: '999451', orderNo: '' })
  })
  it('占位符没被替换时当订单号处理，交给后端报「订单不存在」', () => {
    expect(parseOrderParam({ id: '${商品订单号}' }).orderNo).toBe('${商品订单号}')
  })
})
