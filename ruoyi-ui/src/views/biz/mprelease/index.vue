<template>
  <div class="app-container">
    <el-alert
      v-if="status"
      :title="statusTitle"
      :type="status.configured ? 'success' : 'warning'"
      :closable="false"
      show-icon
      class="mb8"
    />

    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="商户" prop="merchantId">
        <el-select v-model="queryParams.merchantId" placeholder="全部" clearable filterable style="width: 180px">
          <el-option
            v-for="item in merchantOptions"
            :key="item.merchantId"
            :label="item.merchantName"
            :value="item.merchantId"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="版本号" prop="userVersion">
        <el-input
          v-model="queryParams.userVersion"
          placeholder="请输入版本号"
          clearable
          style="width: 150px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="审核状态" prop="auditStatus">
        <el-select v-model="queryParams.auditStatus" placeholder="全部" clearable style="width: 130px">
          <el-option v-for="item in auditOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="发布状态" prop="releaseStatus">
        <el-select v-model="queryParams.releaseStatus" placeholder="全部" clearable style="width: 130px">
          <el-option v-for="item in releaseOptions" :key="item.value" :label="item.label" :value="item.value" />
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
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleDownloadCodePack"
          v-hasPermi="['biz:mprelease:upload']"
        >下载代码包</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="primary"
          plain
          icon="el-icon-upload"
          size="mini"
          @click="handleAdd"
          v-hasPermi="['biz:mprelease:upload']"
        >代上传版本</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="danger"
          plain
          icon="el-icon-delete"
          size="mini"
          :disabled="multiple"
          @click="handleDelete"
          v-hasPermi="['biz:mprelease:list']"
        >删除</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="releaseList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="商户" align="left" prop="merchantName" min-width="150" show-overflow-tooltip />
      <el-table-column label="小程序AppId" align="center" prop="appid" width="190" />
      <el-table-column label="版本号" align="center" prop="userVersion" width="110" />
      <el-table-column label="版本描述" align="left" prop="userDesc" min-width="160" show-overflow-tooltip />
      <el-table-column label="审核状态" align="center" prop="auditStatus" width="110">
        <template slot-scope="scope">
          <el-tag :type="auditTagType(scope.row.auditStatus)" size="mini">
            {{ labelOf(auditOptions, scope.row.auditStatus) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="发布状态" align="center" prop="releaseStatus" width="110">
        <template slot-scope="scope">
          <el-tag :type="releaseTagType(scope.row.releaseStatus)" size="mini">
            {{ labelOf(releaseOptions, scope.row.releaseStatus) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="发布时间" align="center" prop="releaseTime" width="160" />
      <el-table-column label="操作" align="center" width="260" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            v-if="canSubmit(scope.row)"
            size="mini"
            type="text"
            icon="el-icon-s-promotion"
            @click="handleSubmit(scope.row)"
            v-hasPermi="['biz:mprelease:audit']"
          >提审</el-button>
          <el-button
            v-if="scope.row.auditStatus === '1'"
            size="mini"
            type="text"
            icon="el-icon-refresh-left"
            @click="handleUndo(scope.row)"
            v-hasPermi="['biz:mprelease:audit']"
          >撤回</el-button>
          <el-button
            v-if="scope.row.auditStatus === '2' && scope.row.releaseStatus !== '1'"
            size="mini"
            type="text"
            icon="el-icon-check"
            @click="handleRelease(scope.row)"
            v-hasPermi="['biz:mprelease:release']"
          >发布</el-button>
          <el-button
            v-if="scope.row.releaseStatus === '1'"
            size="mini"
            type="text"
            icon="el-icon-back"
            @click="handleRollback(scope.row)"
            v-hasPermi="['biz:mprelease:rollback']"
          >回退</el-button>
          <el-button
            v-if="scope.row.auditStatus === '0'"
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:mprelease:upload']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-view"
            @click="handleDetail(scope.row)"
            v-hasPermi="['biz:mprelease:query']"
          >详情</el-button>
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

    <!-- 代上传/修改版本对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="商户" prop="merchantId">
          <el-select
            v-model="form.merchantId"
            placeholder="请选择商户"
            filterable
            :disabled="form.releaseId != null"
            style="width: 100%"
            @change="handleMerchantChange"
          >
            <el-option
              v-for="item in merchantOptions"
              :key="item.merchantId"
              :label="item.merchantName + (item.appid ? '（' + item.appid + '）' : '（未配置AppId）')"
              :value="item.merchantId"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="版本号" prop="userVersion">
          <el-input v-model="form.userVersion" placeholder="如：1.0.0" />
        </el-form-item>
        <el-form-item label="版本描述" prop="userDesc">
          <el-input v-model="form.userDesc" type="textarea" placeholder="本次更新内容，将展示给微信审核人员" />
        </el-form-item>
        <el-form-item label="模板ID" prop="templateId">
          <el-input v-model="form.templateId" placeholder="第三方平台模板库中的 templateId" />
        </el-form-item>
        <el-form-item label="ext.json" prop="extJson">
          <div class="ext-header">
            <span class="ext-label">选择商户后按其微信配置自动生成，如需特殊参数可手动微调</span>
            <el-button
              type="text"
              size="mini"
              icon="el-icon-refresh"
              :loading="extLoading"
              :disabled="!form.merchantId"
              @click="generateExtJson(true)"
            >重新生成</el-button>
          </div>
          <el-input
            v-model="form.extJson"
            type="textarea"
            :rows="8"
            placeholder="选择商户后自动生成，留空提交时后端也会自动补全"
          />
          <div class="form-tip">
            小程序代码中的 appid、域名等差异只能通过 ext.json 注入，不可编译期写死。
            接口域名取系统参数 <code>wx.open.apiBaseUrl</code>，商户 AppId 取商户管理中的微信配置。
          </div>
        </el-form-item>
        <el-form-item label="备注" prop="remark">
          <el-input v-model="form.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>

    <!-- 详情对话框 -->
    <el-dialog title="发布详情" :visible.sync="detailOpen" width="640px" append-to-body>
      <el-descriptions :column="2" border size="small">
        <el-descriptions-item label="商户">{{ detail.merchantName }}</el-descriptions-item>
        <el-descriptions-item label="AppId">{{ detail.appid }}</el-descriptions-item>
        <el-descriptions-item label="版本号">{{ detail.userVersion }}</el-descriptions-item>
        <el-descriptions-item label="模板ID">{{ detail.templateId || '-' }}</el-descriptions-item>
        <el-descriptions-item label="审核状态">{{ labelOf(auditOptions, detail.auditStatus) }}</el-descriptions-item>
        <el-descriptions-item label="发布状态">{{ labelOf(releaseOptions, detail.releaseStatus) }}</el-descriptions-item>
        <el-descriptions-item label="审核单号">{{ detail.auditId || '-' }}</el-descriptions-item>
        <el-descriptions-item label="发布时间">{{ detail.releaseTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="版本描述" :span="2">{{ detail.userDesc || '-' }}</el-descriptions-item>
        <el-descriptions-item label="审核失败原因" :span="2">{{ detail.auditReason || '-' }}</el-descriptions-item>
        <el-descriptions-item label="ext.json" :span="2">
          <pre class="ext-json">{{ detail.extJson || '-' }}</pre>
        </el-descriptions-item>
      </el-descriptions>
      <div v-if="detail.qrcodeUrl" class="qrcode-box">
        <div class="qrcode-title">体验版二维码</div>
        <el-image :src="detail.qrcodeUrl" style="width: 160px; height: 160px" fit="contain" />
      </div>
      <div slot="footer" class="dialog-footer">
        <el-button @click="detailOpen = false">关 闭</el-button>
      </div>
    </el-dialog>
  <!-- 代上传向导 -->
  <el-dialog title="代上传小程序版本" :visible.sync="wizardVisible" width="640px" append-to-body>
    <el-steps :active="wizardStep" finish-status="success" simple>
      <el-step title="选商户/版本"></el-step>
      <el-step title="生成 ext_json"></el-step>
      <el-step title="确认提交"></el-step>
    </el-steps>
    <div class="wizard-body" style="margin-top: 24px;">
      <div v-show="wizardStep === 0">
        <el-form :model="wizardForm" label-width="100px">
          <el-form-item label="目标商户">
            <el-select v-model="wizardForm.merchantId" placeholder="请选择商户" filterable style="width: 100%" @change="onWizardMerchantChange">
              <el-option v-for="m in merchantOptions" :key="m.merchantId" :label="m.merchantName" :value="m.merchantId" />
            </el-select>
          </el-form-item>
          <el-form-item label="版本号">
            <el-input v-model="wizardForm.userVersion" placeholder="如 1.0.3" />
          </el-form-item>
          <el-form-item label="版本描述">
            <el-input v-model="wizardForm.userDesc" type="textarea" :rows="2" placeholder="本次发版说明" />
          </el-form-item>
          <el-form-item label="模板 ID">
            <el-input v-model="wizardForm.templateId" placeholder="微信开放平台后台申请的小程序代码模板 ID" />
          </el-form-item>
        </el-form>
      </div>
      <div v-show="wizardStep === 1">
        <el-alert title="自动从商户的微信配置生成（注入 merchantId / appid / apiBaseUrl），可手动改" type="info" :closable="false" show-icon style="margin-bottom: 12px;" />
        <el-input v-model="wizardForm.extJson" type="textarea" :rows="10" placeholder="选完商户后会自动生成" />
      </div>
      <div v-show="wizardStep === 2">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="商户">{{ (merchantOptions.find(m => m.merchantId === wizardForm.merchantId) || {}).merchantName }}</el-descriptions-item>
          <el-descriptions-item label="版本号">{{ wizardForm.userVersion }}</el-descriptions-item>
          <el-descriptions-item label="描述">{{ wizardForm.userDesc || '—' }}</el-descriptions-item>
          <el-descriptions-item label="模板 ID">{{ wizardForm.templateId || '—' }}</el-descriptions-item>
          <el-descriptions-item label="ext_json"><pre style="margin: 0;">{{ wizardForm.extJson }}</pre></el-descriptions-item>
        </el-descriptions>
      </div>
    </div>
    <div slot="footer" class="dialog-footer">
      <el-button @click="wizardVisible = false">取 消</el-button>
      <el-button v-if="wizardStep > 0" @click="onWizardPrev">上一步</el-button>
      <el-button v-if="wizardStep < 2" type="primary" @click="onWizardNext">下一步</el-button>
      <el-button v-else type="primary" @click="onWizardSubmit">提 交</el-button>
    </div>
  </el-dialog>

    <!-- 代码包下载弹窗 -->
    <el-dialog title="下载小程序代码包" :visible.sync="codePackVisible" width="540px" append-to-body>
      <el-form :model="codePackForm" label-width="100px" size="small">
        <el-form-item label="选择商家" required>
          <el-select v-model="codePackForm.merchantId" placeholder="请选择商家" filterable clearable style="width:100%" @change="onCodePackMerchantChange">
            <el-option v-for="m in merchantOptions" :key="m.merchantId" :label="m.merchantName + ' (' + (m.merchantNo || ('M' + m.merchantId)) + ')'" :value="m.merchantId" />
          </el-select>
        </el-form-item>
        <el-form-item label="小程序 AppID">
          <el-input v-model="codePackForm.appid" disabled placeholder="随商家自动带出" />
        </el-form-item>
        <el-form-item label="API 地址" required>
          <el-input v-model="codePackForm.baseUrl" placeholder="https://api.wetangou.com 或 http://192.168.x.x:8080" />
        </el-form-item>
        <el-alert
          v-if="codePackForm.appid === ''"
          type="warning"
          :closable="false"
          show-icon
          title="该商家尚未配置 AppID，无法下载"
        />
        <el-alert
          v-else
          type="info"
          :closable="false"
          show-icon
          :title="'zip 里会自动改写 ' + codePackForm.appid + ' 与 API 地址'"
        />
      </el-form>
      <div slot="footer">
        <el-button @click="codePackVisible = false">取 消</el-button>
        <el-button type="primary" :disabled="!codePackForm.appid" @click="onCodePackConfirm">下载 zip</el-button>
      </div>
    </el-dialog>
  </div>
</template>


<script>
import {
  listMpRelease,
  getMpRelease,
  addMpRelease,
  updateMpRelease,
  submitMpRelease,
  undoMpRelease,
  releaseMpRelease,
  rollbackMpRelease,
  delMpRelease,
  buildExtJson,
  getPlatformStatus
} from "@/api/biz/mprelease"
import { listMerchant } from "@/api/biz/merchant"

export default {
  name: "MpRelease",
  data() {
    return {
      loading: true,
      ids: [],
      multiple: true,
      showSearch: true,
      total: 0,
      releaseList: [],
      merchantOptions: [],
      title: "",
      // 第三方平台状态（loadStatus 写入）
      status: null,
      // 代上传向导弹窗。
      //
      // 这三个原先只在 openWizard() 里赋值，从没在 data() 声明过（74f97704 引入
      // 向导时就漏了）—— Vue 的响应式只认 data 里声明过的键，未声明的属性初始
      // 渲染时是 undefined，模板里 wizardForm.merchantId 直接抛
      // 「Cannot read properties of undefined」，整页渲染中断变白板。
      // 弹窗的 v-if 挡不住这个：el-form 的 :model="wizardForm" 在外层就会先求值。
      wizardVisible: false,
      wizardStep: 0,
      wizardForm: {
        merchantId: null,
        userVersion: '',
        userDesc: '',
        templateId: '',
        extJson: ''
      },
      // 代码包下载弹窗
      codePackVisible: false,
      codePackForm: {
        merchantId: null,
        merchantName: '',
        appid: '',
        baseUrl: 'https://api.wetangou.com'
      },
      open: false,
      detailOpen: false,
      extLoading: false,
      detail: {},
      auditOptions: [
        { value: "0", label: "待提交" },
        { value: "1", label: "审核中" },
        { value: "2", label: "审核通过" },
        { value: "3", label: "审核失败" },
        { value: "4", label: "已撤回" }
      ],
      releaseOptions: [
        { value: "0", label: "未发布" },
        { value: "1", label: "已发布" },
        { value: "2", label: "已回退" }
      ],
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        merchantId: null,
        userVersion: null,
        auditStatus: null,
        releaseStatus: null
      },
      form: {},
      rules: {
        merchantId: [
          { required: true, message: "请选择商户", trigger: "change" }
        ],
        userVersion: [
          { required: true, message: "版本号不能为空", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
    this.getMerchantOptions();
    this.loadStatus();
  },
  methods: {
    loadStatus() {
      getPlatformStatus().then(res => {
        if (res && res.data) this.status = res.data
      }).catch(() => {})
    },
    statusTitle() {
      if (!this.status) return ''
      const s = this.status
      const ticketAge = s.ticketAgeSeconds != null
        ? Math.floor(s.ticketAgeSeconds / 60) + ' 分钟前'
        : '尚未推送'
      if (!s.configured) {
        return '微信开放平台第三方平台未配置：提审/发布将仅记录状态、不实际调用微信。可在【平台配置 → 小程序平台配置】中补全 component_appid / component_appsecret。'
      }
      if (!s.ticketFresh) {
        return '第三方平台已配置，但 component_verify_ticket ' + ticketAge + ' 推送过旧，请检查回调连通性。已授权商户：' + s.authorizerCount + ' 个。'
      }
      return '第三方平台运行正常：ticket ' + ticketAge + ' 推送，已授权商户 ' + s.authorizerCount + ' 个。'
    },
    labelOf(options, value) {
      const hit = options.find(item => item.value === value);
      return hit ? hit.label : "-";
    },
    auditTagType(status) {
      const map = { "0": "info", "1": "warning", "2": "success", "3": "danger", "4": "info" };
      return map[status] || "info";
    },
    releaseTagType(status) {
      const map = { "0": "info", "1": "success", "2": "warning" };
      return map[status] || "info";
    },
    // 待提交/审核失败/已撤回均可提审
    canSubmit(row) {
      return ["0", "3", "4"].indexOf(row.auditStatus) >= 0;
    },
    getMerchantOptions() {
      listMerchant({ pageNum: 1, pageSize: 500 }).then(response => {
        this.merchantOptions = response.rows || [];
      }).catch(() => {
        this.merchantOptions = [];
      });
    },
    // 切换商户时自动生成 ext.json；已手动编辑过的内容不静默覆盖
    handleMerchantChange() {
      this.generateExtJson(false);
    },
    // force=true 时无条件覆盖（点“重新生成”）
    generateExtJson(force) {
      if (!this.form.merchantId) {
        return;
      }
      if (!force && this.form.extJson) {
        return;
      }
      this.extLoading = true;
      buildExtJson(this.form.merchantId).then(response => {
        this.$set(this.form, "extJson", response.data || response.msg);
        this.extLoading = false;
        if (force) {
          this.$modal.msgSuccess("已按商户微信配置重新生成");
        }
      }).catch(() => {
        this.extLoading = false;
      });
    },
    getList() {
      this.loading = true;
      listMpRelease(this.queryParams).then(response => {
        this.releaseList = response.rows || [];
        this.total = response.total || 0;
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
        releaseId: null,
        merchantId: null,
        userVersion: null,
        userDesc: null,
        templateId: null,
        extJson: null,
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
      this.queryParams = {
        pageNum: 1,
        pageSize: 10,
        merchantId: null,
        userVersion: null,
        auditStatus: null,
        releaseStatus: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.releaseId);
      this.multiple = !selection.length;
    },
    handleAdd() {
      // 向导式代上传：3 步 = 选商户+版本 → 生成 ext_json → 确认提交
      this.wizardForm = { merchantId: null, userVersion: '', userDesc: '', templateId: '', extJson: '' }
      this.wizardStep = 0
      this.wizardVisible = true
    },
    onWizardMerchantChange(merchantId) {
      if (!merchantId) return
      buildExtJson(merchantId).then(res => {
        this.wizardForm.extJson = (res && res.data) ? (typeof res.data === 'string' ? res.data : JSON.stringify(res.data, null, 2)) : ''
      }).catch(() => {})
    },
    onWizardNext() {
      if (this.wizardStep === 0) {
        if (!this.wizardForm.merchantId) { this.$message.warning('请选择商户'); return }
        if (!this.wizardForm.userVersion) { this.$message.warning('请输入版本号'); return }
      } else if (this.wizardStep === 1) {
        if (!this.wizardForm.extJson) { this.$message.warning('请先生成或填写 ext_json'); return }
      }
      this.wizardStep++
    },
    onWizardPrev() { if (this.wizardStep > 0) this.wizardStep-- },
    onWizardSubmit() {
      addMpRelease({
        merchantId: this.wizardForm.merchantId,
        userVersion: this.wizardForm.userVersion,
        userDesc: this.wizardForm.userDesc,
        templateId: this.wizardForm.templateId,
        extJson: this.wizardForm.extJson
      }).then(() => {
        this.$modal.msgSuccess('已创建待提交版本')
        this.wizardVisible = false
        this.getList()
      })
    },
    legacyHandleAdd() {
      this.reset();
      this.title = "代上传小程序版本";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      getMpRelease(row.releaseId).then(response => {
        this.form = response.data;
        this.open = true;
        this.title = "修改待提交版本";
      });
    },
    handleDetail(row) {
      getMpRelease(row.releaseId).then(response => {
        this.detail = response.data || {};
        this.detailOpen = true;
      });
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (!valid) {
          return;
        }
        // ext.json 需为合法 JSON，避免提交后微信侧报错难排查
        if (this.form.extJson) {
          try {
            JSON.parse(this.form.extJson);
          } catch (e) {
            this.$modal.msgError("ext.json 不是合法的 JSON，请检查后重试");
            return;
          }
        }
        if (this.form.releaseId != null) {
          updateMpRelease(this.form).then(() => {
            this.$modal.msgSuccess("修改成功");
            this.open = false;
            this.getList();
          });
        } else {
          addMpRelease(this.form).then(() => {
            this.$modal.msgSuccess("已生成待提交版本");
            this.open = false;
            this.getList();
          });
        }
      });
    },
    handleSubmit(row) {
      this.$modal.confirm(`是否提交版本 ${row.userVersion} 进行微信审核？审核时长由微信侧决定。`).then(() => {
        return submitMpRelease(row.releaseId);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("已提交审核");
      }).catch(() => {});
    },
    handleUndo(row) {
      this.$modal.confirm(`是否撤回版本 ${row.userVersion} 的审核？`).then(() => {
        return undoMpRelease(row.releaseId);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("已撤回审核");
      }).catch(() => {});
    },
    handleRelease(row) {
      this.$modal.confirm(`是否发布版本 ${row.userVersion} 到线上？发布后全部用户将使用该版本。`).then(() => {
        return releaseMpRelease(row.releaseId);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("已发布上线");
      }).catch(() => {});
    },
    handleRollback(row) {
      this.$modal.confirm(`是否回退版本 ${row.userVersion}？回退后线上将恢复到上一个版本。`).then(() => {
        return rollbackMpRelease(row.releaseId);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("已回退");
      }).catch(() => {});
    },
    handleDelete(row) {
      const releaseIds = row.releaseId || this.ids;
      this.$modal.confirm('是否确认删除发布记录编号为"' + releaseIds + '"的数据项？').then(() => {
        return delMpRelease(releaseIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    },
    /** 打开代码包下载弹窗 */
    handleDownloadCodePack() {
      this.codePackForm = { merchantId: null, merchantName: '', appid: '', baseUrl: 'https://api.wetangou.com' }
      this.codePackVisible = true
    },
    /** 弹窗内点"确认"：浏览器走 a 标签下载 zip（后端返回 Content-Disposition: attachment） */
    onCodePackConfirm() {
      if (!this.codePackForm.merchantId) {
        this.msgError('请选择商家')
        return
      }
      if (!this.codePackForm.baseUrl) {
        this.msgError('请填写 API 地址')
        return
      }
      const url = `/biz/codepack/${this.codePackForm.merchantId}?baseUrl=${encodeURIComponent(this.codePackForm.baseUrl)}`
      this.$download.zip(url, `dytuangou-mini-${this.codePackForm.merchantId}.zip`)
      this.codePackVisible = false
    },
    /** 弹窗内选了商家后回填名称 / appid */
    onCodePackMerchantChange(merchantId) {
      const m = this.merchantOptions.find(x => x.merchantId === merchantId)
      if (m) {
        this.codePackForm.merchantName = m.merchantName
        this.codePackForm.appid = m.appid || ''
      }
    }
  }
};
</script>

<style scoped>
.form-tip {
  color: #909399;
  font-size: 12px;
  line-height: 1.5;
}
.ext-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  line-height: 20px;
}
.ext-label {
  color: #909399;
  font-size: 12px;
}
.ext-json {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-all;
  font-size: 12px;
}
.qrcode-box {
  margin-top: 16px;
  text-align: center;
}
.qrcode-title {
  margin-bottom: 8px;
  color: #606266;
  font-size: 13px;
}
</style>
