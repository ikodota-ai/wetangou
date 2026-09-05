// tests/productCreateAdv.test.js
//
// PC 建品页「交易规则开关渐进」的静态契约。
//
// 为何需要它：这一块的真正风险不在“开关能不能点”，而在
// “关掉开关后值还在 form 里、packFormToExt 仍把它落进 ext”——
// 运营以为取消了限制，顾客详情页继续显着那条限制，
// 这是「界面说没有、库里说有」的隐性脏数据，浏览器不报错、后端 200。
//
// 项目里没有 Vue 组件测试环境（无 @vue/test-utils），lint-vue-sfc.sh 又只查
// :model 绑的对象有没在 data 声明 —— 两道门都盖不住这个联动，
// 所以用文本契约锁住关键结构。
import { describe, it, expect } from 'vitest'
import fs from 'fs'
import path from 'path'

const SFC = fs.readFileSync(
  path.resolve(__dirname, '../../ruoyi-ui/src/views/biz/product/create.vue'), 'utf8')
const TPL = SFC.slice(0, SFC.indexOf('<script>'))
const JS = SFC.slice(SFC.indexOf('<script>'))

// 方案 doc/商品字段缺口与抖音来客对齐方案-2026-08-27.md P2-1 明写的四个字段。
// 少做一个都不行：codeType 最容易被漏（全库 525 条全是 MERCHANT，
// 两个单选常驻并列只会让运营误选平台券然后到店核不了）。
const ADV_KEYS = ['consumeDate', 'excludeDate', 'dailyTime', 'codeType']

describe('P2-1 四个字段全部改成开关渐进', () => {
  it('data 里声明了 adv 容器，且包含四个 key', () => {
    const m = JS.match(/adv:\s*\{([^}]*)\}/)
    expect(m, 'data 必须有 adv 容器，否则模板读 adv.xxx 会 undefined').not.toBeNull()
    ADV_KEYS.forEach(k => {
      expect(m[1], 'adv 必须有 ' + k).toContain(k)
    })
  })

  it('每个开关都绑了 onToggleAdv（不能只绑 v-model 不清值）', () => {
    ADV_KEYS.forEach(k => {
      expect(TPL, k + ' 必须有 el-switch 绑 adv.' + k)
        .toContain('v-model="adv.' + k + '"')
      expect(TPL, k + ' 必须 @change 调 onToggleAdv')
        .toContain("onToggleAdv('" + k + "', $event)")
    })
  })

  it('三个日期字段默认收起：picker 包在 v-if="adv.xxx" 里', () => {
    ;['consumeDate', 'excludeDate', 'dailyTime'].forEach(k => {
      expect(TPL, k + ' 的细则必须条件渲染').toContain('v-if="adv.' + k + '"')
    })
  })

  it('关闭开关时必须清空对应 form 字段（否则仍会落库）', () => {
    const i = JS.indexOf('onToggleAdv(key, val)')
    expect(i, '必须有 onToggleAdv 方法').toBeGreaterThan(-1)
    const body = JS.slice(i, i + 900)
    expect(body).toContain('consumeDateRange')
    expect(body).toContain('excludeDateRange')
    expect(body).toContain('dailyTimeRange')
    // 清空动作本体
    expect(body).toMatch(/\$set\(this\.form,\s*f,\s*\[\]\)/)
  })

  it('codeType 是枚举不是数组：开关直接映射 PLATFORM / MERCHANT', () => {
    const i = JS.indexOf('onToggleAdv(key, val)')
    const body = JS.slice(i, i + 900)
    expect(body).toContain('PLATFORM')
    expect(body).toContain('MERCHANT')
    // 不能把 codeType 当数组清成 []（那会落一个空串进 ext.code_type）
    expect(body).toMatch(/key === 'codeType'/)
  })

  it('编辑态回填：库里有值 → 开关自动打开', () => {
    // 否则编辑一个已配了限制的老商品会看到开关全关，一保存就把限制清掉。
    const i = JS.indexOf('unpackExtToForm(p) {')
    expect(i).toBeGreaterThan(-1)
    const body = JS.slice(i, i + 2200)
    ADV_KEYS.forEach(k => {
      expect(body, 'unpackExtToForm 必须回填 adv.' + k)
        .toContain("this.adv, '" + k + "'")
    })
    expect(body, 'codeType 开关按 PLATFORM 判定').toContain("=== 'PLATFORM'")
  })
})

describe('P1-1 consumeStartToday 在 PC 端真有输入框且会落主表', () => {
  it('form 初值有 consumeStartToday，默认 1（与建表 DEFAULT 一致）', () => {
    expect(JS).toMatch(/consumeStartToday:\s*1/)
  })

  it('模板里有对应单选（1=当天 / 0=次日）', () => {
    expect(TPL).toContain('form.consumeStartToday')
    expect(TPL).toMatch(/:label="1"/)
    expect(TPL).toMatch(/:label="0"/)
  })

  it('它是主表字段，不能被 packFormToExt 的 delete 列表干掉', () => {
    const i = JS.indexOf('packFormToExt(payload)')
    const body = JS.slice(i, i + 3000)
    const del = body.slice(body.indexOf('forEach(k => { delete payload[k] })') - 400,
      body.indexOf('forEach(k => { delete payload[k] })'))
    expect(del).not.toContain('consumeStartToday')
  })

  it('unpackExtToForm 回填它，null 当 1', () => {
    const i = JS.indexOf('unpackExtToForm(p) {')
    const body = JS.slice(i, i + 2200)
    expect(body).toContain('consumeStartToday')
    expect(body).toMatch(/==\s*null\s*\?\s*1/)
  })
})

// P2-1 第 2 条：「每个字段下方补一行次级说明（抖音每项都有，我们一个都没有）」
describe('P2-1 字段级说明覆盖', () => {
  // 自解释字段（所属商家/品类/类型/组名称/排序…）不强求说明，
  // 但下面这批是运营真会填错口径的，必须有说明。
  const NEED_TIP = [
    '市场价', '库存', '副标题', '项目补充说明',
    '职人带货', '商品售卖日期', '商家平台子品ID',
    '券类型', '适用规则',
    '限购规则', '售后政策', '预约规则',
    '店内其他优惠', '额外费用', '使用张数限制',
    '使用人数限制', '适用范围', '其他说明信息'
  ]

  it('关键字段全部带 dyl-tip 次级说明', () => {
    const segs = TPL.split('<el-form-item')
    const byLabel = {}
    segs.slice(1).forEach(p => {
      const m = p.slice(0, 300).match(/label="([^"]+)"/)
      if (!m) return
      const seg = p.split('</el-form-item>')[0]
      // 同名 label 多处（如库存/售卖日期各两处），要求全部都有
      byLabel[m[1]] = (byLabel[m[1]] !== false) && seg.indexOf('dyl-tip') >= 0
      if (seg.indexOf('dyl-tip') < 0) byLabel[m[1]] = false
    })
    const missing = NEED_TIP.filter(l => byLabel[l] !== true)
    expect(missing, '这些字段缺次级说明').toEqual([])
  })
})
