<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>
      <el-form-item label="位置" prop="position">
        <el-select v-model="queryParams.position" placeholder="请选择位置" clearable>
          <el-option label="首页" value="home" />
          <el-option label="代理商" value="agent" />
          <el-option label="推客中心" value="distributor" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable>
          <el-option label="启用" value="0" />
          <el-option label="停用" value="1" />
        </el-select>
      </el-form-item>
      <el-form-item label="标题" prop="title">
        <el-input v-model="queryParams.title" placeholder="请输入标题" clearable @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="el-icon-plus" size="mini" @click="handleAdd" v-hasPermi="['biz:banner:add']">新增</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:banner:remove']">删除</el-button>
      </el-col>
    </el-row>

    <el-table v-loading="loading" :data="bannerList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="ID" prop="bannerId" width="80" />
      <el-table-column label="图片" align="center" width="120">
        <template slot-scope="scope">
          <image-preview :src="scope.row.imageUrl" :width="80" :height="40" />
        </template>
      </el-table-column>
      <el-table-column label="标题" prop="title" :show-overflow-tooltip="true" />
      <el-table-column label="跳转链接" prop="linkUrl" :show-overflow-tooltip="true" />
      <el-table-column label="位置" prop="position" width="100">
        <template slot-scope="scope">
          <el-tag v-if="scope.row.position==='home'" type="success">首页</el-tag>
          <el-tag v-else-if="scope.row.position==='agent'" type="warning">代理商</el-tag>
          <el-tag v-else type="info">推客中心</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag v-if="scope.row.status==='0'" type="success">启用</el-tag>
          <el-tag v-else type="danger">停用</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="顺序" prop="sort" width="80" />
      <el-table-column label="生效" prop="activeFrom" width="160">
        <template slot-scope="scope">
          <span>{{ scope.row.activeFrom || '-' }}<br/><span style="color:#909399">至 {{ scope.row.activeTo || '永久' }}</span></span>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="120" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-edit" @click="handleUpdate(scope.row)" v-hasPermi="['biz:banner:edit']">修改</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:banner:remove']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total>0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />

    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
          <biz-select v-model="form.merchantId" type="merchant" width="100%" placeholder="不选=全平台" />
        </el-form-item>
        <el-form-item label="位置" prop="position">
          <el-select v-model="form.position" placeholder="请选择位置" style="width:100%">
            <el-option label="首页" value="home" />
            <el-option label="代理商" value="agent" />
            <el-option label="推客中心" value="distributor" />
          </el-select>
        </el-form-item>
        <el-form-item label="标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入标题" />
        </el-form-item>
        <el-form-item label="图片URL" prop="imageUrl">
          <image-upload v-model="form.imageUrl" :limit="1" />
        </el-form-item>
        <el-form-item label="跳转链接" prop="linkUrl">
          <el-input v-model="form.linkUrl" placeholder="可选：/pages/xxx 或外链 URL" />
        </el-form-item>
        <el-form-item label="显示顺序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" :max="9999" />
        </el-form-item>
        <el-form-item label="生效时间" prop="activeFrom">
          <el-date-picker v-model="form.activeFrom" type="datetime" value-format="yyyy-MM-dd HH:mm:ss" placeholder="可选" />
        </el-form-item>
        <el-form-item label="失效时间" prop="activeTo">
          <el-date-picker v-model="form.activeTo" type="datetime" value-format="yyyy-MM-dd HH:mm:ss" placeholder="可选，留空=永久" />
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
import { showMerchantField } from "@/utils/identity"
import { listBanner, getBanner, addBanner, updateBanner, delBanner } from '@/api/biz/banner'

export default {
  name: 'Banner',
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      bannerList: [],
      title: '',
      open: false,
      showMerchantFilter: true,
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        merchantId: null,
        position: null,
        status: null,
        title: null
      },
      form: {},
      rules: {
        position: [{ required: true, message: '请选择位置', trigger: 'change' }],
        imageUrl: [{ required: true, message: '请上传图片', trigger: 'blur' }],
        status: [{ required: true, message: '请选择状态', trigger: 'change' }]
      }
    }
  },
  created() {
    this.showMerchantFilter = this.isShowMerchantFilter()
    this.getList()
  },
  methods: {
    getList() {
      this.loading = true
      listBanner(this.queryParams).then((res) => {
        this.bannerList = res.rows
        this.total = res.total
        this.loading = false
      })
    },
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    resetQuery() {
      this.resetForm('queryForm')
      this.queryParams.merchantId = null
      this.handleQuery()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map((item) => item.bannerId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    handleAdd() {
      this.resetForm('form')
      this.form = { status: '0', position: 'home', sort: 0, merchantId: this.queryParams.merchantId || 0 }
      this.open = true
      this.title = '新增轮播图'
    },
    handleUpdate(row) {
      getBanner(row.bannerId).then((res) => {
        this.form = res.data
        this.open = true
        this.title = '修改轮播图'
      })
    },
    submitForm() {
      this.$refs.form.validate((valid) => {
        if (!valid) return
        if (this.form.bannerId != null) {
          updateBanner(this.form).then(() => { this.$modal.msgSuccess('修改成功'); this.open = false; this.getList() })
        } else {
          addBanner(this.form).then(() => { this.$modal.msgSuccess('新增成功'); this.open = false; this.getList() })
        }
      })
    },
    handleDelete(row) {
      const ids = row && row.bannerId ? [row.bannerId] : this.ids
      this.$confirm('确认删除?', '提示', { type: 'warning' }).then(() => {
        return delBanner(ids.join(','))
      }).then(() => { this.getList(); this.$modal.msgSuccess('删除成功') }).catch(() => {})
    },
    cancel() { this.open = false },
    isShowMerchantFilter() {
      return showMerchantField()
    }
  }
}
</script>
