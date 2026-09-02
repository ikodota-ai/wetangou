// tests/mineStaffEntry.test.js
//
// 「我的」页的商家入口 —— 锁住「只有一个账号密码入口，且它去新商家版」。
//
// 原来这里并排挂着两个入口：
//   「员工 / 商家登录」  → goStaffLogin  → pages/login/login 或旧 pages/staff/home
//   「商家员工登录」      → goMerchantLogin → pages/merchant/login
// 两个长得一样、都要账号密码，但去的是两套不同的商家端。老板拿着店长给的账号
// 有五成概率点中上面那个，落进旧门店端（/api/store/staff/login）——
// 而那个端点要求 biz_store_user 里挂过门店，商家版建出来的账号一律没挂，
// 只会看到「该账号未关联门店，无门店端权限」。实测 owner_c43 和 staff_c43 都被拒，
// 库里只剩 staff001 一个历史账号能登旧门店端。
//
// 这类问题 lint 和 smoke 都发现不了：两个入口各自都能跳、目标页都存在、
// 后端两套端点都活着，只有真人拿着商家账号点错一次才知道。
import { describe, it, expect, beforeEach, vi } from 'vitest'
import fs from 'fs'
import path from 'path'

const SRC = path.resolve(__dirname, '../pages/mine/index/index.js')
const WXML = path.resolve(__dirname, '../pages/mine/index/index.wxml')

let pageDef, nav

function loadPage() {
  pageDef = null
  nav = { navigateTo: [], reLaunch: [], switchTab: [] }
  const wxStub = {
    getStorageSync: () => '', setStorageSync: () => {},
    navigateTo: (o) => nav.navigateTo.push(o.url),
    reLaunch: (o) => nav.reLaunch.push(o.url),
    switchTab: (o) => nav.switchTab.push(o.url),
    showToast: () => {}, showModal: () => {}, showLoading: () => {}, hideLoading: () => {},
    makePhoneCall: () => {}, previewImage: () => {}
  }
  const requireStub = (id) => {
    if (id.indexOf('request.js') >= 0) {
      return { api: {}, APPID: 'wxtest', toFullUrl: (u) => u }
    }
    if (id.indexOf('identity.js') >= 0) {
      return { hasStaffSession: () => false, switchToMember: () => ({ ok: true }) }
    }
    throw new Error('unexpected require: ' + id)
  }
  const src = fs.readFileSync(SRC, 'utf8')
  // eslint-disable-next-line no-new-func
  new Function('require', 'Page', 'getApp', 'wx', 'console', src)(
    requireStub, (def) => { pageDef = def },
    () => ({ globalData: { user: {}, store: {} } }),
    wxStub, { log: () => {}, warn: () => {}, error: () => {} }
  )
  return Object.assign({}, pageDef, {
    data: Object.assign({}, pageDef.data),
    setData(patch) { Object.assign(this.data, patch) }
  })
}

beforeEach(() => { vi.resetModules() })

describe('「我的」页商家入口', () => {
  it('账号密码入口只去新商家版登录页', () => {
    const ctx = loadPage()
    ctx.goMerchantLogin()
    expect(nav.navigateTo).toEqual(['/pages/merchant/login/index'])
  })

  it('已删掉会走旧门店端的 goStaffLogin（老板点错就被拒登）', () => {
    const ctx = loadPage()
    expect(ctx.goStaffLogin).toBeUndefined()
  })

  it('WXML 里不再有指向 goStaffLogin 的按钮', () => {
    const wxml = fs.readFileSync(WXML, 'utf8')
    expect(wxml).not.toContain('goStaffLogin')
  })

  it('没有商家身份时只显示一个账号密码入口', () => {
    const wxml = fs.readFileSync(WXML, 'utf8')
    // 去掉注释再数，注释里保留了改动说明会误伤计数
    const body = wxml.replace(/<!--[\s\S]*?-->/g, '')
    const hits = body.match(/bindtap="goMerchantLogin"/g) || []
    expect(hits.length).toBe(1)
  })

  it('旧门店端登录态的人仍能回工作台（不把历史用户锁在外面）', () => {
    const ctx = loadPage()
    expect(typeof ctx.goLegacyStoreHome).toBe('function')
    ctx.goLegacyStoreHome()
    expect(nav.reLaunch).toEqual(['/pages/staff/home/index'])
  })

  it('旧门店端入口只在 staffActive 时出现，不与商家登录入口同时显示', () => {
    const wxml = fs.readFileSync(WXML, 'utf8')
    const body = wxml.replace(/<!--[\s\S]*?-->/g, '')
    // 商家登录入口：无商家身份 且 非旧门店端登录态
    expect(body).toContain('wx:if="{{!canSwitchStaff && !staffActive}}"')
    // 旧门店端入口：仅 staffActive
    expect(body).toContain('wx:if="{{staffActive}}"')
  })
})
