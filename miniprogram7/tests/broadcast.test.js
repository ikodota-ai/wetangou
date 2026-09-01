// utils/broadcast.js —— 页面栈广播
//
// 这个文件锁住的是一个「调用 8 次、一次都没生效」的缺陷：
// app.js 里从来没有定义过 notifyUserUpdate，而 8 处调用都写成
// `appInst.notifyUserUpdate && appInst.notifyUserUpdate(user)`，
// `&&` 把 undefined 短路掉 → 全部静默失效。5 个页面实现了 onUserUpdate
// 在等这个广播，一直没收到。
import { describe, it, expect, vi } from 'vitest'

const { broadcast } = require('../utils/broadcast.js')

describe('broadcast：正常派发', () => {
  it('只派发给实现了该 hook 的页面', () => {
    const a = { route: 'a', onUserUpdate: vi.fn() }
    const b = { route: 'b' }                       // 没实现
    const c = { route: 'c', onUserUpdate: vi.fn() }
    const n = broadcast([a, b, c], 'onUserUpdate', { phone: '138' })
    expect(n).toBe(2)
    expect(a.onUserUpdate).toHaveBeenCalledWith({ phone: '138' })
    expect(c.onUserUpdate).toHaveBeenCalledWith({ phone: '138' })
  })

  it('payload 原样传递（不做拷贝，页面可拿到同一引用）', () => {
    const payload = { merchantId: 100 }
    let got = null
    broadcast([{ onMerchantUpdate: (p) => { got = p } }], 'onMerchantUpdate', payload)
    expect(got).toBe(payload)
  })

  it('hook 名不同的页面不会被误触发', () => {
    const pg = { onUserUpdate: vi.fn(), onMerchantUpdate: vi.fn() }
    broadcast([pg], 'onMerchantUpdate', {})
    expect(pg.onMerchantUpdate).toHaveBeenCalledTimes(1)
    expect(pg.onUserUpdate).not.toHaveBeenCalled()
  })
})

describe('broadcast：单个页面抛错不能影响其他页面', () => {
  it('第一个页面抛错，后面的仍收到', () => {
    const boom = { route: 'boom', onUserUpdate: () => { throw new Error('x') } }
    const ok = { route: 'ok', onUserUpdate: vi.fn() }
    const onError = vi.fn()
    const n = broadcast([boom, ok], 'onUserUpdate', 1, onError)
    // boom 没算进 delivered，但 ok 必须被调到 ——
    // 如果把整个循环包一层 try，这里 ok 就收不到了
    expect(n).toBe(1)
    expect(ok.onUserUpdate).toHaveBeenCalledTimes(1)
    expect(onError).toHaveBeenCalledTimes(1)
    expect(onError.mock.calls[0][0]).toBe(boom)
  })

  it('不传 onError 时抛错被吞掉，不向上冒泡', () => {
    const boom = { onUserUpdate: () => { throw new Error('x') } }
    expect(() => broadcast([boom], 'onUserUpdate', 1)).not.toThrow()
  })
})

describe('broadcast：边界输入', () => {
  it('空页面栈 → 0', () => {
    expect(broadcast([], 'onUserUpdate', 1)).toBe(0)
  })
  it('非数组 → 0（不抛）', () => {
    expect(broadcast(null, 'onUserUpdate', 1)).toBe(0)
    expect(broadcast(undefined, 'onUserUpdate', 1)).toBe(0)
  })
  it('缺 hook 名 → 0', () => {
    expect(broadcast([{ onUserUpdate: () => {} }], '', 1)).toBe(0)
  })
  it('页面栈里有 null 元素 → 跳过不抛', () => {
    const ok = { onUserUpdate: vi.fn() }
    expect(broadcast([null, undefined, ok], 'onUserUpdate', 1)).toBe(1)
  })
  it('hook 存在但不是函数 → 跳过', () => {
    expect(broadcast([{ onUserUpdate: 'notAFunction' }], 'onUserUpdate', 1)).toBe(0)
  })
  it('payload 为 undefined 也照样派发（不能当成没数据跳过）', () => {
    const pg = { onUserUpdate: vi.fn() }
    expect(broadcast([pg], 'onUserUpdate', undefined)).toBe(1)
    expect(pg.onUserUpdate).toHaveBeenCalledWith(undefined)
  })
})
