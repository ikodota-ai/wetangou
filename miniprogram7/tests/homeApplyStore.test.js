// pages/home/index.js —— 「拿到门店之后该做什么」必须只有一个入口
//
// 这个文件锁住的是「后台配了却不显示」的**第四个**根因，也是最容易走到的一条：
//
// onLoad 里有个 3.5s 兜底定时器（避免首屏白板卡死），它原先只 setData({store})，
// 不调 loadFacilities / _contactPatch / loadBookingGoods。而首启无缓存时
// pickNearestStore 要走 storeList → 取位 → storeNearest 好几个来回，
// 冷启动 + 弱网很容易超 3.5s —— 用户真机日志里就是
// 「[home] 3.5s 仍无 store，触发降级」。走到这条路径时店名有了，
// 但评分/设施/客服/预约商品一个都拉不到，表现和「回调被 changed 短路」一模一样。
//
// 前三次复发（banner / 设施 / 拨打电话）都是在各页面加「先主动拉一次」绕过去，
// 所以每加一条新路径就再中一次。这次收口成 _applyStore()，两条路径共用。
import { describe, it, expect, beforeEach, vi } from 'vitest'
import fs from 'fs'
import path from 'path'

const HOME = path.resolve(__dirname, '../pages/home/index.js')

// ---- 用 globalThis 桩把 pages/home/index.js 真实加载进来 ----
// 项目里 tests/pay.test.js 已是这个模式：小程序页面依赖 Page()/getApp() 全局，
// 没有这两个桩 require 会直接抛。
let pageDef = null
let appStub = null
let storeListResult = null
let timers = []

function loadHomePage() {
  pageDef = null
  timers = []
  storeListResult = null

  appStub = {
    globalData: { store: null, stores: [], goods: [], location: null, merchant: {} },
    pickNearestStore: vi.fn(),
    loadAllPickupGoods: vi.fn(() => Promise.resolve([])),
    buildGoodsDesc: () => ''
  }

  globalThis.getApp = () => appStub
  globalThis.Page = (def) => { pageDef = def }
  globalThis.getCurrentPages = () => []
  globalThis.setTimeout = (fn, ms) => { timers.push({ fn, ms }); return timers.length }
  globalThis.clearTimeout = () => {}
  globalThis.wx = {
    getSystemInfoSync: () => ({ statusBarHeight: 20 }),
    getStorageSync: () => null,
    setStorageSync: () => {},
    getLocation: (o) => o.fail && o.fail(),
    showToast: () => {},
    showActionSheet: () => {},
    previewImage: () => {},
    makePhoneCall: () => {},
    navigateTo: () => {},
    switchTab: () => {}
  }

  // request.js 是 CJS 且被 home/index.js 直接 require —— 用 vi.doMock 拦掉，
  // 否则会走进真实现去发请求
  vi.resetModules()
  const src = fs.readFileSync(HOME, 'utf8')
  const apiStub = {
    storeList: vi.fn(() => Promise.resolve(storeListResult)),
    storeServices: vi.fn(() => Promise.resolve({ data: ['可堂食'] })),
    bannerList: vi.fn(() => Promise.resolve({ data: [] })),
    productList: vi.fn(() => Promise.resolve({ data: [] }))
  }
  // 手动执行源码，把 require 换成受控版本 —— 比改 vitest 配置轻
  const requireStub = (id) => {
    if (id.indexOf('request.js') >= 0) return { api: apiStub, toFullUrl: (u) => u }
    if (id.indexOf('util.js') >= 0) return require('../utils/util.js')
    if (id.indexOf('contact.js') >= 0) return require('../utils/contact.js')
    if (id.indexOf('rating.js') >= 0) return require('../utils/rating.js')
    throw new Error('unexpected require: ' + id)
  }
  // eslint-disable-next-line no-new-func
  new Function('require', 'Page', 'getApp', 'wx', 'setTimeout', 'clearTimeout', 'console', src)(
    requireStub, globalThis.Page, globalThis.getApp, globalThis.wx,
    globalThis.setTimeout, globalThis.clearTimeout,
    { log: () => {}, warn: () => {}, error: () => {} }
  )
  return { def: pageDef, api: apiStub }
}

// 造一个页面实例：把 def 的方法挂上，setData 合并进 data
function instantiate(def) {
  const pg = Object.assign({}, def)
  pg.data = JSON.parse(JSON.stringify(def.data))
  pg.setData = (patch) => { Object.assign(pg.data, patch) }
  return pg
}

const STORE = {
  storeId: 100,
  storeName: '锦江区心依美服装店',
  businessHours: '10:00-22:00',
  address: '成都市锦江区',
  rating: 4.8,
  phone: '13568824703',
  servicePhone: '13540472877',
  serviceQrcode: '',
  serviceHours: '09:00-22:00'
}

