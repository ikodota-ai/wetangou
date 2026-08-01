<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="72px">
      <el-form-item label="订单编号" prop="orderNo">
        <el-input v-model="queryParams.orderNo" placeholder="请输入订单编号" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
      </el-form-item>
      <el-form-item label="会员" prop="memberIds">
        <biz-select v-model="queryParams.memberIds" type="member" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商品" prop="productIds">
        <biz-select v-model="queryParams.productIds" type="product" multiple width="220px" />
      </el-form-item>
      <el-form-item label="订单状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 140px">
          <el-option label="待付款" value="0" />
          <el-option label="待使用" value="1" />
          <el-option label="已完成" value="2" />
          <el-option label="已退款" value="3" />
          <el-option label="已取消" value="4" />
        </el-select>
      </el-form-item>
      <el-form-item label="下单时间">
        <el-date-picker
          v-model="dateRange"
          style="width: 240px"
          value-format="yyyy-MM-dd"
          type="daterange"
          range-separator="-"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
        ></el-date-picker>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:order:remove']">删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="el-icon-download" size="mini" @click="handleExport" v-hasPermi="['biz:order:export']">导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="orderList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="订单编号" align="center" prop="orderNo" width="180" />
      <el-table-column label="门店" align="center" prop="storeName" min-width="130" show-overflow-tooltip>
        <template slot-scope="scope">{{ scope.row.storeName || ('门店' + scope.row.storeId) }}</template>
      </el-table-column>
      <el-table-column label="会员" align="center" prop="memberName" min-width="130" show-overflow-tooltip>
        <template slot-scope="scope">{{ scope.row.memberName || ('会员' + scope.row.memberId) }}</template>
      </el-table-column>
      <el-table-column label="商品" align="center" prop="productName" min-width="150" show-overflow-tooltip />
      <el-table-column label="类型" align="center" prop="orderType" width="100">
        <template slot-scope="scope">{{ scope.row.orderType === '1' ? '到店买单' : '到店自取' }}</template>
      </el-table-column>
      <el-table-column label="数量" align="center" prop="num" width="70" />
      <el-table-column label="实付金额" align="center" prop="payAmount" width="100">
        <template slot-scope="scope"><span style="color:#F56C6C;font-weight:bold">¥{{ scope.row.payAmount }}</span></template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="statusType(scope.row.status)">{{ statusText(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="核销码" align="center" prop="verifyCode" width="120" />
      <el-table-column label="下单时间" align="center" prop="createTime" width="160" />
      <el-table-column label="操作" align="center" width="90" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-view" @click="handleView(scope.row)">详情</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination
      v-show="total>0"
      :total="total"
      :page.sync="queryParams.pageNum"
      :limit.sync="queryParams.pageSize"
      @pagination="getList"
    />

    <!-- 订单详情 -->
    <el-dialog title="订单详情" :visible.sync="open" width="560px" append-to-body>
      <el-descriptions :column="2" border size="small">
        <el-descriptions-item label="订单编号">{{ form.orderNo }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ statusText(form.status) }}</el-descriptions-item>
        <el-descriptions-item label="门店">{{ form.storeName || form.storeId }}</el-descriptions-item>
        <el-descriptions-item label="会员">{{ form.memberName || form.memberId }}</el-descriptions-item>
        <el-descriptions-item label="商品">{{ form.productName }}</el-descriptions-item>
        <el-descriptions-item label="类型">{{ form.orderType === '1' ? '到店买单' : '到店自取' }}</el-descriptions-item>
        <el-descriptions-item label="单价">¥{{ form.price }}</el-descriptions-item>
        <el-descriptions-item label="数量">{{ form.num }}</el-descriptions-item>
        <el-descriptions-item label="订单金额">¥{{ form.totalAmount }}</el-descriptions-item>
        <el-descriptions-item label="优惠金额">¥{{ form.discountAmount }}</el-descriptions-item>
        <el-descriptions-item label="实付金额">¥{{ form.payAmount }}</el-descriptions-item>
        <el-descriptions-item label="核销码">{{ form.verifyCode }}</el-descriptions-item>
        <el-descriptions-item label="核销时间">{{ form.verifyTime }}</el-descriptions-item>
        <el-descriptions-item label="核销人">{{ form.verifyUser }}</el-descriptions-item>
        <el-descriptions-item label="支付时间">{{ form.payTime }}</el-descriptions-item>
        <el-descriptions-item label="微信支付单号">{{ form.payNo }}</el-descriptions-item>
        <el-descriptions-item label="下单时间">{{ form.createTime }}</el-descriptions-item>
        <el-descriptions-item label="核销有效期">{{ form.expireTime }}</el-descriptions-item>
      </el-descriptions>
      <div slot="footer" class="dialog-footer">
        <el-button @click="open = false">关 闭</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listOrder, getOrder, delOrder } from "@/api/biz/order"

export default {
  name: "Order",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      orderList: [],
      title: "",
      open: false,
      dateRange: [],
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        orderNo: null,
        storeIds: [],
        memberIds: [],
        productIds: [],
        status: null
      },
      form: {}
    }
  },
  created() {
    this.getList()
  },
  methods: {
    statusText(status) {
      return { '0': '待付款', '1': '待使用', '2': '已完成', '3': '已退款', '4': '已取消' }[status] || status
    },
    statusType(status) {
      return { '0': 'warning', '1': 'primary', '2': 'success', '3': 'info', '4': 'danger' }[status] || 'info'
    },
    buildParams() {
      const params = {
        pageNum: this.queryParams.pageNum,
        pageSize: this.queryParams.pageSize,
        orderNo: this.queryParams.orderNo,
        status: this.queryParams.status,
        params: {
          storeIds: this.queryParams.storeIds,
          memberIds: this.queryParams.memberIds,
          productIds: this.queryParams.productIds
        }
      }
      if (this.dateRange && this.dateRange.length === 2) {
        params.params.beginTime = this.dateRange[0]
        params.params.endTime = this.dateRange[1] + ' 23:59:59'
      }
      return params
    },
    getList() {
      this.loading = true
      listOrder(this.buildParams()).then(response => {
        this.orderList = response.rows
        this.total = response.total
        this.loading = false
      })
    },
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    resetQuery() {
      this.dateRange = []
      this.queryParams = {
        pageNum: 1,
        pageSize: 10,
        orderNo: null,
        storeIds: [],
        memberIds: [],
        productIds: [],
        status: null
      }
      this.handleQuery()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.orderId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    handleView(row) {
      getOrder(row.orderId).then(response => {
        this.form = response.data
        this.open = true
      })
    },
    handleDelete(row) {
      const orderIds = row.orderId || this.ids
      this.$modal.confirm('是否确认删除订单编号为"' + orderIds + '"的数据项？').then(function() {
        return delOrder(orderIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    handleExport() {
      this.download('biz/order/export', {
        ...this.buildParams()
      }, `order_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
