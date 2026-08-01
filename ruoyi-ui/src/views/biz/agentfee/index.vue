<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="缴费单号" prop="feeNo">
        <el-input
          v-model="queryParams.feeNo"
          placeholder="请输入缴费单号"
          clearable
          style="width: 180px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
      <el-form-item label="代理商" prop="agentId">
        <el-select v-model="queryParams.agentId" placeholder="全部" clearable filterable style="width: 180px">
          <el-option
            v-for="item in agentOptions"
            :key="item.agentId"
            :label="item.agentName"
            :value="item.agentId"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="费用类型" prop="feeType">
        <el-select v-model="queryParams.feeType" placeholder="全部" clearable style="width: 130px">
          <el-option v-for="item in feeTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="状态" prop="status">
        <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 120px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
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
          v-hasPermi="['biz:agentfee:add']"
        >登记缴费</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="el-icon-edit"
          size="mini"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['biz:agentfee:edit']"
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
          v-hasPermi="['biz:agentfee:remove']"
        >删除</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="feeList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="缴费单号" align="center" prop="feeNo" width="170" />
      <el-table-column label="代理商" align="left" prop="agentName" min-width="140" show-overflow-tooltip />
      <el-table-column label="费用类型" align="center" prop="feeType" width="110">
        <template slot-scope="scope">
          <span>{{ labelOf(feeTypeOptions, scope.row.feeType) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="缴费金额" align="right" prop="amount" width="110">
        <template slot-scope="scope">
          <span>￥{{ scope.row.amount || 0 }}</span>
        </template>
      </el-table-column>
      <el-table-column label="增加额度" align="center" prop="quotaAdd" width="90" />
      <el-table-column label="延长月数" align="center" prop="months" width="90" />
      <el-table-column label="收款方式" align="center" prop="payChannel" width="110">
        <template slot-scope="scope">
          <span>{{ labelOf(payChannelOptions, scope.row.payChannel) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="到账时间" align="center" prop="payTime" width="160" />
      <el-table-column label="状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="statusTagType(scope.row.status)" size="mini">
            {{ labelOf(statusOptions, scope.row.status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="审核人" align="center" prop="auditBy" width="100" />
      <el-table-column label="操作" align="center" width="170" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <template v-if="scope.row.status === '0'">
            <el-button
              size="mini"
              type="text"
              icon="el-icon-check"
              @click="handleAudit(scope.row, '1')"
              v-hasPermi="['biz:agentfee:audit']"
            >确认</el-button>
            <el-button
              size="mini"
              type="text"
              icon="el-icon-close"
              @click="handleAudit(scope.row, '2')"
              v-hasPermi="['biz:agentfee:audit']"
            >驳回</el-button>
            <el-button
              size="mini"
              type="text"
              icon="el-icon-edit"
              @click="handleUpdate(scope.row)"
              v-hasPermi="['biz:agentfee:edit']"
            >修改</el-button>
          </template>
          <span v-else class="text-muted">已{{ labelOf(statusOptions, scope.row.status) }}</span>
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

    <!-- 添加或修改缴费对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="代理商" prop="agentId">
              <el-select v-model="form.agentId" placeholder="请选择代理商" filterable :disabled="form.feeId != null" style="width: 100%">
                <el-option
                  v-for="item in agentOptions"
                  :key="item.agentId"
                  :label="item.agentName + '（额度 ' + (item.usedQuota || 0) + '/' + (item.merchantQuota || 0) + '）'"
                  :value="item.agentId"
                />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="费用类型" prop="feeType">
              <el-select v-model="form.feeType" placeholder="请选择" style="width: 100%">
                <el-option v-for="item in feeTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="缴费金额" prop="amount">
              <el-input-number v-model="form.amount" :min="0" :precision="2" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="增加额度" prop="quotaAdd">
              <el-input-number v-model="form.quotaAdd" :min="0" :precision="0" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="延长月数" prop="months">
              <el-input-number v-model="form.months" :min="0" :precision="0" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="收款方式" prop="payChannel">
              <el-select v-model="form.payChannel" placeholder="请选择" style="width: 100%">
                <el-option v-for="item in payChannelOptions" :key="item.value" :label="item.label" :value="item.value" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="到账时间" prop="payTime">
              <el-date-picker
                v-model="form.payTime"
                type="datetime"
                value-format="yyyy-MM-dd HH:mm:ss"
                placeholder="选择到账时间"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="付款凭证" prop="payVoucher">
              <image-upload v-model="form.payVoucher" :limit="3" />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="备注" prop="remark">
              <el-input v-model="form.remark" type="textarea" placeholder="请输入备注" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-alert
          title="缴费单确认后才会为代理商增加商户额度并延长资格有效期，确认后不可修改或删除。"
          type="warning"
          :closable="false"
          show-icon
        />
      </el-form>
      <div slot="footer" class="dialog-footer">
        <el-button type="primary" @click="submitForm">确 定</el-button>
        <el-button @click="cancel">取 消</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { listAgentFee, getAgentFee, delAgentFee, addAgentFee, updateAgentFee, auditAgentFee } from "@/api/biz/agentfee"
import { listAgent } from "@/api/biz/agent"

export default {
  name: "AgentFee",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      feeList: [],
      agentOptions: [],
      title: "",
      open: false,
      feeTypeOptions: [
        { value: "0", label: "加盟费" },
        { value: "1", label: "商户额度" },
        { value: "2", label: "资格续费" },
        { value: "3", label: "其他" }
      ],
      payChannelOptions: [
        { value: "0", label: "线下转账" },
        { value: "1", label: "微信" },
        { value: "2", label: "支付宝" },
        { value: "3", label: "其他" }
      ],
      statusOptions: [
        { value: "0", label: "待确认" },
        { value: "1", label: "已确认" },
        { value: "2", label: "已驳回" }
      ],
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        feeNo: null,
        agentId: null,
        feeType: null,
        status: null
      },
      form: {},
      rules: {
        agentId: [
          { required: true, message: "请选择代理商", trigger: "change" }
        ],
        feeType: [
          { required: true, message: "请选择费用类型", trigger: "change" }
        ],
        amount: [
          { required: true, message: "请输入缴费金额", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
    this.getAgentOptions();
  },
  methods: {
    labelOf(options, value) {
      const hit = options.find(item => item.value === value);
      return hit ? hit.label : "-";
    },
    statusTagType(status) {
      if (status === "1") {
        return "success";
      }
      return status === "2" ? "danger" : "warning";
    },
    getAgentOptions() {
      listAgent({ pageNum: 1, pageSize: 200 }).then(response => {
        this.agentOptions = response.rows || [];
      }).catch(() => {
        this.agentOptions = [];
      });
    },
    getList() {
      this.loading = true;
      listAgentFee(this.queryParams).then(response => {
        this.feeList = response.rows || [];
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
        feeId: null,
        agentId: null,
        feeType: "1",
        amount: 0,
        quotaAdd: 0,
        months: 0,
        payChannel: "0",
        payVoucher: null,
        payTime: null,
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
        feeNo: null,
        agentId: null,
        feeType: null,
        status: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.feeId);
      this.single = selection.length != 1;
      this.multiple = !selection.length;
    },
    handleAdd() {
      this.reset();
      this.title = "登记代理商缴费";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const feeId = row.feeId || this.ids[0];
      getAgentFee(feeId).then(response => {
        this.form = response.data;
        this.open = true;
        this.title = "修改缴费单";
      });
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (!valid) {
          return;
        }
        if (this.form.feeId != null) {
          updateAgentFee(this.form).then(() => {
            this.$modal.msgSuccess("修改成功");
            this.open = false;
            this.getList();
          });
        } else {
          addAgentFee(this.form).then(() => {
            this.$modal.msgSuccess("登记成功，待确认后发放额度");
            this.open = false;
            this.getList();
          });
        }
      });
    },
    // 审核：确认会发放额度与有效期，需二次确认
    handleAudit(row, status) {
      const isPass = status === "1";
      const tip = isPass
        ? `确认收款后将为「${row.agentName}」增加 ${row.quotaAdd || 0} 个商户额度、延长 ${row.months || 0} 个月有效期，是否继续？`
        : `是否确认驳回缴费单「${row.feeNo}」？`;
      this.$modal.confirm(tip).then(() => {
        return auditAgentFee(row.feeId, status);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess(isPass ? "已确认并发放额度" : "已驳回");
      }).catch(() => {});
    },
    handleDelete(row) {
      const feeIds = row.feeId || this.ids;
      this.$modal.confirm('是否确认删除缴费单编号为"' + feeIds + '"的数据项？').then(() => {
        return delAgentFee(feeIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    }
  }
};
</script>

<style scoped>
.text-muted {
  color: #909399;
}
</style>
