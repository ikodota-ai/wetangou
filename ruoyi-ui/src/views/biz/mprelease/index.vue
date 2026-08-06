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