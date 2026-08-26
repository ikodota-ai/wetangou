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
      <el-table-column label="类型" align="center" prop="typeCode" width="100">
        <template slot-scope="scope">
          <el-tag :type="typeTag(scope.row.typeCode)">{{ typeText(scope.row.typeCode) }}</el-tag>
        </template>
      </el-table-column>
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
          >编辑</el-button>
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

  </div>
</template>

<script>
import { listProduct, delProduct } from "@/api/biz/product"
import { selectProductTypeList } from "@/api/biz/productType"

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
      // v2 商品类型字典（v-for 渲染 typeCode 下拉）
      typeList: [],
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        storeIds: [],
        productName: null,
        status: null
      },
      showMerchantFilter: this.isShowMerchantFilter()
    };
  },
  created() {
    this.getList();
    this.loadTypeList();
  },
  methods: {
    /** v2 字典：拉取商品类型列表（v-for 下拉数据源） */
    loadTypeList() {
      selectProductTypeList().then(res => {
        this.typeList = (res.rows || []).filter(t => t.status === '0' || t.status === 0)
      })
    },
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    typeText(code) {
      // v2 字典化：从 typeList 查 typeName（替代原 hardcode map）
      const t = (this.typeList || []).find(x => x.typeCode === code)
      return t ? t.typeName : (code || '-')
    },
    typeTag(code) {
      return ({
        GROUPON: '', VOUCHER: 'success', TIMECARD: 'warning',
        STORED_CARD: 'danger', PERIOD_CARD: 'info', HUIXIANG_CARD: 'danger',
        COMBO: 'success', BILL: '', BOOKING: 'info'
      })[code] || ''
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
    handleQuery() {
      this.queryParams.pageNum = 1;
      this.getList();
    },
    resetQuery() {
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
    /**
     * 新增：直接进「商品高级编辑」分段式创建页。
     *
     * 原来点新增是开本页的简易弹窗，但那个弹窗缺 maxPerOrder / bookingRequired
     * 等后端强制必填项，GROUPON / VOUCHER / BOOKING 一律保存失败；
     * 而分段式创建页字段是齐的，却只能从已有商品的「高级编辑」进去 ——
     * 没有商品时无路可走，一个都建不出来。这里统一入口，避免维护两套表单。
     */
    handleAdd() {
      this.$router.push({ path: '/product/create' }).catch(() => {})
    },
    /**
     * 修改：与新增一样跳「商品高级编辑」。
     *
     * 原来点修改是开本页的简易弹窗，那是旧版不分步表单，有两个硬伤：
     *   1) 字段不全 —— 缺 maxPerOrder / bookingRequired 等后端强制必填项，
     *      GROUPON / VOUCHER / BOOKING 改完保存直接被 ProductValidator 拒；
     *   2) 适用门店下拉不按商家过滤 —— 能选到别家商户的门店，把商品配成跨商家。
     * 分段式编辑页字段齐全、且门店按所属商家联动，所以统一入口，
     * 不再维护两套表单（避免改了新页忘了旧弹窗）。
     */
    handleUpdate(row) {
      const productId = (row && row.productId) || (this.ids && this.ids[0]);
      if (productId == null) {
        this.$modal.msgWarning('请先选择要修改的商品');
        return;
      }
      this.$router.push({ path: '/product/create', query: { productId } }).catch(() => {})
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
