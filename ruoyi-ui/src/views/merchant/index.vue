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
          <el-button type="primary" size="mini" icon="el-icon-s-shop" @click="goBiz('store')">门店</el-button>
          <el-button size="mini" icon="el-icon-tickets" @click="goBiz('order')" style="margin-left: 8px">订单</el-button>
          <el-button size="mini" icon="el-icon-money" @click="goBiz('fund')" style="margin-left: 8px">资金</el-button>
        </p>
      </el-col>
      <el-col :sm="24" :lg="12" style="padding-left: 50px">
        <h2>概览</h2>
        <ul>
          <li>今日订单数 / 核销率</li>
          <li>本月营业额 / 待结算金额</li>
          <li>门店在线状态 / 库存预警</li>
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
  name: 'MerchantIndex',
  computed: {
    nickName() {
      return this.$store.state.user.nickName
    },
    name() {
      return this.$store.state.user.name
    },
    merchantId() {
      return this.$store.state.user.merchantId
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
