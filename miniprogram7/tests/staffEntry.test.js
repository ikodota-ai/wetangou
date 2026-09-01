// tests/staffEntry.test.js
// 「我的」页那个「切换到商家版」入口的可见性，唯一依据是 storage 里的
// hasStaffAccount。它由会员登录响应写入，而会员登录有两条入口：
//   a) pages/login/login.js —— 用户点「微信登录」的显式路径
//   b) utils/request.js 的 _reloginAndRetry —— 会员 token 过期后的静默重登
// 原来只有 a 写这个标记。店员换设备或清了缓存后，首次是走 b 静默进来的，
// storage 里没有标记 → 明明已入职的店员在会员端找不到任何进商家版的路。
// 现在两条入口共用 pickHasStaffAccount，这里锁住它的取值语义。
import { describe, it, expect } from 'vitest'

const { pickHasStaffAccount } = require('../utils/request.js')

describe('pickHasStaffAccount', () => {
  it('空输入一律 false，不能误判成有商家身份', () => {
    expect(pickHasStaffAccount(null)).toBe(false)
    expect(pickHasStaffAccount(undefined)).toBe(false)
    expect(pickHasStaffAccount({})).toBe(false)
  })

  it('顶层 hasStaffAccount=true → true（/api/auth/login 的实际形态）', () => {
    expect(pickHasStaffAccount({ code: 200, hasStaffAccount: true })).toBe(true)
  })

  it('包在 data 里也要认（AjaxResult 被再包一层时）', () => {
    expect(pickHasStaffAccount({ code: 200, data: { hasStaffAccount: true } })).toBe(true)
  })

  it('false 就是 false —— 没入职的普通会员不能看到商家版入口', () => {
    expect(pickHasStaffAccount({ code: 200, hasStaffAccount: false })).toBe(false)
    expect(pickHasStaffAccount({ code: 200, data: { hasStaffAccount: false } })).toBe(false)
  })

  it('只认严格 true，字符串/数字等真值不算（后端字段类型变化时宁可不显示入口）', () => {
    expect(pickHasStaffAccount({ hasStaffAccount: 'true' })).toBe(false)
    expect(pickHasStaffAccount({ hasStaffAccount: 1 })).toBe(false)
    expect(pickHasStaffAccount({ data: { hasStaffAccount: 'yes' } })).toBe(false)
  })

  it('返回值必须是布尔，直接写进 storage 不会存成 undefined', () => {
    expect(typeof pickHasStaffAccount({})).toBe('boolean')
    expect(typeof pickHasStaffAccount({ hasStaffAccount: true })).toBe('boolean')
  })
})
