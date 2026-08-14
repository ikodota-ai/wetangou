<template>
  <div class="app-container home">
    <el-row :gutter="20">
      <el-col :sm="24" :lg="12" style="padding-left: 20px">
        <h2>代理商工作台</h2>
        <p>
          欢迎，<b>{{ nickName || name }}</b>。这里是代理商视角的统一入口，可查看名下商户、缴费记录与剩余额度。
        </p>
        <p>
          <el-tag type="info">代理商账号</el-tag>
          <el-tag v-if="agentId" type="success" style="margin-left: 8px">代理商 ID: {{ agentId }}</el-tag>
        </p>
        <p>
          <el-button type="primary" size="mini" icon="el-icon-shop" @click="$router.push('/biz/merchant')">名下商户</el-button>
          <el-button size="mini" icon="el-icon-wallet" @click="$router.push('/biz/agentfee')" style="margin-left: 8px">缴费记录</el-button>
          <el-button size="mini" icon="el-icon-coin" @click="$router.push('/biz/agent')" style="margin-left: 8px">额度</el-button>
        </p>
      </el-col>
      <el-col :sm="24" :lg="12" style="padding-left: 50px">
        <h2>核心指标</h2>
        <el-row :gutter="20">
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">名下商户</div>
              <div class="metric-value">{{ stats.merchantCount }} <span class="metric-unit">/ {{ stats.merchantQuota }}</span></div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">已缴金额</div>
              <div class="metric-value">¥ {{ stats.paidAmount }}</div>
            </el-card>
          </el-col>
          <el-col :span="8">
            <el-card shadow="hover">
              <div class="metric-label">到期</div>
              <div class="metric-value" :class="{ 'expire-warn': stats.expiringSoon }">{{ stats.expireText }}</div>
            </el-card>
          </el-col>
        </el-row>
        <p class="placeholder" v-if="loading">加载中…</p>
        <p class="placeholder" v-else-if="!agentId">未关联代理商记录，请联系平台管理员。</p>
      </el-col>
    </el-row>
          <el-col :sm="24" :lg="24" style="padding-left: 20px; margin-top: 24px">
        <h2>本月佣金概览 <el-tag v-if="commission.beginTime" type="info" size="mini">{{ formatDate(commission.beginTime) }} ~ 现在</el-tag></h2>
        <el-row :gutter="20">
          <el-col :span="6">
            <el-card shadow="hover" class="commission-card commission-total">
              <div class="metric-label">本月总佣金</div>
              <div class="metric-value">¥ {{ num(commission.totalAmount) }}</div>
              <div class="metric-foot">{{ commission.commissionCount || 0 }} 笔 / {{ commission.merchantCount || 0 }} 商户</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover" class="commission-card commission-settled">
              <div class="metric-label">已结算</div>
              <div class="metric-value">¥ {{ num(commission.settledAmount) }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover" class="commission-card commission-pending">
              <div class="metric-label">待结算</div>
              <div class="metric-value">¥ {{ num(commission.pendingAmount) }}</div>
            </el-card>
          </el-col>
          <el-col :span="6">
            <el-card shadow="hover" class="commission-card commission-extra">
              <div class="metric-label">名下商户 / 区间</div>
              <div class="metric-value commission-extra-v">{{ commission.merchantCount || 0 }} <span class="metric-unit">商户</span></div>
              <div class="metric-foot">代理商 ID: {{ agentId }}</div>
            </el-card>
          </el-col>
        </el-row>
        <el-table
          v-if="commission.byMerchant && commission.byMerchant.length"
          :data="merchantRows"
          stripe
          size="small"
          style="margin-top: 16px"
        >
          <el-table-column prop="merchantId" label="商户ID" width="100" />
          <el-table-column prop="totalAmount" label="本月总佣金" align="right">
            <template slot-scope="scope">¥ {{ num(scope.row.totalAmount) }}</template>
          </el-table-column>
          <el-table-column prop="settledAmount" label="已结算" align="right">
            <template slot-scope="scope">¥ {{ num(scope.row.settledAmount) }}</template>
          </el-table-column>
          <el-table-column prop="pendingAmount" label="待结算" align="right">
            <template slot-scope="scope">¥ {{ num(scope.row.pendingAmount) }}</template>
          </el-table-column>
          <el-table-column prop="commissionCount" label="笔数" align="right" width="80" />
        </el-table>
        <p class="placeholder" v-if="commission.loading">佣金加载中…</p>
        <p class="placeholder" v-else-if="!agentId">未关联代理商记录，请联系平台管理员。</p>
      </el-col>
  </div>
</template>

<script>
import { getAgent } from '@/api/biz/agent'
import { listMerchant } from '@/api/biz/merchant'
import { getAgentCommissionSummary } from '@/api/biz/agentCommission'

export default {
  name: 'AgentIndex',
  data() {
    return {
      loading: false,
      stats: {
        merchantCount: 0,
        merchantQuota: 0,
        paidAmount: '0.00',
        expireText: '—',
        expiringSoon: false
      },
      commission: {
        loading: false,
        totalAmount: 0,
        settledAmount: 0,
        pendingAmount: 0,
        commissionCount: 0,
        merchantCount: 0,
        beginTime: null,
        endTime: null,
        byMerchant: []
      }
    }
  },
  computed: {
    nickName() { return this.$store.state.user.nickName },
    merchantRows() { return this.commission.byMerchant || [] },
    name() { return this.$store.state.user.name },
    agentId() { return this.$store.state.user.agentId }
  },
  mounted() {
    if (this.agentId) {
      this.loadStats()
      this.loadCommission()
    }
  },
  methods: {
    loadStats() {
      this.loading = true
      Promise.all([
        getAgent(this.agentId).catch(() => null),
        listMerchant({ agentId: this.agentId, pageNum: 1, pageSize: 1 }).catch(() => ({ total: 0 }))
      ]).then(([agent, merchantResp]) => {
        if (agent && agent.data) {
          const a = agent.data
          this.stats.merchantQuota = a.merchantQuota || 0
          this.stats.paidAmount = (a.paidAmount || 0).toFixed(2)
          if (a.expireTime) {
            const d = new Date(a.expireTime)
            const days = Math.ceil((d - Date.now()) / 86400000)
            this.stats.expireText = days + ' 天'
            this.stats.expiringSoon = days <= 30
          }
        }
        this.stats.merchantCount = (merchantResp && merchantResp.total) || 0
        this.loading = false
      }).catch(() => { this.loading = false })
    },
    loadCommission() {
      this.commission.loading = true
      getAgentCommissionSummary(this.agentId)
        .then((res) => {
          if (res && res.data) {
            this.commission.totalAmount = res.data.totalAmount || 0
            this.commission.settledAmount = res.data.settledAmount || 0
            this.commission.pendingAmount = res.data.pendingAmount || 0
            this.commission.commissionCount = res.data.commissionCount || 0
            this.commission.merchantCount = res.data.merchantCount || 0
            this.commission.beginTime = res.data.beginTime
            this.commission.endTime = res.data.endTime
            this.commission.byMerchant = (res.data.byMerchant || []).map((row) => ({
              merchantId: row.merchant_id,
              totalAmount: row.total_amount,
              settledAmount: row.settled_amount,
              pendingAmount: row.pending_amount,
              commissionCount: row.commission_count
            }))
          }
        })
        .catch((err) => {
          console.warn('[agent/index] loadCommission FAIL', err)
        })
        .finally(() => { this.commission.loading = false })
    },
    num(v) {
      if (v == null) return '0.00'
      const n = Number(v)
      return isNaN(n) ? '0.00' : n.toFixed(2)
    },
    formatDate(d) {
      if (!d) return ''
      return String(d).slice(0, 10)
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
.commission-card { border-top: 3px solid #909399; }
.commission-total { border-top-color: #3A6B35; }
.commission-settled { border-top-color: #67C23A; }
.commission-pending { border-top-color: #E6A23C; }
.commission-extra { border-top-color: #909399; }
.commission-card .metric-value { font-size: 22px; }
.commission-extra-v { font-size: 20px; }
.commission-card .metric-foot { color: #909399; font-size: 12px; margin-top: 4px; }
</style>
