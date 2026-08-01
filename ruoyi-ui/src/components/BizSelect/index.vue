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
    :placeholder="placeholder || defaultPlaceholder"
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
import { listStore, getStore } from '@/api/biz/store'
import { listMember, getMember } from '@/api/biz/member'
import { listProduct, getProduct } from '@/api/biz/product'
import { listDistributor, getDistributor } from '@/api/biz/distributor'

const CONFIG = {
  store: {
    api: listStore,
    getById: getStore,
    idField: 'storeId',
    queryField: 'storeName',
    label: row => row.storeName,
    placeholder: '请选择门店'
  },
  member: {
    api: listMember,
    getById: getMember,
    idField: 'memberId',
    queryField: 'nickname',
    label: row => (row.nickname || ('会员' + row.memberId)) + (row.phone ? ('（' + row.phone + '）') : ''),
    placeholder: '请选择会员'
  },
  product: {
    api: listProduct,
    getById: getProduct,
    idField: 'productId',
    queryField: 'productName',
    label: row => row.productName,
    placeholder: '请选择商品'
  },
  distributor: {
    api: listDistributor,
    getById: getDistributor,
    idField: 'distributorId',
    queryField: 'memberId',
    label: row => (row.memberName || ('会员' + row.memberId)) + '（推客' + row.distributorId + '）',
    placeholder: '请选择推客'
  }
}

export default {
  name: 'BizSelect',
  props: {
    // v-model 值：单选为 id，多选为 id 数组
    value: { type: [Number, String, Array], default: null },
    // 数据类型：store | member | product
    type: { type: String, required: true },
    multiple: { type: Boolean, default: false },
    placeholder: { type: String, default: '' },
    width: { type: String, default: '100%' }
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
    }
  },
  watch: {
    value: {
      immediate: true,
      handler(val) {
        this.innerValue = this.normalize(val)
        this.ensureLabels(this.innerValue)
      }
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
      this.loading = true
      const query = { pageNum: 1, pageSize: 20 }
      if (keyword) query[this.cfg.queryField] = keyword
      this.cfg.api(query).then(res => {
        const rows = res.rows || res.data || []
        this.mergeOptions(rows.map(r => this.toOption(r)))
        this.loadedOnce = true
        this.loading = false
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
