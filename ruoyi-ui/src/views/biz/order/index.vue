<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="72px">
      <el-form-item label="订单编号" prop="orderNo">
        <el-input v-model="queryParams.orderNo" placeholder="请输入订单编号" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" :merchant-id="queryParams.merchantId" multiple width="220px" />
      </el-form-item>
      <el-form-item label="会员" prop="memberIds">
        <biz-select v-model="queryParams.memberIds" type="member" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商品" prop="productIds">
        <biz-select v-model="queryParams.productIds" type="product" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
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
        <el-button type="primary" plain icon="el-icon-check" size="mini" @click="openVerifyDialog()" v-hasPermi="['biz:order:verify']">核销</el-button>
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
      <el-table-column label="操作" align="center" width="180" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-view" @click="handleView(scope.row)">详情</el-button>
          <el-button v-if="scope.row.status === '1'" size="mini" type="text" icon="el-icon-check" v-hasPermi="['biz:order:verify']" @click="handleQuickVerify(scope.row)">核销</el-button>
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

    <!-- 核销弹窗 -->
    <el-dialog title="订单核销" :visible.sync="verifyOpen" width="500px" append-to-body @closed="resetVerifyForm">
      <el-form ref="verifyForm" :model="verifyForm" :rules="verifyRules" label-width="100px">
        <el-form-item label="核销码" prop="verifyCode">
          <el-input v-model="verifyForm.verifyCode" placeholder="请输入会员出示的 12 位核销码" maxlength="32" clearable style="width: 100%" />
        </el-form-item>
        <el-form-item label="订单编号" prop="orderNo">
          <el-input v-model="verifyForm.orderNo" placeholder="（可选）填写订单编号可直接核销" maxlength="32" clearable style="width: 100%" />
        </el-form-item>
        <el-alert v-if="verifyResult" :title="verifyResultTitle" :type="verifyResultType" :closable="false" show-icon style="margin-top: 8px">
          <div slot="default">
            <div v-if="verifyResult.orderNo">订单编号：{{ verifyResult.orderNo }}</div>
            <div v-if="verifyResult.productName">商品：{{ verifyResult.productName }}</div>
            <div v-if="verifyResult.storeName">门店：{{ verifyResult.storeName }}</div>
            <div v-if="verifyResult.memberName">会员：{{ verifyResult.memberName }}</div>
            <div v-if="verifyResult.payAmount">实付金额：¥{{ verifyResult.payAmount }}</div>
            <div v-if="verifyResult.verifyTime">核销时间：{{ verifyResult.verifyTime }}</div>
          </div>
        </el-alert>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button @click="verifyOpen = false">关 闭</el-button>
        <el-button type="primary" :loading="verifyLoading" @click="submitVerify">确认核销</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listOrder, getOrder, delOrder, verifyOrder } from "@/api/biz/order"

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
        merchantId: null,
        storeIds: [],
        memberIds: [],
        productIds: [],
        status: null
      },
      // 商户筛选：平台/代理商账号显示；商户账号自动隐藏（自带 merchantId 上下文）
      showMerchantFilter: this.isShowMerchantFilter(),
      form: {},
      // 核销弹窗
      verifyOpen: false,
      verifyLoading: false,
      verifyForm: {
        verifyCode: '',
        orderNo: ''
      },
      verifyRules: {
        verifyCode: [
          { required: true, message: '请输入核销码', trigger: 'blur' },
          { min: 4, max: 32, message: '核销码长度 4-32 位', trigger: 'blur' }
        ]
      },
      verifyResult: null,
      verifyResultType: 'success',
      verifyResultTitle: ''
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
        merchantId: this.queryParams.merchantId,
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
        merchantId: null,
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
    },
    isShowMerchantFilter() {
      // 商户账号自带 merchantId 上下文，前端再筛无意义
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    // 打开核销弹窗（顶部工具栏按钮）
    openVerifyDialog() {
      this.verifyOpen = true
    },
    // 行内快捷核销（直接把订单的核销码填入弹窗）
    handleQuickVerify(row) {
      this.verifyForm.verifyCode = row.verifyCode || ''
      this.verifyForm.orderNo = row.orderNo || ''
      this.verifyOpen = true
    },
    resetVerifyForm() {
      this.verifyForm = { verifyCode: '', orderNo: '' }
      this.verifyResult = null
      this.verifyResultType = 'success'
      this.verifyResultTitle = ''
      if (this.$refs.verifyForm) this.$refs.verifyForm.clearValidate()
    },
    submitVerify() {
      this.$refs.verifyForm.validate((valid) => {
        if (!valid) return
        const payload = {}
        const code = (this.verifyForm.verifyCode || '').trim()
        const no = (this.verifyForm.orderNo || '').trim()
        if (code) payload.verifyCode = code
        if (no) payload.orderNo = no
        if (!code && !no) {
          this.$modal.msgError('核销码和订单编号至少填一个')
          return
        }
        this.verifyLoading = true
        verifyOrder(payload).then((res) => {
          this.verifyResult = res.data || res
          this.verifyResultType = 'success'
          this.verifyResultTitle = '核销成功'
          this.$modal.msgSuccess('核销成功')
          this.getList()
        }).catch((err) => {
          this.verifyResult = null
          this.verifyResultType = 'error'
          this.verifyResultTitle = (err && (err.msg || err.message)) || '核销失败'
          this.$modal.msgError(this.verifyResultTitle)
        }).finally(() => {
          this.verifyLoading = false
        })
      })
    }
  }
}
</script>