describe('_applyStore 是唯一入口', () => {
  let def, api, pg
  beforeEach(() => {
    const r = loadHomePage(); def = r.def; api = r.api
    pg = instantiate(def)
  })

  it('_applyStore 存在（不是又把逻辑内联回回调里）', () => {
    expect(typeof def._applyStore).toBe('function')
  })

  it('调 _applyStore 会同时拉设施、算客服、拉预约商品', () => {
    pg._applyStore(STORE)
    expect(api.storeServices).toHaveBeenCalledWith(100)
    expect(api.productList).toHaveBeenCalled()
    // 客服四项算出来了（门店电话优先）
    expect(pg.data.callPhone).toBe('13568824703')
    expect(pg.data.phone).toBe('13540472877')
  })

  it('评分走 utils/rating.js，视图字段齐全', () => {
    pg._applyStore(STORE)
    expect(pg.data.store.hasRating).toBe(true)
    expect(pg.data.store.ratingText).toBe('4.8')
    expect(pg.data.store.ratingStars).toBe(5)
  })

  it('同一个 storeId 重复调不重复请求门店级数据', () => {
    pg._applyStore(STORE)
    pg._applyStore(STORE)
    expect(api.storeServices).toHaveBeenCalledTimes(1)
  })

  it('门店换了要重新拉（占位店 → 最近店升级）', () => {
    pg._applyStore(STORE)
    pg._applyStore(Object.assign({}, STORE, { storeId: 200 }))
    expect(api.storeServices).toHaveBeenCalledTimes(2)
    expect(api.storeServices).toHaveBeenLastCalledWith(200)
  })

  it('空门店 / 缺 storeId 直接返回，不发请求', () => {
    pg._applyStore(null)
    pg._applyStore({})
    pg._applyStore({ storeName: '没有 id' })
    expect(api.storeServices).not.toHaveBeenCalled()
  })
})

describe('3.5s 降级路径必须和正常回调做同样的事', () => {
  // 这是本次修的核心：用户真机日志走的就是这条路
  let def, api, pg
  beforeEach(() => {
    const r = loadHomePage(); def = r.def; api = r.api
    pg = instantiate(def)
  })

  it('降级分支拿到门店后会拉设施和客服（原先只 setData 店名）', async () => {
    storeListResult = { rows: [STORE] }
    pg.onLoad()
    // onLoad 注册了 3.5s 兜底定时器
    const slow = timers.find((t) => t.ms === 3500)
    expect(slow).toBeTruthy()

    // 模拟「3.5s 到了还没有 store」
    expect(pg.data.store.storeId).toBeUndefined()
    slow.fn()
    await Promise.resolve(); await Promise.resolve(); await Promise.resolve()

    expect(pg.data.store.storeId).toBe(100)
    // 关键断言：这三件事原先在降级路径上一件都不做
    expect(api.storeServices).toHaveBeenCalledWith(100)
    expect(api.productList).toHaveBeenCalled()
    expect(pg.data.callPhone).toBe('13568824703')
    expect(pg.data.store.ratingText).toBe('4.8')
  })

  it('已经有 store 时降级分支不覆盖（正常回调已经跑过了）', async () => {
    storeListResult = { rows: [Object.assign({}, STORE, { storeId: 999, storeName: '兜底店' })] }
    pg.onLoad()
    // 正常回调先到
    pg._applyStore(STORE)
    const slow = timers.find((t) => t.ms === 3500)
    slow.fn()
    await Promise.resolve(); await Promise.resolve()
    expect(pg.data.store.storeId).toBe(100)
    expect(pg.data.store.storeName).toBe('锦江区心依美服装店')
  })

  it('降级请求返空也不抛（后台一个门店都没建）', async () => {
    storeListResult = { rows: [] }
    pg.onLoad()
    const slow = timers.find((t) => t.ms === 3500)
    expect(() => slow.fn()).not.toThrow()
    await Promise.resolve(); await Promise.resolve()
    // 保留「门店加载中…」占位，不崩
    expect(pg.data.store.name).toBe('门店加载中…')
  })
})

describe('loadData 的回调也走 _applyStore', () => {
  it('pickNearestStore 的回调里不再内联那套动作', () => {
    const { def } = loadHomePage()
    const pg = instantiate(def)
    pg.loadData()
    expect(appStub.pickNearestStore).toHaveBeenCalled()
    const cb = appStub.pickNearestStore.mock.calls[0][0]
    const spy = vi.fn()
    pg._applyStore = spy
    cb(STORE)
    expect(spy).toHaveBeenCalledWith(STORE)
  })
})
