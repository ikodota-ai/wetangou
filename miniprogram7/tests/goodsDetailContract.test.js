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

// cover / images 职责划分的渲染契约。
//
// 上一版顶部轮播写的是「images 优先，cover 兑底」，恰好把两个字段的
// 职责说反了（cover=商品头图、images=环境图）；而本地 10 条商品两边
// 首张恰好相同，胮眼和真机都看不出差别 —— 只有契约能盯住它。
describe('头图 / 环境图 各归各位', () => {
  it('顶部轮播读 product.images，而它必须由 heroImages（取 cover）算出来', () => {
    expect(WXML).toMatch(/<swiper[^>]*class="hero"/)
    expect(JS).toContain('heroImages(p)')
    // 不能回到「优先 images」的旧写法
    expect(JS).not.toMatch(/const images = p\.images/)
  })

  it('环境图走 product.contentImages，展在图文详情卡里（不上顶部）', () => {
    expect(JS).toContain('contentImages:')
    expect(WXML).toContain('product.contentImages')
    // 必须在「图文详情」那张卡内，而不是自己另开一张无标题的卡
    const i = WXML.indexOf('图文详情')
    const j = WXML.indexOf('product.contentImages')
    expect(i).toBeGreaterThan(-1)
    expect(j).toBeGreaterThan(i)
  })

  it('图文详情卡的 wx:if 要把环境图算进去：只有图没富文时也得显示', () => {
    // 否则商家只传了 10 张实拍、没写富文，那批图就永远不会出现。
    expect(WXML).toMatch(/wx:if="\{\{product\.detail \|\| product\.contentImages\.length\}\}"/)
  })

  it('只能放一张图的 product.cover 必须过 firstCover（cover 是逗号串）', () => {
    expect(JS).toContain('firstCover(p)')
    // 旧写法：toFullUrl(p.cover) 直接把整串当 URL
    expect(JS).not.toMatch(/cover: p\.cover \? toFullUrl\(p\.cover\)/)
  })

  it('分享 / 收藏 封面不能再取环境图首张', () => {
    // 旧写法 p.images && p.images[0] || p.cover：发出去的封面是环境图，
    // 不是商家选的主图。
    expect(JS).not.toMatch(/p\.images && p\.images\[0\]/)
  })

  it('环境图可点大图，且 previewImage 传全部图（只传当前张等于废掉划动）', () => {
    expect(WXML).toContain('bindtap="onPreviewContentImage"')
    const i = JS.indexOf('onPreviewContentImage(e)')
    expect(i).toBeGreaterThan(-1)
    const body = JS.slice(i, i + 420)
    expect(body).toContain('wx.previewImage')
    expect(body).toContain('urls:')
  })
})

// 套餐详情（子品分组）与类型名。
//
// 两个真实缺陷：
// 1) 后端只给 GROUPON/COMBO 下发 subitemGroups，前端又多一道
//    typeCode !== 'VOUCHER'。两道类型卡叠加 → 库里 BOOKING 类型的 999534
//    真有 4 组 17 个子品，顾客一样看不到自己能挑什么。
// 2) 类型名在前端写死一份（GROUPON →「团购套餐」），而
//    biz_product_type.type_name 已被运营改成「到店自取」。
describe('套餐详情只看数据、不看类型', () => {
  it('那张卡的 wx:if 不能再带 typeCode 判断（后端已按「有数据才下发」把关）', () => {
    const m = WXML.match(/<view class="card" wx:if="\{\{product\.subitemGroups[^"]*"/)
    expect(m, '应有套餐详情卡').not.toBeNull()
    expect(m[0]).not.toContain('typeCode')
    expect(m[0]).toContain('product.subitemGroups.length')
  })
})

describe('类型名只能来自 biz_product_type 字典', () => {
  it('前端不再编造类型中文名（typeText 已清空兑底表）', () => {
    // 两份事实必然漂，而漂了也不报错 —— 只会让顾客看到已废弃的旧名。
    expect(JS).not.toMatch(/GROUPON:\s*'团购套餐'/)
    expect(JS).not.toMatch(/GROUPON:\s*'团购'/)
  })

  it('typeName 优先用后端顶层下发的字典值', () => {
    expect(JS).toContain('typeName: p.typeName')
    // 后端顶层兄弟键必须并进商品对象，否则 normalize 拿不到
    expect(JS).toContain('typeName: raw.typeName || p.typeName')
  })
})

// 顶部「门店」行（类型下一行）。
//
// 业务背景：首页已按位置定位到最近门店，商品列表也是按那家店拉的，
// 所以详情页顶部应直接展“当前门店 + 距离 + 星级”。
// 上一轮我把旧的 storeScopeText（“N 店通用”）删了，并不等于这行不该存在：
// 那行回答的是“还有哪几家能用”（已由底部「适用门店」卡接管），
// 这行回答的是“我要去的那家叫什么、有多远、好不好”。
describe('顶部门店行：读首页定位的当前门店', () => {
  it('topStore 必须在 data 给初值（WXML 直读 topStore.name，undefined 会报错）', () => {
    const dataBlock = JS.slice(JS.indexOf('data: {'), JS.indexOf('onLoad('))
    expect(dataBlock).toContain('topStore:')
    expect(WXML).toContain('topStore.name')
  })

  it('门店行插在「类型」之后、「服务设施」之前', () => {
    const iType = WXML.indexOf('product.typeName')
    const iStore = WXML.indexOf('class="val top-store"')
    const iSvc = WXML.indexOf('storeServices.length')
    expect(iType).toBeGreaterThan(-1)
    expect(iStore).toBeGreaterThan(iType)
    expect(iSvc).toBeGreaterThan(iStore)
  })

  it('距离+星级走 utils/storeView.js，不能在页面里再算一遍', () => {
    // 首页与详情页各算一遍会漂移（1.2km vs 1200m），而漂了不报错
    expect(JS).toContain('utils/storeView.js')
    expect(JS).toContain('toStoreView(cur,')
    expect(JS).not.toContain('haversineKm')
  })

  it('星级未填时整块不渲染（五颗灰星会被当成差评）', () => {
    expect(WXML).toContain('wx:if="{{topStore.hasRating}}"')
  })

  it('没位置时给可点的「查看距离」，不能写“计算中…”', () => {
    // 首页踩过的坑：未授权时 formatDistance 恒返 ''，
    // 写 `|| '计算中…'` 就永久卡在那儿（因为它不会主动取位）
    expect(WXML).toContain('catchtap="requestDistance"')
    // 剔掉注释后再扫：注释里写的是“不能写成计算中…”的缘由，不是违规
    const wxmlNoComment = WXML.replace(/<!--[\s\S]*?-->/g, '')
    expect(wxmlNoComment).not.toContain('计算中…')
    expect(JS).toContain('requestDistance()')
    // 必须 gcj02：门店经纬度是腾讯地图选点存的，坐标系不一致同城会偏 300~600m
    const i = JS.indexOf('requestDistance()')
    expect(JS.slice(i, i + 900)).toContain('gcj02')
  })

  it('不用后端 storeNameMain 当顶部门店名（那是商品主门店，多店下不是顾客周边那家）', () => {
    const i = WXML.indexOf('class="val top-store"')
    const seg = WXML.slice(i, i + 900)
    expect(seg).not.toContain('storeNameMain')
  })
})
