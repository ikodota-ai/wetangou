// tests/request.test.js
// 测 url 拼接的纯函数（避免后端返回 /dev-api 前缀时拼接出错的 regression）
import { describe, it, expect } from 'vitest'

// 关键：toFullUrl 内部 require './config.js'，config 里有 baseUrl
// 测试运行时 baseUrl 是 http://192.168.1.136:8080（你刚改的）
const { toFullUrl, fixRichText } = require('../utils/request.js')

describe('toFullUrl', () => {
  it('空 / null / undefined → 空字符串', () => {
    expect(toFullUrl(null)).toBe('')
    expect(toFullUrl(undefined)).toBe('')
    expect(toFullUrl('')).toBe('')
  })

  it('http(s):// 外部绝对地址 → 原样返回（不拼 baseUrl）', () => {
    expect(toFullUrl('https://example.com/a.jpg')).toBe('https://example.com/a.jpg')
    expect(toFullUrl('http://cdn.example.com/b.png')).toBe('http://cdn.example.com/b.png')
  })

  it('外部图床 / 微信 CDN 不能被改写', () => {
    // 这两类地址去掉 host 就彻底废了，必须原样保留
    expect(toFullUrl('https://thirdwx.qlogo.cn/mmopen/xxx/132')).toBe('https://thirdwx.qlogo.cn/mmopen/xxx/132')
    expect(toFullUrl('https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/x.png'))
      .toBe('https://wetuango.oss-cn-shenzhen.aliyuncs.com/2026/x.png')
  })

  it('历史脏数据：带内网 host 的 /profile/ 地址 → 换成当前 baseUrl', () => {
    // 早期 ApiMemberController.uploadAvatar 把 serverConfig.getUrl() 拼进库了，
    // 存量记录形如 http://172.31.26.216:8080/profile/avatar/...
    // 换台设备必然打不开，而且 <image> 不支持 http。
    // 认出 /profile/ 前缀就丢掉原 host 重拼 —— 这是「昵称能读出来、头像读不出来」的修复。
    const r1 = toFullUrl('http://172.31.26.216:8080/profile/avatar/2026/08/08/b.jpg')
    expect(r1).not.toContain('172.31.26.216')
    expect(r1).toMatch(/\/profile\/avatar\/2026\/08\/08\/b\.jpg$/)

    const r2 = toFullUrl('http://127.0.0.1:8080/profile/avatar/c.jpeg')
    expect(r2).not.toContain('127.0.0.1')
    expect(r2).toMatch(/\/profile\/avatar\/c\.jpeg$/)
  })

  it('绝对地址里没有 /profile/ 的不动（无法判断归属）', () => {
    expect(toFullUrl('http://x/a.png')).toBe('http://x/a.png')
  })

  it('/path 相对地址 → 拼 baseUrl', () => {
    expect(toFullUrl('/api/store/list')).toMatch(/^https?:\/\/.+\/api\/store\/list$/)
    expect(toFullUrl('/assets/img/RestaurantImg.png')).toMatch(/RestaurantImg\.png$/)
  })

  it('去掉 /dev-api 前缀（ruoyi-ui nginx 用）', () => {
    // 之前 ify 开发环境会返 /dev-api 前缀，这里要剥掉再拼 baseUrl
    const result = toFullUrl('/dev-api/api/order/list')
    expect(result).not.toContain('/dev-api')
    expect(result).toMatch(/\/api\/order\/list$/)
  })

  it('去掉空白字符', () => {
    expect(toFullUrl('  /api/x  ')).toMatch(/\/api\/x$/)
  })

  it('不带 / 开头的相对路径 → 自动加 /', () => {
    expect(toFullUrl('api/store/nearest')).toMatch(/\/api\/store\/nearest$/)
  })
})

// 为什么锁 fixRichText 的宽度注入：
// <rich-text> 内部节点拿不到外部 WXSS 的 class（小程序官方限制），
// 给嬿主元素加 .rich-detail{overflow-x:auto} 也没用 —— rich-text 不是
// scroll-view，不会出滚动条，内容直接把卡片横向撑破。
// 后台富文本用 quill，insertEmbed 吐的 <img> 不带任何 width/style，
// 而手机拍的图三四千像素宽 —— 运营一插图整页必然溢出。
// 四个页面共用这一个函数：商品详情 detail / notice、用户协议、隐私协议。
describe('fixRichText 宽度约束（rich-text 内部只认 inline style）', () => {
  it('img 没写 style 时注入 max-width，否则按原始像素撑破页面', () => {
    const out = fixRichText('<p>x</p><img src="/profile/a.png">')
    expect(out).toContain('max-width:100%')
    expect(out).toContain('height:auto')
  })

  it('运营自己写过 style 的不覆盖', () => {
    const out = fixRichText('<img style="width:50px" src="/profile/a.png">')
    expect(out).toContain('width:50px')
    expect(out.match(/style=/g).length).toBe(1)
  })

  it('table 也要约束（商品 2000 的 detail 就是个无 width 的 12行34格表）', () => {
    const out = fixRichText('<table><tr><td>a</td></tr></table>')
    expect(out).toContain('table-layout:fixed')
    expect(out).toContain('max-width:100%')
  })

  it('注入不能弄丢内容或改变结构', () => {
    const html = '<table><tbody><tr><td>山茶菌</td><td>1</td><td>¥48.00</td></tr></tbody></table>'
    const out = fixRichText(html)
    expect(out).toContain('山茶菌')
    expect(out).toContain('¥48.00')
    expect((out.match(/<td/g) || []).length).toBe(3)
  })

  it('空值仍返空串（详情页靠它隐掉整张卡）', () => {
    expect(fixRichText('')).toBe('')
    expect(fixRichText(null)).toBe('')
    expect(fixRichText(undefined)).toBe('')
  })

  it('img 地址补全仍然生效（原有行为不能回退）', () => {
    const out = fixRichText('<img src="/profile/a.png">')
    expect(out).toContain(toFullUrl('/profile/a.png'))
  })
})
