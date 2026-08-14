<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="会员" prop="memberIds">
        <biz-select v-model="queryParams.memberIds" type="member" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="推客等级" prop="level">
        <el-input
          v-model="queryParams.level"
          placeholder="请输入推客等级"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="累计佣金" prop="totalCommission">
        <el-input
          v-model="queryParams.totalCommission"
          placeholder="请输入累计佣金"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="可提现金额" prop="availableAmount">
        <el-input
          v-model="queryParams.availableAmount"
          placeholder="请输入可提现金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="冻结金额" prop="frozenAmount">
        <el-input
          v-model="queryParams.frozenAmount"
          placeholder="请输入冻结金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="已提现金额" prop="withdrawAmount">
        <el-input
          v-model="queryParams.withdrawAmount"
          placeholder="请输入已提现金额"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="成为推客时间" prop="joinTime">
        <el-date-picker clearable
          v-model="queryParams.joinTime"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择成为推客时间">
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
          v-hasPermi="['biz:distributor:add']"
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
          v-hasPermi="['biz:distributor:edit']"
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
          v-hasPermi="['biz:distributor:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:distributor:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="distributorList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="推客ID" align="center" prop="distributorId" />
      <el-table-column label="会员" align="center" prop="memberName">
        <template slot-scope="scope">{{ scope.row.memberName || ('会员' + scope.row.memberId) }}</template>
      </el-table-column>
      <el-table-column label="推客等级" align="center" prop="level" />
      <el-table-column label="累计佣金" align="center" prop="totalCommission" />
      <el-table-column label="可提现金额" align="center" prop="availableAmount" />
      <el-table-column label="冻结金额" align="center" prop="frozenAmount" />
      <el-table-column label="已提现金额" align="center" prop="withdrawAmount" />
      <el-table-column label="状态" align="center" prop="status" />
      <el-table-column label="成为推客时间" align="center" prop="joinTime" width="180">
        <template slot-scope="scope">
          <span>{{ parseTime(scope.row.joinTime, '{y}-{m}-{d}') }}</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:distributor:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-picture"
            @click="handleQrcode(scope.row)"
            v-hasPermi="['biz:distributor:query']"
          >二维码</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:distributor:remove']"
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

    <!-- 添加或修改推客对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="500px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="会员" prop="memberId">
              <biz-select v-model="form.memberId" type="member" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="推客等级" prop="level">
              <el-input v-model="form.level" placeholder="请输入推客等级" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="累计佣金" prop="totalCommission">
              <el-input v-model="form.totalCommission" placeholder="请输入累计佣金" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="可提现金额" prop="availableAmount">
              <el-input v-model="form.availableAmount" placeholder="请输入可提现金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="冻结金额" prop="frozenAmount">
              <el-input v-model="form.frozenAmount" placeholder="请输入冻结金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="已提现金额" prop="withdrawAmount">
              <el-input v-model="form.withdrawAmount" placeholder="请输入已提现金额" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="成为推客时间" prop="joinTime">
              <el-date-picker clearable
                v-model="form.joinTime"
                type="date"
                value-format="yyyy-MM-dd"
                placeholder="请选择成为推客时间">
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

    <!-- E4: 推客太阳码预览 -->
    <el-dialog title="推客太阳码" :visible.sync="qrcodeOpen" width="420px" append-to-body>
      <div style="text-align:center;">
        <div v-if="qrcodeLoading" v-loading="true" style="height:320px;"></div>
        <template v-else>
          <el-image
            v-if="qrcodeUrl"
            :src="qrcodeUrl"
            fit="contain"
            style="width:360px;height:360px;border:1px solid #ebeef5;"
          />
          <div style="margin-top:12px;color:#909399;font-size:12px;">
            scene: <code>{{ qrcodeScene }}</code>
            <span v-if="qrcodeCached" style="margin-left:8px;color:#67c23a;">[缓存命中]</span>
          </div>
          <div style="margin-top:8px;">
            <el-link :href="qrcodeUrl" target="_blank" type="primary">新窗口打开</el-link>
          </div>
        </template>
      </div>
    </el-dialog>

  </div>
</template>

<script>
import { listDistributor, getDistributor, delDistributor, addDistributor, updateDistributor, getDistributorQrcode } from "@/api/biz/distributor"

export default {
  name: "Distributor",
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
      // 推客表格数据
      distributorList: [],
      // 弹出层标题
      title: "",
      // 是否显示弹出层
      open: false,
      // 查询参数
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        memberIds: [],
        level: null,
        totalCommission: null,
        availableAmount: null,
        frozenAmount: null,
        withdrawAmount: null,
        status: null,
        joinTime: null,
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        memberId: [
          { required: true, message: "会员ID不能为空", trigger: "blur" }
        ],
      },
      // E4: 推客太阳码预览
      qrcodeOpen: false,
      qrcodeLoading: false,
      qrcodeUrl: '',
      qrcodeScene: '',
      qrcodeCached: false
    }
  },
  created() {
    this.getList()
  },
    /** E4: 推客太阳码预览 */
    handleQrcode(row) {
      this.qrcodeOpen = true
      this.qrcodeLoading = true
      this.qrcodeUrl = ''
      this.qrcodeScene = ''
      this.qrcodeCached = false
      getDistributorQrcode(row.distributorId).then(res => {
        this.qrcodeLoading = false
        this.qrcodeUrl = res.url || ''
        this.qrcodeScene = res.scene || ''
        this.qrcodeCached = res.cached === true
      }).catch(() => {
        this.qrcodeLoading = false
        this.$message.error('获取二维码失败')
      })
    },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    /** 查询推客列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = { memberIds: this.queryParams.memberIds }
      delete p.memberIds
      return p
    },
    getList() {
      this.loading = true
      listDistributor(this.buildParams()).then(response => {
        this.distributorList = response.rows
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
        distributorId: null,
        memberId: null,
        level: null,
        totalCommission: null,
        availableAmount: null,
        frozenAmount: null,
        withdrawAmount: null,
        status: null,
        joinTime: null,
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
      this.queryParams.memberIds = []
      this.resetForm("queryForm")
      this.handleQuery()
    },
    // 多选框选中数据
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.distributorId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加推客"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const distributorId = row.distributorId || this.ids
      getDistributor(distributorId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改推客"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.distributorId != null) {
            updateDistributor(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addDistributor(this.form).then(response => {
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
      const distributorIds = row.distributorId || this.ids
      this.$modal.confirm('是否确认删除推客编号为"' + distributorIds + '"的数据项？').then(function() {
        return delDistributor(distributorIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/distributor/export', {
        ...this.buildParams()
      }, `distributor_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
