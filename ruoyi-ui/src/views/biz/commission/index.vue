<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="推客" prop="distributorIds">
        <biz-select v-model="queryParams.distributorIds" type="distributor" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="订单ID" prop="orderId">
        <el-input
          v-model="queryParams.orderId"
          placeholder="请输入订单ID"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
      </el-form-item>
      <el-form-item label="佣金金额" prop="amount">
        <el-input
          v-model="queryParams.amount"
          placeholder="请输入佣金金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="佣金比例(%)" prop="rate">
        <el-input
          v-model="queryParams.rate"
          placeholder="请输入佣金比例(%)"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="结算时间" prop="settleTime">
        <el-date-picker clearable
          v-model="queryParams.settleTime"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择结算时间">
        </el-date-picker>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button
          type="primary"
          plain
          icon="el-icon-plus"
          size="mini"
          @click="handleAdd"
          v-hasPermi="['biz:commission:add']"
        >新增</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="el-icon-edit"
          size="mini"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['biz:commission:edit']"
        >修改</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="danger"
          plain
          icon="el-icon-delete"
          size="mini"
          :disabled="multiple"
          @click="handleDelete"
          v-hasPermi="['biz:commission:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="el-icon-money"
          size="mini"
          @click="handleSettle"
          v-hasPermi="['biz:commission:edit']"
        >结算到期佣金</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:commission:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="commissionList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="佣金ID" align="center" prop="commissionId" />
      <el-table-column label="推客" align="center" prop="memberName">
        <template slot-scope="scope">{{ scope.row.memberName || ('推客' + scope.row.distributorId) }}</template>
      </el-table-column>
      <el-table-column label="订单编号" align="center" prop="orderNo">
        <template slot-scope="scope">{{ scope.row.orderNo || scope.row.orderId }}</template>
      </el-table-column>
      <el-table-column label="门店" align="center" prop="storeName">
        <template slot-scope="scope">{{ scope.row.storeName || scope.row.storeId }}</template>
      </el-table-column>
      <el-table-column label="佣金金额" align="center" prop="amount" />
      <el-table-column label="佣金比例(%)" align="center" prop="rate" />
      <el-table-column label="状态" align="center" prop="status" />
      <el-table-column label="结算时间" align="center" prop="settleTime" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.settleTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:commission:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:commission:remove']"
          >删除</el-button>
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

    <!-- 添加或修改佣金明细对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="推客" prop="distributorId">
              <biz-select v-model="form.distributorId" type="distributor" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="订单ID" prop="orderId">
              <el-input v-model="form.orderId" placeholder="请输入订单ID" />
            </el-form-item>
          </el-col>
          <el-col :span="24" v-if="!isMerchant()">
            <el-form-item label="所属商户" prop="merchantId">
              <biz-select v-model="form.merchantId" type="merchant" @change="onMerchantChange" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店" prop="storeId">
              <biz-select v-model="form.storeId" type="store" :merchant-id="form.merchantId" auto-pick-single @auto-pick="onStoreAutoPick" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="佣金金额" prop="amount">
              <el-input v-model="form.amount" placeholder="请输入佣金金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="佣金比例(%)" prop="rate">
              <el-input v-model="form.rate" placeholder="请输入佣金比例(%)" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="结算时间" prop="settleTime">
              <el-date-picker clearable
                v-model="form.settleTime"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择结算时间">
              </el-date-picker>
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listCommission, getCommission, delCommission, addCommission, updateCommission, settleCommission } from "@/api/biz/commission"

export default {
  name: "Commission",
  data() {
    return {
      // 遮罩层
      loading: true,
      // 选中数组
      ids: [],
      // 非单个禁用
      single: true,
      // 非多个禁用
      multiple: true,
      // 显示搜索条件
      showSearch: true,
      // 总条数
      total: 0,
      // 佣金明细表格数据
      commissionList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        distributorIds: [],
        orderId: null,
        storeIds: [],
        amount: null,
        rate: null,
        status: null,
        settleTime: null,
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        distributorId: [
          { required: true, message: "推客ID不能为空", trigger: "blur" }
        ],
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    // 商户账号自带 merchantId 上下文，表单里隐藏"所属商户"下拉
    isMerchant() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType === '2'
    },
    // 商户账号登录时，从 vuex 取自己的 merchantId
    currentMerchantId() {
      const u = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.user) || {}
      return u.merchantId || null
    },
    // 切换商户时清空已选门店（防越权）
    onMerchantChange(val) {
      this.form.storeId = null
    },
    onStoreAutoPick(val, row) {
      this.$modal && this.$modal.msgSuccess && this.$modal.msgSuccess(`已自动选中唯一门店：${row.storeName}`)
    },
    /** 查询佣金明细列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = { storeIds: this.queryParams.storeIds, distributorIds: this.queryParams.distributorIds }
      delete p.storeIds
      delete p.distributorIds
      return p
    },
    getList() {
      this.loading = true
      listCommission(this.buildParams()).then(response => {
        this.commissionList = response.rows
        this.total = response.total
        this.loading = false
      })
    },
    // 取消按钮
    cancel() {
      this.open = false
      this.reset()
    },
    // 表单重置
    reset() {
      this.form = {
        commissionId: null,
        merchantId: this.currentMerchantId() || null,
        distributorId: null,
        orderId: null,
        storeId: null,
        amount: null,
        rate: null,
        status: null,
        settleTime: null,
        createTime: null
      }
      this.resetForm("form")
    },
    /** 搜索按钮操作 */
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    /** 重置按钮操作 */
    resetQuery() {
      this.queryParams.storeIds = []
      this.queryParams.distributorIds = []
      this.resetForm("queryForm")
      this.handleQuery()
    },
    // 多选框选中数据
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.commissionId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加佣金明细"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const commissionId = row.commissionId || this.ids
      getCommission(commissionId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改佣金明细"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.commissionId != null) {
            updateCommission(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addCommission(this.form).then(response => {
              this.$modal.msgSuccess("新增成功")
              this.open = false
              this.getList()
            })
          }
        }
      })
    },
    /** 删除按钮操作 */
    handleDelete(row) {
      const commissionIds = row.commissionId || this.ids
      this.$modal.confirm('是否确认删除佣金明细编号为"' + commissionIds + '"的数据项？').then(function() {
        return delCommission(commissionIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 结算到期佣金 */
    handleSettle() {
      this.$modal.confirm('确认结算所有已过冷静期的待结算佣金？将把对应冻结金额转入推客可提现余额。').then(() => {
        return settleCommission()
      }).then((res) => {
        this.getList()
        this.$modal.msgSuccess(res.msg || "结算成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/commission/export', {
        ...this.buildParams()
      }, `commission_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
