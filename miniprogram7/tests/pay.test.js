// utils/pay.js —— 订单续付的公共逻辑
//
// 抽出来的动机：详情页原先没有支付入口，导致列表页不得不拦截「待支付」
// 订单的点击直接拉支付，这类订单永远进不去详情页。
// 而微信支付商户平台配的「订单页面路径」指向的正是详情页。
import { describe, it, expect, beforeEach } from 'vitest'

let toasts = []
let payArgs = null
let loadingShown = 0
let loadingHidden = 0

globalThis.wx = {
  showLoading: () => { loadingShown++ },
  hideLoading: () => { loadingHidden++ },
  showToast: (o) => { toasts.push(o.title) },
  requestPayment: (o) => { payArgs = o }
}

// request.js 是 CJS，vi.mock 的 ESM 工厂对它不生效（实测会走进真实现，
// 报 wx.getStorageSync is not a function）。改用第三参注入 api。
globalThis.wx.getStorageSync = () => null
globalThis.wx.setStorageSync = () => {}

const { payOrder: _payOrder } = require('../utils/pay.js')
// 包一层，把 mock 的 api 注进去，测试用例里就不用每次都写
const payOrder = (id, cb) => _payOrder(id, cb, { api: { prepayOrder: (...a) => globalThis.__prepay(...a) } })

beforeEach(() => {
  toasts = []; payArgs = null; loadingShown = 0; loadingHidden = 0
})

const flush = () => new Promise((r) => setTimeout(r, 0))

describe('payOrder 入参防御', () => {
  it('orderId 为空直接返回，不发请求也不转圈', () => {
    let called = false
    globalThis.__prepay = () => { called = true; return Promise.resolve({}) }
    payOrder(null, () => {})
    expect(called).toBe(false)
    expect(loadingShown).toBe(0)
  })
})

describe('mock 模式（后端未配支付凭证）', () => {
  it('返 mock:true 时当成功并回调刷新', async () => {
    globalThis.__prepay = () => Promise.resolve({ mock: true })
    let paid = 0
    payOrder(1001, () => { paid++ })
    await flush()
    expect(toasts).toContain('支付成功')
    expect(paid).toBe(1)
    // 不该再去调 requestPayment
    expect(payArgs).toBe(null)
  })
})

describe('正常拉起支付', () => {
  it('把后端返回的签名参数原样传给 requestPayment', async () => {
    globalThis.__prepay = () => Promise.resolve({
      data: { timeStamp: 1700000000, nonceStr: 'abc', package: 'prepay_id=wx123', signType: 'RSA', paySign: 'SIGN' }
    })
    payOrder(1002, () => {})
    await flush()
    expect(payArgs).not.toBe(null)
    // timeStamp 必须是字符串，微信要求
    expect(payArgs.timeStamp).toBe('1700000000')
    expect(typeof payArgs.timeStamp).toBe('string')
    expect(payArgs.package).toBe('prepay_id=wx123')
    expect(payArgs.paySign).toBe('SIGN')
  })

  it('signType 缺省时补 RSA', async () => {
    globalThis.__prepay = () => Promise.resolve({ data: { timeStamp: 1, nonceStr: 'n', package: 'p', paySign: 'S' } })
    payOrder(1003, () => {})
    await flush()
    expect(payArgs.signType).toBe('RSA')
  })

  it('支付成功才触发回调', async () => {
    globalThis.__prepay = () => Promise.resolve({ data: { timeStamp: 1, nonceStr: 'n', package: 'p', paySign: 'S' } })
    let paid = 0
    payOrder(1004, () => { paid++ })
    await flush()
    expect(paid).toBe(0)   // 还没点确认，不能提前刷新
    payArgs.success()
    expect(paid).toBe(1)
    expect(toasts).toContain('支付成功')
  })

  it('用户取消不触发回调', async () => {
    globalThis.__prepay = () => Promise.resolve({ data: { timeStamp: 1, nonceStr: 'n', package: 'p', paySign: 'S' } })
    let paid = 0
    payOrder(1005, () => { paid++ })
    await flush()
    payArgs.fail({ errMsg: 'requestPayment:fail cancel' })
    expect(paid).toBe(0)
    expect(toasts).toContain('已取消支付')
  })
})

describe('异常分支', () => {
  it('缺 paySign 时提示且不拉起支付', async () => {
    globalThis.__prepay = () => Promise.resolve({ data: { timeStamp: 1 } })
    payOrder(1006, () => {})
    await flush()
    expect(payArgs).toBe(null)
    expect(toasts).toContain('暂不可支付，请稍后重试')
  })

  it('接口报错时用后端 msg，且 loading 必须收掉', async () => {
    globalThis.__prepay = () => Promise.reject({ msg: '订单已取消' })
    payOrder(1007, () => {})
    await flush()
    expect(toasts).toContain('订单已取消')
    expect(loadingHidden).toBe(loadingShown)  // 不能留下转圈遮罩
  })

  it('报错无 msg 时给兜底文案', async () => {
    globalThis.__prepay = () => Promise.reject(new Error('boom'))
    payOrder(1008, () => {})
    await flush()
    expect(toasts).toContain('支付失败')
  })
})
