// tests/role.test.js
// 5 角色工具单测（v2.5 V5-4）
// 锁定 getMember/getRoles/isOwner/isManagerOrAbove 等纯函数行为
import { describe, it, expect, beforeEach, vi } from 'vitest'

// 模拟 wx 存储
const _store = {}
global.wx = {
  getStorageSync: (k) => _store[k],
  setStorageSync: (k, v) => { _store[k] = v }
}

// 模拟 getApp
const _app = { globalData: {} }
global.getApp = () => _app

const role = require('../utils/role.js')

describe('role.isPlatform', () => {
  beforeEach(() => {
    _store.member = null
    _app.globalData = {}
  })

  it('空 member → false', () => {
    expect(role.isPlatform()).toBe(false)
    expect(role.isAgent()).toBe(false)
    expect(role.isOwner()).toBe(false)
    expect(role.isManager()).toBe(false)
    expect(role.isStaff()).toBe(false)
  })

  it('PLATFORM 角色 → isPlatform true', () => {
    _store.member = { userType: 'platform', roles: ['PLATFORM'] }
    expect(role.isPlatform()).toBe(true)
    expect(role.isAgent()).toBe(false)
  })

  it('AGENT 角色 → isAgent true', () => {
    _store.member = { userType: 'agent', roles: ['AGENT'] }
    expect(role.isAgent()).toBe(true)
    expect(role.isManagerOrAbove()).toBe(false)
  })

  it('OWNER 角色 → isManagerOrAbove true（包含 OWNER）', () => {
    _store.member = { userType: 'owner', roles: ['OWNER'] }
    expect(role.isOwner()).toBe(true)
    expect(role.isManagerOrAbove()).toBe(true)
  })

  it('MANAGER 角色 → isManagerOrAbove true', () => {
    _store.member = { userType: 'manager', roles: ['MANAGER'] }
    expect(role.isManager()).toBe(true)
    expect(role.isManagerOrAbove()).toBe(true)
  })

  it('STAFF 角色 → isManagerOrAbove false', () => {
    _store.member = { userType: 'staff', roles: ['STAFF'] }
    expect(role.isStaff()).toBe(true)
    expect(role.isManagerOrAbove()).toBe(false)
  })

  it('平台超管 + OWNER 角色叠加（user_type=00 但有商家身份）', () => {
    _store.member = { userType: 'platform', roles: ['PLATFORM', 'OWNER'] }
    expect(role.isPlatform()).toBe(true)
    expect(role.isOwner()).toBe(true)
    expect(role.isManagerOrAbove()).toBe(true)
  })
})

describe('role.getUserType', () => {
  beforeEach(() => { _store.member = null })
  it('从 member.userType 读', () => {
    _store.member = { userType: 'agent' }
    expect(role.getUserType()).toBe('agent')
  })
  it('无 member → 空串', () => {
    expect(role.getUserType()).toBe('')
  })
})

describe('role.isMerchantSide', () => {
  beforeEach(() => { _store.member = null })
  it('OWNER → true', () => {
    _store.member = { roles: ['OWNER'] }
    expect(role.isMerchantSide()).toBe(true)
  })
  it('MANAGER → true', () => {
    _store.member = { roles: ['MANAGER'] }
    expect(role.isMerchantSide()).toBe(true)
  })
  it('STAFF → true', () => {
    _store.member = { roles: ['STAFF'] }
    expect(role.isMerchantSide()).toBe(true)
  })
  it('AGENT only → false', () => {
    _store.member = { roles: ['AGENT'] }
    expect(role.isMerchantSide()).toBe(false)
  })
  it('PLATFORM only → false', () => {
    _store.member = { roles: ['PLATFORM'] }
    expect(role.isMerchantSide()).toBe(false)
  })
})
