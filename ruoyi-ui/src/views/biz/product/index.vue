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
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-document"
            @click="handleAdvancedEdit(scope.row)"
            v-hasPermi="['biz:product:edit']"
          >高级编辑</el-button>
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
            <el-form-item label="商品类型" prop="typeCode">
              <el-select v-model="form.typeCode" placeholder="请选择商品类型" style="width: 100%" @change="onTypeCodeChange">
                <el-option v-for="t in typeList" :key="t.typeCode" :label="t.typeName" :value="t.typeCode" />
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
          <el-col :span="12" v-if="isType('VOUCHER')">
            <el-form-item label="代金券面值" prop="faceValue">
              <el-input v-model="form.faceValue" placeholder="请输入代金券面值（划线价）" />
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('VOUCHER')">
            <el-form-item label="最低消费" prop="minConsume">
              <el-input v-model="form.minConsume" placeholder="请输入最低消费门槛（满 X 减 Y 的 X）" />
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('TIMECARD') || isType('HUIXIANG_CARD')">
            <el-form-item label="总次数" prop="totalTimes">
              <el-input v-model="form.totalTimes" placeholder="请输入总次数" />
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('PERIOD_CARD')">
            <el-form-item label="周期类型" prop="periodType">
              <el-select v-model="form.periodType" placeholder="请选择" style="width: 100%">
                <el-option label="月卡" value="MONTH" />
                <el-option label="季卡" value="QUARTER" />
                <el-option label="年卡" value="YEAR" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('PERIOD_CARD')">
            <el-form-item label="周期数" prop="periodCount">
              <el-input v-model="form.periodCount" placeholder="请输入周期数（默认 1）" />
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('COMBO')">
            <el-form-item label="组合总价值" prop="totalValue">
              <el-input v-model="form.totalValue" placeholder="请输入组合券包总价值（划线价）" />
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="isType('COMBO')">
            <el-form-item label="子品选择规则" prop="subitemPickRule">
              <el-select v-model="form.subitemPickRule" placeholder="请选择" style="width: 100%">
                <el-option label="全部可享" value="ALL" />
                <el-option label="1选1" value="1选1" />
                <el-option label="2选2" value="2选2" />
                <el-option label="3选2" value="3选2" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12" v-if="needsXiaoxin">
            <el-form-item label="冷静期" prop="requireXiaoxin">
              <el-switch v-model="form.requireXiaoxin" :active-value="1" :inactive-value="0" />
              <span class="form-tip">次卡/储值卡/周期卡/惠享卡/组合券需冷静期保护</span>
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
          <el-col :span="24" v-if="form.productId && (form.typeCode === 'GROUPON' || form.typeCode === 'COMBO')">
            <el-divider content-position="left">子品搭配（团购 / 组合券包）</el-divider>
            <div class="subitem-toolbar">
              <el-button size="mini" type="primary" icon="el-icon-plus" @click="openAddGroup">添加商品组</el-button>
              <span class="subitem-tip">商品组：例如「主食」「小吃」「饮品」；组内每个子品是具体商品（如红烧肉、可乐）。</span>
            </div>
            <div v-for="g in subitemGroups" :key="g.groupId" class="group-card">
              <div class="group-head">
                <div>
                  <span class="group-name">{{ g.groupName }}</span>
                  <el-tag size="mini" style="margin-left:8px">{{ g.pickRule || 'ALL' }}</el-tag>
                </div>
                <div>
                  <el-button type="text" size="mini" @click="openAddSubitem(g)">添加子品</el-button>
                  <el-button type="text" size="mini" icon="el-icon-delete" @click="onDeleteGroup(g)">删除</el-button>
                </div>
              </div>
              <el-table :data="g.subitems" size="mini" empty-text="该组还没有子品">
                <el-table-column label="子品名称" prop="subitemName" />
                <el-table-column label="数量" prop="quantity" width="80" align="center" />
                <el-table-column label="单价" prop="price" width="100" align="center">
                  <template slot-scope="scope">¥{{ scope.row.price }}</template>
                </el-table-column>
                <el-table-column label="操作" width="120" align="center">
                  <template slot-scope="scope">
                    <el-button type="text" size="mini" @click="onDeleteSubitem(g, scope.row)">删除</el-button>
                  </template>
                </el-table-column>
              </el-table>
            </div>
            <div v-if="!subitemGroups.length" class="subitem-empty">还没有商品组，点上方按钮添加</div>
          </el-col>
        </el-row>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>

    <!-- 添加商品组 -->
    <el-dialog title="添加商品组" :visible.sync="groupOpen" width="420px" append-to-body>
      <el-form ref="groupForm" :model="groupForm" :rules="groupRules" label-width="100px">
        <el-form-item label="组名称" prop="groupName">
          <el-input v-model="groupForm.groupName" placeholder="如：主食" maxlength="50" />
        </el-form-item>
        <el-form-item label="选择规则" prop="pickRule">
          <el-select v-model="groupForm.pickRule" style="width:100%">
            <el-option label="全部可享" value="ALL" />
            <el-option label="1选1" value="1选1" />
            <el-option label="2选2" value="2选2" />
            <el-option label="3选2" value="3选2" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="groupForm.sort" :min="0" :max="999" />
        </el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="groupOpen = false">取 消</el-button>
        <el-button type="primary" @click="submitAddGroup">添 加</el-button>
      </div>
    </el-dialog>

    <!-- 添加子品 -->
    <el-dialog title="添加子品" :visible.sync="subitemOpen" width="420px" append-to-body>
      <el-form ref="subitemForm" :model="subitemForm" :rules="subitemRules" label-width="100px">
        <el-form-item label="所属组">
          <span>{{ subitemForm._groupName }}</span>
        </el-form-item>
        <el-form-item label="子品名称" prop="subitemName">
          <el-select
            v-model="subitemForm.subitemName"
            filterable
            allow-create
            default-first-option
            remote
            :remote-method="searchSubitemName"
            :loading="nameLoading"
            placeholder="输入可筛选历史子品，也可直接输入新名称"
            style="width: 100%"
          >
            <el-option v-for="n in nameOptions" :key="n" :label="n" :value="n" />
          </el-select>
          <div class="subitem-tip">支持搜索复用历史子品名称；没有匹配项时直接输入即可新建。</div>
        </el-form-item>
        <el-form-item label="数量" prop="quantity">
          <el-input-number v-model="subitemForm.quantity" :min="1" :max="99" />
        </el-form-item>
        <el-form-item label="单价" prop="price">
          <el-input-number v-model="subitemForm.price" :min="0" :precision="2" :step="1" />
        </el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="subitemOpen = false">取 消</el-button>
        <el-button type="primary" @click="submitAddSubitem">添 加</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listProduct, getProduct, delProduct, addProduct, updateProduct } from "@/api/biz/product"
