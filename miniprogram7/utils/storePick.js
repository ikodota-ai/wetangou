/**
 * pickNearestStore 里「拿到一个门店之后要做什么」的判定逻辑
 *
 * 抽出来的动机：这段判断出过三次同一个 bug，而原来的单测是把 app.js 里的
 * 逻辑**复制**了一份来测（tests/pickNearestStore.test.js 顶部有注释说明），
 * 复制品和真实代码会各自演化 —— 事实上那份副本一直把 bug 当成预期行为在断言，
 * 所以三次复发单测全绿。现在改成生产代码和测试引用同一个函数。
 *
 * 三次复发分别是：
 *   1) 首页 banner 恒空白（loadBanners 挂在回调里）
 *   2) 首页设施标签恒「暂无服务标签」（loadFacilities 挂在回调里）
 *   3) 首页「拨打电话」恒「暂无联系电话」（客服信息在回调里算）
 * 根因都是 `if (changed) callback(s)`：app.onLaunch 的 bootDefaultStore()
 * 已经把 globalData.store 填好，页面 onLoad 再调时 changed 恒为 false，
 * 回调一次都不执行。
 */

/**
 * @param {Object} prev 当前 globalData.store（可为空）
 * @param {Object} next 这次拿到的门店
 * @param {String} source 来源标记（sync / globalData_placeholder / nearest / ...）
 * @returns {{shouldCallback:Boolean, changed:Boolean, shouldStore:Boolean}}
 */
function decide(prev, next, source) {
  // 拿不到门店：只有同步阶段才回调（告诉调用方"确实没有店"，好显示空态）。
  // 异步阶段失败保持静默 —— 页面上已经有同步阶段选出的占位店，
  // 这时弹一句"加载失败"反而让用户以为页面坏了。
  if (!next || !next.storeId) {
    return {
      shouldCallback: source === 'sync',
      changed: false,
      shouldStore: false
    }
  }

  const changed = !prev || prev.storeId !== next.storeId || prev.latitude !== next.latitude

  return {
    // 关键：回调不看 changed。
    // 「门店没变就别重复 setData」这个优化的代价是整套业务数据拉不到，
    // 完全不成比例；防抖交给页面自己按 storeId 判断。
    shouldCallback: true,
    changed: changed,
    shouldStore: true
  }
}

module.exports = { decide: decide }
