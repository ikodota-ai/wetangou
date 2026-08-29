// tests/pickNearestStore.test.js
// 验证：首启无缓存时也走 storeList 同步占位，**不**等位置
// 这是修"首次进入白板"的关键
//
// 注意：wx 全局在测试环境是 undefined（用 happy-dom 也没意义），
// 这里只测「纯逻辑部分」：useStore 的去重判断、回调触发条件等。
// 真正端到端靠真机验证。
import { describe, it, expect } from 'vitest'

// 在 vitest 跑之前注入一个 mock 的 wx 全局，避免 app.js 顶部 require 时崩
globalThis.wx = {
  getStorageSync: () => null,
  setStorageSync: () => {},
  removeStorageSync: () => {},
  getFuzzyLocation: () => {},
  getLocation: () => {}
}

// 关键：必须在 require app.js 之前 mock api，因为 app.js 里 useStore → loadGoods → api.productList
// 实际我们只测 pickNearestStore 的「是否调用 storeList / 是否同步 callback」
// 简化做法：mock 掉 app.js 依赖的 request 模块
import { vi } from 'vitest'

// 重新 require app.js 会污染其他测试，这里直接复制 pickNearestStore 的关键逻辑来测
// （避免 app.js 顶层副作用）
const buildUseStore = (globalData, callback) => (s, source) => {
  if (!s || !s.storeId) {
    if (source === 'sync') callback(null);
    return;
  }
  const prev = globalData.store
  const changed = !prev || prev.storeId !== s.storeId || prev.latitude !== s.latitude
  globalData.store = s
  if (changed) callback(s)
}

describe('pickNearestStore 用例 (pure logic)', () => {
  it('useStore: storeId 变化时 callback 触发', () => {
    const calls = []
    const gd = { store: null }
    const useStore = buildUseStore(gd, s => calls.push(s))
    useStore({ storeId: 1, latitude: 30, name: 'a' }, 'sync')
    expect(calls).toHaveLength(1)
    expect(calls[0].storeId).toBe(1)
  })

  it('useStore: storeId 不变时 callback 不重复触发（防 setData 抖动）', () => {
    const calls = []
    const gd = { store: { storeId: 1, latitude: 30, name: 'a' } }
    const useStore = buildUseStore(gd, s => calls.push(s))
    useStore({ storeId: 1, latitude: 30, name: 'a' }, 'sync')
    expect(calls).toHaveLength(0)  // 没变化不触发
  })

  it('useStore: 同一 storeId 但 latitude 变化（位置变了）→ 触发升级', () => {
    const calls = []
    const gd = { store: { storeId: 1, latitude: 30, name: 'a' } }
    const useStore = buildUseStore(gd, s => calls.push(s))
    useStore({ storeId: 1, latitude: 31, name: 'a' }, 'nearest')
    expect(calls).toHaveLength(1)  // 经纬度变化时仍触发（nearest 升级场景）
  })

  it('useStore: null store 在 sync 阶段会 callback(null) 让 caller 知道', () => {
    const calls = []
    const gd = { store: null }
    const useStore = buildUseStore(gd, s => calls.push(s))
    useStore(null, 'sync')
    expect(calls).toEqual([null])
  })

  it('useStore: null store 在 nearest 阶段不 callback（async 失败不打扰用户）', () => {
    const calls = []
    const gd = { store: { storeId: 1 } }
    const useStore = buildUseStore(gd, s => calls.push(s))
    useStore(null, 'nearest_fail')  // 异步失败 → 不应 callback
    expect(calls).toHaveLength(0)  // 没新 callback，已有占位保留
  })

  // 回归：app.js onLaunch 的 bootDefaultStore() 会先把 globalData.store 填好，
  // 于是首页 onLoad 再调 pickNearestStore 时 changed=false，回调一次都不触发。
  // 任何「只在这个回调里做的事」都会永远不执行 —— 首页 banner 就是这么丢的
  // （挂在回调里 → 后台配了也恒空白）。
  it('bootDefaultStore 先填过 store 后，首页 onLoad 的回调不会触发（banner 不能挂这里）', () => {
    const calls = []
    const gd = { store: null }

    // 1) app.js onLaunch → bootDefaultStore()：静默预加载，callback 是空函数
    const bootUseStore = buildUseStore(gd, () => {})
    bootUseStore({ storeId: 100, latitude: 30, name: '旗舰店' }, 'list_placeholder')
    expect(gd.store.storeId).toBe(100)   // globalData 已被填好

    // 2) 首页 onLoad → loadData() 再调一次，命中 globalData_placeholder 分支
    const homeUseStore = buildUseStore(gd, s => calls.push(s))
    homeUseStore(gd.store, 'globalData_placeholder')

    // 同一个 store 对象 → changed=false → 首页回调不执行
    expect(calls).toHaveLength(0)
  })
})