import { selectProductTypeList } from "@/api/biz/productType"
import { listGroups, addGroup, delGroup, addSubitem, updateSubitem, delSubitem, listSubitemNameCandidates } from "@/api/biz/productSubitem"

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
      },
      // 子品搭配
      subitemGroups: [],
      groupOpen: false,
      groupForm: { productId: null, groupName: '', pickRule: 'ALL', sort: 0 },
      groupRules: {
        groupName: [{ required: true, message: '请输入组名称', trigger: 'blur' }]
      },
      subitemOpen: false,
      // 子品名称候选（历史去重），支持筛选复用
      nameOptions: [],
      nameLoading: false,
      subitemForm: { productId: null, groupId: null, _groupName: '', subitemName: '', quantity: 1, price: 0 },
      subitemRules: {
        subitemName: [{ required: true, message: '请输入子品名称', trigger: 'blur' }]
      }
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
    isType(code) {
      return this.form && this.form.typeCode === code
    },
    needsXiaoxin() {
      const t = this.form && this.form.typeCode
      return t === 'TIMECARD' || t === 'STORED_CARD' || t === 'PERIOD_CARD' || t === 'HUIXIANG_CARD' || t === 'COMBO'
    },
    onTypeCodeChange(val) {
      // 选择类型后，把不相关的字段清空，避免脏数据
      if (val !== 'VOUCHER') { this.form.faceValue = null; this.form.minConsume = null }
      if (val !== 'TIMECARD' && val !== 'HUIXIANG_CARD') { this.form.totalTimes = null }
      if (val !== 'PERIOD_CARD') { this.form.periodType = null; this.form.periodCount = null }
      if (val !== 'COMBO') { this.form.totalValue = null; this.form.subitemPickRule = 'ALL' }
      this.form.requireXiaoxin = this.needsXiaoxin() ? 1 : 0
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
    // ===== 子品搭配 =====
    loadSubitems() {
      if (!this.form || !this.form.productId) { this.subitemGroups = []; return }
      listGroups(this.form.productId).then(res => {
        this.subitemGroups = (res && (res.data || res)) || []
      }).catch(() => { this.subitemGroups = [] })
    },
    openAddGroup() {
      this.groupForm = { productId: this.form.productId, groupName: '', pickRule: 'ALL', sort: 0 }
      this.groupOpen = true
    },
    submitAddGroup() {
      this.$refs.groupForm.validate(v => {
        if (!v) return
        addGroup(this.groupForm).then(() => {
          this.$modal.msgSuccess('已添加')
          this.groupOpen = false
          this.loadSubitems()
        }).catch(e => this.$modal.msgError((e && (e.msg||e.message)) || '添加失败'))
      })
    },
    onDeleteGroup(g) {
      this.$modal.confirm('确认删除商品组「' + g.groupName + '」？组内子品将一起删除').then(() => {
        return delGroup(g.groupId)
      }).then(() => {
        this.$modal.msgSuccess('已删除')
        this.loadSubitems()
      }).catch(() => {})
    },
    openAddSubitem(g) {
      this.subitemForm = {
        productId: this.form.productId,
        groupId: g.groupId,
        _groupName: g.groupName,
        subitemName: '',
        quantity: 1,
        price: 0
      }
      this.subitemOpen = true
      this.searchSubitemName('')
    },
    /** 拉取历史子品名称候选（el-select remote） */
    searchSubitemName(keyword) {
      this.nameLoading = true
      listSubitemNameCandidates(keyword || '').then(res => {
        this.nameOptions = (res && (res.data || res)) || []
      }).catch(() => {
        this.nameOptions = []
      }).finally(() => {
        this.nameLoading = false
      })
    },
    submitAddSubitem() {
      this.$refs.subitemForm.validate(v => {
        if (!v) return
        const payload = { ...this.subitemForm }
        delete payload._groupName
        addSubitem(payload).then(() => {
          this.$modal.msgSuccess('已添加')
          this.subitemOpen = false
          this.loadSubitems()
        }).catch(e => this.$modal.msgError((e && (e.msg||e.message)) || '添加失败'))
      })
    },
    onDeleteSubitem(g, s) {
      this.$modal.confirm('确认删除子品「' + s.subitemName + '」？').then(() => {
        return delSubitem(s.subitemId)
      }).then(() => {
        this.$modal.msgSuccess('已删除')
        this.loadSubitems()
      }).catch(() => {})
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
        typeCode: 'GROUPON',
        faceValue: null,
        minConsume: null,
        totalTimes: null,
        periodType: null,
        periodCount: null,
        totalValue: null,
        subitemPickRule: 'ALL',
        requireXiaoxin: 0,
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
    /** 高级编辑：跳到抖音来客 6 步编辑页（产品类型/售卖/交易/消费/扩展属性） */
    handleAdvancedEdit(row) {
      const productId = row.productId
      this.$router.push({ path: '/product/create', query: { productId } }).catch(() => {})
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
        this.loadSubitems();
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
<style scoped>
.subitem-toolbar { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.subitem-tip { font-size: 12px; color: #999; }
.group-card { background: #fafbfc; border: 1px solid #ebeef5; border-radius: 6px; padding: 12px; margin-bottom: 12px; }
.group-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
.group-name { font-weight: 600; color: #303133; }
.subitem-empty { text-align: center; color: #999; padding: 16px 0; font-size: 13px; }
</style>
