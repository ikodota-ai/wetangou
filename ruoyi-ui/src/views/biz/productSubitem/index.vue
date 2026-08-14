<template>
  <div class="app-container">
    <el-alert
      title="子品管理 v2 占位页"
      type="info"
      description="子品（搭配）v2 接口已实装在 ruoyi-system (BizProductSubitemController)，admin 端 CRUD 页面待完善。当前页可作为路由入口占位。"
      :closable="false"
      show-icon />
    <br />
    <el-form :model="queryParams" size="small" :inline="true" v-show="showSearch">
      <el-form-item label="商品ID" prop="productId">
        <el-input v-model="queryParams.productId" placeholder="商品ID" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList" />
    </el-row>

    <el-table v-loading="loading" :data="groupList">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="组ID" align="center" prop="groupId" width="100" />
      <el-table-column label="商品ID" align="center" prop="productId" width="120" />
      <el-table-column label="组名称" align="center" prop="groupName" />
      <el-table-column label="选择规则" align="center" prop="pickRule" width="120">
        <template slot-scope="scope">{{ pickRuleMap[scope.row.pickRule] || scope.row.pickRule || '-' }}</template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="80" />
    </el-table>

    <pagination v-show="total > 0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />
  </div>
</template>

<script>
import { listGroups } from "@/api/biz/productSubitem"

export default {
  name: "ProductSubitem",
  data() {
    return {
      loading: false,
      showSearch: true,
      total: 0,
      groupList: [],
      queryParams: { pageNum: 1, pageSize: 20, productId: null },
      pickRuleMap: { ALL: '全部可享', '1选1': '1选1', '2选2': '2选2', '3选2': '3选2' }
    }
  },
  created() {
    // 占位页：不主动加载，留给产品页组合使用
  },
  methods: {
    getList() {
      if (!this.queryParams.productId) {
        this.groupList = []
        this.total = 0
        return
      }
      this.loading = true
      listGroups(this.queryParams.productId).then(res => {
        this.groupList = (res && (res.data || res)) || []
        this.total = Array.isArray(this.groupList) ? this.groupList.length : 0
        this.loading = false
      }).catch(() => { this.loading = false })
    },
    handleQuery() { this.queryParams.pageNum = 1; this.getList() },
    resetQuery() { this.queryParams = { pageNum: 1, pageSize: 20, productId: null }; this.getList() }
  }
}
</script>
