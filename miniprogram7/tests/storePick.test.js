// utils/storePick.js —— pickNearestStore 拿到门店后的判定
//
// 这个文件存在的理由：同一个 bug 在这段逻辑上复发了三次
//   1) 首页 banner 恒空白
//   2) 首页设施标签恒「暂无服务标签」
//   3) 首页「拨打电话」恒「暂无联系电话」
// 而旧的 tests/pickNearestStore.test.js 是把 app.js 的逻辑**复制**一份来测的，
// 那份副本把 `if (changed) callback()` 当成预期行为断言，所以三次复发单测全绿。
// 现在生产代码和测试引用同一个 decide()，不再有副本。
import { describe, it, expect } from 'vitest'

const { decide, decideLocation } = require('../utils/storePick.js')

const S1 = { storeId: 100, latitude: 30.65 }
const S1_MOVED = { storeId: 100, latitude: 31.00 }
const S2 = { storeId: 200, latitude: 30.65 }

describe('decide：拿到门店', () => {
  it('首次填充（prev 为空）→ 回调 + changed', () => {
    const d = decide(null, S1, 'list_placeholder')
    expect(d.shouldCallback).toBe(true)
    expect(d.changed).toBe(true)
    expect(d.shouldStore).toBe(true)
  })

  it('换了另一家门店 → 回调 + changed', () => {
    const d = decide(S1, S2, 'nearest')
    expect(d.shouldCallback).toBe(true)
    expect(d.changed).toBe(true)
  })

  it('同一门店但坐标变了（nearest 升级）→ 回调 + changed', () => {
    const d = decide(S1, S1_MOVED, 'nearest')
    expect(d.shouldCallback).toBe(true)
    expect(d.changed).toBe(true)
  })

  // 这条是三次复发的核心：bootDefaultStore 已经把 store 填好，
  // 页面 onLoad 再调时门店没变 —— 以前这里 shouldCallback=false，
  // 于是挂在回调里的 banner / 设施 / 客服信息一次都不执行。
  it('门店完全没变 → 仍然回调（挂回调里的业务数据必须拿得到）', () => {
    const d = decide(S1, S1, 'globalData_placeholder')
    expect(d.shouldCallback).toBe(true)
    expect(d.changed).toBe(false)   // 但要告诉调用方"没变"，好跳过重复的列表请求
  })

  it('bootDefaultStore 填过之后，页面 onLoad 的回调照样触发', () => {
    // 1) app.onLaunch → bootDefaultStore()，callback 是空函数
    const boot = decide(null, S1, 'list_placeholder')
    expect(boot.shouldStore).toBe(true)
    const globalStore = S1

    // 2) 页面 onLoad → 再调一次，命中 globalData_placeholder 分支
    const page = decide(globalStore, globalStore, 'globalData_placeholder')
    expect(page.shouldCallback).toBe(true)
    // changed=false 让页面知道不必重拉门店级列表，但回调本身必须给
    expect(page.changed).toBe(false)
  })
})

describe('decide：拿不到门店', () => {
  it('同步阶段拿不到 → 回调 null，让页面显示空态', () => {
    const d = decide(null, null, 'sync')
    expect(d.shouldCallback).toBe(true)
    expect(d.shouldStore).toBe(false)
  })

  it('异步阶段失败 → 静默，保留同步阶段选出的占位店', () => {
    const d = decide(S1, null, 'nearest_fail')
    expect(d.shouldCallback).toBe(false)
    expect(d.shouldStore).toBe(false)
  })

  it('门店对象缺 storeId 视为拿不到（后端返了空壳对象的情况）', () => {
    const d = decide(S1, { storeName: '有名字没ID' }, 'nearest')
    expect(d.shouldStore).toBe(false)
    expect(d.shouldCallback).toBe(false)
  })

  it('changed 恒为 false，不能因为拿不到店就把它标成"变了"', () => {
    expect(decide(S1, null, 'sync').changed).toBe(false)
    expect(decide(S1, null, 'nearest_fail').changed).toBe(false)
  })
})

// ---------------------------------------------------------------
// decideLocation：silent 开关
//
// bootDefaultStore() 一直传 { silent: true }，但 pickNearestStore 从来
// 没读过它（opts 只被读了 force）——于是 onLaunch 就弹位置授权框。
// wx.getLocation 在用户不点时既不 success 也不 fail，一直挂着，
// 首屏门店迟迟不到 → 触发首页 3.5s 降级 → 评分/设施/客服全拉不到。
// 这是用户真机日志「[home] 3.5s 仍无 store，触发降级」的成因，
// 也是第五个「写了但没生效」的开关（同型：notifyUserUpdate 从未定义）。
// ---------------------------------------------------------------
describe('decideLocation：silent 不许弹授权框', () => {
  const LOC = { lat: 30.65, lng: 104.08 }

  it('silent + 无位置 → 不弹框（关键：onLaunch 不该挡住首屏）', () => {
    const d = decideLocation({ silent: true }, null)
    expect(d.requestPermission).toBe(false)
    expect(d.useExisting).toBe(false)
  })

  it('非 silent + 无位置 → 才允许弹框（用户主动点「查看距离」）', () => {
    expect(decideLocation({}, null).requestPermission).toBe(true)
    expect(decideLocation(undefined, null).requestPermission).toBe(true)
  })

  it('已有位置 → 直接用，不需要弹框（silent 与否都一样）', () => {
    expect(decideLocation({ silent: true }, LOC)).toEqual({ useExisting: true, requestPermission: false })
    expect(decideLocation({}, LOC)).toEqual({ useExisting: true, requestPermission: false })
  })

  it('位置字段不合法当成没位置（NaN / 缺字段 / 字符串）', () => {
    expect(decideLocation({ silent: true }, { lat: NaN, lng: 104 }).useExisting).toBe(false)
    expect(decideLocation({ silent: true }, { lat: 30.65 }).useExisting).toBe(false)
    expect(decideLocation({ silent: true }, { lat: '30.65', lng: '104' }).useExisting).toBe(false)
    expect(decideLocation({ silent: true }, {}).useExisting).toBe(false)
  })

  it('Infinity 也当没位置（isFinite 而不是 typeof 判断）', () => {
    expect(decideLocation({}, { lat: Infinity, lng: 104 }).useExisting).toBe(false)
  })

  it('silent + 不合法位置 → 仍然不弹框', () => {
    expect(decideLocation({ silent: true }, { lat: NaN, lng: NaN }).requestPermission).toBe(false)
  })
})
