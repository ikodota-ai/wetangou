/**
 * 套餐「几选几」的唯一口径（商家端编辑页 + 会员端详情页 共用）。
 *
 * 为什么抽出来：这套规则原先只存在于商家端
 * pages/merchant/product/combo/index.js，会员端详情页的「套餐详情」卡
 * 直接把库里的枚举码 pickRule 渲染给顾客 —— 顾客看到的是大写的
 * `PICK_2`，无法理解“买了这个套餐到店能挑几样菜”，而这正是他判断
 * 值不值的前提。之前这张卡因为 subitemGroups 被 request() 解包吃掉而
 * 从来没真正显示过，所以它自身的这个 bug 也一直没被发现。
 *
 * 抽成公共模块而不是在会员端再写一份：两边各写一份早晚会漂移，
 * 到时商家在后台设的是「3选2」、顾客看到的是「3选3」，那是履约纠纷。
 *
 * 口径与 PC 端 views/biz/product/create.vue 的 groupPickCount / pickRuleOptions
 * 保持一致：全系统 pickRule 只认 'ALL'（全部可选）或 'PICK_N'（可选 N 个）。
 *
 * 「个数」按单品品种数算，不看 quantity：一组里「红烧肉 ×2」「可乐 ×1」
 * 是 2 个单品而不是 3 个，quantity 是这道菜给几份，跟顾客能挑几样是两回事。
 */

/** 本组单品品种数 */
function groupSize(g) {
  return ((g && g.subitems) || []).length
}

/** 解析 pickRule 得到「可选几个」；无规则 / ALL / 超出范围都按全选 */
function groupPickCount(g) {
  const size = groupSize(g)
  const rule = g && g.pickRule
  if (!rule || rule === 'ALL') return size
  const m = String(rule).match(/^PICK_(\d+)$/)
  let n = m ? Number(m[1]) : null
  if (n == null) {
    // 兼容历史写进库的中文 'N选M'，取「选」后面那个数
    const cn = String(rule).match(/\u9009\s*(\d+)$/)
    if (cn) n = Number(cn[1])
  }
  if (n == null || n <= 0 || n >= size) return size
  return n
}

/** 商家端标签文案：3 个单品全选 → 「共3个单品：3选3」 */
function pickRuleText(g) {
  const size = groupSize(g)
  if (size === 0) return '未添加单品'
  return '共' + size + '个单品：' + size + '选' + groupPickCount(g)
}

/**
 * 顾客端标签文案。
 *
 * 与商家端分开一个函数是有意的：商家在编辑页需要知道「本组共几个单品」
 * （这是他刚加完菜要校对的数）；而顾客只关心「我能挑几样」，
 * “共3个单品”对他是噪音 —— 下面就列着那 3 行菜名，他自己数得出来。
 *
 * 全选时返空字符串（让 WXML 不展这个标签）：列出的每一道都给，
 * 再挂一个「全部可选」反而让人疑心是不是要选。
 */
function customerPickText(g) {
  const size = groupSize(g)
  if (size === 0) return ''
  const pick = groupPickCount(g)
  if (pick >= size) return ''
  return size + '选' + pick
}

/**
 * 本组子品原价合计（元，保留两位小数的字符串）。
 *
 * 为何要它：拖音来客的套餐明细卡尾部都有一行加重的「合计 / 总价值」
 * （doc 里 c1_341/342 + c2_350 交叉证实过），而我们的子品卡只逐行列价格。
 * 顾客要自己把 17 行菜的价钱加起来才知道这个套餐到底便宜多少 ——
 * 而“划算”正是他下单前唯一想算的那个数。
 *
 * quantity 必须乘进去：它是“这道菜给几份”（实测 999534 的荤菜组
 * 8 个单品 = 264 元，含多份项），与 groupPickCount 只数品种不同 ——
 * 后者算“能挑几样”，前者算“值多少钱”，两个口径不能混。
 *
 * 返空串而不是 "0.00"：库里子品价格大量未填（实测 999534 的锅底组、
 * 999742 两组均为 0），展一行“合计 ¥0.00”会让顾客以为这组不值钱。
 */
function groupTotalPrice(g) {
  var list = (g && g.subitems) || []
  var sum = 0
  var any = false
  for (var i = 0; i < list.length; i++) {
    var price = Number(list[i] && list[i].price)
    if (!isFinite(price) || price <= 0) continue
    var qty = Number(list[i].quantity)
    if (!isFinite(qty) || qty <= 0) qty = 1
    sum += price * qty
    any = true
  }
  if (!any) return ''
  return sum.toFixed(2)
}

/**
 * 可选规则按本组实际单品数动态生成：3 个单品 → 全部可选(3选3) / 3选2 / 3选1。
 * 不能硬编码：2 个单品的组也能设成「3选2」，存进去就是永远履约不了的脏数据。
 */
function pickRuleOptions(g) {
  const size = groupSize(g)
  const labels = ['全部可选（' + size + '选' + size + '）']
  const values = ['ALL']
  for (let n = size - 1; n >= 1; n--) {
    labels.push(size + '选' + n)
    values.push('PICK_' + n)
  }
  return { labels, values }
}

module.exports = {
  groupSize: groupSize,
  groupPickCount: groupPickCount,
  pickRuleText: pickRuleText,
  customerPickText: customerPickText,
  groupTotalPrice: groupTotalPrice,
  pickRuleOptions: pickRuleOptions
}
