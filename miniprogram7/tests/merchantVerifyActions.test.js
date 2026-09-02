// tests/merchantVerifyActions.test.js
//
// 核销页底部两个入口 + 「最近核销」点一条 —— 锁住它们不是死按钮。
//
// pages/merchant/verify/index.wxml 上一直挂着三个 bindtap：
//   goHistory（核销记录）/ goSwitchAccount（切换回会员）/ onRepeat（最近核销点一条）
// 但 index.js 里三个都没有定义。小程序对不存在的处理器既不报错也不警告，
// 点下去完全没反应。其中「核销记录」还是 verify/records 那个功能在核销页的
// 唯一入口 —— 店员点不进去就等于没做。
//
// onRepeat 的口径要专门锁：点历史条目只回填核销码，**不重新发起核销**。
// 已核销的单再提交必然被后端拒（「该订单已核销」），弹个错误 toast 只会让
// 店员以为系统出问题；真实场景是客人问「刚那单核上了吗」，店员想把码填回去
// 再确认一次，按不按确认由人决定。
import { describe, it, expect, beforeEach, vi } from 'vitest'
import fs from 'fs'
import path from 'path'

const SRC = path.resolve(__dirname, '../pages/merchant/verify/index.js')

let pageDef, apiStub, identityStub, nav, toastArgs, modalArgs

function loadPage(opts) {
  const o = opts || {}
  pageDef = null
  nav = { navigateTo: [], reLaunch: [], redirectTo: [] }
  toastArgs = []
  modalArgs = []
  apiStub = {
    verifyOrder: vi.fn(() => Promise.resolve({})),
    merchantStaffSwitchStore: vi.fn(() => Promise.resolve({}))
  }
  identityStub = {
    switchToMember: vi.fn(() => (o.hasMember === false
      ? { ok: false, reason: 'NO_MEMBER_SESSION' }
      : { ok: true }))
  }
  const wxStub = {
    showToast: (a) => toastArgs.push(a),
    showLoading: () => {}, hideLoading: () => {},
    showModal: (a) => modalArgs.push(a),
    navigateTo: (a) => nav.navigateTo.push(a.url),
    reLaunch: (a) => nav.reLaunch.push(a.url),
    redirectTo: (a) => nav.redirectTo.push(a.url),
    getStorageSync: () => '', setStorageSync: () => {},
    scanCode: () => {}
  }
  const requireStub = (id) => {
    if (id.indexOf('request.js') >= 0) return { api: apiStub }
    if (id.indexOf('identity.js') >= 0) return identityStub
    throw new Error('unexpected require: ' + id)
  }
  const src = fs.readFileSync(SRC, 'utf8')
  // eslint-disable-next-line no-new-func
  new Function('require', 'Page', 'wx', 'console', 'setTimeout', src)(
    requireStub, (def) => { pageDef = def }, wxStub,
    { log: () => {}, warn: () => {}, error: () => {} },
    (fn) => fn
  )
  const ctx = Object.assign({}, pageDef, {
    data: Object.assign({}, pageDef.data, o.data || {}),
    setData(patch) { Object.assign(this.data, patch) }
  })
  return ctx
}

beforeEach(() => { vi.resetModules() })

describe('核销页三个入口', () => {
  it('三个处理器都必须存在（模板绑了它们）', () => {
    const ctx = loadPage()
    expect(typeof ctx.goHistory).toBe('function')
    expect(typeof ctx.goSwitchAccount).toBe('function')
    expect(typeof ctx.onRepeat).toBe('function')
  })

  it('goHistory 跳核销记录页（不是买单流水页）', () => {
    const ctx = loadPage()
    ctx.goHistory()
    expect(nav.navigateTo).toEqual(['/pages/merchant/history/index'])
  })

  it('有会员登录态时切回会员版首页', () => {
    const ctx = loadPage()
    ctx.goSwitchAccount()
    expect(identityStub.switchToMember).toHaveBeenCalled()
    expect(nav.reLaunch).toEqual(['/pages/home/index'])
  })

  it('没有会员登录态时弹引导，不静默失败', () => {
    const ctx = loadPage({ hasMember: false })
    ctx.goSwitchAccount()
    expect(nav.reLaunch.length).toBe(0)
    expect(modalArgs.length).toBe(1)
    expect(modalArgs[0].title).toContain('尚未登录会员')
    // 点「去登录」才跳
    modalArgs[0].success({ confirm: true })
    expect(nav.reLaunch).toEqual(['/pages/login/login'])
  })

  it('onRepeat 只回填核销码，绝不重新发起核销', () => {
    const ctx = loadPage({ data: { history: [
      { orderNo: 'NO1', verifyCode: 'CODE1' },
      { orderNo: 'NO2', verifyCode: 'CODE2' }
    ] } })
    ctx.onRepeat({ currentTarget: { dataset: { idx: 1 } } })
    expect(ctx.data.verifyCode).toBe('CODE2')
    // 已核销的单再提交必然被拒，不能自动打接口
    expect(apiStub.verifyOrder).not.toHaveBeenCalled()
  })

  it('onRepeat 回填时清掉订单号，避免两个条件互相干扰', () => {
    const ctx = loadPage({ data: { orderNo: 'OLD', history: [{ orderNo: 'NO1', verifyCode: 'CODE1' }] } })
    ctx.onRepeat({ currentTarget: { dataset: { idx: 0 } } })
    expect(ctx.data.orderNo).toBe('')
  })

  it('历史条目没核销码时退回订单号（后端两者任填其一）', () => {
    const ctx = loadPage({ data: { history: [{ orderNo: 'NO9' }] } })
    ctx.onRepeat({ currentTarget: { dataset: { idx: 0 } } })
    expect(ctx.data.verifyCode).toBe('NO9')
  })

  it('索引越界时安全返回，不抛异常', () => {
    const ctx = loadPage({ data: { history: [] } })
    expect(() => ctx.onRepeat({ currentTarget: { dataset: { idx: 5 } } })).not.toThrow()
  })
})
