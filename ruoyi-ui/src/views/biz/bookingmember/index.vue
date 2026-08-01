<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="90px">
      <el-form-item label="门店" prop="storeIds">
        <biz-select v-model="queryParams.storeIds" type="store" multiple width="220px" />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="报名会员" prop="memberIds">
        <biz-select v-model="queryParams.memberIds" type="member" multiple width="220px" />
      </el-form-item>
      <el-form-item label="服务名称" prop="serviceName">
        <el-input
          v-model="queryParams.serviceName"
          placeholder="请输入服务名称"
          clearable
          style="width: 180px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="预约日期" prop="bookingDate">
        <el-date-picker clearable
          v-model="queryParams.bookingDate"
          type="date"
          value-format="yyyy-MM-dd"
          placeholder="请选择预约日期">
        </el-date-picker>
      </el-form-item>
      <el-form-item label="联系人" prop="contact">
        <el-input
          v-model="queryParams.contact"
          placeholder="请输入联系人"
          clearable
          style="width: 150px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="联系电话" prop="phone">
        <el-input
          v-model="queryParams.phone"
          placeholder="请输入联系电话"
          clearable
          style="width: 150px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 130px">
          <el-option label="已报名" value="0" />
          <el-option label="已取消" value="1" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="warning" plain icon="el-icon-download" size="mini" @click="handleExport" v-hasPermi="['biz:booking:export']">导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="memberList" style="width: 100%">
      <el-table-column label="明细ID" align="center" prop="id" width="80" />
      <el-table-column label="门店" align="center" prop="storeName" min-width="140" show-overflow-tooltip />
      <el-table-column label="服务名称" align="center" prop="serviceName" min-width="140" show-overflow-tooltip />
      <el-table-column label="预约日期" align="center" prop="bookingDate" width="110" />
      <el-table-column label="时段" align="center" prop="timeSlot" width="120" />
      <el-table-column label="报名会员" align="center" prop="memberName" min-width="120" show-overflow-tooltip />
      <el-table-column label="联系人" align="center" prop="contact" width="100" />
      <el-table-column label="联系电话" align="center" prop="phone" width="130" />
      <el-table-column label="报名人数" align="center" prop="people" width="90" />
      <el-table-column label="状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'info'">
            {{ scope.row.status === '0' ? '已报名' : '已取消' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="报名时间" align="center" prop="createTime" width="160" />
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
import { listBookingMember } from "@/api/biz/booking"

export default {
  name: "BookingMember",
  data() {
    return {
      loading: true,
      showSearch: true,
      total: 0,
      memberList: [],
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        storeIds: [],
        memberIds: [],
        serviceName: null,
        bookingDate: null,
        contact: null,
        phone: null,
        status: null
      },
      showMerchantFilter: this.isShowMerchantFilter()
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
      return {
        pageNum: this.queryParams.pageNum,
        pageSize: this.queryParams.pageSize,
        serviceName: this.queryParams.serviceName,
        bookingDate: this.queryParams.bookingDate,
        contact: this.queryParams.contact,
        phone: this.queryParams.phone,
        status: this.queryParams.status,
        params: {
          storeIds: this.queryParams.storeIds,
          memberIds: this.queryParams.memberIds
        }
      };
    },
    getList() {
      this.loading = true;
      listBookingMember(this.buildParams()).then(response => {
        this.memberList = response.rows || response.data || [];
        this.total = response.total || this.memberList.length;
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
        memberIds: [],
        serviceName: null,
        bookingDate: null,
        contact: null,
        phone: null,
        status: null
      };
      this.handleQuery();
    },
    handleExport() {
      this.download('biz/booking/member/export', {
        ...this.buildParams()
      }, `booking_member_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
