<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="68px">
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" :merchant-id="queryParams.merchantId" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="图片地址" prop="imageUrl">
        <el-input
          v-model="queryParams.imageUrl"
          placeholder="请输入图片地址"
          clearable
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="显示顺序" prop="sort">
        <el-input
          v-model="queryParams.sort"
          placeholder="请输入显示顺序"
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
          v-hasPermi="['biz:album:add']"
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
          v-hasPermi="['biz:album:edit']"
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
          v-hasPermi="['biz:album:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:album:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="albumList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="相册ID" align="center" prop="albumId" />
      <el-table-column label="门店" align="center" prop="storeName">
        <template slot-scope="scope">{{ scope.row.storeName || (scope.row.storeId === 0 ? '全部门店' : scope.row.storeId) }}</template>
      </el-table-column>
      <el-table-column label="图片" align="center" prop="imageUrl" width="100">
        <template slot-scope="scope">
          <el-image v-if="scope.row.imageUrl" :src="scope.row.imageUrl" style="width: 60px; height: 60px; border-radius: 4px" fit="cover" :preview-src-list="[scope.row.imageUrl]" />
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="类型" align="center" prop="albumType" />
      <el-table-column label="显示顺序" align="center" prop="sort" />
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:album:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:album:remove']"
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

    <!-- 添加或修改门店相册对话框 -->
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
            <el-form-item label="图片地址" prop="imageUrl">
              <image-upload v-model="form.imageUrl" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="显示顺序" prop="sort">
              <el-input v-model="form.sort" placeholder="请输入显示顺序" />
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
import { listAlbum, getAlbum, delAlbum, addAlbum, updateAlbum } from "@/api/biz/album"

export default {
  name: "Album",
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
      // 门店相册表格数据
      albumList: [],
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
        imageUrl: null,
        albumType: null,
        sort: null,
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      // 表单参数
      form: {},
      // 表单校验
      rules: {
        storeId: [
          { required: true, message: "门店ID不能为空", trigger: "blur" }
        ],
        imageUrl: [
          { required: true, message: "图片地址不能为空", trigger: "blur" }
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
    /** 查询门店相册列表 */
    buildParams() {
      const p = { ...this.queryParams }
      p.params = Object.assign({}, p.params, { storeIds: this.queryParams.storeIds })
      delete p.storeIds
      return p
    },
    getList() {
      this.loading = true
      listAlbum(this.buildParams()).then(response => {
        this.albumList = response.rows
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
        albumId: null,
        storeId: null,
        imageUrl: null,
        albumType: null,
        sort: null,
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
      this.ids = selection.map(item => item.albumId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    /** 新增按钮操作 */
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "添加门店相册"
    },
    /** 修改按钮操作 */
    handleUpdate(row) {
      this.reset()
      const albumId = row.albumId || this.ids
      getAlbum(albumId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改门店相册"
      })
    },
    /** 提交按钮 */
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.albumId != null) {
            updateAlbum(this.form).then(response => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addAlbum(this.form).then(response => {
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
      const albumIds = row.albumId || this.ids
      this.$modal.confirm('是否确认删除门店相册编号为"' + albumIds + '"的数据项？').then(function() {
        return delAlbum(albumIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    /** 导出按钮操作 */
    handleExport() {
      this.download('biz/album/export', {
        ...this.buildParams()
      }, `album_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
