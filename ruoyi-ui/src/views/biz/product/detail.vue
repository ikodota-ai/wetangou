<template>
  <div class="dyl-detail">
    <div class="dyl-header">
      <div class="dyl-header-main">
        <span class="dyl-title">{{ form.productName || '商品详情' }}</span>
        <el-tag :type="form.status === '0' ? 'success' : 'info'" size="small">
          {{ form.status === '0' ? '已上架' : '未上架' }}
        </el-tag>
        <el-tag type="warning" size="small" effect="plain">{{ typeName || form.typeCode || '未知类型' }}</el-tag>
      </div>
      <div>
        <el-button size="small" type="primary" icon="el-icon-edit"
                   v-hasPermi="['biz:product:edit']" @click="goEdit">编辑</el-button>
        <el-button size="small" @click="goBack">返回</el-button>
      </div>
    </div>
    <div class="dyl-header-sub">
      商品 ID {{ form.productId || '—' }}
      <span class="dyl-dot">·</span> 创建于 {{ form.createTime || '—' }}
      <template v-if="form.updateTime">
        <span class="dyl-dot">·</span> 最近修改 {{ form.updateTime }}
      </template>
    </div>

    <el-card class="dyl-card" shadow="never" v-loading="loading">
      <!-- 吸顶锚点导航：与编辑页同一套分组和顺序，运营在两页之间不用重新找位置 -->
      <div class="dyl-anchor-nav" ref="anchorNav">
        <div class="dyl-anchor-track">
          <div
            v-for="sec in visibleSections"
            :key="sec.name"
            class="dyl-anchor-item"
            :class="{ 'is-active': activeTab === sec.name }"
            @click="scrollToSection(sec.name)"
          >{{ sec.label }}</div>
        </div>
      </div>

      <!-- ============ 基础信息 ============ -->
      <section class="dyl-sec" :ref="'sec_basic'" data-sec="basic">
        <div class="dyl-sec-title">基础信息</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="商品名称" :span="2">{{ dash(form.productName) }}</el-descriptions-item>
          <el-descriptions-item label="商品品类">{{ dash(form.categoryName) }}</el-descriptions-item>
          <el-descriptions-item label="商品类型">{{ dash(typeName || form.typeCode) }}</el-descriptions-item>
          <el-descriptions-item label="商品发布细则">{{ dash(form.industryCode) }}</el-descriptions-item>
          <el-descriptions-item v-if="isVoucher" label="代金券面值">{{ money(form.faceValue) }}</el-descriptions-item>
          <el-descriptions-item label="副标题" :span="2">{{ dash(form.subtitle) }}</el-descriptions-item>
        </el-descriptions>
      </section>

      <!-- ============ 商家信息 / 商品类型（沿用编辑页的动态标题）============
           这一块所有类型都显示，不照抄编辑页的 isGroupon || isVoucher 限制：
           编辑页那样裁剪是因为 STORED_CARD / BOOKING 等走别的编辑表单，
           但「所属商家 / 适用门店」是通用信息，查看态漏掉它们
           会让 14 个储值卡/预约商品看不到自己配在哪些门店。 -->
      <section class="dyl-sec" :ref="'sec_merchant'" data-sec="merchant">
        <div class="dyl-sec-title">{{ merchantTabLabel }}</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="所属商家">{{ dash(merchantLabel) }}</el-descriptions-item>
          <el-descriptions-item label="收款方式">{{ collectMethodText }}</el-descriptions-item>
          <el-descriptions-item label="适用门店" :span="2">
            <template v-if="storeNameList.length">
              <el-tag v-for="s in storeNameList" :key="s" size="mini" class="dyl-tag">{{ s }}</el-tag>
            </template>
            <span v-else class="dyl-empty">未配置（顾客在任何门店都看不到该商品）</span>
          </el-descriptions-item>
        </el-descriptions>
      </section>

      <!-- ============ 商品资质（组合券包）============ -->
      <section v-if="isCombo" class="dyl-sec" :ref="'sec_qualify'" data-sec="qualify">
        <div class="dyl-sec-title">商品资质</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="券类型">{{ voucherTypeText }}</el-descriptions-item>
          <el-descriptions-item label="适用规则">
            <template v-if="voucherRuleList.length">
              <el-tag v-for="r in voucherRuleList" :key="r" size="mini" class="dyl-tag">{{ voucherRuleText(r) }}</el-tag>
            </template>
            <span v-else class="dyl-empty">未配置</span>
          </el-descriptions-item>
        </el-descriptions>
      </section>

      <!-- ============ 商品信息 ============ -->
      <section class="dyl-sec" :ref="'sec_product'" data-sec="product">
        <div class="dyl-sec-title">商品信息</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="售价">{{ money(form.price) }}</el-descriptions-item>
          <el-descriptions-item label="市场价">{{ money(form.marketPrice) }}</el-descriptions-item>
          <el-descriptions-item v-if="showFaceValue" label="面值">{{ money(form.faceValue) }}</el-descriptions-item>
          <el-descriptions-item v-if="showMinConsume" label="最低消费">{{ money(form.minConsume) }}</el-descriptions-item>
          <el-descriptions-item v-if="showTotalValue" label="券包总价值">{{ money(form.totalValue) }}</el-descriptions-item>
          <el-descriptions-item v-if="showTotalTimes" label="总次数">{{ dash(form.totalTimes) }}</el-descriptions-item>
          <el-descriptions-item label="库存">{{ stockText }}</el-descriptions-item>
          <el-descriptions-item label="已售">{{ form.sales || 0 }}</el-descriptions-item>
          <el-descriptions-item label="排序">{{ form.sort == null ? '—' : form.sort }}</el-descriptions-item>
          <el-descriptions-item label="项目补充说明" :span="2">
            <span class="dyl-pre">{{ dash(form.detail) }}</span>
          </el-descriptions-item>
        </el-descriptions>
        <div class="dyl-imgs">
          <div class="dyl-sub-label">商品头图</div>
          <template v-if="coverList.length">
            <el-image v-for="(u, i) in coverList" :key="'c' + i" :src="u"
                      :preview-src-list="coverList" fit="cover" class="dyl-img" />
          </template>
          <span v-else class="dyl-empty">未上传</span>
        </div>
        <div class="dyl-imgs" v-if="!isVoucher">
          <div class="dyl-sub-label">环境图</div>
          <template v-if="imageList.length">
            <el-image v-for="(u, i) in imageList" :key="'i' + i" :src="u"
                      :preview-src-list="imageList" fit="cover" class="dyl-img" />
          </template>
          <span v-else class="dyl-empty">未上传</span>
        </div>
      </section>

      <!-- ============ 商品搭配（团购 / 组合券包）============ -->
      <section v-if="isGroupon || isCombo" class="dyl-sec" :ref="'sec_subitem'" data-sec="subitem">
        <div class="dyl-sec-title">
          {{ isCombo ? '组合商品搭配' : '商品搭配' }}
          <span v-if="subitemGroups.length" class="dyl-sec-extra">
            共 {{ subitemTotal }} 个单品 · 顾客实际可享 {{ totalPickCount }} 个
          </span>
        </div>
        <div v-if="!subitemGroups.length" class="dyl-empty-box">未配置搭配</div>
        <div v-for="g in subitemGroups" :key="g.groupId" class="dyl-group">
          <div class="dyl-group-head">
            <span class="dyl-group-name">{{ g.groupName || '未命名分组' }}</span>
            <el-tag size="mini" :type="isPickAll(g) ? 'success' : 'warning'">{{ pickRuleText(g) }}</el-tag>
          </div>
          <el-table :data="g.subitems || []" size="mini" border>
            <el-table-column label="单品名称" prop="subitemName" show-overflow-tooltip />
            <el-table-column label="数量" prop="quantity" width="70" align="center" />
            <el-table-column label="单价" width="100" align="center">
              <template slot-scope="s">{{ money(s.row.price) }}</template>
            </el-table-column>
          </el-table>
        </div>
      </section>

      <!-- ============ 售卖信息 ============ -->
      <section class="dyl-sec" :ref="'sec_sale'" data-sec="sale">
        <div class="dyl-sec-title">售卖信息</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="商品售卖日期" :span="2">{{ rangeText(form.saleStartDate, form.saleEndDate, '长期售卖') }}</el-descriptions-item>
          <el-descriptions-item label="投放渠道" :span="2">
            <template v-if="channelTagList.length">
              <el-tag v-for="c in channelTagList" :key="c.code" size="mini" class="dyl-tag"
                      :type="c.stale ? 'danger' : ''">{{ c.name }}</el-tag>
            </template>
            <span v-else class="dyl-empty">未配置（不会在任何渠道曝光）</span>
          </el-descriptions-item>
          <el-descriptions-item label="职人带货">{{ boolText(ext.staffPromote, '允许', '不允许') }}</el-descriptions-item>
          <el-descriptions-item v-if="ext.outerSubitemId" label="商家平台子品ID">{{ dash(ext.outerSubitemId) }}</el-descriptions-item>
        </el-descriptions>
      </section>

      <!-- ============ 交易规则 ============ -->
      <section class="dyl-sec" :ref="'sec_trade'" data-sec="trade">
        <div class="dyl-sec-title">交易规则</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="限购规则">{{ form.limitPerUser ? '每人限购 ' + form.limitPerUser + ' 份' : '不限' }}</el-descriptions-item>
          <!-- 存量 refund_policy 有直接存中文长句的（如「未核销整单退；部分核销按比例退」），
               不是枚举，占满整行并允许换行，否则会被挤成一条看不全的窄格 -->
          <el-descriptions-item label="售后政策" :span="2">
            <span class="dyl-pre">{{ refundPolicyText }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="预约规则">{{ boolText(form.bookingRequired, '需要预约', '无需预约') }}</el-descriptions-item>
          <el-descriptions-item label="券码类型">{{ codeTypeText }}</el-descriptions-item>
          <el-descriptions-item label="有效期">{{ validityText }}</el-descriptions-item>
        </el-descriptions>
      </section>

      <!-- ============ 消费规则 ============ -->
      <!-- 同上：消费规则（可消费日期 / 时段 / 店内优惠）对所有类型都有意义，
           查看态不做类型裁剪，字段没值时各自显示占位而不是整块消失 -->
      <section class="dyl-sec" :ref="'sec_consume'" data-sec="consume">
        <div class="dyl-sec-title">消费规则</div>
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="店内其他优惠" :span="2">{{ mutexText }}</el-descriptions-item>
          <el-descriptions-item label="顾客可消费日期" :span="2">{{ rangeText(ext.consumeStartDate, ext.consumeEndDate, '按有效期') }}</el-descriptions-item>
          <el-descriptions-item label="顾客不可消费日期" :span="2">{{ excludeText }}</el-descriptions-item>
          <el-descriptions-item label="每日消费时段" :span="2">{{ dailyTimeText }}</el-descriptions-item>
          <el-descriptions-item label="额外费用">{{ dash(form.extraFeeDesc) }}</el-descriptions-item>
          <el-descriptions-item label="使用张数限制">{{ form.maxPerOrder ? '单次最多 ' + form.maxPerOrder + ' 张' : '—' }}</el-descriptions-item>
          <el-descriptions-item v-if="isGroupon" label="使用人数限制">{{ form.maxPersons ? '单次最多 ' + form.maxPersons + ' 人' : '—' }}</el-descriptions-item>
          <el-descriptions-item v-if="isVoucher" label="适用范围">{{ scopeTypeText }}</el-descriptions-item>
          <el-descriptions-item label="其他说明信息" :span="2">
            <span class="dyl-pre">{{ dash(form.notice) }}</span>
          </el-descriptions-item>
        </el-descriptions>
      </section>
    </el-card>
  </div>
</template>

<script>
import { getProduct } from '@/api/biz/product'
import { enabledSaleChannel } from '@/api/biz/saleChannel'
import { selectProductTypeList } from '@/api/biz/productType'
import { listMerchant } from '@/api/biz/merchant'
import { listGroups } from '@/api/biz/productSubitem'

// 文案与 create.vue 的选项一一对应（改一边必须改另一边，否则详情会显示原始 code）
const REFUND = { ANYTIME: '支持随时退', BEFORE_EXPIRE: '仅过期前可退', NONE: '不可退' }
const CODE_TYPE = { MERCHANT: '商家券（本商户自行核销）', PLATFORM: '平台券（平台统一发码）' }
const VOUCHER_TYPE = { GENERAL: '通兑券', CATEGORY: '单品类券' }
const SCOPE = { ALL: '全场通用', CATEGORY: '按品类', STORE: '按门店' }
const V_RULE = { ALL_CATEGORY: '全部品类适用', ALL_BRAND: '全部品牌适用' }
/**
 * collect_method 语义已由 sql/upgrade/biz_collect_method_semantic_v6.sql 统一为「收款方式」，
 * 357 条存量全部归一到 HEAD/STORE，旧的券码类型取值（PLATFORM/THIRD_PARTY/
 * MERCHANT_OWN）已清零，故不再保留兼容映射。
 * 券码类型现由 ext.code_type 承载，见下方 CODE_TYPE。
 * 背景：doc/collect_method-语义冲突排查-2026-08-27.md
 */
const COLLECT = { HEAD: '总部统一收款', STORE: '门店独立收款' }

export default {
  name: 'ProductDetail',
  data() {
    return {
      loading: true,
      form: {},
      ext: {},
      typeList: [],
      channelList: [],
      merchantList: [],
      subitemGroups: [],
      activeTab: 'basic',
      suppressScrollSpy: false,
      scrollSpyTimer: null,
      _scrollParent: null,
      _boundScroller: null
    }
  },
  computed: {
    isGroupon() { return this.form.typeCode === 'GROUPON' },
    isVoucher() { return this.form.typeCode === 'VOUCHER' },
    isCombo() { return this.form.typeCode === 'COMBO' },
    typeName() {
      const t = (this.typeList || []).find(x => x.typeCode === this.form.typeCode)
      return t ? t.typeName : ''
    },
    // 与 create.vue merchantTabLabel 保持一致（代金券那一栏在编辑页叫「商品类型」）
    merchantTabLabel() { return this.isVoucher ? '商品类型' : '商家信息' },
    merchantLabel() {
      if (this.form.merchantName) return this.form.merchantName
      const id = this.form.merchantId
      if (!id) return ''
      // 详情接口不返 merchantName（ProductMapper 没聚合），靠商户列表兜底；
      // 兜不到时也要把 id 显示出来，不能让运营以为商品没归属
      const m = (this.merchantList || []).find(x => Number(x.merchantId) === Number(id))
      return m ? m.merchantName : '商户 ' + id
    },
    // 面值/最低消费/总次数只对用得上的类型显示，避免一屏全是「—」
    showFaceValue() {
      return ['STORED_CARD', 'HUIXIANG_CARD'].indexOf(this.form.typeCode) >= 0
    },
    showMinConsume() {
      return ['VOUCHER', 'STORED_CARD'].indexOf(this.form.typeCode) >= 0 && Number(this.form.minConsume) > 0
    },
    showTotalTimes() {
      return Number(this.form.totalTimes) > 0
    },
    showTotalValue() {
      return Number(this.form.totalValue) > 0
    },
    /**
     * 锚点必须与真实渲染出来的区块严格一一对应，否则点导航滚不动（找不到 ref）。
     * 只有「商品资质」「商品搭配」两块按类型裁剪 —— 它们对其他类型确实没有数据源；
     * 其余区块一律展示，字段没值时显示占位。
     */
    visibleSections() {
      const list = [
        { name: 'basic', label: '基础信息' },
        { name: 'merchant', label: this.merchantTabLabel }
      ]
      if (this.isCombo) list.push({ name: 'qualify', label: '商品资质' })
      list.push({ name: 'product', label: '商品信息' })
      if (this.isGroupon || this.isCombo) list.push({ name: 'subitem', label: this.isCombo ? '组合商品搭配' : '商品搭配' })
      list.push({ name: 'sale', label: '售卖信息' })
      list.push({ name: 'trade', label: '交易规则' })
      list.push({ name: 'consume', label: '消费规则' })
      return list
    },
    // 后端 storeNames 是「、」拼的（ProductMapper 用 separator '、'），
    // 不是逗号。按逗号切会得到一整条长字符串塞进单个 tag。
    storeNameList() {
      const raw = this.form.storeNames || this.form.storeName || ''
      return String(raw).split(/[、,，]/).map(s => s.trim()).filter(s => s)
    },
    coverList() { return this.splitUrls(this.form.cover) },
    imageList() { return this.splitUrls(this.form.images) },
    // 渠道代码要翻成名字。字典里查不到的原样显示并标红 ——
    // 说明该渠道被停用或删了，运营需要看见它而不是被静默吞掉
    channelTagList() {
      const codes = this.ext.saleChannels ? String(this.ext.saleChannels).split(',').filter(v => v) : []
      return codes.map(code => {
        const hit = (this.channelList || []).find(c => c.channelCode === code)
        return hit ? { code, name: hit.channelName, stale: false }
          : { code, name: code + '（已停用）', stale: true }
      })
    },
    voucherRuleList() {
      return this.ext.voucherRules ? String(this.ext.voucherRules).split(',').filter(v => v) : []
    },
    subitemTotal() {
      return (this.subitemGroups || []).reduce((n, g) => n + this.groupSize(g), 0)
    },
    totalPickCount() {
      return (this.subitemGroups || []).reduce((n, g) => n + this.groupPickCount(g), 0)
    },
    stockText() {
      const s = this.form.stock
      if (Number(s) === -1) return '不限库存'
      return s == null ? '—' : String(s)
    },
    collectMethodText() { return COLLECT[this.form.collectMethod] || this.dash(this.form.collectMethod) },
    refundPolicyText() { return REFUND[this.form.refundPolicy] || this.dash(this.form.refundPolicy) },
    codeTypeText() { return CODE_TYPE[this.ext.codeType] || CODE_TYPE.MERCHANT },
    // 组合券包用 voucherType 语义、代金券用 scopeType 语义，两者共用 ext.voucherScopeType
    // 这一列（跟 create.vue packFormToExt 的写法一致），所以分两个 computed 各自解释
    voucherTypeText() { return VOUCHER_TYPE[this.ext.voucherScopeType] || '—' },
    scopeTypeText() { return SCOPE[this.ext.voucherScopeType] || '—' },
    validityText() {
      const d = this.form.validityDays || this.form.consumeValidDays
      return d ? '自购买后 ' + d + ' 天内有效' : '—'
    },
    // 库里存的是「互斥」，展示要反过来说，跟 create.vue 的 SHARE/EXCLUSIVE 映射一致
    mutexText() {
      return Number(this.form.mutexWithStorePromotion) === 0 ? '与店内优惠同享' : '不与店内优惠同享'
    },
    dailyTimeText() {
      const a = this.ext.dailyTimeStart, b = this.ext.dailyTimeEnd
      return (a && b) ? a + ' ~ ' + b : '全天可用'
    },
    excludeText() {
      const json = this.ext.excludeDates
      if (!json) return '无'
      try {
        const arr = JSON.parse(json)
        if (Array.isArray(arr) && arr.length) {
          const txt = arr.filter(p => Array.isArray(p) && p.length === 2)
            .map(p => p[0] + ' ~ ' + p[1]).join('；')
          return txt || '无'
        }
      } catch (e) { /* 脏 JSON 不能让整页打不开 */ }
      return '无'
    }
  },
  created() {
    const pid = this.$route.params.productId || this.$route.query.productId
    if (!pid) {
      this.loading = false
      this.$modal.msgError('缺少商品 ID')
      return
    }
    // 字典先加载完再取商品，否则类型名/渠道名会先闪一下原始 code 再变成中文
    Promise.all([
      selectProductTypeList().then(r => { this.typeList = (r && (r.rows || r.data)) || [] }).catch(() => {}),
      enabledSaleChannel().then(r => { this.channelList = (r && r.data) || [] }).catch(() => {}),
      listMerchant({ pageNum: 1, pageSize: 200 }).then(r => { this.merchantList = (r && r.rows) || [] }).catch(() => {})
    ]).then(() => this.loadProduct(pid))
  },
  mounted() {
    this.rebindScroller()
  },
  beforeDestroy() {
    clearTimeout(this.scrollSpyTimer)
    if (this._boundScroller) this._boundScroller.removeEventListener('scroll', this.onScrollSpy)
  },
  methods: {
    dash(v) { return (v === null || v === undefined || v === '') ? '—' : v },
    money(v) {
      if (v === null || v === undefined || v === '') return '—'
      const n = Number(v)
      return isNaN(n) ? '—' : '¥' + n.toFixed(2)
    },
    boolText(v, yes, no) { return Number(v) === 1 ? yes : no },
    rangeText(a, b, fallback) { return (a && b) ? a + ' ~ ' + b : (fallback || '—') },
    voucherRuleText(r) { return V_RULE[r] || r },
    splitUrls(raw) {
      if (!raw) return []
      return String(raw).split(',').map(s => s.trim()).filter(s => s)
    },

    loadProduct(pid) {
      getProduct(pid).then(res => {
        const p = (res && res.data) || {}
        this.form = p
        this.ext = p.ext || {}
        this.loading = false
        if (this.isGroupon || this.isCombo) this.loadSubitems(pid)
        // 类型判定要等 form 到手才成立，区块数量随之变化，
        // 所以滚动容器要在渲染完成后重新探测一次
        this.$nextTick(() => this.rebindScroller())
      }).catch(e => {
        this.loading = false
        this.$modal.msgError((e && (e.msg || e.message)) || '商品加载失败')
      })
    },
    loadSubitems(pid) {
      // listGroups 收的是位置参数（productId），不是查询对象
      listGroups(pid).then(r => {
        this.subitemGroups = (r && (r.data || r.rows)) || []
      }).catch(() => { this.subitemGroups = [] })
    },

    // ===== 「几选几」：与 create.vue 同一套解析，含存量中文格式兼容 =====
    groupSize(g) { return ((g && g.subitems) || []).length },
    groupPickCount(g) {
      const size = this.groupSize(g)
      const rule = g && g.pickRule
      if (!rule || rule === 'ALL') return size
      const m = String(rule).match(/^PICK_(\d+)$/)
      let n = m ? Number(m[1]) : null
      if (n == null) {
        // 兼容存量中文格式 'N选M'，取「选」后面那个数
        const cn = String(rule).match(/选\s*(\d+)$/)
        if (cn) n = Number(cn[1])
      }
      if (n == null || n <= 0 || n >= size) return size
      return n
    },
    isPickAll(g) { return this.groupPickCount(g) >= this.groupSize(g) },
    pickRuleText(g) {
      const size = this.groupSize(g)
      if (size === 0) return '未添加单品'
      return '共' + size + '个单品：' + size + '选' + this.groupPickCount(g)
    },

    // ===== 吸顶导航（与 create.vue 同一套实现）=====
    sectionEl(name) {
      const r = this.$refs['sec_' + name]
      if (!r) return null
      return Array.isArray(r) ? r[0] : r
    },
    /**
     * 找真正在滚动的祖先容器。
     * RuoYi 布局里 .app-main 自己是 overflow-y: auto，滚动发生在它内部，
     * window 根本不触发 scroll —— 直接监听 window 会让吸顶高亮完全不工作。
     */
    scrollParent() {
      if (this._scrollParent) return this._scrollParent
      let node = this.$el && this.$el.parentElement
      while (node && node !== document.body) {
        const oy = window.getComputedStyle(node).overflowY
        if ((oy === 'auto' || oy === 'scroll') && node.scrollHeight > node.clientHeight) {
          this._scrollParent = node
          return node
        }
        node = node.parentElement
      }
      // 没找到时不缓存：数据还没到手时内容不够高会被判成不可滚动，
      // 缓存下来就再也不会重新探测了
      return window
    },
    rebindScroller() {
      const prev = this._boundScroller
      this._scrollParent = null
      const sp = this.scrollParent()
      if (prev === sp) return
      if (prev) prev.removeEventListener('scroll', this.onScrollSpy)
      sp.addEventListener('scroll', this.onScrollSpy, { passive: true })
      this._boundScroller = sp
    },
    scrollTopOf(sp) {
      return sp === window ? (window.pageYOffset || document.documentElement.scrollTop) : sp.scrollTop
    },
    /** 吸顶导航自身高度，滚动定位要让出来，否则区块标题被盖住 */
    anchorOffset() {
      const nav = this.$refs.anchorNav
      return (nav ? nav.offsetHeight : 0) + 12
    },
    scrollToSection(name) {
      const el = this.sectionEl(name)
      if (!el) return
      // 平滑滚动会连续穿过中间区块，不抑制高亮会一路乱跳
      this.suppressScrollSpy = true
      this.activeTab = name
      const sp = this.scrollParent()
      const offset = this.anchorOffset()
      if (sp === window) {
        window.scrollTo({ top: el.getBoundingClientRect().top + this.scrollTopOf(sp) - offset, behavior: 'smooth' })
      } else {
        // 元素容器要换算成「相对容器」的偏移，不能直接用视口坐标
        const top = el.getBoundingClientRect().top - sp.getBoundingClientRect().top + sp.scrollTop - offset
        sp.scrollTo({ top, behavior: 'smooth' })
      }
      clearTimeout(this.scrollSpyTimer)
      this.scrollSpyTimer = setTimeout(() => { this.suppressScrollSpy = false }, 600)
    },
    /**
     * 取「最后一个顶部已越过判定线的区块」，而不是找距离最近的：
     * 区块高度差异很大（商品信息很长、商品资质很短），按最近算会在长区块内部提前跳走
     */
    onScrollSpy() {
      if (this.suppressScrollSpy) return
      const sp = this.scrollParent()
      const baseTop = sp === window ? 0 : sp.getBoundingClientRect().top
      const line = baseTop + this.anchorOffset() + 20
      let current = null
      for (const sec of this.visibleSections) {
        const el = this.sectionEl(sec.name)
        if (!el) continue
        if (el.getBoundingClientRect().top - line <= 0) current = sec.name
      }
      // 滚到底时点亮最后一块：它可能不够高，顶部永远越不过判定线
      const atBottom = sp === window
        ? window.innerHeight + this.scrollTopOf(sp) >= document.body.scrollHeight - 40
        : sp.scrollTop + sp.clientHeight >= sp.scrollHeight - 40
      if (atBottom && this.visibleSections.length) {
        current = this.visibleSections[this.visibleSections.length - 1].name
      }
      if (current && current !== this.activeTab) this.activeTab = current
    },

    goEdit() {
      // 编辑页是 router/index.js 里静态注册的 /product/create（不带 /biz 前缀）
      this.$router.push({ path: '/product/create', query: { productId: this.form.productId } }).catch(() => {})
    },
    goBack() {
      // 优先回列表而不是 history.back：从新标签页直接打开详情时 back 会退到空白页
      this.$router.push({ path: '/goods/product' }).catch(() => {})
    }
  }
}
</script>

<style scoped>
/* 不能用 100vh：本页渲染在 .app-main 内，其可视高度已减掉固定头（navbar 50 + tagsView 34） */
.dyl-detail { max-width: 960px; margin: 0 auto; padding: 12px; background: #f5f5f7; min-height: 100%; }
.dyl-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: #fff; border-radius: 8px 8px 0 0; }
.dyl-header-main { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.dyl-title { font-size: 18px; font-weight: 600; color: #161823; }
.dyl-header-sub { background: #fff; padding: 0 16px 12px; border-radius: 0 0 8px 8px; margin-bottom: 12px; color: #909399; font-size: 12px; }
.dyl-dot { margin: 0 4px; }

/* overflow: visible 是吸顶能否生效的关键，不是样式偏好。
   element-ui 给 .el-card 设了 overflow: hidden，吸顶导航就在这张卡片里；
   祖先一旦裁剪内容，它就成了 sticky 的滚动容器，而这张卡片自己从不滚动，
   导航便会跟着内容一路向上跑出可视区（表现为「滚动时导航不见了」）。
   这条必须落在 .el-card 这一层，写在导航自己身上无效。 */
.dyl-card { border-radius: 8px; padding-bottom: 40px; overflow: visible; }

.dyl-anchor-nav {
  position: sticky; top: 0; z-index: 8;
  background: #fff; border-bottom: 1px solid #ebeef5;
  margin: -20px -20px 16px; padding: 12px 20px;
  /* 吸顶时补回卡片圆角，否则贴住时上缘露出方角 */
  border-radius: 8px 8px 0 0;
}
/* 横向滚动放内层 track，让滚动条只出现在按钮那一行 */
.dyl-anchor-track { display: flex; gap: 4px; overflow-x: auto; white-space: nowrap; }
.dyl-anchor-track::-webkit-scrollbar { height: 4px; }
.dyl-anchor-track::-webkit-scrollbar-thumb { background: #dcdfe6; border-radius: 2px; }
.dyl-anchor-item {
  flex: none; cursor: pointer; padding: 6px 14px; border-radius: 16px;
  font-size: 13px; color: #606266; background: #f5f5f7; transition: all .2s;
}
.dyl-anchor-item:hover { color: #fe2c55; }
.dyl-anchor-item.is-active { color: #fff; background: #fe2c55; font-weight: 500; }

.dyl-sec { padding: 4px 0 20px; }
.dyl-sec-title {
  font-size: 15px; font-weight: 600; color: #161823; margin-bottom: 12px;
  padding-left: 9px; border-left: 3px solid #fe2c55;
}
.dyl-sec-extra { font-weight: 400; font-size: 12px; color: #909399; margin-left: 8px; }
.dyl-tag { margin: 0 6px 4px 0; }
.dyl-empty { color: #c0c4cc; }
.dyl-empty-box {
  color: #909399; background: #fafafa; border: 1px dashed #dcdfe6;
  border-radius: 4px; padding: 16px; text-align: center; font-size: 13px;
}
.dyl-pre { white-space: pre-wrap; word-break: break-all; }

.dyl-imgs { margin-top: 14px; }
.dyl-sub-label { font-size: 13px; color: #606266; margin-bottom: 8px; }
.dyl-img { width: 104px; height: 104px; margin: 0 10px 10px 0; border-radius: 4px; border: 1px solid #ebeef5; vertical-align: top; }

.dyl-group { margin-bottom: 14px; }
.dyl-group-head { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
.dyl-group-name { font-size: 14px; font-weight: 600; color: #161823; }
</style>
