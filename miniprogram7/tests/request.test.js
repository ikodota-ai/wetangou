// tests/request.test.js
// 测 url 拼接的纯函数（避免后端返回 /dev-api 前缀时拼接出错的 regression）
import { describe, it, expect } from 'vitest'

// 关键：toFullUrl 内部 require './config.js'，config 里有 baseUrl
// 测试运行时 baseUrl 是 http://192.168.1.136:8080（你刚改的）
const { toFullUrl } = require('../utils/request.js')

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
