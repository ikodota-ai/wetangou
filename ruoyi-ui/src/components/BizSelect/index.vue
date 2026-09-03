<template>
  <el-select
    v-model="innerValue"
    :multiple="multiple"
    filterable
    remote
    clearable
    :collapse-tags="multiple"
    :remote-method="remoteSearch"
    :loading="loading"
    :disabled="blockedByMerchant"
    :placeholder="blockedByMerchant ? '请先选择商户' : (placeholder || defaultPlaceholder)"
    :style="{ width: width }"
    @change="handleChange"
    @visible-change="onVisible"
  >
    <el-option
      v-for="item in options"
      :key="item.value"
      :label="item.label"
      :value="item.value"
    />
  </el-select>
</template>

<script>
// D2：业务 API 自动注册——加新业务类型无需改本文件
// （在 src/api/biz/<type>.js 暴露 listX/getX 即可被 BizSelect 自动支持）
import BIZ_API_REGISTRY from '@/api/biz/registry'

// 向后兼容：保留 5 个原 CONFIG 字段供外部直接引用
export const CONFIG = BIZ_API_REGISTRY

export default {
  name: 'BizSelect',
  props: {
    // v-model 值：单选为 id，多选为 id 数组
    value: { type: [Number, String, Array], default: null },
    // 数据类型：store | member | product
    type: { type: String, required: true },
    multiple: { type: Boolean, default: false },
    placeholder: { type: String, default: '' },
    width: { type: String, default: '100%' },
    // 所属商户 ID（非空时，列表只返回该商户下的数据）。后端 Store/Product/Member 等已全部支持 merchantId 过滤。
    merchantId: { type: [Number, String], default: null },
    // 单选且下拉只剩 1 个选项时自动选中（如：某商户下只有 1 个门店）。多选不生效。
    autoPickSingle: { type: Boolean, default: false },
    // 必须先有 merchantId 才允许选择。给平台/代理商账号用：
    // 不设这个约束，他们能在「全部门店」里挑一个别家的，提交时才被后端
    // 以「门店不属于该商家」打回。商户账号的 merchantId 由 token 钉住，不受影响。
    requireMerchant: { type: Boolean, default: false }
  },
  data() {
    return {
      innerValue: this.multiple ? [] : null,
      options: [],
      loading: false,
      loadedOnce: false
    }
  },
  computed: {
    cfg() {
      return CONFIG[this.type] || CONFIG.store
    },
    defaultPlaceholder() {
      return this.cfg.placeholder
    },
    blockedByMerchant() {
      return this.requireMerchant && (this.merchantId == null || this.merchantId === '')
    }
  },
  watch: {
    value: {
      immediate: true,
      handler(val) {
        this.innerValue = this.normalize(val)
        this.ensureLabels(this.innerValue)
      }
    },
    // 切换商户时清空选项重新拉取；多选同步清空已选值
    merchantId(val, oldVal) {
      const wasEmpty = (oldVal == null || oldVal === '')
      this.options = []
      this.loadedOnce = false
      // 只有「从一个商户换到另一个商户」才清空已选，
      // 从空变成有值不清 —— 编辑回显时 form.merchantId 和 form.storeId 是同一次赋值，
      // 两个 watch 排在同一个刷新队列里，value 先跑填好门店，
      // merchantId 后跑要是无脑清空，编辑框里的门店就永远是空的。
      if (!wasEmpty) {
        if (this.multiple) {
          this.innerValue = []
          this.handleChange([])
        } else {
          this.innerValue = null
          this.handleChange(null)
        }
      }
      // 触发一次空查询（用户点开下拉时 onVisible 也会拉）
      this.fetch('')
    }
  },
  methods: {
    normalize(val) {
      if (this.multiple) {
        if (val == null || val === '') return []
        return Array.isArray(val) ? val : [val]
      }
      return (val === '' ? null : val)
    },
    toOption(row) {
      return { value: row[this.cfg.idField], label: this.cfg.label(row) }
    },
    remoteSearch(keyword) {
      this.fetch(keyword)
    },
    onVisible(visible) {
      if (visible && !this.loadedOnce) {
        this.fetch('')
      }
    },
    fetch(keyword) {
      // 未选商户就不该去拉全平台的数据 —— 既没意义也会把别家数据带到前端
      if (this.blockedByMerchant) {
        this.options = []
        return
      }
      this.loading = true
      // pageSize=100 一次性拉完，避免商户/门店量超过 20 时下拉被截断
      const query = { pageNum: 1, pageSize: 100 }
      if (keyword) query[this.cfg.queryField] = keyword
      if (this.merchantId != null && this.merchantId !== '') {
        query.merchantId = this.merchantId
      }
      this.cfg.api(query).then(res => {
        const rows = res.rows || res.data || []
        this.mergeOptions(rows.map(r => this.toOption(r)))
        this.loadedOnce = true
        this.loading = false
        // 单选 + autoPickSingle + 仅 1 条 → 自动回填
        if (!this.multiple && this.autoPickSingle && rows.length === 1 && this.innerValue == null) {
          const only = rows[0]
          const val = only[this.cfg.idField]
          this.innerValue = val
          this.handleChange(val)
          this.$emit('auto-pick', val, only)
        }
      }).catch(() => { this.loading = false })
    },
    // 回显：对已选但选项里没有的 id 补齐 label
    ensureLabels(val) {
      const ids = this.multiple ? (val || []) : (val != null ? [val] : [])
      const missing = ids.filter(id => !this.options.find(o => o.value === id))
      missing.forEach(id => {
        // 先占位，避免显示成 id
        if (!this.options.find(o => o.value === id)) {
          this.options.push({ value: id, label: String(id) })
        }
        this.cfg.getById(id).then(res => {
          const row = res.data || res
          if (row && row[this.cfg.idField] != null) {
            const opt = this.toOption(row)
            const idx = this.options.findIndex(o => o.value === id)
            if (idx > -1) this.$set(this.options, idx, opt)
          }
        }).catch(() => {})
      })
    },
    mergeOptions(list) {
      const map = {}
      this.options.forEach(o => { map[o.value] = o })
      list.forEach(o => { map[o.value] = o })
      this.options = Object.values(map)
    },
    handleChange(val) {
      this.$emit('input', val)
      this.$emit('change', val)
    }
  }
}
</script>
