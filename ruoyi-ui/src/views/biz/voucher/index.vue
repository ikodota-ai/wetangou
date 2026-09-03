<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" :merchant-id="queryParams.merchantId" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="代金券名称" prop="voucherName">
        <el-input
          v-model="queryParams.voucherName"
          placeholder="请输入代金券名称"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="面额" prop="faceValue">
        <el-input
          v-model="queryParams.faceValue"
          placeholder="请输入面额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="使用门槛" prop="threshold">
        <el-input
          v-model="queryParams.threshold"
          placeholder="请输入使用门槛"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="发放总量" prop="total">
        <el-input
          v-model="queryParams.total"
          placeholder="请输入发放总量"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="已领取数量" prop="received">
        <el-input
          v-model="queryParams.received"
          placeholder="请输入已领取数量"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="有效期开始" prop="validFrom">
        <el-date-picker clearable
          v-model="queryParams.validFrom"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择有效期开始">
        </el-date-picker>
      </el-form-item>
      <el-form-item label="有效期结束" prop="validTo">
        <el-date-picker clearable
          v-model="queryParams.validTo"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择有效期结束">
        </el-date-picker>
      </el-form-item>
      <el-form-item label="领取后有效天数" prop="validDays">
        <el-input
          v-model="queryParams.validDays"
          placeholder="请输入领取后有效天数"
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
          v-hasPermi="['biz:voucher:add']"
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
          v-hasPermi="['biz:voucher:edit']"
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
          v-hasPermi="['biz:voucher:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:voucher:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="voucherList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="代金券ID" align="center" prop="voucherId" />
      <el-table-column label="门店" align="center" prop="storeName">
        <template slot-scope="scope">{{ scope.row.storeName || (scope.row.storeId === 0 ? '全部门店' : scope.row.storeId) }}</template>
      </el-table-column>
      <el-table-column label="代金券名称" align="center" prop="voucherName" />
      <el-table-column label="面额" align="center" prop="faceValue" />
      <el-table-column label="使用门槛" align="center" prop="threshold" />
      <el-table-column label="发放总量" align="center" prop="total" />
      <el-table-column label="已领取数量" align="center" prop="received" />
      <el-table-column label="有效期开始" align="center" prop="validFrom" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.validFrom, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="有效期结束" align="center" prop="validTo" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.validTo, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="领取后有效天数" align="center" prop="validDays" />
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
            v-hasPermi="['biz:voucher:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:voucher:remove']"
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

    <!-- 添加或修改代金券模板对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="所属商户" prop="merchantId" v-if="showMerchantFilter">
              <biz-select v-model="form.merchantId" type="merchant" @change="onFormMerchantChange" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店" prop="storeId">
              <biz-select v-model="form.storeId" type="store" :merchant-id="form.merchantId" :require-merchant="showMerchantFilter" auto-pick-single />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="代金券名称" prop="voucherName">
              <el-input v-model="form.voucherName" placeholder="请输入代金券名称" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="面额" prop="faceValue">
              <el-input v-model="form.faceValue" placeholder="请输入面额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="使用门槛" prop="threshold">
              <el-input v-model="form.threshold" placeholder="请输入使用门槛" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="发放总量" prop="total">
              <el-input v-model="form.total" placeholder="请输入发放总量" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="已领取数量" prop="received">
              <el-input v-model="form.received" placeholder="请输入已领取数量" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="有效期开始" prop="validFrom">
              <el-date-picker clearable
                v-model="form.validFrom"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择有效期开始">
              </el-date-picker>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="有效期结束" prop="validTo">
              <el-date-picker clearable
                v-model="form.validTo"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择有效期结束">
              </el-date-picker>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="领取后有效天数" prop="validDays">
              <el-input v-model="form.validDays" placeholder="请输入领取后有效天数" />
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
import { showMerchantField, currentMerchantId as identityMerchantId } from "@/utils/identity"
import { listVoucher, getVoucher, delVoucher, addVoucher, updateVoucher } from "@/api/biz/voucher"

export default {
  name: "Voucher",
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
      // 代金券模板表格数据
      voucherList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        storeIds: [],
        voucherName: null,
        faceValue: null,
        threshold: null,
        total: null,
        received: null,
        validFrom: null,
        validTo: null,
        validDays: null,
        status: null,
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        voucherName: [
          { required: true, message: "代金券名称不能为空", trigger: "blur" }
        ],
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    isShowMerchantFilter() {
      return showMerchantField()
    },
    // 商户账号自带 merchantId 上下文，表单直接落自己的商户，不给选
    currentMerchantId() {
      return identityMerchantId()
    },
    // 换商户必须清空已选门店：否则会留下上一个商户的 storeId，
    // 提交时门店与商户不属于同一家，后端归属校验直接拒
    onFormMerchantChange() {
      this.form.storeId = null
    },
    /** 查询代金券模板列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = Object.assign({}, p.params, { storeIds: this.queryParams.storeIds })
      delete p.storeIds
      return p
    },
    getList() {
      this.loading = true
      listVoucher(this.buildParams()).then(response => {
        this.voucherList = response.rows
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
        merchantId: this.currentMerchantId() || null,
        voucherId: null,
        storeId: null,
        voucherName: null,
        faceValue: null,
        threshold: null,
        total: null,
        received: null,
        validFrom: null,
        validTo: null,
        validDays: null,
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
      this.ids = selection.map(item => item.voucherId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加代金券模板"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const voucherId = row.voucherId || this.ids
      getVoucher(voucherId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改代金券模板"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.voucherId != null) {
            updateVoucher(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addVoucher(this.form).then(response => {
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
      const voucherIds = row.voucherId || this.ids
      this.$modal.confirm('是否确认删除代金券模板编号为"' + voucherIds + '"的数据项？').then(function() {
        return delVoucher(voucherIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/voucher/export', {
        ...this.buildParams()
      }, `voucher_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
