<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="类型代码" prop="typeCode">
        <el-input v-model="queryParams.typeCode" placeholder="请输入类型代码" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
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
        <el-button type="primary" plain icon="el-icon-plus" size="mini" @click="handleAdd" v-hasPermi="['biz:productType:add']">新增</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="success" plain icon="el-icon-edit" size="mini" :disabled="single" @click="handleUpdate" v-hasPermi="['biz:productType:edit']">修改</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:productType:remove']">删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="el-icon-download" size="mini" @click="handleExport" v-hasPermi="['biz:productType:export']">导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="typeList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="类型代码" align="center" prop="typeCode" width="160" />
      <el-table-column label="类型名称" align="center" prop="typeName" />
      <el-table-column label="业务说明" align="center" prop="typeDesc" show-overflow-tooltip />
      <el-table-column label="顾客端说明" align="center" prop="typeTips" show-overflow-tooltip />
      <el-table-column label="App可创建" align="center" prop="appCanCreate" width="100">
        <template slot-scope="scope">
          <el-tag :type="scope.row.appCanCreate === 1 ? 'success' : 'info'">{{ scope.row.appCanCreate === 1 ? '是' : '否' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="需冷静期" align="center" prop="needLicense" width="100">
        <template slot-scope="scope">
          <el-tag :type="scope.row.needLicense === 1 ? 'warning' : 'info'">{{ scope.row.needLicense === 1 ? '是' : '否' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="80" />
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">{{ scope.row.status === '0' ? '启用' : '停用' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="160" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-edit" @click="handleUpdate(scope.row)" v-hasPermi="['biz:productType:edit']">修改</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:productType:remove']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total > 0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />

    <!-- 新增/修改对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="560px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="类型代码" prop="typeCode">
          <el-input v-model="form.typeCode" placeholder="如 GROUPON（新建时必填，修改时不可改）" :disabled="!!form.isEdit" />
        </el-form-item>
        <el-form-item label="类型名称" prop="typeName">
          <el-input v-model="form.typeName" placeholder="请输入类型名称" />
        </el-form-item>
        <el-form-item label="业务说明" prop="typeDesc">
          <el-input v-model="form.typeDesc" type="textarea" :rows="2" placeholder="写给运营/商家看的招商话术，不展示给顾客" />
        </el-form-item>
        <el-form-item label="顾客端说明" prop="typeTips">
          <el-input v-model="form.typeTips" type="textarea" :rows="3" placeholder="小程序商品详情页「××说明」卡的正文，直接给顾客看" />
          <div class="el-upload__tip">与「业务说明」分开：业务说明是「搭配自由，快速吸引顾客」这种内部话术，搬到顾客面前不知所云。留空则详情页不展说明卡。</div>
        </el-form-item>
        <el-form-item label="App可创建" prop="appCanCreate">
          <el-radio-group v-model="form.appCanCreate">
            <el-radio :label="1">是</el-radio>
            <el-radio :label="0">否</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="需冷静期" prop="needLicense">
          <el-radio-group v-model="form.needLicense">
            <el-radio :label="1">是</el-radio>
            <el-radio :label="0">否</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" :max="999" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio label="0">启用</el-radio>
            <el-radio label="1">停用</el-radio>
          </el-radio-group>
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
import { listProductType, getProductType, addProductType, updateProductType, delProductType } from "@/api/biz/productType"

export default {
  name: "ProductType",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      typeList: [],
      title: "",
      open: false,
      queryParams: {
        pageNum: 1,
        pageSize: 20,
        typeCode: null,
        status: null
      },
      form: {},
      rules: {
        typeCode: [{ required: true, message: "类型代码不能为空", trigger: "blur" }],
        typeName: [{ required: true, message: "类型名称不能为空", trigger: "blur" }]
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    getList() {
      this.loading = true
      listProductType(this.queryParams).then(res => {
        this.typeList = res.rows || []
        this.total = res.total || 0
        this.loading = false
      }).catch(() => { this.loading = false })
    },
    handleQuery() { this.queryParams.pageNum = 1; this.getList() },
    resetQuery() {
      this.queryParams = { pageNum: 1, pageSize: 20, typeCode: null, status: null }
      this.getList()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.typeCode)
      this.single = selection.length !== 1
      this.multiple = selection.length === 0
    },
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "新增商品类型"
    },
    handleUpdate(row) {
      this.reset()
      const code = row.typeCode || this.ids[0]
      getProductType(code).then(res => {
        this.form = Object.assign({}, res.data, { isEdit: true })
        this.open = true
        this.title = "修改商品类型"
      })
    },
    handleDelete(row) {
      const codes = row ? [row.typeCode] : this.ids
      this.$modal.confirm('确认删除类型代码为 "' + codes.join(',') + '" 的数据项？').then(() => {
        return delProductType(codes[0])
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    handleExport() {
      this.download('biz/productType/export', { ...this.queryParams }, `productType_${new Date().getTime()}.xlsx`)
    },
    submitForm() {
      this.$refs.form.validate(valid => {
        if (!valid) return
        // 判断新增/修改要用真实主键 typeCode —— 实体里没有 typeCodeId 这个字段，
        // 写它则恒为 undefined，修改也会走 addProductType，
        // 报 Duplicate entry 'STORED_CARD' for key 'PRIMARY'。
        // isEdit 由 handleUpdate 打标，比看 typeCode 有没有值更可靠（新增时用户也会填 typeCode）。
        // isEdit 只是前端标记，不发给后端
        const payload = Object.assign({}, this.form)
        delete payload.isEdit
        if (this.form.isEdit) {
          updateProductType(payload).then(() => {
            this.$modal.msgSuccess("修改成功")
            this.open = false
            this.getList()
          })
        } else {
          addProductType(payload).then(() => {
            this.$modal.msgSuccess("新增成功")
            this.open = false
            this.getList()
          })
        }
      })
    },
    cancel() { this.open = false; this.reset() },
    reset() {
      this.form = { typeCode: null, typeName: null, typeDesc: '', typeTips: '', appCanCreate: 1, needLicense: 0, sort: 0, status: '0', isEdit: false }
      this.$nextTick(() => { if (this.$refs.form) this.$refs.form.clearValidate() })
    }
  }
}
</script>
