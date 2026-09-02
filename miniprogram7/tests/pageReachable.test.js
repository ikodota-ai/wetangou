// tests/pageReachable.test.js
//
// 锁「商家端每个注册进 app.json 的页面都至少有一处能跳到它」。
//
// 为什么需要：pages/merchant/product/list 曾经是个零入口死页 ——
// app.json 注册了、页面本身写全了（三个状态 tab、上下架、改库存、编辑），
// 但整个小程序没有任何一处 navigateTo 它。首页只有「创建商品」直接进建品页，
// 而新建的商品一律落草稿，上架按钮只在列表页上；建品页存完草稿弹的提示是
// 「可在商品列表中上架」然后 navigateBack 退回首页 —— 提示指向了一个用户
// 根本到不了的页面，草稿建出来就永远上不了架。
// pages/merchant/poster-invite 也踩过同一个坑（那次是连 app.json 都没注册）。
//
// 这类缺陷编译器和 lint 都发现不了：文件语法全对、后端接口全通、
// smoke 直接打 API 也全绿，只有真人在手机上点才会发现「点不到」。
import { describe, it, expect } from 'vitest'
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '..')

function readJSON(p) { return JSON.parse(fs.readFileSync(p, 'utf8')) }

/** 收集所有 js/wxml 源码文本（不含 tests 和 node_modules） */
function collectSources() {
  const out = []
  const walk = (dir, exts) => {
    for (const name of fs.readdirSync(dir)) {
      if (name === 'node_modules' || name === 'tests' || name === 'target' || name.startsWith('.')) continue
      const full = path.join(dir, name)
      let st
      try { st = fs.statSync(full) } catch (e) { continue }
      if (st.isDirectory()) walk(full, exts)
      else if (exts.test(name)) out.push({ file: full, text: fs.readFileSync(full, 'utf8') })
    }
  }
  walk(ROOT, /\.(js|wxml)$/)
  // 后端也算入口来源：员工入职页 pages/merchant/scan 是靠小程序码的 page 参数直达的
  // （wxMaService.getWxaCodeUnlimited(scene, "pages/merchant/scan/index", ...)），
  // 按已定决策它不该有小程序内入口 —— 只能从微信「扫一扫」进。只扫前端会误判成死页。
  const backend = path.join(ROOT, '..', 'ruoyi-admin', 'src', 'main', 'java')
  if (fs.existsSync(backend)) walk(backend, /\.java$/)
  return out
}

describe('商家端页面可达性', () => {
  const app = readJSON(path.join(ROOT, 'app.json'))
  const sources = collectSources()

  // tabBar 页面天生可达（底部导航直接点），登录页由未登录跳转兜底
  const tabPages = ((app.tabBar && app.tabBar.list) || []).map(x => x.pagePath)
  const SELF_REACHABLE = new Set([...tabPages, 'pages/merchant/login/index'])

  const merchantPages = (app.pages || []).filter(p => p.indexOf('pages/merchant/') === 0)

  it('app.json 里确实注册了商家端页面（防这个测试因取不到数据而空跑）', () => {
    expect(merchantPages.length).toBeGreaterThan(5)
  })

  for (const page of merchantPages) {
    if (SELF_REACHABLE.has(page)) continue
    it(`${page} 至少有一处跳转引用（不是死页）`, () => {
      const refs = sources.filter(s =>
        // 排除页面自己的文件：自引用不算入口
        s.file.indexOf(path.join(ROOT, page.replace(/\/index$/, ''))) !== 0 &&
        // 前端写 '/pages/xxx'（带前导斜杠），后端小程序码的 page 参数写 'pages/xxx'（不带）
        (s.text.indexOf('/' + page) > -1 || s.text.indexOf('"' + page + '"') > -1)
      )
      expect(refs.length, `${page} 没有任何地方跳转过去，用户点不到`).toBeGreaterThan(0)
    })
  }

  // 首页和「我的」各锁一遍，不能用 or 合起来判：合并后只要有一处还在，
  // 另一处被删掉也发现不了（写的时候真踩过 —— 删了首页入口测试照样绿）。
  // 首页是店长每天进的第一屏，是上架路径的主入口，不能只剩「我的」里藏着一个。
  for (const page of ['home', 'me']) {
    it(`${page} 页必须有商品管理入口（上架按钮只在商品列表页上）`, () => {
      const text = ['index.wxml', 'index.js']
        .map(f => fs.readFileSync(path.join(ROOT, 'pages/merchant/' + page, f), 'utf8')).join('\n')
      expect(text).toContain('/pages/merchant/product/list/index')
    })
  }
})
