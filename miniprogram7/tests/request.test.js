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

  it('http(s):// 绝对地址 → 原样返回（不拼 baseUrl）', () => {
    expect(toFullUrl('https://example.com/a.jpg')).toBe('https://example.com/a.jpg')
    expect(toFullUrl('http://cdn.example.com/b.png')).toBe('http://cdn.example.com/b.png')
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
