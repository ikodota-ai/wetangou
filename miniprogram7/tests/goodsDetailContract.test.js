// tests/goodsDetailContract.test.js
//
// 详情页「WXML 引用 ↔ js 真的会 setData」的渲染契约。
//
// 为什么需要它：本轮修的那批缺陷里有一类是「WXML 分支一直在，但它读的
// 字段 js/后端从未给过」—— 例如底部那张「本店更多商品」读的是
// product.moreGoods，而后端从来没下发过这个字段，连标题里的「3」都是写死的；
// 又例如套餐详情那张卡因为 subitemGroups 被 request() 解包吃掉而从未显示过。
//
// 这类失效的要命是「静默」：wx:if 拿到 undefined 就整卡不渲染，
// 不报错、不编译失败、后端 200。lint-wxml-expr 只管表达式里写不写函数调用，
// lint-wxml-handler 只管 bindtap 有没有对应方法，smoke 只能证明后端下发了字段
// —— 三道门全结合起来也盖不住「下发了但页面没接住」这一段。
import { describe, it, expect } from 'vitest'
import fs from 'fs'
import path from 'path'

const WXML = fs.readFileSync(path.resolve(__dirname, '../pages/goods/detail/index.wxml'), 'utf8')
const JS = fs.readFileSync(path.resolve(__dirname, '../pages/goods/detail/index.js'), 'utf8')

// 后端 detail 接口直接透传的字段（normalize 里的 ...p）。
// 它们不会在 js 里出现同名 key，但 payload 里确实有 —— 实测商品 2000 逐个确认过。
const PASSTHROUGH = ['consumeStartDays', 'consumeValidDays', 'subtitle']

function refs(re) {
  const out = new Set()
  let m
  while ((m = re.exec(WXML)) !== null) out.add(m[1])
  return Array.from(out).sort()
}

describe('详情页 WXML 引用的字段必须真有人给', () => {
  it('每个 product.xxx 要么 normalize 里算了，要么是后端透传字段', () => {
    const orphans = refs(/product\.([A-Za-z_][A-Za-z0-9_]*)/g).filter(function (k) {
      if (PASSTHROUGH.indexOf(k) >= 0) return false
      return JS.indexOf(k + ':') < 0 && JS.indexOf('.' + k) < 0
    })
    expect(orphans).toEqual([])
  })

  it('顶层兄弟键（不在 product 里的）必须在 data 给了初值', () => {
    // WXML 用 .length 判空，undefined.length 在渲染层会直接报错，
    // 所以这几个必须在 data 里先给空数组/空串，不能等 setData。
    const TOP = ['applicableStores', 'moreGoods', 'storeServices', 'storeCountLabel']
    const dataBlock = JS.slice(JS.indexOf('data: {'), JS.indexOf('onLoad('))
    TOP.forEach(function (k) {
      expect(WXML.indexOf(k), k + ' 应在 WXML 被用').toBeGreaterThan(-1)
      expect(dataBlock.indexOf(k + ':'), k + ' 必须在 data 给初值').toBeGreaterThan(-1)
    })
  })

  it('本轮补的交易规则文案字段全部在 normalize 里真算了', () => {
    // 这批字段后端一直在下发，是前端从未读过；一旦有人把 normalize 里那行删了，
    // 页面不报错、只是那几行静默消失 —— 回到修之前的状态。
    const NEEDED = [
      'mutexText', 'collectMethodText', 'codeTypeText',
      'dailyTimeText', 'excludeDatesText', 'voucherRulesText',
      'voucherScopeLabel', 'voucherScopeValue', 'refundPolicyText',
      'noticeRich', 'detail'
    ]
    const norm = JS.slice(JS.indexOf('normalize(p, groups)'))
    NEEDED.forEach(function (k) {
      expect(norm.indexOf(k + ':'), 'normalize 必须算 ' + k).toBeGreaterThan(-1)
      expect(WXML.indexOf(k), 'WXML 必须展 ' + k).toBeGreaterThan(-1)
    })
  })

  it('退改政策不能再在页面里自己写一张翻译表', () => {
    // 口径必须在 utils/tradeRules.js（能被单测锁住、与 PC 下拉逐字对齐）。
    // 原先写在详情页里无人校对，凭空编了 EXPIRED / NEVER 两个不存在的键。
    expect(JS).not.toMatch(/EXPIRED\s*:/)
    expect(JS).not.toMatch(/NEVER\s*:/)
    expect(JS).toContain('refundPolicyText')
  })
})

// 逐家拨号是履约级链路：多店商品下面列了 N 行门店，
// 要是拨号取的不是本行那个号（比如图省事把号码放到 data 里共用一份），
// 顾客会把电话打到另一家店 —— 那家店说「没这个套餐」，直接成纠纷。
describe('适用门店逐行拨号必须取本行号码', () => {
  it('bindtap 所在元素自己带 data-phone，不是从共享状态取', () => {
    // 把带 onCallStore 的那一段拉出来，要求同一个标签上同时有 data-phone。
    const m = WXML.match(/<view[^>]*bindtap="onCallStore"[^>]*>/)
    expect(m, '应有绑 onCallStore 的元素').not.toBeNull()
    expect(m[0]).toMatch(/data-phone="\{\{\s*st\.phone\s*\}\}"/)
  })

  it('它必须在 wx:for 的循环体里（st 是循环变量）', () => {
    expect(WXML).toMatch(/wx:for="\{\{applicableStores\}\}"/)
    expect(WXML).toMatch(/wx:for-item="st"/)
  })

  it('onCallStore 从 currentTarget.dataset 取号，不读 this.data', () => {
    const i = JS.indexOf('onCallStore(e)')
    expect(i).toBeGreaterThan(-1)
    const body = JS.slice(i, i + 320)
    expect(body).toContain('currentTarget.dataset.phone')
    // 读 this.data.xxx 就意味着号码是共享的，多店必错
    expect(body).not.toContain('this.data.product.storePhone')
  })
})
