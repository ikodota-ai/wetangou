<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="90px">
      <el-form-item label="预约编号" prop="bookingNo">
        <el-input
          v-model="queryParams.bookingNo"
          placeholder="请输入预约编号"
          clearable
          style="width: 180px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <biz-select v-model="queryParams.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
      </el-form-item>

      <el-form-item label="门店" prop="storeId">
        <biz-select v-model="queryParams.storeId" type="store" width="200px" />
      </el-form-item>
      <el-form-item label="预约服务" prop="productId">
        <biz-select v-model="queryParams.productId" type="product" width="200px" />
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
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 130px">
          <el-option label="开放中" value="0" />
          <el-option label="已确认" value="1" />
          <el-option label="已完成" value="2" />
          <el-option label="已关闭" value="3" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain icon="el-icon-plus" size="mini" @click="handleAdd" v-hasPermi="['biz:booking:add']">新增场次</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="success" plain icon="el-icon-edit" size="mini" :disabled="single" @click="handleUpdate" v-hasPermi="['biz:booking:edit']">修改</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:booking:remove']">删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="el-icon-download" size="mini" @click="handleExport" v-hasPermi="['biz:booking:export']">导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="bookingList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="预约编号" align="center" prop="bookingNo" width="180" />
      <el-table-column label="门店" align="center" prop="storeName" min-width="140" show-overflow-tooltip />
      <el-table-column label="服务名称" align="center" prop="serviceName" min-width="120" show-overflow-tooltip />
      <el-table-column label="预约日期" align="center" prop="bookingDate" width="110" />
      <el-table-column label="时段" align="center" prop="timeSlot" width="100" />
      <el-table-column label="报名人次" align="center" prop="signupCount" width="90" />
      <el-table-column label="报名总人数" align="center" prop="signupPeople" width="100" />
      <el-table-column label="状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="statusType(scope.row.status)">{{ statusText(scope.row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="180" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-user" @click="showMembers(scope.row)" v-hasPermi="['biz:booking:query']">报名名单</el-button>
          <el-button size="mini" type="text" icon="el-icon-edit" @click="handleUpdate(scope.row)" v-hasPermi="['biz:booking:edit']">修改</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:booking:remove']">删除</el-button>
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

    <!-- 新增/修改预约场次对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="560px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="所属商户" prop="merchantId" v-if="!isMerchant()">
          <biz-select v-model="form.merchantId" type="merchant" @change="onMerchantChange" />
        </el-form-item>
        <el-form-item label="门店" prop="storeId">
          <biz-select v-model="form.storeId" type="store" :merchant-id="form.merchantId" auto-pick-single @auto-pick="onStoreAutoPick" />
        </el-form-item>
        <el-form-item label="预约服务" prop="productId">
          <biz-select v-model="form.productId" type="product" @change="onProductChange" />
        </el-form-item>
        <el-form-item label="服务名称" prop="serviceName">
          <el-input v-model="form.serviceName" placeholder="请输入服务名称" />
        </el-form-item>
        <el-form-item label="预约日期" prop="bookingDate">
          <el-date-picker clearable
            v-model="form.bookingDate"
            type="date"
            value-format="yyyy-MM-dd"
            placeholder="请选择预约日期"
            style="width: 100%">
          </el-date-picker>
        </el-form-item>
        <el-form-item label="预约时段" prop="timeSlot">
          <el-input v-model="form.timeSlot" placeholder="如：18:00" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="form.status" placeholder="请选择状态" style="width: 100%">
            <el-option label="开放中" value="0" />
            <el-option label="已确认" value="1" />
            <el-option label="已完成" value="2" />
            <el-option label="已关闭" value="3" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" type="textarea" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>

    <!-- 报名名单抽屉 -->
    <el-drawer title="报名名单" :visible.sync="memberDrawer" size="620px">
      <div style="padding: 0 20px">
        <el-table v-loading="memberLoading" :data="memberList">
          <el-table-column label="会员" prop="memberName" min-width="140" show-overflow-tooltip>
            <template slot-scope="scope">{{ scope.row.memberName || ('会员' + scope.row.memberId) }}</template>
          </el-table-column>
          <el-table-column label="联系人" prop="contact" width="100" />
          <el-table-column label="联系电话" prop="phone" width="130" />
          <el-table-column label="人数" prop="people" width="70" align="center" />
          <el-table-column label="状态" prop="status" width="90" align="center">
            <template slot-scope="scope">
              <el-tag :type="scope.row.status === '0' ? 'success' : 'info'">{{ scope.row.status === '0' ? '已报名' : '已取消' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="报名时间" prop="createTime" width="160" />
        </el-table>
        <el-empty v-if="!memberLoading && memberList.length === 0" description="暂无报名"></el-empty>
      </div>
    </el-drawer>
  </div>
</template>

<script>
import { listBooking, getBooking, delBooking, addBooking, updateBooking, listBookingMembers } from "@/api/biz/booking"

export default {
  name: "Booking",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      bookingList: [],
      title: "",
      open: false,
      memberDrawer: false,
      memberLoading: false,
      memberList: [],
      queryParams: {
        pageNum: 1,
        merchantId: null,
        pageSize: 10,
        bookingNo: null,
        storeId: null,
        productId: null,
        serviceName: null,
        bookingDate: null,
        status: null
      },
      showMerchantFilter: this.isShowMerchantFilter(),
      form: {},
      rules: {
        storeId: [
          { required: true, message: "门店不能为空", trigger: "change" }
        ],
        bookingDate: [
          { required: true, message: "预约日期不能为空", trigger: "blur" }
        ]
      }
    }
  },
  created() {
    this.getList()
  },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    statusText(status) {
      return { '0': '开放中', '1': '已确认', '2': '已完成', '3': '已关闭' }[status] || status
    },
    statusType(status) {
      return { '0': 'success', '1': 'primary', '2': 'info', '3': 'danger' }[status] || 'info'
    },
    getList() {
      this.loading = true
      listBooking(this.queryParams).then(response => {
        this.bookingList = response.rows
        this.total = response.total
        this.loading = false
      })
    },
    onProductChange() {},
    cancel() {
      this.open = false
      this.reset()
    },
    reset() {
      this.form = {
        bookingId: null,
        bookingNo: null,
        storeId: null,
        productId: null,
        serviceName: null,
        bookingDate: null,
        timeSlot: null,
        status: '0',
        remark: null,
        merchantId: this.currentMerchantId() || null,
        }
      this.resetForm("form")
    },
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    resetQuery() {
      this.resetForm("queryForm")
      this.queryParams.storeId = null
      this.queryParams.productId = null
      this.handleQuery()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.bookingId)
      this.single = selection.length !== 1
      this.multiple = !selection.length
    },
    handleAdd() {
      this.reset()
      this.open = true
      this.title = "新增预约场次"
    },
    handleUpdate(row) {
      this.reset()
      const bookingId = row.bookingId || this.ids
      getBooking(bookingId).then(response => {
        this.form = response.data
        this.open = true
        this.title = "修改预约场次"
      })
    },
    showMembers(row) {
      this.memberDrawer = true
      this.memberLoading = true
      this.memberList = []
      listBookingMembers(row.bookingId).then(res => {
        this.memberList = res.data || res.rows || []
        this.memberLoading = false
      }).catch(() => { this.memberLoading = false })
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (valid) {
          if (this.form.bookingId != null) {
            updateBooking(this.form).then(() => {
              this.$modal.msgSuccess("修改成功")
              this.open = false
              this.getList()
            })
          } else {
            addBooking(this.form).then(() => {
              this.$modal.msgSuccess("新增成功")
              this.open = false
              this.getList()
            })
          }
        }
      })
    },
    handleDelete(row) {
      const bookingIds = row.bookingId || this.ids
      this.$modal.confirm('是否确认删除预约场次编号为"' + bookingIds + '"的数据项？').then(function() {
        return delBooking(bookingIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    handleExport() {
      this.download('biz/booking/export', {
        ...this.queryParams
      }, `booking_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
