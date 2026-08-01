<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="标题" prop="title">
        <el-input
          v-model="queryParams.title"
          placeholder="请输入标题"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
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
          v-hasPermi="['biz:agreement:add']"
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
          v-hasPermi="['biz:agreement:edit']"
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
          v-hasPermi="['biz:agreement:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:agreement:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="agreementList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="协议ID" align="center" prop="agreementId" />
      <el-table-column label="类型" align="center" prop="agreementType" />
      <el-table-column label="标题" align="center" prop="title" />
      <el-table-column label="协议内容" align="center" prop="content" />
      <el-table-column label="门店" align="center" prop="storeName">
        <template slot-scope="scope">{{ scope.row.storeName || (scope.row.storeId === 0 ? '全部门店' : scope.row.storeId) }}</template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{ scope.row.status === '0' ? '正常' : '停用' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:agreement:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:agreement:remove']"
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

    <!-- 添加或修改协议对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="标题" prop="title">
              <el-input v-model="form.title" placeholder="请输入标题" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="协议内容">
              <editor v-model="form.content" :min-height="192"/>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店" prop="storeId">
              <biz-select v-model="form.storeId" type="store" />
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
import { listAgreement, getAgreement, delAgreement, addAgreement, updateAgreement } from "@/api/biz/agreement"

export default {
  name: "Agreement",
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
      // 协议表格数据
      agreementList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        agreementType: null,
        title: null,
        content: null,
        storeIds: [],
        status: null,
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        agreementType: [
          { required: true, message: "类型不能为空", trigger: "change" }
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
    /** 查询协议列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = Object.assign({}, p.params, { storeIds: this.queryParams.storeIds })
      delete p.storeIds
      return p
    },
    getList() {
      this.loading = true
      listAgreement(this.buildParams()).then(response => {
        this.agreementList = response.rows
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
        agreementId: null,
        agreementType: null,
        title: null,
        content: null,
        storeId: null,
        status: null,
        createBy: null,
        createTime: null,
        updateBy: null,
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
      this.resetForm("queryForm")
      this.handleQuery()
    },
    // 多选框选中数据
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.agreementId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加协议"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const agreementId = row.agreementId || this.ids
      getAgreement(agreementId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改协议"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.agreementId != null) {
            updateAgreement(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addAgreement(this.form).then(response => {
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
      const agreementIds = row.agreementId || this.ids
      this.$modal.confirm('是否确认删除协议编号为"' + agreementIds + '"的数据项？').then(function() {
        return delAgreement(agreementIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/agreement/export', {
        ...this.buildParams()
      }, `agreement_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
