<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="买单编号" prop="billNo">
        <el-input
          v-model="queryParams.billNo"
          placeholder="请输入买单编号"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="关联订单ID" prop="orderId">
        <el-input
          v-model="queryParams.orderId"
          placeholder="请输入关联订单ID"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
      </el-form-item>
      <el-form-item label="会员" prop="memberIds">
        <biz-select v-model="queryParams.memberIds" type="member" multiple width="220px" />
      </el-form-item>
      <el-form-item label="消费金额" prop="amount">
        <el-input
          v-model="queryParams.amount"
          placeholder="请输入消费金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="使用的会员代金券ID" prop="memberVoucherId">
        <el-input
          v-model="queryParams.memberVoucherId"
          placeholder="请输入使用的会员代金券ID"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="优惠金额" prop="discountAmount">
        <el-input
          v-model="queryParams.discountAmount"
          placeholder="请输入优惠金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="实付金额" prop="payAmount">
        <el-input
          v-model="queryParams.payAmount"
          placeholder="请输入实付金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="确认店员" prop="confirmUser">
        <el-input
          v-model="queryParams.confirmUser"
          placeholder="请输入确认店员"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="确认时间" prop="confirmTime">
        <el-date-picker clearable
          v-model="queryParams.confirmTime"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择确认时间">
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
          v-hasPermi="['biz:bill:add']"
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
          v-hasPermi="['biz:bill:edit']"
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
          v-hasPermi="['biz:bill:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:bill:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="billList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="买单ID" align="center" prop="billId" />
      <el-table-column label="买单编号" align="center" prop="billNo" />
      <el-table-column label="关联订单ID" align="center" prop="orderId" />
      <el-table-column label="门店" align="center" prop="storeName">
        <template slot-scope="scope">{{ scope.row.storeName || scope.row.storeId }}</template>
      </el-table-column>
      <el-table-column label="会员" align="center" prop="memberName">
        <template slot-scope="scope">{{ scope.row.memberName || ('会员' + scope.row.memberId) }}</template>
      </el-table-column>
      <el-table-column label="消费金额" align="center" prop="amount" />
      <el-table-column label="使用的会员代金券ID" align="center" prop="memberVoucherId" />
      <el-table-column label="优惠金额" align="center" prop="discountAmount" />
      <el-table-column label="实付金额" align="center" prop="payAmount" />
      <el-table-column label="确认店员" align="center" prop="confirmUser" />
      <el-table-column label="确认时间" align="center" prop="confirmTime" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.confirmTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" />
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:bill:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:bill:remove']"
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

    <!-- 添加或修改买单流水对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="买单编号" prop="billNo">
              <el-input v-model="form.billNo" placeholder="请输入买单编号" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="关联订单ID" prop="orderId">
              <el-input v-model="form.orderId" placeholder="请输入关联订单ID" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店" prop="storeId">
              <biz-select v-model="form.storeId" type="store" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="会员" prop="memberId">
              <biz-select v-model="form.memberId" type="member" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="消费金额" prop="amount">
              <el-input v-model="form.amount" placeholder="请输入消费金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="使用的会员代金券ID" prop="memberVoucherId">
              <el-input v-model="form.memberVoucherId" placeholder="请输入使用的会员代金券ID" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="优惠金额" prop="discountAmount">
              <el-input v-model="form.discountAmount" placeholder="请输入优惠金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="实付金额" prop="payAmount">
              <el-input v-model="form.payAmount" placeholder="请输入实付金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="确认店员" prop="confirmUser">
              <el-input v-model="form.confirmUser" placeholder="请输入确认店员" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="确认时间" prop="confirmTime">
              <el-date-picker clearable
                v-model="form.confirmTime"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择确认时间">
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
import { listBill, getBill, delBill, addBill, updateBill } from "@/api/biz/bill"

export default {
  name: "Bill",
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
      // 买单流水表格数据
      billList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        billNo: null,
        orderId: null,
        storeIds: [],
        memberIds: [],
        amount: null,
        memberVoucherId: null,
        discountAmount: null,
        payAmount: null,
        confirmUser: null,
        confirmTime: null,
        status: null,
      },
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        billNo: [
          { required: true, message: "买单编号不能为空", trigger: "blur" }
        ],
        storeId: [
          { required: true, message: "门店ID不能为空", trigger: "blur" }
        ],
        memberId: [
          { required: true, message: "会员ID不能为空", trigger: "blur" }
        ],
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    /** 查询买单流水列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = { storeIds: this.queryParams.storeIds, memberIds: this.queryParams.memberIds }
      delete p.storeIds
      delete p.memberIds
      return p
    },
    getList() {
      this.loading = true
      listBill(this.buildParams()).then(response => {
        this.billList = response.rows
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
        billId: null,
        billNo: null,
        orderId: null,
        storeId: null,
        memberId: null,
        amount: null,
        memberVoucherId: null,
        discountAmount: null,
        payAmount: null,
        confirmUser: null,
        confirmTime: null,
        status: null,
        createTime: null,
        updateTime: null
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
      this.queryParams.memberIds = []
      this.resetForm("queryForm")
      this.handleQuery()
    },
    // 多选框选中数据
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.billId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加买单流水"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const billId = row.billId || this.ids
      getBill(billId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改买单流水"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.billId != null) {
            updateBill(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addBill(this.form).then(response => {
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
      const billIds = row.billId || this.ids
      this.$modal.confirm('是否确认删除买单流水编号为"' + billIds + '"的数据项？').then(function() {
        return delBill(billIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/bill/export', {
        ...this.buildParams()
      }, `bill_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
