// tests/merchantProductExtFormat.test.js
//
// 商家端建品页的日期/时间格式换算。
//
// 为什么必需：这一层踩过两个真实的 500，且两个方向都会错。
//
// 1) 提交方向：ProductExt.consumeStartDate 是 java.util.Date 且没加 @JsonFormat，
//    只认全局的 yyyy-MM-dd HH:mm:ss。PC 的 el-date-picker 就是
//    value-format="yyyy-MM-dd HH:mm:ss" 所以一直没事；小程序
//    <picker mode="date"> 只给 yyyy-MM-dd，直传实测报 500 Unparseable date。
// 2) 回填方向：后端下发 '2026-09-10 00:00:00'，直塞 picker 会显空 ——
//    商家打开一个已设过日期的商品只看到占位符，以为没保存成功。
//
// 两个方向都是「无报错的静默错」或「只在真机才现形」，只能靠单测盯。
import { describe, it, expect, vi } from 'vitest'
import fs from 'fs'
import path from 'path'

const SRC = path.resolve(__dirname, '../pages/merchant/product/create/index.js')

/** 载入建品页，取到 Page 定义（页面依赖 Page()/wx 全局，没桩 require 会直接抛） */
function loadPage() {
  let def = null
  const wxStub = {
    showToast: () => {}, showLoading: () => {}, hideLoading: () => {},
    showModal: () => {}, navigateTo: () => {}, navigateBack: () => {},
    redirectTo: () => {}, reLaunch: () => {},
    getStorageSync: () => '', setStorageSync: () => {},
    setNavigationBarTitle: () => {}, createSelectorQuery: () => ({
      selectAll: () => ({ boundingClientRect: () => ({ exec: () => {} }) }),
      select: () => ({ boundingClientRect: () => ({ exec: () => {} }) })
    })
  }
  const requireStub = (id) => {
    if (id.indexOf('request.js') >= 0) return { api: {} }
    if (id.indexOf('productPreview.js') >= 0) return { draftToProduct: () => ({}) }
    if (id.indexOf('pickRule.js') >= 0) return { customerPickText: () => '' }
    if (id.indexOf('identity.js') >= 0) return {}
    if (id.indexOf('role.js') >= 0) return {}
    return {}
  }
  const src = fs.readFileSync(SRC, 'utf8')
  // eslint-disable-next-line no-new-func
  new Function('require', 'Page', 'wx', 'getApp', 'console', 'setTimeout', src)(
    requireStub, (d) => { def = d }, wxStub, () => ({ globalData: {} }),
    { log: () => {}, warn: () => {}, error: () => {} }, (fn) => fn
  )
  return def
}

const page = loadPage()

describe('_toDateTime：picker 的 yyyy-MM-dd 补成后端认的格式', () => {
  it('开始日期补 00:00:00，结束日期补 23:59:59（否则最后一天等于不能用）', () => {
    expect(page._toDateTime('2026-09-10', '00:00:00')).toBe('2026-09-10 00:00:00')
    expect(page._toDateTime('2026-12-31', '23:59:59')).toBe('2026-12-31 23:59:59')
  })

  it('已带时分秒的不重复拼（编辑态从库里回填回来的就带）', () => {
    expect(page._toDateTime('2026-09-10 08:30:00', '00:00:00')).toBe('2026-09-10 08:30:00')
  })

  it('空值不能拼成 " 00:00:00"：后端会当非法日期直接 500', () => {
    expect(page._toDateTime('', '00:00:00')).toBe('')
    expect(page._toDateTime(null, '00:00:00')).toBe('')
  })
})

describe('_toTime：daily_time 是 time 类型，PC 传 HH:mm:ss', () => {
  it('HH:mm 补秒', () => {
    expect(page._toTime('09:00')).toBe('09:00:00')
    expect(page._toTime('22:30')).toBe('22:30:00')
  })

  it('已带秒的不再补', () => {
    expect(page._toTime('09:00:00')).toBe('09:00:00')
  })

  it('空值 → 空串', () => {
    expect(page._toTime('')).toBe('')
  })
})

describe('_toDateOnly：回填时把 datetime 剔回 picker 认的 yyyy-MM-dd', () => {
  it('带时分秒的截前 10 位（不截 picker 直接显空）', () => {
    expect(page._toDateOnly('2026-09-10 00:00:00')).toBe('2026-09-10')
  })

  it('本来就是纯日期的原样返', () => {
    expect(page._toDateOnly('2026-09-10')).toBe('2026-09-10')
  })

  it('空 / 脉数据 → 空串（不能把垃圾塞进 picker）', () => {
    expect(page._toDateOnly('')).toBe('')
    expect(page._toDateOnly(null)).toBe('')
  })
})

describe('_pickExclude：exclude_dates 存的是 [[起,止]] JSON', () => {
  it('取第一段的起 / 止', () => {
    const json = JSON.stringify([['2026-10-01', '2026-10-07']])
    expect(page._pickExclude(json, 0)).toBe('2026-10-01')
    expect(page._pickExclude(json, 1)).toBe('2026-10-07')
  })

  it('脉 JSON 当空处理：不能因为一条坏数据就打不开编辑页', () => {
    expect(page._pickExclude('{不是json', 0)).toBe('')
    expect(page._pickExclude('[]', 0)).toBe('')
    expect(page._pickExclude('[["只有一个"]]', 0)).toBe('')
    expect(page._pickExclude('', 0)).toBe('')
  })
})

describe('_hhmm：time 类型回填到 picker mode=time', () => {
  it('HH:mm:ss 剔掉秒（带秒 picker 会显空）', () => {
    expect(page._hhmm('09:00:00')).toBe('09:00')
  })

  it('单位数小时补 0（picker 认 HH:mm 两位）', () => {
    expect(page._hhmm('9:05')).toBe('09:05')
  })

  it('空 → 空串', () => {
    expect(page._hhmm('')).toBe('')
  })
})
