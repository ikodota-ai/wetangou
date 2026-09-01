/**
 * 给当前页面栈上实现了某个 hook 的页面派发一次通知
 *
 * 抽成独立纯函数的动机和 utils/storePick.js 一样：让单测引用真实代码，
 * 而不是复制一份逻辑到测试里（复制品会和生产代码各自演化）。
 *
 * 背景 —— 这里修的是一个「调用了 8 次、一次都没生效」的缺陷：
 * app.js / pages/login / pages/mine/profile / pages/order/submit 共 8 处写的是
 *   appInst.notifyUserUpdate && appInst.notifyUserUpdate(user)
 * 但 app.js 里**从来没有定义过 notifyUserUpdate** —— `&&` 把 undefined
 * 短路掉，所有调用静默失效。而 5 个页面（mine/index、mine/profile、
 * goods/detail、order/submit、promoter/index）都实现了 onUserUpdate 在等广播。
 * 表现为：在「我的-资料」授权完手机号，返回下单页手机号还是空，
 * 只能靠 onShow 再打一次接口兜回来。
 */

/**
 * @param {Array}    pages   页面栈（getCurrentPages() 的结果）
 * @param {String}   hook    钩子名，如 'onUserUpdate' / 'onMerchantUpdate'
 * @param {*}        payload 传给钩子的数据
 * @param {Function} onError 单个页面回调抛错时的处理（可选）
 * @returns {Number} 实际派发成功的页面数
 */
function broadcast(pages, hook, payload, onError) {
  if (!Array.isArray(pages) || !hook) return 0
  var delivered = 0
  for (var i = 0; i < pages.length; i++) {
    var pg = pages[i]
    if (!pg || typeof pg[hook] !== 'function') continue
    // 每个页面单独 try：一个页面的回调抛错不能让后面的页面收不到。
    // 把整个循环包一层 try 是错的 —— 第一个抛错就中断派发。
    try {
      pg[hook](payload)
      delivered++
    } catch (e) {
      if (typeof onError === 'function') onError(pg, e)
    }
  }
  return delivered
}

module.exports = { broadcast: broadcast }
