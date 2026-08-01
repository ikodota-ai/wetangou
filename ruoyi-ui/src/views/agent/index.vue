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
          <el-button type="primary" size="mini" icon="el-icon-shop" @click="goBiz('merchant')">名下商户</el-button>
          <el-button size="mini" icon="el-icon-wallet" @click="goBiz('fee')" style="margin-left: 8px">缴费记录</el-button>
          <el-button size="mini" icon="el-icon-coin" @click="goBiz('quota')" style="margin-left: 8px">额度</el-button>
        </p>
      </el-col>
      <el-col :sm="24" :lg="12" style="padding-left: 50px">
        <h2>待办</h2>
        <ul>
          <li>名下商户数 / 今日新增</li>
          <li>本月缴费金额 / 续费到期提醒</li>
          <li>可用额度 / 占用额度</li>
        </ul>
        <p class="placeholder">
          暂未接入实际数据接口，后续迭代在 <code>ruoyi-system/src/main/java/com/ruoyi/biz/service</code> 补充统计 API。
        </p>
      </el-col>
    </el-row>
  </div>
</template>

<script>
export default {
  name: 'AgentIndex',
  computed: {
    nickName() {
      return this.$store.state.user.nickName
    },
    name() {
      return this.$store.state.user.name
    },
    agentId() {
      return this.$store.state.user.agentId
    }
  },
  methods: {
    goBiz(type) {
      this.$message.info('【' + type + '】页面开发中，敬请期待')
    }
  }
}
</script>

<style scoped lang="scss">
.placeholder {
  color: #909399;
  font-size: 12px;
  margin-top: 16px;
}
</style>
