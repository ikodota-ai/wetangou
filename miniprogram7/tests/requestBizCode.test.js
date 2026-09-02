// tests/requestBizCode.test.js
// 守 request() 的业务码判定。
//
// 背景（真实缺陷）：后端有两条不同的错误输出链——
//   * AjaxResult / ServiceException  → {"code":500,...}     数字
//   * DistributorAuthInterceptor     → {"code":"403",...}   字符串（手写 JSON）
//   * RoleAuthInterceptor            → {"code":"403",...}   字符串（手写 JSON）
// 三者 HTTP 状态都是 200。request() 原来只把 code===200/0 当成功、code===401 当未登录，
// 其余全部 resolve(d) —— 于是「HTTP 200 + 业务失败」被调用方的 .then() 当成功处理：
//   实测非推客会员 POST /api/distributor/withdraw 返 {"code":"403","msg":"您还不是推客"}，
//   提现页照样弹「提现申请已提交」；店员点「招人」拿到角色 403，也进成功分支渲染空白邀请码。
import { describe, it, expect, beforeEach } from 'vitest'

let lastReq = null
let nextResponse = null

globalThis.wx = {
  request: (o) => {
    // config.js 的 baseUrl 健康探测也会打 wx.request，那条不是被测对象：
    // 没有排好的响应就走 fail，避免它拿 null 去读 statusCode 报游离异常。
    if (!nextResponse) {
      setTimeout(() => o.fail && o.fail({ errMsg: 'probe skipped in test' }), 0)
      return
    }
    lastReq = o
    const res = nextResponse
    setTimeout(() => o.success(res), 0)
  },
  getStorageSync: () => null,
  setStorageSync: () => {},
  removeStorageSync: () => {},
  login: (o) => o.fail(new Error('no wx in test')),
  reLaunch: () => {},
  navigateTo: () => {}
}

const { request } = require('../utils/request.js')

function reply(statusCode, data) {
  nextResponse = { statusCode, data }
}

async function outcome(p) {
  try {
    return { ok: true, value: await p }
  } catch (e) {
    return { ok: false, err: e }
  }
}

describe('request() 业务码判定', () => {
  beforeEach(() => { lastReq = null; nextResponse = null })

  it('数字 code=200 → resolve(data)', async () => {
    reply(200, { code: 200, msg: '操作成功', data: { a: 1 } })
    const r = await outcome(request('/api/x'))
    expect(r.ok).toBe(true)
    expect(r.value).toEqual({ a: 1 })
  })

  it('字符串 code="200" 也算成功（后端手写 JSON 的形态）', async () => {
    reply(200, { code: '200', data: { b: 2 } })
    const r = await outcome(request('/api/x'))
    expect(r.ok).toBe(true)
    expect(r.value).toEqual({ b: 2 })
  })

  it('code=0 视为成功', async () => {
    reply(200, { code: 0, data: { c: 3 } })
    expect((await outcome(request('/api/x'))).ok).toBe(true)
  })

  it('数字 code=500 业务异常 → reject 且带 msg', async () => {
    reply(200, { code: 500, msg: '可提现余额不足' })
    const r = await outcome(request('/api/distributor/withdraw', { method: 'POST' }))
    expect(r.ok).toBe(false)
    expect(r.err.code).toBe(500)
    expect(r.err.msg).toBe('可提现余额不足')
  })

  it('字符串 code="403" 必须 reject —— 这是提现页误弹「已提交」的根因', async () => {
    reply(200, { code: '403', msg: '您还不是推客，请先申请加入' })
    const r = await outcome(request('/api/distributor/withdraw', { method: 'POST' }))
    expect(r.ok).toBe(false)
    expect(r.err.code).toBe(403)
    expect(r.err.msg).toBe('您还不是推客，请先申请加入')
  })

  it('字符串 code="403" 角色无权限（店员点「招人」）同样 reject', async () => {
    reply(200, { code: '403', msg: '当前角色无权限访问该接口（需要 OWNER/MANAGER）' })
    const r = await outcome(request('/api/merchant/staff/staff/invite', { method: 'POST' }))
    expect(r.ok).toBe(false)
    expect(r.err.code).toBe(403)
  })

  it('数字 code=401 → reject({code:401})，非会员态不静默重登', async () => {
    reply(200, { code: 401, msg: '员工登录态失效', authScope: 'staff' })
    const r = await outcome(request('/api/merchant/staff/me'))
    expect(r.ok).toBe(false)
    expect(r.err.code).toBe(401)
    expect(r.err.authScope).toBe('staff')
  })

  it('字符串 code="401" 也要按未登录处理，不能落进业务失败分支', async () => {
    reply(200, { code: '401', msg: '请先登录' })
    const r = await outcome(request('/api/distributor/center'))
    expect(r.ok).toBe(false)
    expect(r.err.code).toBe(401)
  })

  it('响应体没有 code 字段（裸数据端点）→ 原样 resolve，不能误判失败', async () => {
    reply(200, [{ id: 1 }, { id: 2 }])
    const r = await outcome(request('/api/store/1/album'))
    expect(r.ok).toBe(true)
    expect(r.value).toEqual([{ id: 1 }, { id: 2 }])
  })

  it('code 是非数字字符串（脏数据）→ 当作无码原样 resolve，不误伤', async () => {
    reply(200, { code: 'OK', data: { d: 4 } })
    const r = await outcome(request('/api/x'))
    expect(r.ok).toBe(true)
  })

  it('success:true 无 code 也算成功', async () => {
    reply(200, { success: true, data: { e: 5 } })
    expect((await outcome(request('/api/x'))).ok).toBe(true)
  })

  it('HTTP 500 → reject 整个 res（网络/网关层失败）', async () => {
    reply(500, { msg: 'boom' })
    const r = await outcome(request('/api/x'))
    expect(r.ok).toBe(false)
    expect(r.err.statusCode).toBe(500)
  })
})
