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
  </div>
</template>

<script>
import { getAgent } from '@/api/biz/agent'
import { listMerchant } from '@/api/biz/merchant'

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
      }
    }
  },
  computed: {
    nickName() { return this.$store.state.user.nickName },
    name() { return this.$store.state.user.name },
    agentId() { return this.$store.state.user.agentId }
  },
  mounted() {
    if (this.agentId) this.loadStats()
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
