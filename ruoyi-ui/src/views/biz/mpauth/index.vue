<template>
  <div class="app-container">
    <el-alert
      title="本页展示商户小程序通过微信开放平台第三方平台的授权结果。授权由商户扫码完成，平台侧只做查看与状态维护，不能凭空新增授权。"
      type="info"
      :closable="false"
      show-icon
      class="mb8"
    />

    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
        <el-select v-model="queryParams.merchantId" placeholder="全部" clearable filterable style="width: 180px">
          <el-option
            v-for="item in merchantOptions"
            :key="item.merchantId"
            :label="item.merchantName"
            :value="item.merchantId"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="AppId" prop="appid">
        <el-input v-model="queryParams.appid" placeholder="请输入 AppId" clearable style="width: 200px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="小程序名称" prop="nickName">
        <el-input v-model="queryParams.nickName" placeholder="请输入小程序名称" clearable style="width: 180px" @keyup.enter.native="handleQuery" />
      </el-form-item>
      <el-form-item label="授权状态" prop="authStatus">
        <el-select v-model="queryParams.authStatus" placeholder="全部" clearable style="width: 120px">
          <el-option v-for="d in authStatusOptions" :key="d.value" :label="d.label" :value="d.value" />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" icon="el-icon-search" size="mini" @click="handleQuery">搜索</el-button>
        <el-button icon="el-icon-refresh" size="mini" @click="resetQuery">重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="danger" plain icon="el-icon-delete" size="mini" :disabled="multiple" @click="handleDelete" v-hasPermi="['biz:mpauth:remove']">删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button type="warning" plain icon="el-icon-download" size="mini" @click="handleExport" v-hasPermi="['biz:mpauth:export']">导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="mpauthList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="小程序" align="left" min-width="200">
        <template slot-scope="scope">
          <div style="display: flex; align-items: center;">
            <el-avatar v-if="scope.row.headImg" :src="scope.row.headImg" :size="32" style="flex-shrink: 0;"></el-avatar>
            <el-avatar v-else :size="32" icon="el-icon-mobile-phone" style="flex-shrink: 0;"></el-avatar>
            <div style="margin-left: 8px; line-height: 1.4;">
              <div>{{ scope.row.nickName || '未获取' }}</div>
              <div style="color: #909399; font-size: 12px;">{{ scope.row.appid }}</div>
            </div>
          </div>
        </template>
      </el-table-column>
      <el-table-column label="所属商户" align="center" prop="merchantName" min-width="120">
        <template slot-scope="scope">{{ scope.row.merchantName || ('商户' + scope.row.merchantId) }}</template>
      </el-table-column>
      <el-table-column label="主体名称" align="center" prop="principalName" min-width="140" show-overflow-tooltip />
      <el-table-column label="认证类型" align="center" width="100">
        <template slot-scope="scope">{{ verifyTypeLabel(scope.row.verifyType) }}</template>
      </el-table-column>
      <el-table-column label="授权状态" align="center" width="100">
        <template slot-scope="scope">
          <el-tag :type="statusTagType(scope.row.authStatus)" size="mini">{{ labelOf(authStatusOptions, scope.row.authStatus) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="授权时间" align="center" prop="authTime" width="160" />
      <el-table-column label="操作" align="center" width="140" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button size="mini" type="text" icon="el-icon-view" @click="handleView(scope.row)" v-hasPermi="['biz:mpauth:query']">详情</el-button>
          <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDelete(scope.row)" v-hasPermi="['biz:mpauth:remove']">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total>0" :total="total" :page.sync="queryParams.pageNum" :limit.sync="queryParams.pageSize" @pagination="getList" />

    <!-- 授权详情 -->
    <el-dialog title="授权详情" :visible.sync="viewOpen" width="640px" append-to-body>
      <el-descriptions :column="2" border size="small" v-if="detail">
        <el-descriptions-item label="所属商户">{{ detail.merchantName || ('商户' + detail.merchantId) }}</el-descriptions-item>
        <el-descriptions-item label="AppId">{{ detail.appid }}</el-descriptions-item>
        <el-descriptions-item label="小程序名称">{{ detail.nickName || '-' }}</el-descriptions-item>
        <el-descriptions-item label="主体名称">{{ detail.principalName || '-' }}</el-descriptions-item>
        <el-descriptions-item label="认证类型">{{ verifyTypeLabel(detail.verifyType) }}</el-descriptions-item>
        <el-descriptions-item label="授权状态">
          <el-tag :type="statusTagType(detail.authStatus)" size="mini">{{ labelOf(authStatusOptions, detail.authStatus) }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="授权时间" :span="2">{{ detail.authTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="已授权权限集" :span="2">
          <span v-if="!detail.funcInfo">-</span>
          <el-tag v-for="f in funcList" :key="f" size="mini" style="margin: 2px 4px 2px 0;">{{ f }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="刷新令牌" :span="2">
          <!-- refresh_token 是长期凭证，等同账号密码，默认打码，避免截图外泄 -->
          <span v-if="!detail.refreshToken">-</span>
          <template v-else>
            <span style="word-break: break-all;">{{ tokenMasked ? maskToken(detail.refreshToken) : detail.refreshToken }}</span>
            <el-button type="text" size="mini" style="margin-left: 8px;" @click="tokenMasked = !tokenMasked">{{ tokenMasked ? '显示' : '隐藏' }}</el-button>
          </template>
        </el-descriptions-item>
      </el-descriptions>
      <div slot="footer" class="dialog-footer">
        <el-button @click="viewOpen = false">关 闭</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listMpAuth, getMpAuth, delMpAuth } from "@/api/biz/mpauth"
import { listMerchant } from "@/api/biz/merchant"

export default {
  name: "MpAuth",
  data() {
    return {
      loading: true,
      ids: [],
      multiple: true,
      showSearch: true,
      total: 0,
      mpauthList: [],
      merchantOptions: [],
      viewOpen: false,
      detail: null,
      // refresh_token 默认打码，点「显示」才展开
      tokenMasked: true,
      // 与 MpAuth.authStatus 的 readConverterExp 保持一致：0=已授权 1=已取消 2=已过期
      authStatusOptions: [
        { value: "0", label: "已授权" },
        { value: "1", label: "已取消" },
        { value: "2", label: "已过期" }
      ],
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        merchantId: null,
        appid: null,
        nickName: null,
        authStatus: null
      }
    }
  },
  computed: {
    // 商户账号(userType=2)只能看自己，隐藏商户筛选框避免误以为能切换
    // 注意：store/getters.js 未暴露 userType，需直接读 state（与 biz/order 页一致）
    showMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    funcList() {
      if (!this.detail || !this.detail.funcInfo) return []
      return String(this.detail.funcInfo).split(',').filter(s => s !== '')
    }
  },
  created() {
    this.getList()
    if (this.showMerchantFilter) {
      this.loadMerchants()
    }
  },
  methods: {
    getList() {
      this.loading = true
      listMpAuth(this.queryParams).then(response => {
        this.mpauthList = response.rows
        this.total = response.total
        this.loading = false
      }).catch(() => {
        this.loading = false
      })
    },
    loadMerchants() {
      listMerchant({ pageNum: 1, pageSize: 200 }).then(res => {
        this.merchantOptions = res.rows || []
      }).catch(() => {})
    },
    labelOf(options, value) {
      const hit = options.find(o => o.value === String(value))
      return hit ? hit.label : (value == null || value === '' ? '-' : value)
    },
    statusTagType(status) {
      if (String(status) === '0') return 'success'
      if (String(status) === '2') return 'warning'
      return 'danger'
    },
    verifyTypeLabel(t) {
      // 微信开放平台 verify_type_info：-1 未认证 0 微信认证 1 新浪微博 2 腾讯微博
      const map = { '-1': '未认证', '0': '微信认证', '1': '新浪微博认证', '2': '腾讯微博认证' }
      const key = String(t)
      return map[key] !== undefined ? map[key] : (t == null || t === '' ? '-' : t)
    },
    maskToken(token) {
      const s = String(token)
      if (s.length <= 12) return '****'
      return s.slice(0, 6) + '****' + s.slice(-4)
    },
    handleQuery() {
      this.queryParams.pageNum = 1
      this.getList()
    },
    resetQuery() {
      this.resetForm("queryForm")
      this.handleQuery()
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.authId)
      this.multiple = !selection.length
    },
    handleView(row) {
      this.tokenMasked = true
      getMpAuth(row.authId).then(res => {
        this.detail = res.data
        this.viewOpen = true
      })
    },
    handleDelete(row) {
      const authIds = row.authId || this.ids
      this.$modal.confirm('删除授权记录不会取消微信侧的授权关系，仅清理本地数据。确认删除授权编号为「' + authIds + '」的记录？').then(() => {
        return delMpAuth(authIds)
      }).then(() => {
        this.getList()
        this.$modal.msgSuccess("删除成功")
      }).catch(() => {})
    },
    handleExport() {
      this.download('biz/mpauth/export', {
        ...this.queryParams
      }, `mpauth_${new Date().getTime()}.xlsx`)
    }
  }
}
</script>
