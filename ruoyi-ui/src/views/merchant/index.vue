<template>
  <div class="app-container home">
    <el-row :gutter="20">
      <el-col :sm="24" :lg="12" style="padding-left: 20px">
        <h2>商户工作台</h2>
        <p>
          欢迎，<b>{{ nickName || name }}</b>。这里是商户视角的统一入口，可管理门店、订单与资金。
        </p>
        <p>
          <el-tag type="info">商户账号</el-tag>
          <el-tag v-if="merchantId" type="success" style="margin-left: 8px">商户 ID: {{ merchantId }}</el-tag>
        </p>
        <p>
          <el-button type="primary" size="mini" icon="el-icon-s-shop" @click="$router.push('/biz/store')">门店</el-button>
          <el-button size="mini" icon="el-icon-tickets" @click="$router.push('/biz/order')" style="margin-left: 8px">订单</el-button>
          <el-button size="mini" icon="el-icon-money" @click="$router.push('/biz/bill')" style="margin-left: 8px">买单</el-button>
        </p>
      </el-col>
      <el-col :sm="24" :lg="12" style="padding-left: 50px">
        <h2>核心指标</h2>
        <el-row :gutter="20">
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">今日订单</div>
              <div class="metric-value">{{ stats.todayOrder }} <span class="metric-unit">单</span></div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">本月营业额</div>
              <div class="metric-value">¥ {{ stats.monthRevenue }}</div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">服务到期</div>
              <div class="metric-value" :class="{ 'expire-warn': stats.expiringSoon }">{{ stats.expireText }}</div>
            </el-card>
          </el-col>
        </el-row>
        <p class="placeholder" v-if="loading">加载中…</p>
        <p class="placeholder" v-else-if="!merchantId">未关联商户记录，请联系平台管理员。</p>
      </el-col>
    </el-row>
  </div>
</template>

<script>
import { getMerchant } from '@/api/biz/merchant'
import { listOrder } from '@/api/biz/order'

export default {
  name: 'MerchantIndex',
  data() {
    return {
      loading: false,
      stats: {
        todayOrder: 0,
        monthRevenue: '0.00',
        expireText: '—',
        expiringSoon: false
      }
    }
  },
  computed: {
    nickName() { return this.$store.state.user.nickName },
    name() { return this.$store.state.user.name },
    merchantId() { return this.$store.state.user.merchantId }
  },
  mounted() {
    if (this.merchantId) this.loadStats()
  },
  methods: {
    loadStats() {
      this.loading = true
      // 今天 00:00 ~ 当前
      const today = new Date(); today.setHours(0, 0, 0, 0)
      const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
      Promise.all([
        getMerchant(this.merchantId).catch(() => null),
        listOrder({ merchantId: this.merchantId, pageNum: 1, pageSize: 1, params: { beginCreateTime: this.fmt(today) } }).catch(() => ({ rows: [], total: 0 })),
        listOrder({ merchantId: this.merchantId, pageNum: 1, pageSize: 100, params: { beginCreateTime: this.fmt(monthStart), payStatus: '1' } }).catch(() => ({ rows: [], total: 0 }))
      ]).then(([merchant, todayResp, monthResp]) => {
        if (merchant && merchant.data) {
          const m = merchant.data
          if (m.serviceExpire) {
            const d = new Date(m.serviceExpire)
            const days = Math.ceil((d - Date.now()) / 86400000)
            this.stats.expireText = days + ' 天'
            this.stats.expiringSoon = days <= 30
          }
        }
        this.stats.todayOrder = (todayResp && todayResp.total) || 0
        const monthOrders = (monthResp && monthResp.rows) || []
        const revenue = monthOrders.reduce((s, o) => s + (parseFloat(o.payAmount) || 0), 0)
        this.stats.monthRevenue = revenue.toFixed(2)
        this.loading = false
      }).catch(() => { this.loading = false })
    },
    fmt(d) {
      const p = (n) => (n < 10 ? '0' + n : n)
      return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' 00:00:00'
    }
  }
}
</script>

<style scoped>
.metric-label { color: #909399; font-size: 12px; }
.metric-value { font-size: 24px; font-weight: 600; color: #303133; margin-top: 4px; }
.metric-unit { font-size: 14px; color: #909399; font-weight: 400; }
.expire-warn { color: #f56c6c; }
.placeholder { color: #c0c4cc; font-size: 12px; margin-top: 16px; }
</style>
