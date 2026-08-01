<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="提现单号" prop="withdrawNo">
        <el-input
          v-model="queryParams.withdrawNo"
          placeholder="请输入提现单号"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="推客" prop="distributorIds">
        <biz-select v-model="queryParams.distributorIds" type="distributor" multiple width="220px" />
      </el-form-item>
      <el-form-item label="提现金额" prop="amount">
        <el-input
          v-model="queryParams.amount"
          placeholder="请输入提现金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="收款账户" prop="account">
        <el-input
          v-model="queryParams.account"
          placeholder="请输入收款账户"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="收款人姓名" prop="accountName">
        <el-input
          v-model="queryParams.accountName"
          placeholder="请输入收款人姓名"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="申请时间" prop="applyTime">
        <el-date-picker clearable
          v-model="queryParams.applyTime"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择申请时间">
        </el-date-picker>
      </el-form-item>
      <el-form-item label="完成时间" prop="finishTime">
        <el-date-picker clearable
          v-model="queryParams.finishTime"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择完成时间">
        </el-date-picker>
      </el-form-item>
      <el-form-item label="失败原因" prop="failReason">
        <el-input
          v-model="queryParams.failReason"
          placeholder="请输入失败原因"
          clearable
          @keyup.enter.native="handleQuery"
        />
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
          v-hasPermi="['biz:withdraw:add']"
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
          v-hasPermi="['biz:withdraw:edit']"
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
          v-hasPermi="['biz:withdraw:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:withdraw:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="withdrawList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="提现ID" align="center" prop="withdrawId" />
      <el-table-column label="提现单号" align="center" prop="withdrawNo" />
      <el-table-column label="推客" align="center" prop="memberName">
        <template slot-scope="scope">{{ scope.row.memberName || ('推客' + scope.row.distributorId) }}</template>
      </el-table-column>
      <el-table-column label="提现金额" align="center" prop="amount" />
      <el-table-column label="方式" align="center" prop="withdrawType">
        <template slot-scope="scope">
          <span>{{ scope.row.withdrawType === '1' ? '支付宝' : '微信' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="收款账户" align="center" prop="account" />
      <el-table-column label="收款人姓名" align="center" prop="accountName" />
      <el-table-column label="状态" align="center" prop="status">
        <template slot-scope="scope">
          <el-tag v-if="scope.row.status === '0'" type="warning">处理中</el-tag>
          <el-tag v-else-if="scope.row.status === '1'" type="success">已到账</el-tag>
          <el-tag v-else-if="scope.row.status === '2'" type="danger">已驳回</el-tag>
          <span v-else>{{ scope.row.status }}</span>
        </template>
      </el-table-column>
      <el-table-column label="申请时间" align="center" prop="applyTime" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.applyTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="完成时间" align="center" prop="finishTime" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.finishTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="失败原因" align="center" prop="failReason" />
      <el-table-column label="操作" align="center" width="200" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            v-if="scope.row.status === '0'"
            size="mini"
            type="text"
            icon="el-icon-check"
            @click="handleApprove(scope.row)"
            v-hasPermi="['biz:withdraw:edit']"
          >通过</el-button>
          <el-button
            v-if="scope.row.status === '0'"
            size="mini"
            type="text"
            icon="el-icon-close"
            @click="handleReject(scope.row)"
            v-hasPermi="['biz:withdraw:edit']"
          >驳回</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:withdraw:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:withdraw:remove']"
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

    <!-- 添加或修改提现记录对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="提现单号" prop="withdrawNo">
              <el-input v-model="form.withdrawNo" placeholder="请输入提现单号" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="推客" prop="distributorId">
              <biz-select v-model="form.distributorId" type="distributor" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="提现金额" prop="amount">
              <el-input v-model="form.amount" placeholder="请输入提现金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="收款账户" prop="account">
              <el-input v-model="form.account" placeholder="请输入收款账户" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="收款人姓名" prop="accountName">
              <el-input v-model="form.accountName" placeholder="请输入收款人姓名" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="申请时间" prop="applyTime">
              <el-date-picker clearable
                v-model="form.applyTime"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择申请时间">
              </el-date-picker>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="完成时间" prop="finishTime">
              <el-date-picker clearable
                v-model="form.finishTime"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择完成时间">
              </el-date-picker>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="失败原因" prop="failReason">
              <el-input v-model="form.failReason" placeholder="请输入失败原因" />
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
import { listWithdraw, getWithdraw, delWithdraw, addWithdraw, updateWithdraw, auditWithdraw } from "@/api/biz/withdraw"

export default {
  name: "Withdraw",
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
      // 提现记录表格数据
      withdrawList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        withdrawNo: null,
        distributorIds: [],
        amount: null,
        withdrawType: null,
        account: null,
        accountName: null,
        status: null,
        applyTime: null,
        finishTime: null,
        failReason: null,
      },
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        withdrawNo: [
          { required: true, message: "提现单号不能为空", trigger: "blur" }
        ],
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
    /** 查询提现记录列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = { distributorIds: this.queryParams.distributorIds }
      delete p.distributorIds
      return p
    },
    getList() {
      this.loading = true
      listWithdraw(this.buildParams()).then(response => {
        this.withdrawList = response.rows
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
        withdrawId: null,
        withdrawNo: null,
        distributorId: null,
        amount: null,
        withdrawType: null,
        account: null,
        accountName: null,
        status: null,
        applyTime: null,
        finishTime: null,
        failReason: null,
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
      this.queryParams.distributorIds = []
      this.resetForm("queryForm")
      this.handleQuery()
    },
    // 多选框选中数据
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.withdrawId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加提现记录"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const withdrawId = row.withdrawId || this.ids
      getWithdraw(withdrawId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改提现记录"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.withdrawId != null) {
            updateWithdraw(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addWithdraw(this.form).then(response => {
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
      const withdrawIds = row.withdrawId || this.ids
      this.$modal.confirm('是否确认删除提现记录编号为"' + withdrawIds + '"的数据项？').then(function() {
        return delWithdraw(withdrawIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 提现审核通过 */
    handleApprove(row) {
      this.$modal.confirm('确认通过推客 ' + row.distributorId + ' 的提现申请（金额 ' + row.amount + ' 元）？').then(() => {
        return auditWithdraw({ withdrawId: row.withdrawId, status: "1" })
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("审核通过")
      }).catch(() => {})
    },
    /** 提现审核驳回 */
    handleReject(row) {
      this.$prompt('请输入驳回原因', '驳回提现', {
        confirmButtonText: "确定",
        cancelButtonText: "取消",
        inputValidator: (v) => (v && v.trim().length > 0) ? true : "驳回原因不能为空"
      }).then(({ value }) => {
        return auditWithdraw({ withdrawId: row.withdrawId, status: "2", failReason: value })
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("已驳回，金额已退回可提现余额")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/withdraw/export', {
        ...this.buildParams()
      }, `withdraw_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
