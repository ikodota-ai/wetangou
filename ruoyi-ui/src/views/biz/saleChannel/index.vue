<template>
  <div class="app-container">
    <el-alert type="info" :closable="false" show-icon style="margin-bottom: 12px">
      投放渠道是平台级保底配置：商户建品时只能在这里维护的渠道中勾选，不能自行增删渠道。
      勾了「默认勾选」的渠道，商户新建商品时会自动带上。
    </el-alert>

    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="渠道名称" prop="channelName">
        <el-input v-model="queryParams.channelName" placeholder="请输入渠道名称" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="分组" prop="channelGroup">
        <el-select v-model="queryParams.channelGroup" placeholder="全部" clearable style="width: 140px">
          <el-option v-for="g in groupOptions" :key="g.value" :label="g.label" :value="g.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 120px">
          <el-option label="启用" value="0" />
          <el-option label="停用" value="1" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="el-icon-plus" size="mini" @click="handleAdd" v-hasPermi="['biz:saleChannel:add']">新增</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="success" plain icon="el-icon-edit" size="mini" :disabled="single" @click="handleUpdate" v-hasPermi="['biz:saleChannel:edit']">修改</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:saleChannel:remove']">删除</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="channelList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="渠道代码" align="center" prop="channelCode" width="150" />
      <el-table-column label="渠道名称" align="center" prop="channelName" width="140" />
      <el-table-column label="分组" align="center" prop="channelGroup" width="110">
        <template slot-scope="scope">{{ groupLabel(scope.row.channelGroup) }}</template>
      </el-table-column>
      <el-table-column label="投放规则说明" align="left" prop="channelDesc" show-overflow-tooltip />
      <el-table-column label="默认勾选" align="center" prop="isDefault" width="100">
        <template slot-scope="scope">
          <el-tag :type="scope.row.isDefault === 1 ? 'success' : 'info'">{{ scope.row.isDefault === 1 ? '是' : '否' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="80" />
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{ scope.row.status === '0' ? '启用' : '停用' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="150" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-edit" @click="handleUpdate(scope.row)" v-hasPermi="['biz:saleChannel:edit']">修改</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:saleChannel:remove']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total > 0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />

    <el-dialog :title="title" :visible.sync="open" width="560px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="110px">
        <el-form-item label="渠道代码" prop="channelCode">
          <el-input v-model="form.channelCode" :disabled="isEdit" placeholder="如 MINI_HOME（作为主键，建后不可改）" />
        </el-form-item>
        <el-form-item label="渠道名称" prop="channelName">
          <el-input v-model="form.channelName" placeholder="商户建品页看到的名字" />
        </el-form-item>
        <el-form-item label="分组" prop="channelGroup">
          <el-select v-model="form.channelGroup" placeholder="请选择分组" style="width: 100%">
            <el-option v-for="g in groupOptions" :key="g.value" :label="g.label" :value="g.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="投放规则说明" prop="channelDesc">
          <el-input v-model="form.channelDesc" type="textarea" :rows="2" placeholder="会作为灰字提示显示在建品页该渠道下方" />
        </el-form-item>
        <el-form-item label="默认勾选" prop="isDefault">
          <el-radio-group v-model="form.isDefault">
            <el-radio :label="1">是</el-radio>
            <el-radio :label="0">否</el-radio>
          </el-radio-group>
          <div class="form-tip">商户新建商品时自动带上；已建好的商品不受影响</div>
        </el-form-item>
        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" :max="999" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio label="0">启用</el-radio>
            <el-radio label="1">停用</el-radio>
          </el-radio-group>
          <div class="form-tip">停用后建品页不再出现，但存量商品里已存的渠道代码不会被清掉</div>
        </el-form-item>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listSaleChannel, getSaleChannel, addSaleChannel, updateSaleChannel, delSaleChannel } from "@/api/biz/saleChannel"

const GROUPS = [
  { value: 'SELF', label: '自有渠道' },
  { value: 'SOCIAL', label: '社交分享' },
  { value: 'OFFLINE', label: '线下物料' }
]

export default {
  name: "SaleChannel",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      channelList: [],
      title: "",
      open: false,
      isEdit: false,
      groupOptions: GROUPS,
      queryParams: { pageNum: 1, pageSize: 20, channelName: null, channelGroup: null, status: null },
      form: {},
      rules: {
        channelCode: [
          { required: true, message: "渠道代码不能为空", trigger: "blur" },
          { pattern: /^[A-Z][A-Z0-9_]{1,31}$/, message: "只能用大写字母/数字/下划线，字母开头，2-32 位", trigger: "blur" }
        ],
        channelName: [{ required: true, message: "渠道名称不能为空", trigger: "blur" }],
        channelGroup: [{ required: true, message: "请选择分组", trigger: "change" }]
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    groupLabel(v) {
      const hit = GROUPS.find(g => g.value === v)
      return hit ? hit.label : (v || '-')
    },
    getList() {
      this.loading = true
      listSaleChannel(this.queryParams).then(res => {
        this.channelList = res.rows || []
        this.total = res.total || 0
        this.loading = false
      }).catch(() => { this.loading = false })
    },
    handleQuery() { this.queryParams.pageNum = 1; this.getList() },
    resetQuery() {
      this.queryParams = { pageNum: 1, pageSize: 20, channelName: null, channelGroup: null, status: null }
      this.getList()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.channelCode)
      this.single = selection.length !== 1
      this.multiple = selection.length === 0
    },
    handleAdd() {
      this.reset()
      this.isEdit = false
      this.open = true
      this.title = "新增投放渠道"
    },
    handleUpdate(row) {
      this.reset()
      // 用列表选中项兜底：工具栏「修改」按钮传进来的是 event 而不是 row
      const code = (row && row.channelCode) ? row.channelCode : this.ids[0]
      getSaleChannel(code).then(res => {
        this.form = res.data || {}
        this.isEdit = true
        this.open = true
        this.title = "修改投放渠道"
      })
    },
    handleDelete(row) {
      const codes = (row && row.channelCode) ? [row.channelCode] : this.ids
      this.$modal.confirm('确认删除渠道「' + codes.join('、') + '」？存量商品里已存的渠道代码不会被清理。').then(() => {
        return delSaleChannel(codes.join(','))
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    submitForm() {
      this.$refs.form.validate(valid => {
        if (!valid) return
        const req = this.isEdit ? updateSaleChannel(this.form) : addSaleChannel(this.form)
        req.then(() => {
          this.$modal.msgSuccess(this.isEdit ? "修改成功" : "新增成功")
          this.open = false
          this.getList()
        })
      })
    },
    cancel() { this.open = false; this.reset() },
    reset() {
      this.form = { channelCode: null, channelName: null, channelGroup: 'SELF', channelDesc: '', isDefault: 1, sort: 0, status: '0' }
      this.$nextTick(() => { if (this.$refs.form) this.$refs.form.clearValidate() })
    }
  }
}
</script>

<style scoped>
.form-tip { font-size: 12px; color: #909399; line-height: 1.5; margin-top: 2px; }
</style>
