<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="适用门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="商品名称" prop="productName">
        <el-input
          v-model="queryParams.productName"
          placeholder="请输入商品名称"
          clearable
          style="width: 200px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="商品状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 120px">
          <el-option label="上架" value="0" />
          <el-option label="下架" value="1" />
        </el-select>
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
          v-hasPermi="['biz:product:add']"
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
          v-hasPermi="['biz:product:edit']"
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
          v-hasPermi="['biz:product:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:product:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="productList" @selection-change="handleSelectionChange" style="width: 100%">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="商品ID" align="center" prop="productId" width="80" />
      <el-table-column label="适用门店" align="center" prop="storeNames" min-width="160" show-overflow-tooltip />
      <el-table-column label="商品名称" align="left" prop="productName" min-width="180" show-overflow-tooltip />
      <el-table-column label="封面图" align="center" prop="cover" width="100">
        <template slot-scope="scope">
          <el-image v-if="scope.row.cover" :src="scope.row.cover" style="width: 60px; height: 60px; border-radius: 4px" fit="cover" :preview-src-list="[scope.row.cover]" />
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="售价" align="center" prop="price" width="100" />
      <el-table-column label="市场价" align="center" prop="marketPrice" width="100" />
      <el-table-column label="库存" align="center" prop="stock" width="80" />
      <el-table-column label="销量" align="center" prop="sales" width="80" />
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">
            {{ scope.row.status === '0' ? '上架' : '下架' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="80" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="160" />
      <el-table-column label="操作" align="center" width="120" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:product:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:product:remove']"
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

    <!-- 添加或修改商品对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="12">
            <el-form-item label="适用门店" prop="storeIdList">
              <biz-select v-model="form.storeIdList" type="store" multiple @change="onStoreChange" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="商品状态" prop="status">
              <el-select v-model="form.status" placeholder="请选择状态" style="width: 100%">
                <el-option label="上架" value="0" />
                <el-option label="下架" value="1" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="商品名称" prop="productName">
              <el-input v-model="form.productName" placeholder="请输入商品名称" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="副标题" prop="subtitle">
              <el-input v-model="form.subtitle" placeholder="请输入副标题" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="售价" prop="price">
              <el-input v-model="form.price" placeholder="请输入售价" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="市场价" prop="marketPrice">
              <el-input v-model="form.marketPrice" placeholder="请输入市场价" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="库存" prop="stock">
              <el-input v-model="form.stock" placeholder="请输入库存" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="销量" prop="sales">
              <el-input v-model="form.sales" placeholder="请输入销量" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="显示顺序" prop="sort">
              <el-input v-model="form.sort" placeholder="请输入显示顺序" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="有效天数" prop="validityDays">
              <el-input v-model="form.validityDays" placeholder="请输入有效天数" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="封面图" prop="cover">
              <image-upload v-model="form.cover" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="轮播图" prop="images">
              <image-upload v-model="form.images" :limit="8" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="图文详情" prop="detail">
              <editor v-model="form.detail" :min-height="192" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="购买须知" prop="notice">
              <editor v-model="form.notice" :min-height="150" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="备注" prop="remark">
              <el-input v-model="form.remark" type="textarea" placeholder="请输入备注" />
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
import { listProduct, getProduct, delProduct, addProduct, updateProduct } from "@/api/biz/product"

export default {
  name: "Product",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      productList: [],
      title: "",
      open: false,
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        storeIds: [],
        productName: null,
        status: null
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      form: {},
      rules: {
        storeIdList: [
          { required: true, message: "适用门店不能为空", trigger: "change", type: "array" }
        ],
        productName: [
          { required: true, message: "商品名称不能为空", trigger: "blur" }
        ],
        price: [
          { required: true, message: "售价不能为空", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
  },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    buildParams() {
      const params = {
        pageNum: this.queryParams.pageNum,
        pageSize: this.queryParams.pageSize,
        productName: this.queryParams.productName,
        status: this.queryParams.status,
        params: {
          storeIds: this.queryParams.storeIds
        }
      };
      return params;
    },
    getList() {
      this.loading = true;
      listProduct(this.buildParams()).then(response => {
        this.productList = response.rows || response.data || [];
        this.total = response.total || this.productList.length;
        this.loading = false;
      }).catch(() => {
        this.loading = false;
      });
    },
    cancel() {
      this.open = false;
      this.reset();
    },
    reset() {
      this.form = {
        productId: null,
        storeId: null,
        storeIdList: [],
        categoryId: null,
        productName: null,
        subtitle: null,
        cover: null,
        images: null,
        price: null,
        marketPrice: null,
        stock: null,
        sales: null,
        validityDays: null,
        detail: null,
        notice: null,
        sort: 0,
        status: '0',
        delFlag: null,
        remark: null
      };
      if (this.$refs.form !== undefined) {
        this.$refs.form.resetFields();
      }
    },
    handleQuery() {
      this.queryParams.pageNum = 1;
      this.getList();
    },
    resetQuery() {
      this.reset();
      this.queryParams = {
        merchantId: null,
        pageNum: 1,
        pageSize: 10,
        storeIds: [],
        productName: null,
        status: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.productId);
      this.single = selection.length != 1;
      this.multiple = !selection.length;
    },
    handleAdd() {
      this.reset();
      this.title = "添加商品";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const productId = row.productId || this.ids;
      getProduct(productId).then(response => {
        const data = response.data || response;
        data.storeIdList = data.storeIds ? data.storeIds.split(',').map(v => Number(v)) : [];
        this.form = data;
        this.title = "修改商品";
        this.open = true;
      });
    },
    onStoreChange(val) {
      this.$set(this.form, 'storeIdList', val || []);
      if (this.$refs.form) {
        this.$refs.form.validateField('storeIdList');
      }
    },
    submitForm() {
      this.$refs.form.validate(valid => {
        if (valid) {
          this.form.storeIds = (this.form.storeIdList || []).join(',');
          if (this.form.productId != null) {
            updateProduct(this.form).then(response => {
              this.$modal.msgSuccess("修改成功");
              this.open = false;
              this.getList();
            });
          } else {
            addProduct(this.form).then(response => {
              this.$modal.msgSuccess("新增成功");
              this.open = false;
              this.getList();
            });
          }
        }
      });
    },
    handleDelete(row) {
      const productIds = row.productId || this.ids;
      this.$modal.confirm('是否确认删除商品编号为"' + productIds + '"的数据项？').then(function() {
        return delProduct(productIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    },
    handleExport() {
      this.download('biz/product/export', { ...this.buildParams() }, `product_${new Date().getTime()}.xlsx`);
    }
  }
};
</script>
