<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="门店名称" prop="storeName">
        <el-input
          v-model="queryParams.storeName"
          placeholder="请输入门店名称"
          clearable
          style="width: 200px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="门店状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 120px">
          <el-option label="营业中" value="0" />
          <el-option label="已停业" value="1" />
        </el-select>
      </el-form-item>
      <el-form-item label="所在城市" prop="city">
        <el-input
          v-model="queryParams.city"
          placeholder="请输入城市"
          clearable
          style="width: 150px"
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
          v-hasPermi="['biz:store:add']"
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
          v-hasPermi="['biz:store:edit']"
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
          v-hasPermi="['biz:store:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:store:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="storeList" @selection-change="handleSelectionChange" style="width: 100%">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="门店ID" align="center" prop="storeId" width="80" />
      <el-table-column label="门店Logo" align="center" prop="logo" width="100">
        <template slot-scope="scope">
          <el-image v-if="scope.row.logo" :src="scope.row.logo" style="width: 60px; height: 60px; border-radius: 4px" fit="cover" :preview-src-list="[scope.row.logo]" />
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="门店名称" align="left" prop="storeName" min-width="150" show-overflow-tooltip />
      <el-table-column label="联系电话" align="center" prop="phone" width="130" />
      <el-table-column label="所在城市" align="center" prop="city" width="100" />
      <el-table-column label="营业状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'">
            {{ scope.row.status === '0' ? '营业中' : '已停业' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="营业时间" align="center" prop="businessHours" width="150" />
      <el-table-column label="客服服务时间" align="center" prop="serviceHours" width="150" />
      <el-table-column label="服务设施" align="center" prop="services" min-width="200">
        <template slot-scope="scope">
          <el-tag
            v-for="item in (scope.row.services ? scope.row.services.split(',') : [])"
            :key="item"
            size="mini"
            style="margin: 2px"
          >{{ serviceLabel(item) }}</el-tag>
          <span v-if="!scope.row.services">-</span>
        </template>
      </el-table-column>
      <el-table-column label="排序" align="center" prop="sort" width="70" />
      <el-table-column label="创建时间" align="center" prop="createTime" width="160" />
      <el-table-column label="操作" align="center" width="120" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:store:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:store:remove']"
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

    <!-- 添加或修改门店对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <!-- 商户账号自身就带 merchantId，后端会自动补，无需也不应让它选 -->
          <el-col :span="24" v-if="showMerchantFilter">
            <el-form-item label="所属商户" prop="merchantId">
              <biz-select v-model="form.merchantId" type="merchant" width="100%" placeholder="请选择所属商户" />
              <div class="form-tip" v-if="form.storeId">
                门店归属不建议变更：已产生的订单、商品、员工都挂在原商户下。
              </div>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店名称" prop="storeName">
              <el-input v-model="form.storeName" placeholder="请输入门店名称" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="门店Logo" prop="logo">
              <image-upload v-model="form.logo" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="省" prop="province">
              <el-input v-model="form.province" placeholder="请输入省" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="市" prop="city">
              <el-input v-model="form.city" placeholder="请输入市" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="区" prop="district">
              <el-input v-model="form.district" placeholder="请输入区" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="详细地址" prop="address">
              <el-input v-model="form.address" placeholder="请输入详细地址，可点右侧地图搜索定位">
                <el-button slot="append" @click="locateByAddress">地图定位</el-button>
              </el-input>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="地图选点">
              <tencent-map
                ref="tmap"
                v-model="mapPoint"
                :address="form.address"
                height="360px"
                @addressResolved="onAddressResolved"
              />
              <div class="map-tip">拖动标记或点击地图可微调位置，也可点“根据坐标获取地址”回填详细地址。</div>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="经度" prop="longitude">
              <el-input v-model="form.longitude" placeholder="经度（地图选点自动填充）" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="纬度" prop="latitude">
              <el-input v-model="form.latitude" placeholder="纬度（地图选点自动填充）" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="门店电话" prop="phone">
              <el-input v-model="form.phone" placeholder="请输入门店电话" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="客服电话" prop="servicePhone">
              <el-input v-model="form.servicePhone" placeholder="请输入客服电话" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="营业时间" prop="businessHours">
              <el-input v-model="form.businessHours" placeholder="门店营业时间，如 09:00-22:00" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="客服服务时间" prop="serviceHours">
              <el-input v-model="form.serviceHours" placeholder="客服工作时段，如 09:00-22:00" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="服务设施" prop="services">
              <el-checkbox-group v-model="serviceList">
                <el-checkbox
                  v-for="dict in dict.type.biz_store_service"
                  :key="dict.value"
                  :label="dict.value"
                >{{ dict.label }}</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="买单自动确认" prop="billAutoConfirm">
              <el-radio-group v-model="form.billAutoConfirm">
                <el-radio label="1">自动确认（推荐）</el-radio>
                <el-radio label="0">需店员确认金额</el-radio>
              </el-radio-group>
              <div class="form-tip">
                买单的常规场景是顾客在店员面前输入消费金额后直接付款，保持「自动确认」即可。
                选「需店员确认」后顾客要等门店在系统里确认金额才能支付，而当前商家端暂无确认入口，会导致付不了款。
              </div>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="门店状态" prop="status">
              <el-select v-model="form.status" placeholder="请选择状态" style="width: 100%">
                <el-option label="营业中" value="0" />
                <el-option label="已停业" value="1" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
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
import { listStore, getStore, delStore, addStore, updateStore } from "@/api/biz/store"
import TencentMap from "@/components/TencentMap"

export default {
  name: "Store",
  components: { TencentMap },
  dicts: ['biz_store_service'],
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      storeList: [],
      serviceList: [],
      mapPoint: { lng: null, lat: null },
      title: "",
      open: false,
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        storeName: null,
        status: null,
        city: null
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      form: {},
      rules: {
        // 商户账号不显示该字段、由后端按 token 补齐；
        // 注意 v-if 移除 DOM 后 validate() 仍会校验规则，
        // 所以这里必须按身份动态决定 required，否则商户账号提交会被卡住。
        merchantId: [
          { required: this.isShowMerchantFilter(), message: "请选择所属商户", trigger: "change" }
        ],
        storeName: [
          { required: true, message: "门店名称不能为空", trigger: "blur" }
        ],
        phone: [
          { required: true, message: "门店电话不能为空", trigger: "blur" }
        ]
      }
    };
  },
  watch: {
    mapPoint(val) {
      if (val) {
        if (val.lng != null) this.$set(this.form, 'longitude', val.lng);
        if (val.lat != null) this.$set(this.form, 'latitude', val.lat);
      }
    }
  },
  created() {
    this.getList();
  },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    // 服务字典值转标签
    serviceLabel(value) {
      const dict = this.dict.type.biz_store_service || [];
      const hit = dict.find(d => d.value === value);
      return hit ? hit.label : value;
    },
    // 点击“地图定位”按钮，根据详细地址搜索
    locateByAddress() {
      if (this.$refs.tmap) {
        this.$refs.tmap.searchKeyword = this.form.address || '';
        this.$refs.tmap.searchAddress();
      }
    },
    // 逆地址解析回填详细地址
    onAddressResolved(address) {
      if (address) this.$set(this.form, 'address', address);
    },
    getList() {
      this.loading = true;
      listStore(this.queryParams).then(response => {
        this.storeList = response.rows || response.data || [];
        this.total = response.total || this.storeList.length;
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
        storeId: null,
        merchantId: null,
        storeName: null,
        logo: null,
        province: null,
        city: null,
        district: null,
        address: null,
        longitude: null,
        latitude: null,
        phone: null,
        servicePhone: null,
        businessHours: null,
        serviceHours: null,
        billAutoConfirm: '1',
        status: '0',
        sort: 0
      };
      this.serviceList = [];
      this.mapPoint = { lng: null, lat: null };
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
        storeName: null,
        status: null,
        city: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.storeId);
      this.single = selection.length != 1;
      this.multiple = !selection.length;
    },
    handleAdd() {
      this.reset();
      this.title = "添加门店";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const storeId = row.storeId || this.ids;
      getStore(storeId).then(response => {
        this.form = response.data || response;
        // 存量门店该列可能是 null（加列前建的），radio 会变成一个都没选中，
        // 保存时又把 null 原样提交回去 —— 兜底成默认的「自动确认」。
        if (!this.form.billAutoConfirm) {
          this.form.billAutoConfirm = '1';
        }
        this.serviceList = this.form.services ? this.form.services.split(',') : [];
        this.mapPoint = { lng: this.form.longitude, lat: this.form.latitude };
        this.title = "修改门店";
        this.open = true;
      });
    },
    submitForm() {
      this.$refs.form.validate(valid => {
        if (valid) {
          this.form.services = this.serviceList.join(',');
          if (this.form.storeId != null) {
            updateStore(this.form).then(response => {
              this.$modal.msgSuccess("修改成功");
              this.open = false;
              this.getList();
            });
          } else {
            addStore(this.form).then(response => {
              this.$modal.msgSuccess("新增成功");
              this.open = false;
              this.getList();
            });
          }
        }
      });
    },
    handleDelete(row) {
      const storeIds = row.storeId || this.ids;
      this.$modal.confirm('是否确认删除门店编号为"' + storeIds + '"的数据项？').then(function() {
        return delStore(storeIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    },
    handleExport() {
      this.download('biz/store/export', { ...this.queryParams }, `store_${new Date().getTime()}.xlsx`);
    }
  }
};
</script>

<style scoped>
.map-tip { font-size: 12px; color: #909399; margin-top: 4px; }
.form-tip { font-size: 12px; color: #E6A23C; line-height: 1.5; }
</style>
