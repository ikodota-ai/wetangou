<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="商户名称" prop="merchantName">
        <el-input
          v-model="queryParams.merchantName"
          placeholder="请输入商户名称"
          clearable
          style="width: 200px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="AppId" prop="appid">
        <el-input
          v-model="queryParams.appid"
          placeholder="请输入小程序AppId"
          clearable
          style="width: 200px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="所属代理商" prop="agentId" label-width="90px">
        <el-select v-model="queryParams.agentId" placeholder="全部" clearable filterable style="width: 180px">
          <el-option
            v-for="item in agentOptions"
            :key="item.agentId"
            :label="item.agentName"
            :value="item.agentId"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="请选择状态" clearable style="width: 120px">
          <el-option label="正常" value="0" />
          <el-option label="停用" value="1" />
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
          v-hasPermi="['biz:merchant:add']"
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
          v-hasPermi="['biz:merchant:edit']"
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
          v-hasPermi="['biz:merchant:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:merchant:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="merchantList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="编号" align="center" prop="merchantNo" width="120" />
      <el-table-column label="商户名称" align="left" prop="merchantName" min-width="160" show-overflow-tooltip />
      <el-table-column label="所属代理商" align="center" prop="agentName" width="130" show-overflow-tooltip>
        <template slot-scope="scope">
          <span>{{ scope.row.agentName || '平台直营' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="小程序AppId" align="center" prop="appid" width="190">
        <template slot-scope="scope">
          <span v-if="scope.row.appid">{{ scope.row.appid }}</span>
          <el-tag v-else type="warning" size="mini">未配置</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="支付方式" align="center" prop="payMode" width="130">
        <template slot-scope="scope">
          <span>{{ scope.row.payMode === '1' ? '平台统一收款' : '商户自有商户号' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="联系人" align="center" prop="contact" width="100" />
      <el-table-column label="联系电话" align="center" prop="phone" width="130" />
      <el-table-column label="服务到期" align="center" prop="serviceExpire" width="160">
        <template slot-scope="scope">
          <span v-if="!scope.row.serviceExpire">未设置</span>
          <span v-else :class="{ 'expire-warn': isExpired(scope.row.serviceExpire) }">{{ scope.row.serviceExpire }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'" size="mini">
            {{ scope.row.status === '0' ? '正常' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="180" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:merchant:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-setting"
            @click="handleWxConfig(scope.row)"
            v-hasPermi="['biz:merchant:wxconfig']"
          >微信配置</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:merchant:remove']"
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

    <!-- 添加或修改商户对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="620px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="商户名称" prop="merchantName">
              <el-input v-model="form.merchantName" placeholder="请输入商户名称" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="所属代理商" prop="agentId">
              <el-select v-model="form.agentId" placeholder="平台直营" clearable filterable style="width: 100%">
                <el-option
                  v-for="item in agentOptions"
                  :key="item.agentId"
                  :label="item.agentName"
                  :value="item.agentId"
                />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="商户Logo" prop="logo">
              <image-upload v-model="form.logo" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="联系人" prop="contact">
              <el-input v-model="form.contact" placeholder="请输入联系人" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="联系电话" prop="phone">
              <el-input v-model="form.phone" placeholder="请输入联系电话" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
                      <el-col :span="12">
            <el-form-item label="客服电话" prop="servicePhone">
              <el-input v-model="form.servicePhone" placeholder="门店未配置时小程序客服兜底" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="营业时间" prop="businessHours">
              <el-input v-model="form.businessHours" placeholder="如 09:00-22:00" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="客服二维码" prop="serviceQrcode">
              <image-upload v-model="form.serviceQrcode" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="商家简介" prop="intro">
              <el-input v-model="form.intro" type="textarea" :rows="3" placeholder="小程序首页/联系客服展示" />
            </el-form-item>
          </el-col>
<el-form-item label="营业执照号" prop="licenseNo">
              <el-input v-model="form.licenseNo" placeholder="请输入营业执照号" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="服务到期" prop="serviceExpire">
              <el-date-picker
                v-model="form.serviceExpire"
                type="datetime"
                value-format="yyyy-MM-dd HH:mm:ss"
                placeholder="留空表示不限期"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="营业执照" prop="licenseImg">
              <image-upload v-model="form.licenseImg" :limit="1" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="状态" prop="status">
              <el-select v-model="form.status" placeholder="请选择状态" style="width: 100%">
                <el-option label="正常" value="0" />
                <el-option label="停用" value="1" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="备注" prop="remark">
              <el-input v-model="form.remark" type="textarea" placeholder="请输入备注" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-alert
          title="小程序 AppId 与支付凭证请在列表的「微信配置」中维护，一个商户仅对应一个 AppId。"
          type="info"
          :closable="false"
          show-icon
        />
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>

    <!-- 微信配置对话框 -->
    <el-dialog title="商户微信配置" :visible.sync="wxOpen" width="640px" append-to-body>
      <el-form ref="wxForm" :model="wxForm" :rules="wxRules" label-width="130px">
        <el-divider content-position="left">小程序</el-divider>
        <el-form-item label="小程序AppId" prop="appid">
          <el-input v-model="wxForm.appid" placeholder="wx 开头，全平台唯一" />
        </el-form-item>
        <el-form-item label="小程序AppSecret" prop="appSecret">
          <el-input v-model="wxForm.appSecret" placeholder="请输入 AppSecret" show-password />
        </el-form-item>
        <el-form-item label="接入方式" prop="mpAuthMode">
          <el-radio-group v-model="wxForm.mpAuthMode">
            <el-radio label="0">商户自有密钥</el-radio>
            <el-radio label="1">第三方平台代管</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="联调mock" prop="mockEnabled">
          <el-radio-group v-model="wxForm.mockEnabled">
            <el-radio label="0">开启</el-radio>
            <el-radio label="1">关闭</el-radio>
          </el-radio-group>
          <div class="form-tip">开启后用 code 直接派生 openid，仅用于本地联调，上线务必关闭。</div>
        </el-form-item>

        <el-divider content-position="left">微信支付</el-divider>
        <el-form-item label="支付方式" prop="payMode">
          <el-radio-group v-model="wxForm.payMode">
            <el-radio label="0">商户自有商户号</el-radio>
            <el-radio label="1">平台统一收款</el-radio>
          </el-radio-group>
          <div class="form-tip">推荐自有商户号，资金直达商户，无二清风险。</div>
        </el-form-item>
        <template v-if="wxForm.payMode === '0'">
          <el-form-item label="支付商户号" prop="payMchId">
            <el-input v-model="wxForm.payMchId" placeholder="请输入微信支付商户号" />
          </el-form-item>
          <el-form-item label="支付AppId" prop="payAppid">
            <el-input v-model="wxForm.payAppid" placeholder="一般与小程序 AppId 相同" />
          </el-form-item>
          <el-form-item label="证书序列号" prop="payCertSerial">
            <el-input v-model="wxForm.payCertSerial" placeholder="请输入证书序列号" />
          </el-form-item>
          <el-form-item label="私钥路径" prop="payKeyPath">
            <el-input v-model="wxForm.payKeyPath" placeholder="服务器上 apiclient_key.pem 的绝对路径" />
          </el-form-item>
          <el-form-item label="APIv3密钥" prop="payApiV3Key">
            <el-input v-model="wxForm.payApiV3Key" placeholder="请输入 APIv3 密钥" show-password />
          </el-form-item>
          <el-form-item label="支付回调地址" prop="payNotifyUrl">
            <el-input v-model="wxForm.payNotifyUrl" placeholder="如：https://域名/api/pay/notify" />
          </el-form-item>
        </template>
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitWxForm">确 定</el-button>
        <el-button @click="wxOpen = false">取 消</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listMerchant, getMerchant, delMerchant, addMerchant, updateMerchant } from "@/api/biz/merchant"
import { listAgent } from "@/api/biz/agent"

export default {
  name: "Merchant",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      merchantList: [],
      agentOptions: [],
      title: "",
      open: false,
      wxOpen: false,
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        merchantName: null,
        appid: null,
        agentId: null,
        status: null
      },
      form: {},
      wxForm: {},
      rules: {
        merchantName: [
          { required: true, message: "商户名称不能为空", trigger: "blur" }
        ],
        contact: [
          { required: true, message: "联系人不能为空", trigger: "blur" }
        ]
      },
      wxRules: {
        appid: [
          { required: true, message: "小程序AppId不能为空", trigger: "blur" },
          { pattern: /^wx[0-9a-zA-Z]{6,}$/, message: "AppId 格式应为 wx 开头的字符串", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
    this.getAgentOptions();
  },
  methods: {
    isExpired(time) {
      return time ? new Date(time.replace(/-/g, "/")).getTime() < Date.now() : false;
    },
    // 代理商下拉：商户账号无权访问代理商接口，静默失败即可
    getAgentOptions() {
      listAgent({ pageNum: 1, pageSize: 200 }).then(response => {
        this.agentOptions = response.rows || [];
      }).catch(() => {
        this.agentOptions = [];
      });
    },
    getList() {
      this.loading = true;
      listMerchant(this.queryParams).then(response => {
        this.merchantList = response.rows || [];
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
        merchantId: null,
        merchantName: null,
        agentId: null,
        logo: null,
        contact: null,
        phone: null,
        licenseNo: null,
        licenseImg: null,
        serviceExpire: null,
        status: "0",
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
        merchantName: null,
        appid: null,
        agentId: null,
        status: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.merchantId);
      this.single = selection.length != 1;
      this.multiple = !selection.length;
    },
    handleAdd() {
      this.reset();
      this.title = "添加商户";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const merchantId = row.merchantId || this.ids[0];
      getMerchant(merchantId).then(response => {
        this.form = response.data;
        this.open = true;
        this.title = "修改商户";
      });
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (!valid) {
          return;
        }
        if (this.form.merchantId != null) {
          updateMerchant(this.form).then(() => {
            this.$modal.msgSuccess("修改成功");
            this.open = false;
            this.getList();
          });
        } else {
          addMerchant(this.form).then(() => {
            this.$modal.msgSuccess("新增成功");
            this.open = false;
            this.getList();
          });
        }
      });
    },
    // 打开微信配置：单独表单只提交凭证相关字段
    handleWxConfig(row) {
      getMerchant(row.merchantId).then(response => {
        const data = response.data || {};
        this.wxForm = {
          merchantId: data.merchantId,
          appid: data.appid,
          appSecret: data.appSecret,
          mpAuthMode: data.mpAuthMode || "0",
          mockEnabled: data.mockEnabled || "1",
          payMode: data.payMode || "0",
          payMchId: data.payMchId,
          payAppid: data.payAppid,
          payCertSerial: data.payCertSerial,
          payKeyPath: data.payKeyPath,
          payApiV3Key: data.payApiV3Key,
          payNotifyUrl: data.payNotifyUrl
        };
        this.wxOpen = true;
      });
    },
    submitWxForm() {
      this.$refs["wxForm"].validate(valid => {
        if (!valid) {
          return;
        }
        updateMerchant(this.wxForm).then(() => {
          this.$modal.msgSuccess("配置已保存，小程序侧即时生效");
          this.wxOpen = false;
          this.getList();
        });
      });
    },
    handleDelete(row) {
      const merchantIds = row.merchantId || this.ids;
      this.$modal.confirm('删除商户会同时影响其名下门店与业务数据，是否确认删除编号为"' + merchantIds + '"的数据项？').then(() => {
        return delMerchant(merchantIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    },
    handleExport() {
      this.download('biz/merchant/export', {
        ...this.queryParams
      }, `merchant_${new Date().getTime()}.xlsx`)
    }
  }
};
</script>

<style scoped>
.expire-warn {
  color: #f56c6c;
}
.form-tip {
  color: #909399;
  font-size: 12px;
  line-height: 1.5;
}
</style>
