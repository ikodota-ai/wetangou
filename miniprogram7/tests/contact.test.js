import { describe, it, expect } from 'vitest'
const { resolveContact, firstFilled } = require('../utils/contact.js')

// 真实数据形态：门店未填字段后端返 ''，商家未填返 null，两种都要挡住
const STORE_FULL = { phone: '0755-88888888', servicePhone: '0755-11111111', serviceQrcode: '/s.jpg', serviceHours: '10:00-20:00' }
const STORE_EMPTY = { phone: '', servicePhone: '', serviceQrcode: '', serviceHours: '' }
const MERCHANT = { phone: '13900000022', servicePhone: '400-888-8888', serviceQrcode: '/m.jpg', serviceHours: '09:00-22:00（人工客服）', businessHours: '09:00-22:00' }

describe('firstFilled', () => {
  it('跳过 null/undefined/空串/纯空格', () => {
    expect(firstFilled(null, undefined, '', '   ', 'x')).toBe('x')
  })
  it('全空返空串', () => {
    expect(firstFilled(null, '', '  ')).toBe('')
  })
  it('去掉首尾空格', () => {
    expect(firstFilled('  400-1  ')).toBe('400-1')
  })
})

describe('1. 拨打电话：门店电话优先，商家电话兜底', () => {
  it('门店有电话用门店的', () => {
    expect(resolveContact(STORE_FULL, MERCHANT).callPhone).toBe('0755-88888888')
  })
  it('门店空则降到商家电话（不是商家客服热线）', () => {
    expect(resolveContact(STORE_EMPTY, MERCHANT).callPhone).toBe('13900000022')
  })
  it('门店只填了客服电话时也拿来用，好过提示暂无', () => {
    expect(resolveContact({ phone: '', servicePhone: '0755-2222' }, MERCHANT).callPhone).toBe('0755-2222')
  })
  it('商家只有客服热线时垫底', () => {
    expect(resolveContact(STORE_EMPTY, { phone: null, servicePhone: '400-9' }).callPhone).toBe('400-9')
  })
})

describe('2. 客服电话：门店客服优先，商家客服兜底', () => {
  it('门店有客服电话用门店的', () => {
    expect(resolveContact(STORE_FULL, MERCHANT).servicePhone).toBe('0755-11111111')
  })
  it('门店空则降到商家客服热线', () => {
    expect(resolveContact(STORE_EMPTY, MERCHANT).servicePhone).toBe('400-888-8888')
  })
  it('和 callPhone 是两条链，不能混', () => {
    const r = resolveContact(STORE_FULL, MERCHANT)
    expect(r.callPhone).not.toBe(r.servicePhone)
  })
})

describe('3. 客服二维码：门店优先，商家兜底', () => {
  it('门店有用门店的', () => {
    expect(resolveContact(STORE_FULL, MERCHANT).qrcode).toBe('/s.jpg')
  })
  it('门店空降到商家', () => {
    expect(resolveContact(STORE_EMPTY, MERCHANT).qrcode).toBe('/m.jpg')
  })
  it('两边都没有返空串（前端据此显示占位文案）', () => {
    expect(resolveContact(STORE_EMPTY, { serviceQrcode: null }).qrcode).toBe('')
  })
})

describe('4. 客服服务时间：门店 -> 商家客服时间 -> 商家营业时间', () => {
  it('门店有用门店的', () => {
    expect(resolveContact(STORE_FULL, MERCHANT).serviceHours).toBe('10:00-20:00')
  })
  it('门店空降到商家客服时间', () => {
    expect(resolveContact(STORE_EMPTY, MERCHANT).serviceHours).toBe('09:00-22:00（人工客服）')
  })
  it('商家客服时间也没有才退到营业时间（营业时间不等于客服时间，只能垫底）', () => {
    expect(resolveContact(STORE_EMPTY, { serviceHours: '', businessHours: '09:00-22:00' }).serviceHours).toBe('09:00-22:00')
  })
  it('全没有返空串，界面显示「请咨询门店」', () => {
    expect(resolveContact(STORE_EMPTY, {}).serviceHours).toBe('')
  })
})

describe('isStoreService 标记', () => {
  it('门店有任一客服项就算门店客服', () => {
    expect(resolveContact({ serviceHours: '10:00-20:00' }, MERCHANT).isStoreService).toBe(true)
  })
  it('降级到商家时不能误标成门店客服', () => {
    expect(resolveContact(STORE_EMPTY, MERCHANT).isStoreService).toBe(false)
  })
  it('门店只有座机不算门店客服（座机不是客服渠道）', () => {
    expect(resolveContact({ phone: '0755-8888' }, MERCHANT).isStoreService).toBe(false)
  })
})

describe('入参防御', () => {
  it('store 为 null 时走商家', () => {
    expect(resolveContact(null, MERCHANT).callPhone).toBe('13900000022')
  })
  it('两个都为 null 不抛异常', () => {
    expect(resolveContact(null, null)).toEqual({
      callPhone: '', servicePhone: '', qrcode: '', serviceHours: '', isStoreService: false
    })
  })
})
