<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="商品" prop="productId">
        <biz-select v-model="queryParams.productId" type="product" width="220px" placeholder="请选择商品" />
      </el-form-item>
      <el-form-item label="商品名称" prop="productName">
        <el-input v-model="queryParams.productName" placeholder="按商品名称模糊查" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="子品名称" prop="subitemName">
        <el-input v-model="queryParams.subitemName" placeholder="按子品名称模糊查" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-alert
      title="子品在「门店商品 → 商品管理」里编辑商品时维护（底部「子品搭配」区）。本页用于跨商品汇总查看与快速改名/改价。"
      type="info" :closable="false" show-icon style="margin-bottom: 12px" />

    <el-row :gutter="10" class="mb8">
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList" />
    </el-row>

    <el-table v-loading="loading" :data="subitemList">
      <el-table-column label="子品ID" align="center" prop="subitemId" width="90" />
      <el-table-column label="所属商品" align="left" prop="productName" min-width="180" show-overflow-tooltip>
        <template slot-scope="scope">{{ scope.row.productName || ('商品' + scope.row.productId) }}</template>
      </el-table-column>
      <el-table-column label="商品组" align="center" prop="groupName" width="140">
        <template slot-scope="scope">{{ scope.row.groupName || '-' }}</template>
      </el-table-column>
      <el-table-column label="选择规则" align="center" prop="pickRule" width="100">
        <template slot-scope="scope">
          <el-tag size="mini">{{ scope.row.pickRule || 'ALL' }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="子品名称" align="left" prop="subitemName" min-width="160" show-overflow-tooltip />
      <el-table-column label="数量" align="center" prop="quantity" width="80" />
      <el-table-column label="单价" align="center" prop="price" width="100">
        <template slot-scope="scope">¥{{ scope.row.price }}</template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="80" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="160" />
      <el-table-column label="操作" align="center" width="140" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-edit" @click="handleUpdate(scope.row)" v-hasPermi="['biz:product:edit']">修改</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:product:remove']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total > 0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />

    <!-- 修改子品 -->
    <el-dialog title="修改子品" :visible.sync="open" width="460px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="所属商品">
          <span>{{ form.productName || ('商品' + form.productId) }}</span>
        </el-form-item>
        <el-form-item label="商品组">
          <span>{{ form.groupName || '-' }}</span>
        </el-form-item>
        <el-form-item label="子品名称" prop="subitemName">
          <el-input v-model="form.subitemName" maxlength="100" />
        </el-form-item>
        <el-form-item label="数量" prop="quantity">
          <el-input-number v-model="form.quantity" :min="1" :max="99" />
        </el-form-item>
        <el-form-item label="单价" prop="price">
          <el-input-number v-model="form.price" :min="0" :precision="2" :step="1" />
        </el-form-item>
        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" :max="999" />
        </el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="open = false">取 消</el-button>
        <el-button type="primary" @click="submitForm">确 定</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listProductSubitem, updateSubitem, delSubitem } from "@/api/biz/productSubitem"

export default {
  name: "ProductSubitem",
  data() {
    return {
      loading: false,
      showSearch: true,
      total: 0,
      subitemList: [],
      open: false,
      form: {},
      rules: {
        subitemName: [{ required: true, message: "子品名称不能为空", trigger: "blur" }]
      },
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        productId: null,
        productName: null,
        subitemName: null
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    getList() {
      this.loading = true
      listProductSubitem(this.queryParams).then(res => {
        this.subitemList = res.rows || []
        this.total = res.total || 0
      }).finally(() => { this.loading = false })
    },
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    resetQuery() {
      this.queryParams = { pageNum: 1, pageSize: 10, productId: null, productName: null, subitemName: null }
      this.getList()
    },
    handleUpdate(row) {
      this.form = Object.assign({}, row)
      this.open = true
    },
    submitForm() {
      this.$refs.form.validate(valid => {
        if (!valid) return
        updateSubitem({
          subitemId: this.form.subitemId,
          subitemName: this.form.subitemName,
          quantity: this.form.quantity,
          price: this.form.price,
          sort: this.form.sort
        }).then(() => {
          this.$modal.msgSuccess("修改成功")
          this.open = false
          this.getList()
        })
      })
    },
    handleDelete(row) {
      this.$modal.confirm('确认删除子品「' + row.subitemName + '」？').then(() => {
        return delSubitem(row.subitemId)
      }).then(() => {
        this.$modal.msgSuccess("删除成功")
        this.getList()
      }).catch(() => {})
    }
  }
}
</script>
