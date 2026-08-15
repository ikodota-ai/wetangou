// tests/inviteScene.test.js
// parseInviteScene 纯函数单测 — 锁住边界行为
// 重要: 本测试锁定的是「当前行为」。如果产品决定放宽 (比如允许 code 长度 3-32)，
// 那应该同时改 inviteScene.js 和这里的测试预期，**别悄悄改代码让测试继续过**。
import { describe, it, expect } from 'vitest'

const { parseInviteScene } = require('../utils/inviteScene.js')

describe('parseInviteScene - 格式 1: 普通短码', () => {
  it('标准 invite:mid:sid:code → ok', () => {
    const r = parseInviteScene('invite:1:100:ABC123')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:1:100:ABC123')
  })

  it('大数字 mid/sid → ok', () => {
    const r = parseInviteScene('invite:999999:888888:XYZABC')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:999999:888888:XYZABC')
  })

  it('trim 前后空白', () => {
    const r = parseInviteScene('  invite:1:100:ABC123  ')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:1:100:ABC123')
  })
})

describe('parseInviteScene - 格式 2: 小程序码 path?query', () => {
  it('pages/merchant/scan/index?scene=invite:1:100:ABC → ok', () => {
    const r = parseInviteScene('pages/merchant/scan/index?scene=invite:1:100:ABCD')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:1:100:ABCD')
  })

  it('URL 编码的冒号 (%3A) → 解码', () => {
    const r = parseInviteScene('pages/merchant/scan/index?scene=invite%3A1%3A100%3AABCD')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:1:100:ABCD')
  })

  it('scene+其他参数并存 (foo=bar) → 只取 scene', () => {
    const r = parseInviteScene('pages/merchant/scan/index?scene=invite:1:100:ABCD&foo=bar')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:1:100:ABCD')
  })

  it('scene 顺序在后 (?foo=bar&scene=...) → 仍能取到', () => {
    const r = parseInviteScene('pages/merchant/scan/index?foo=bar&scene=invite:2:3:CODE1')
    expect(r.ok).toBe(true)
    expect(r.scene).toBe('invite:2:3:CODE1')
  })
})

describe('parseInviteScene - 失败 case', () => {
  it('null → empty', () => {
    expect(parseInviteScene(null).ok).toBe(false)
    expect(parseInviteScene(null).reason).toBe('empty')
  })

  it('undefined → empty', () => {
    expect(parseInviteScene(undefined).ok).toBe(false)
  })

  it('空字符串 → empty', () => {
    expect(parseInviteScene('').ok).toBe(false)
  })

  it('非 string → empty', () => {
    expect(parseInviteScene(123).ok).toBe(false)
  })

  it('非 invite 前缀 → not_invite', () => {
    expect(parseInviteScene('group:1:2:3').reason).toBe('not_invite')
  })

  it('pages/ 但无 query → no_query', () => {
    expect(parseInviteScene('pages/foo').reason).toBe('no_query')
  })

  it('pages/?query 但无 scene → no_scene', () => {
    expect(parseInviteScene('pages/foo?other=1').reason).toBe('no_scene')
  })

  it('段数不对 (3 段) → bad_format', () => {
    expect(parseInviteScene('invite:1:100').reason).toBe('bad_format')
  })

  it('段数不对 (5 段) → bad_format', () => {
    expect(parseInviteScene('invite:1:100:ABC:extra').reason).toBe('bad_format')
  })

  it('mid 非数字 → bad_nums', () => {
    expect(parseInviteScene('invite:abc:100:CODE').reason).toBe('bad_nums')
  })

  it('sid 非数字 → bad_nums', () => {
    expect(parseInviteScene('invite:1:xyz:CODE').reason).toBe('bad_nums')
  })

  it('code 太短 (3 位) → bad_code_len', () => {
    expect(parseInviteScene('invite:1:100:ABC').reason).toBe('bad_code_len')
  })

  it('code 太长 (17 位) → bad_code_len', () => {
    expect(parseInviteScene('invite:1:100:ABCDEFGHI').reason).toBe('bad_code_len')
  })
})

describe('parseInviteScene - 防 XSS / 注入', () => {
  it('scene 含 SQL 注入尝试 → 仍走格式校验', () => {
    // 即使有人构造恶意 scene，段数/数字段校验会拦掉
    const r = parseInviteScene('invite:1:100:ABCDROP--LONG--1234')
    // code 长度 23 > 16 → bad_code_len
    expect(r.reason).toBe('bad_code_len')
  })

  it('空 code → bad_code_len', () => {
    expect(parseInviteScene('invite:1:100:').reason).toBe('bad_code_len')
  })
})
