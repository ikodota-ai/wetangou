// tests/merchantOrderVerify.test.js
//
// 商家端「今日订单」列表里那颗核销按钮 —— 锁住它真的存在且真的会调核销接口。
//
// 为什么单独测：pages/merchant/order/index.wxml 上一直挂着
// <view bindtap="onVerify">核销</view>，但 index.js 里从来没有 onVerify。
// 小程序对不存在的事件处理器**既不报错也不警告**，店员在今日订单里看到
// 客人那单是「待使用」，点核销毫无反应，只能退出去改走核销页手抄核销码 ——
// 而这是商家端最高频的动作之一。编译过、接口通、日志干净，只有真机点了才知道。
//
// 同时锁三条口径：
//  1) 不传 storeId。门店在员工 token 里，后端已按 token 兜底；传 `storeId || 0`
//     会撞 hasStore(0) 抛「无权操作其他门店」（核销页就是这么踩的），
//     而模板里 data-store="{{storeId}}" 压根取不到值（data 里没这字段）。
//  2) 核销成功后必须重新拉列表：状态由 1 变 2，按钮才会消失，
//     否则店员会以为没成功而重复点。
//  3) 防重复提交：verifying 期间再点直接返回，不能连发两次核销请求。
import { describe, it, expect, beforeEach, vi } from 'vitest'
import fs from 'fs'
import path from 'path'

const SRC = path.resolve(__dirname, '../pages/merchant/order/index.js')

let pageDef, apiStub, modalArgs, toastArgs

function loadPage() {
  pageDef = null
  modalArgs = []
  toastArgs = []
  apiStub = {
    merchantStaffTodayOrders: vi.fn(() => Promise.resolve({ data: [] })),
    verifyOrder: vi.fn(() => Promise.resolve({ orderId: 1, orderNo: 'NO1' }))
  }
  const wxStub = {
    showToast: (o) => toastArgs.push(o),
    showLoading: () => {},
    hideLoading: () => {},
    showModal: (o) => { modalArgs.push(o) },
    stopPullDownRefresh: () => {}
  }
  const requireStub = (id) => {
    if (id.indexOf('request.js') >= 0) return { api: apiStub }
    throw new Error('unexpected require: ' + id)
  }
  const src = fs.readFileSync(SRC, 'utf8')
  // eslint-disable-next-line no-new-func
  new Function('require', 'Page', 'wx', 'console', 'module', src)(
    requireStub,
    (def) => { pageDef = def },
    wxStub,
    { log: () => {}, warn: () => {}, error: () => {} },
    { exports: {} }
  )
  // 造一个带 setData 的页面实例
  const ctx = Object.assign({}, pageDef, {
    data: Object.assign({}, pageDef.data),
    setData(patch) { Object.assign(this.data, patch) }
  })
  return { ctx, wxStub }
}

beforeEach(() => { vi.resetModules() })

describe('商家端今日订单 · 核销按钮', () => {
  it('onVerify 必须存在（模板绑了它，缺了就是死按钮）', () => {
    const { ctx } = loadPage()
    expect(typeof ctx.onVerify).toBe('function')
  })

  it('点核销先弹二次确认，不直接扣单', () => {
    const { ctx } = loadPage()
    ctx.onVerify({ currentTarget: { dataset: { code: 'ABC123', no: 'NO1' } } })
    expect(modalArgs.length).toBe(1)
    expect(modalArgs[0].content).toContain('无法撤销')
    // 没点确认之前不能发请求
    expect(apiStub.verifyOrder).not.toHaveBeenCalled()
  })

  it('确认后带核销码调 verifyOrder，且不传 storeId', async () => {
    const { ctx } = loadPage()
    ctx.onVerify({ currentTarget: { dataset: { code: 'ABC123', no: 'NO1' } } })
    modalArgs[0].success({ confirm: true })
    await Promise.resolve(); await Promise.resolve()
    expect(apiStub.verifyOrder).toHaveBeenCalledTimes(1)
    const arg = apiStub.verifyOrder.mock.calls[0][0]
    expect(arg.verifyCode).toBe('ABC123')
    // storeId 一旦传 0 会被后端判成越权门店
    expect(arg.storeId).toBeUndefined()
  })

  it('取消确认则什么都不做', () => {
    const { ctx } = loadPage()
    ctx.onVerify({ currentTarget: { dataset: { code: 'ABC123', no: 'NO1' } } })
    modalArgs[0].success({ confirm: false })
    expect(apiStub.verifyOrder).not.toHaveBeenCalled()
  })

  it('核销成功后重新拉列表（按钮才会消失）', async () => {
    const { ctx } = loadPage()
    await ctx.doVerify('ABC123', 'NO1')
    expect(apiStub.merchantStaffTodayOrders).toHaveBeenCalled()
  })

  it('没有核销码也没订单号时提示去核销页，不发空请求', () => {
    const { ctx } = loadPage()
    ctx.onVerify({ currentTarget: { dataset: {} } })
    expect(apiStub.verifyOrder).not.toHaveBeenCalled()
    expect(modalArgs.length).toBe(0)
    expect(toastArgs.length).toBe(1)
    expect(toastArgs[0].title).toContain('核销页')
  })

  it('verifying 期间再点直接返回，不重复发核销', () => {
    const { ctx } = loadPage()
    ctx.data.verifying = true
    ctx.onVerify({ currentTarget: { dataset: { code: 'ABC123' } } })
    expect(modalArgs.length).toBe(0)
    expect(apiStub.verifyOrder).not.toHaveBeenCalled()
  })

  it('核销失败要把失败原因原样弹出来（不能吞成"操作失败"）', async () => {
    const { ctx } = loadPage()
    apiStub.verifyOrder = vi.fn(() => Promise.reject({ msg: '该订单已核销' }))
    await ctx.doVerify('ABC123', 'NO1')
    expect(toastArgs.some(t => t.title === '该订单已核销')).toBe(true)
  })

  it('失败后 verifying 复位，店员能再试', async () => {
    const { ctx } = loadPage()
    apiStub.verifyOrder = vi.fn(() => Promise.reject({ msg: 'x' }))
    await ctx.doVerify('ABC123', 'NO1')
    expect(ctx.data.verifying).toBe(false)
  })
})
