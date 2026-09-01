<template>
  <div class="app-container">
    <el-tabs v-model="activeTab" @tab-click="onTabChange">
      <el-tab-pane label="邀请码" name="invite"></el-tab-pane>
      <el-tab-pane label="员工名单" name="staff"></el-tab-pane>
    </el-tabs>

    <!-- ============ 邀请码 ============ -->
    <div v-show="activeTab === 'invite'">
      <el-form :model="inviteQuery" ref="inviteQueryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
        <el-form-item label="邀请码" prop="inviteCode">
          <el-input v-model="inviteQuery.inviteCode" placeholder="请输入邀请码" clearable @keyup.enter.native="getInviteList" />
        </el-form-item>
        <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
          <biz-select v-model="inviteQuery.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="inviteQuery.status" placeholder="全部" clearable style="width:140px">
            <el-option label="有效" value="0" />
            <el-option label="已用" value="1" />
            <el-option label="已过期" value="2" />
            <el-option label="已停用" value="3" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="el-icon-search" size="mini" @click="getInviteList">搜索</el-button>
          <el-button icon="el-icon-refresh" size="mini" @click="resetInviteQuery">重置</el-button>
        </el-form-item>
      </el-form>

      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5">
          <el-button type="primary" plain icon="el-icon-plus" size="mini" @click="handleAddInvite" v-hasPermi="['biz:staffInvite:add']">生成邀请码</el-button>
        </el-col>
        <right-toolbar :showSearch.sync="showSearch" @queryTable="getInviteList"></right-toolbar>
      </el-row>

      <el-table v-loading="inviteLoading" :data="inviteList" @selection-change="sel => inviteIds = sel.map(s => s.inviteId)">
        <el-table-column type="selection" width="55" align="center" />
        <el-table-column label="邀请码" align="center" prop="inviteCode">
          <template slot-scope="scope">
            <span class="code-text">{{ scope.row.inviteCode }}</span>
            <el-button type="text" size="mini" @click="copyText(scope.row.inviteCode)">复制</el-button>
          </template>
        </el-table-column>
        <el-table-column label="商户" align="center" prop="merchantName">
          <template slot-scope="scope">{{ scope.row.merchantName || scope.row.merchantId }}</template>
        </el-table-column>
        <el-table-column label="门店" align="center" prop="storeName">
          <template slot-scope="scope">{{ scope.row.storeName || scope.row.storeId }}</template>
        </el-table-column>
        <el-table-column label="角色" align="center" prop="role" />
        <el-table-column label="状态" align="center" prop="status">
          <template slot-scope="scope">
            <el-tag :type="inviteStatusTag(scope.row.status)">{{ inviteStatusText(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="使用人" align="center" prop="usedByName">
          <template slot-scope="scope">{{ scope.row.usedByName || (scope.row.usedBy ? ('员工' + scope.row.usedBy) : '-') }}</template>
        </el-table-column>
        <el-table-column label="使用时间" align="center" prop="usedAt" width="170">
          <template slot-scope="scope">
            <span>{{ scope.row.usedAt ? parseTime(scope.row.usedAt, '{y}-{m}-{d} {h}:{i}') : '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="过期时间" align="center" prop="expireAt" width="170">
          <template slot-scope="scope">
            <span>{{ scope.row.expireAt ? parseTime(scope.row.expireAt, '{y}-{m}-{d} {h}:{i}') : '永久' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="备注" align="center" prop="remark" show-overflow-tooltip />
        <el-table-column label="操作" align="center" width="180" class-name="small-padding fixed-width">
          <template slot-scope="scope">
            <el-button size="mini" type="text" icon="el-icon-qrcode"
              @click="showQrcode(scope.row)"
              :disabled="scope.row.status !== '0'"
              v-hasPermi="['biz:staffInvite:query']">{{ scope.row.status === '0' ? '二维码' : '已失效' }}</el-button>
            <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDeleteInvite(scope.row)" v-hasPermi="['biz:staffInvite:remove']">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="inviteTotal>0" :total="inviteTotal" :page.sync="inviteQuery.pageNum" :limit.sync="inviteQuery.pageSize" @pagination="getInviteList" />
    </div>

    <!-- ============ 员工名单 ============ -->
    <div v-show="activeTab === 'staff'">
      <el-form :model="staffQuery" size="small" :inline="true" v-show="showSearch" label-width="80px">
        <el-form-item label="姓名" prop="realName">
          <el-input v-model="staffQuery.realName" placeholder="真实姓名" clearable @keyup.enter.native="getStaffList" />
        </el-form-item>
        <el-form-item label="手机" prop="phone">
          <el-input v-model="staffQuery.phone" placeholder="手机号" clearable @keyup.enter.native="getStaffList" />
        </el-form-item>
        <el-form-item label="商户" prop="merchantId" v-if="showMerchantFilter">
          <biz-select v-model="staffQuery.merchantId" type="merchant" width="200px" placeholder="请选择商户" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="staffQuery.status" placeholder="全部" clearable style="width:140px" @change="getStaffList">
            <el-option label="在职" value="0" />
            <el-option label="待审核" value="3" />
            <el-option label="离职" value="1" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" icon="el-icon-search" size="mini" @click="getStaffList">搜索</el-button>
          <el-button icon="el-icon-refresh" size="mini" @click="resetStaffQuery">重置</el-button>
        </el-form-item>
      </el-form>

      <el-row :gutter="10" class="mb8">
        <el-col :span="1.5">
          <el-button type="warning" plain size="mini" icon="el-icon-s-check" @click="showPendingOnly">
            待审核{{ pendingCount > 0 ? '（' + pendingCount + '）' : '' }}
          </el-button>
        </el-col>
        <right-toolbar :showSearch.sync="showSearch" @queryTable="getStaffList"></right-toolbar>
      </el-row>

      <el-table v-loading="staffLoading" :data="staffList">
        <el-table-column label="userId" align="center" prop="userId" width="80" />
        <el-table-column label="账号" align="center" prop="userName" />
        <el-table-column label="昵称" align="center" prop="nickName" />
        <el-table-column label="真实姓名" align="center" prop="realName" />
        <el-table-column label="手机" align="center" prop="phone" />
        <el-table-column label="微信绑定" align="center" prop="wxBound" width="150">
          <template slot-scope="scope">
            <el-tag v-if="scope.row.wxBound === 1" type="success" size="mini">已绑（可免密）</el-tag>
            <el-tag v-else type="info" size="mini">未绑</el-tag>
            <div v-if="scope.row.openidMasked" class="openid-masked">{{ scope.row.openidMasked }}</div>
          </template>
        </el-table-column>
        <el-table-column label="门店" align="center" prop="storeName">
          <template slot-scope="scope">{{ scope.row.storeName || scope.row.storeId }}</template>
        </el-table-column>
        <el-table-column label="角色" align="center" prop="role" />
        <el-table-column label="状态" align="center" prop="status">
          <template slot-scope="scope">
            <el-tag :type="staffStatusTag(scope.row.status)">{{ staffStatusText(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="入职" align="center" prop="hiredAt" width="170">
          <template slot-scope="scope">
            <span>{{ scope.row.hiredAt ? parseTime(scope.row.hiredAt, '{y}-{m}-{d}') : '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" align="center" width="330" class-name="small-padding fixed-width">
          <template slot-scope="scope">
            <template v-if="scope.row.status === '3'">
              <el-button size="mini" type="text" icon="el-icon-check" @click="handleAudit(scope.row, true)" v-hasPermi="['biz:staffInvite:edit']">通过</el-button>
              <el-button size="mini" type="text" icon="el-icon-close" style="color:#F56C6C" @click="handleAudit(scope.row, false)" v-hasPermi="['biz:staffInvite:edit']">拒绝</el-button>
            </template>
            <el-button size="mini" type="text" icon="el-icon-edit" @click="handleEditStaff(scope.row)" v-hasPermi="['biz:staffInvite:edit']">补录资料</el-button>
            <el-button
              size="mini"
              type="text"
              icon="el-icon-mobile"
              :disabled="scope.row.wxBound !== 1"
              @click="handleUnbindWx(scope.row)"
              v-hasPermi="['biz:staffInvite:edit']">解绑微信</el-button>
            <el-button
              size="mini"
              type="text"
              icon="el-icon-key"
              @click="handleResetStaffPwd(scope.row)"
              v-hasPermi="['biz:staffInvite:edit']">重置密码</el-button>
            <el-button size="mini" type="text" icon="el-icon-delete" @click="handleDeleteStaff(scope.row)" v-hasPermi="['biz:staffInvite:remove']">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <pagination v-show="staffTotal>0" :total="staffTotal" :page.sync="staffQuery.pageNum" :limit.sync="staffQuery.pageSize" @pagination="getStaffList" />
    </div>

    <!-- 生成邀请码 -->
    <el-dialog title="生成邀请码" :visible.sync="inviteOpen" width="480px" append-to-body>
      <el-form ref="inviteForm" :model="inviteForm" :rules="inviteRules" label-width="100px">
        <el-form-item label="商户" prop="merchantId">
          <biz-select v-model="inviteForm.merchantId" type="merchant" width="100%" placeholder="请选择商户" @change="onInviteMerchantChange" />
        </el-form-item>
        <el-form-item label="门店" prop="storeId">
          <biz-select v-model="inviteForm.storeId" type="store" :params="{ merchantId: inviteForm.merchantId }" width="100%" placeholder="请选择门店" />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="inviteForm.role" placeholder="请选择" style="width:100%">
            <el-option label="员工" value="STAFF" />
            <el-option label="店长" value="MANAGER" />
            <el-option label="店主" value="OWNER" />
          </el-select>
        </el-form-item>
        <el-form-item label="过期时间" prop="expireAt">
          <el-date-picker v-model="inviteForm.expireAt" type="datetime" placeholder="默认 7 天后" style="width:100%" value-format="yyyy-MM-dd HH:mm:ss" />
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="inviteForm.remark" type="textarea" :rows="2" maxlength="200" />
        </el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="inviteOpen = false">取 消</el-button>
        <el-button type="primary" :loading="inviteSubmitting" @click="submitInvite">生成</el-button>
      </div>
    </el-dialog>

    <!-- 二维码弹窗 -->
    <el-dialog :title="'邀请码 ' + (qrcodeRow ? qrcodeRow.inviteCode : '')" :visible.sync="qrcodeOpen" width="420px" append-to-body>
      <div class="qrcode-box">
        <div v-if="qrcodeLoading" class="qrcode-loading">生成中…</div>
        <img v-else-if="qrcodeUrl" :src="qrcodeUrl" class="qrcode-img" />
        <div v-else class="qrcode-loading">无二维码</div>
        <div class="qrcode-hint">
          <div class="qrcode-steps">
            <div><b>①</b> 把二维码发给新员工（可下载图片转发到微信）</div>
            <div><b>②</b> 员工用微信「扫一扫」或相册长按识别，无需先注册登录</div>
            <div><b>③</b> 员工提交入职申请后，在下方「待审核员工」中审核通过</div>
          </div>
          <div class="qrcode-code">邀请码：<b>{{ qrcodeRow ? qrcodeRow.inviteCode : '' }}</b></div>
          <el-alert
            type="warning" :closable="false" show-icon
            title="微信「扫一扫」仅能识别已发布的正式版小程序码；开发版/体验版请用开发者工具的「通过二维码编译」测试。" />
        </div>
      </div>
      <div slot="footer">
        <el-button v-if="qrcodeUrl" type="primary" @click="downloadQrcode">下载图片</el-button>
        <el-button @click="qrcodeOpen = false">关 闭</el-button>
      </div>
    </el-dialog>

    <!-- 补录员工 -->
    <el-dialog title="补录员工资料" :visible.sync="staffOpen" width="480px" append-to-body>
      <el-form ref="staffForm" :model="staffForm" :rules="staffRules" label-width="100px">
        <el-form-item label="账号">
          <span>{{ staffForm.userName || ('用户' + staffForm.userId) }}</span>
        </el-form-item>
        <el-form-item label="真实姓名" prop="realName">
          <el-input v-model="staffForm.realName" maxlength="32" />
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="staffForm.phone" maxlength="11" />
        </el-form-item>
        <el-form-item label="员工编号" prop="staffNo">
          <el-input v-model="staffForm.staffNo" maxlength="32" />
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-select v-model="staffForm.status" style="width:100%">
            <el-option label="在职" value="0" />
            <el-option label="待审核" value="3" />
            <el-option label="离职" value="1" />
          </el-select>
        </el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="staffOpen = false">取 消</el-button>
        <el-button type="primary" :loading="staffSubmitting" @click="submitStaff">保 存</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listStaffInvite, addStaffInvite, delStaffInvite, listStaff, updateStaff, profileStaff, delStaff, qrcodeStaffInvite, unbindStaffWx, resetStaffPwd, listStaffAudit, auditStaff } from '@/api/biz/staffInvite'

export default {
  name: 'StaffInvite',
  data() {
    return {
      activeTab: 'invite',
      showSearch: true,
      showMerchantFilter: this.isShowMerchantFilter(),

      // 邀请码
      inviteLoading: true,
      inviteList: [],
      inviteTotal: 0,
      inviteIds: [],
      inviteQuery: { pageNum: 1, pageSize: 10, inviteCode: null, merchantId: null, status: null },
      inviteOpen: false,
      inviteForm: { merchantId: null, storeId: null, role: 'STAFF', expireAt: null, remark: '' },
      inviteRules: {
        merchantId: [{ required: true, message: '请选择商户', trigger: 'change' }],
        storeId: [{ required: true, message: '请选择门店', trigger: 'change' }],
        role: [{ required: true, message: '请选择角色', trigger: 'change' }]
      },
      inviteSubmitting: false,

      // 二维码弹窗
      qrcodeOpen: false,
      qrcodeRow: null,
      qrcodeUrl: '',
      qrcodeLoading: false,
      // 员工名单
      staffLoading: true,
      staffList: [],
      staffTotal: 0,
      staffQuery: { pageNum: 1, pageSize: 10, realName: null, phone: null, merchantId: null, status: null },
      pendingCount: 0,
      staffOpen: false,
      staffForm: { id: null, userId: null, userName: '', realName: '', phone: '', staffNo: '', status: '0' },
      staffRules: {
        phone: [{ pattern: /^$|^1[3-9]\d{9}$/, message: '手机号格式错误', trigger: 'blur' }]
      },
      staffSubmitting: false
    }
  },
  watch: {
    'inviteQuery.merchantId': {
      handler() { this.getInviteList() }
    },
    'staffQuery.merchantId': {
      handler() { this.getStaffList() }
    }
  },
  mounted() {
    this.getInviteList()
  },
  methods: {
    isShowMerchantFilter() {
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || ''
      return userType !== '2'
    },
    copyText(text) {
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(
            () => this.$modal.msgSuccess('已复制：' + text),
            () => this.$modal.msgWarning('复制失败')
          )
        } else {
          const ta = document.createElement('textarea')
          ta.value = text
          document.body.appendChild(ta)
          ta.select()
          document.execCommand('copy')
          document.body.removeChild(ta)
          this.$modal.msgSuccess('已复制：' + text)
        }
      } catch (e) {
        this.$modal.msgWarning('复制失败：' + e.message)
      }
    },
    onTabChange() {
      if (this.activeTab === 'invite') this.getInviteList()
      else this.getStaffList()
    },

    // ===== 邀请码 =====
    getInviteList() {
      this.inviteLoading = true
      listStaffInvite(this.inviteQuery).then(res => {
        this.inviteList = res.rows || []
        this.inviteTotal = res.total || 0
      }).finally(() => { this.inviteLoading = false })
    },
    resetInviteQuery() {
      this.inviteQuery = { pageNum: 1, pageSize: 10, inviteCode: null, merchantId: this.inviteQuery.merchantId, status: null }
      this.getInviteList()
    },
    handleAddInvite() {
      this.inviteForm = { merchantId: null, storeId: null, role: 'STAFF', expireAt: null, remark: '' }
      this.inviteOpen = true
    },
    onInviteMerchantChange() {
      this.inviteForm.storeId = null
    },
    submitInvite() {
      this.$refs.inviteForm.validate(valid => {
        if (!valid) return
        this.inviteSubmitting = true
        addStaffInvite(this.inviteForm).then(res => {
          this.$modal.msgSuccess(res.msg || '已生成')
          this.inviteOpen = false
          this.getInviteList()
        }).finally(() => { this.inviteSubmitting = false })
      })
    },
    handleDeleteInvite(row) {
      this.$modal.confirm('确认删除邀请码 ' + row.inviteCode + ' ？').then(() => {
        return delStaffInvite(row.inviteId)
      }).then(() => {
        this.getInviteList()
        this.$modal.msgSuccess('已删除')
      }).catch(() => {})
    },
    showQrcode(row) {
      if (row.status !== '0') {
        this.$modal.msgWarning('该邀请码已' + this.inviteStatusText(row.status) + '，无法生成二维码')
        return
      }
      this.qrcodeRow = row
      this.qrcodeUrl = row.wxacodeUrl || ''
      this.qrcodeOpen = true
      if (this.qrcodeUrl) return
      this.qrcodeLoading = true
      qrcodeStaffInvite(row.inviteId).then(res => {
        this.qrcodeUrl = (res && (res.url || (res.data && res.data.url))) || ''
        if (this.qrcodeUrl) this.$modal.msgSuccess('二维码已生成')
      }).catch(err => {
        this.$modal.msgError((err && (err.msg || err.message)) || '生成失败')
      }).finally(() => { this.qrcodeLoading = false })
    },
    downloadQrcode() {
      if (!this.qrcodeUrl) return
      const a = document.createElement('a')
      a.href = this.qrcodeUrl
      a.download = 'invite_' + (this.qrcodeRow ? this.qrcodeRow.inviteCode : '') + '.png'
      a.target = '_blank'
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
    },
    inviteStatusText(s) {
      return ({ '0': '有效', '1': '已用', '2': '已过期' })[s] || s
    },
    inviteStatusTag(s) {
      return ({ '0': 'success', '1': 'info', '2': 'danger' })[s] || ''
    },

    // ===== 员工名单 =====
    getStaffList() {
      this.staffLoading = true
      listStaff(this.staffQuery).then(res => {
        this.staffList = res.rows || []
        this.staffTotal = res.total || 0
      }).finally(() => { this.staffLoading = false })
      this.loadPendingCount()
    },
    loadPendingCount() {
      listStaffAudit().then(res => {
        this.pendingCount = (res.data || []).length
      }).catch(() => { /* 计数失败不影响主列表 */ })
    },
    showPendingOnly() {
      this.staffQuery.status = '3'
      this.staffQuery.pageNum = 1
      this.getStaffList()
    },
    staffStatusText(s) {
      return ({ '0': '在职', '1': '离职', '3': '待审核' })[s] || s
    },
    staffStatusTag(s) {
      return ({ '0': 'success', '1': 'info', '3': 'warning' })[s] || ''
    },
    handleAudit(row, approve) {
      const tip = approve
        ? '确认通过「' + (row.realName || row.nickName || row.userId) + '」的入职申请？通过后即可登录商家端核销。'
        : '确认拒绝并移除该员工的门店关联？账号会保留，可重新扫码入职。'
      this.$modal.confirm(tip).then(() => {
        return auditStaff({ id: row.id, approve: approve })
      }).then(() => {
        this.$modal.msgSuccess(approve ? '已通过' : '已拒绝')
        this.getStaffList()
      }).catch(() => {})
    },
    resetStaffQuery() {
      this.staffQuery = { pageNum: 1, pageSize: 10, realName: null, phone: null, merchantId: this.staffQuery.merchantId, status: null }
      this.getStaffList()
    },
    handleEditStaff(row) {
      this.staffForm = {
        id: row.id,
        userId: row.userId,
        userName: row.userName,
        realName: row.realName || '',
        phone: row.phone || '',
        staffNo: row.staffNo || '',
        status: row.status || '0'
      }
      this.staffOpen = true
    },
    submitStaff() {
      this.$refs.staffForm.validate(valid => {
        if (!valid) return
        this.staffSubmitting = true
        // 同时更新 biz_merchant_staff + sys_user 资料（用 profile 接口更安全）
        const payload = {
          id: this.staffForm.id,
          userId: this.staffForm.userId,
          realName: this.staffForm.realName,
          phone: this.staffForm.phone,
          staffNo: this.staffForm.staffNo,
          status: this.staffForm.status
        }
        // 先 update（id 维度），再 profile（userId 维度），互不冲突
        Promise.all([updateStaff(payload), profileStaff(payload)])
          .then(() => {
            this.$modal.msgSuccess('已保存')
            this.staffOpen = false
            this.getStaffList()
          })
          .catch(err => this.$modal.msgError(err.msg || '保存失败'))
          .finally(() => { this.staffSubmitting = false })
      })
    },
    handleDeleteStaff(row) {
      this.$modal.confirm('确认删除员工 ' + (row.realName || row.userName) + ' ？').then(() => {
        return delStaff(row.id)
      }).then(() => {
        this.getStaffList()
        this.$modal.msgSuccess('已删除')
      }).catch(() => {})
    },
    /** 解绑微信：员工换手机/换微信/离职时用。只清 openid，不解除雇佣关系 */
    handleUnbindWx(row) {
      if (row.wxBound !== 1) {
        this.$modal.msgWarning('该员工尚未绑定微信')
        return
      }
      const who = row.realName || row.userName || ('用户' + row.userId)
      this.$modal.confirm('确认解绑「' + who + '」的微信？解绑后该员工需重新用账号密码登录（登录时会自动绑定新微信），员工关系不受影响。').then(() => {
        return unbindStaffWx(row.userId)
      }).then(() => {
        this.getStaffList()
        this.$modal.msgSuccess('已解绑微信')
      }).catch(() => {})
    },
    /**
     * 重置员工登录密码：后端生成 8 位随机密码，明文只回显一次。
     *
     * 用 $alert（而不是 msgSuccess 一闪而过）是因为这串密码不落库也不写日志，
     * 关掉弹窗就再也拿不到，只能重新重置。
     */
    handleResetStaffPwd(row) {
      const who = row.realName || row.userName || ('用户' + row.userId)
      this.$modal.confirm('确认重置「' + who + '」的登录密码？重置后旧密码立即失效，新密码只显示一次，请及时转交本人。').then(() => {
        return resetStaffPwd(row.userId)
      }).then(res => {
        this.$alert(
          '<div style="line-height:1.9">' +
          '<div>账号：<b>' + (res.userName || '') + '</b></div>' +
          '<div>新密码：<b style="color:#E6A23C;font-size:16px">' + (res.newPassword || '') + '</b></div>' +
          '<div style="color:#909399;font-size:12px;margin-top:6px">密码不会保存，关闭后无法再次查看。员工可用它登录小程序商家版，登录后会自动绑定微信，之后即可免密进入。</div>' +
          '</div>',
          '密码已重置',
          { dangerouslyUseHTMLString: true, confirmButtonText: '我已记录' }
        )
      }).catch(() => {})
    }
  }
}
</script>

<style scoped>
.qrcode-steps { text-align: left; line-height: 1.9; margin-bottom: 8px; }
.qrcode-steps b { color: #409EFF; margin-right: 4px; }
.openid-masked {
  margin-top: 2px;
  font-family: 'SF Mono', Menlo, monospace;
  font-size: 11px;
  color: #999;
}
.code-text {
  font-family: 'SF Mono', Menlo, monospace;
  font-size: 16px;
  font-weight: 700;
  color: #3A6B35;
  margin-right: 8px;
}
.qrcode-box {
  display: flex; flex-direction: column; align-items: center; padding: 16rpx 0 8rpx;
}
.qrcode-img {
  width: 280px; height: 280px;
  border: 1px solid #eee; border-radius: 8px;
}
.qrcode-loading {
  width: 280px; height: 280px;
  display: flex; align-items: center; justify-content: center;
  color: #999; background: #fafafa; border-radius: 8px;
}
.qrcode-hint {
  margin-top: 16px; text-align: center; font-size: 14px; color: #666; line-height: 1.8;
}
.qrcode-code b { color: #3A6B35; font-size: 16px; }
</style>
