<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="收费单号" prop="feeNo">
        <el-input
          v-model="queryParams.feeNo"
          placeholder="请输入收费单号"
          clearable
          style="width: 180px"
          @keyup.enter.native="handleQuery"
        />
      </el-form-item>
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
          v-hasPermi="['biz:merchantfee:add']"
        >开具收费单</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="success"
          plain
          icon="el-icon-edit"
          size="mini"
          :disabled="single"
          @click="handleUpdate"
          v-hasPermi="['biz:merchantfee:edit']"
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
          v-hasPermi="['biz:merchantfee:remove']"
        >删除</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="feeList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="收费单号" align="center" prop="feeNo" width="170" />
      <el-table-column label="商户" align="left" prop="merchantName" min-width="150" show-overflow-tooltip />
      <el-table-column v-if="showAgent" label="收费方" align="center" prop="agentName" width="130" show-overflow-tooltip>
        <template slot-scope="scope">
          <span>{{ scope.row.agentName || '平台直收' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="费用类型" align="center" prop="feeType" width="110">
        <template slot-scope="scope">
          <span>{{ labelOf(feeTypeOptions, scope.row.feeType) }}</span>
        </template>
      </el-table-column>
      <el-table-column label="收费金额" align="right" prop="amount" width="110">
        <template slot-scope="scope">
          <span>￥{{ scope.row.amount || 0 }}</span>
        </template>
      </el-table-column>
      <el-table-column label="服务月数" align="center" prop="months" width="90" />
      <el-table-column label="服务期间" align="center" width="230">
        <template slot-scope="scope">
          <span v-if="scope.row.beginTime || scope.row.endTime">
            {{ (scope.row.beginTime || '').substring(0, 10) }} ~ {{ (scope.row.endTime || '').substring(0, 10) }}
          </span>
          <span v-else>-</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="90">
        <template slot-scope="scope">
          <el-tag :type="statusTagType(scope.row.status)" size="mini">
            {{ labelOf(statusOptions, scope.row.status) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="160" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <template v-if="scope.row.status === '0'">
            <el-button
              size="mini"
              type="text"
              icon="el-icon-check"
              @click="handleConfirm(scope.row)"
              v-hasPermi="['biz:merchantfee:edit']"
            >确认收款</el-button>
            <el-button
              size="mini"
              type="text"
              icon="el-icon-edit"
              @click="handleUpdate(scope.row)"
              v-hasPermi="['biz:merchantfee:edit']"
            >修改</el-button>
          </template>
          <span v-else class="text-muted">{{ labelOf(statusOptions, scope.row.status) }}</span>
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

    <!-- 添加或修改收费对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="商户" prop="merchantId">
              <el-select v-model="form.merchantId" placeholder="请选择商户" filterable :disabled="form.feeId != null" style="width: 100%">
                <el-option
                  v-for="item in merchantOptions"
                  :key="item.merchantId"
                  :label="item.merchantName"
                  :value="item.merchantId"
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
            <el-form-item label="收费金额" prop="amount">
              <el-input-number v-model="form.amount" :min="0" :precision="2" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="服务月数" prop="months">
              <el-input-number v-model="form.months" :min="0" :precision="0" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="服务开始" prop="beginTime">
              <el-date-picker
                v-model="form.beginTime"
                type="datetime"
                value-format="yyyy-MM-dd HH:mm:ss"
                placeholder="默认当前时间"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="服务结束" prop="endTime">
              <el-date-picker
                v-model="form.endTime"
                type="datetime"
                value-format="yyyy-MM-dd HH:mm:ss"
                placeholder="留空则按开始时间与服务月数自动推算"
                style="width: 100%"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="备注" prop="remark">
              <el-input v-model="form.remark" type="textarea" placeholder="请输入备注" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-alert
          title="确认收款后会把服务结束时间同步为商户的服务到期时间（仅在更晚时更新），确认后不可修改或删除。"
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
import { listMerchantFee, getMerchantFee, delMerchantFee, addMerchantFee, updateMerchantFee, confirmMerchantFee } from "@/api/biz/merchantfee"
import { listMerchant } from "@/api/biz/merchant"
import { showAgentField } from "@/utils/identity"

export default {
  name: "MerchantFee",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      feeList: [],
      merchantOptions: [],
      // 「收费方」显示的是代理商名。商户只该知道自己交了多少钱，
      // 不该知道这笔钱是被哪个代理商收走的（渠道关系属平台内部信息）。
      showAgent: showAgentField(),
      title: "",
      open: false,
      feeTypeOptions: [
        { value: "0", label: "开通费" },
        { value: "1", label: "年费" },
        { value: "2", label: "增值服务" },
        { value: "3", label: "其他" }
      ],
      statusOptions: [
        { value: "0", label: "未收" },
        { value: "1", label: "已收" },
        { value: "2", label: "作废" }
      ],
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        feeNo: null,
        merchantId: null,
        feeType: null,
        status: null
      },
      form: {},
      rules: {
        merchantId: [
          { required: true, message: "请选择商户", trigger: "change" }
        ],
        feeType: [
          { required: true, message: "请选择费用类型", trigger: "change" }
        ],
        amount: [
          { required: true, message: "请输入收费金额", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
    this.getMerchantOptions();
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
      return status === "2" ? "info" : "warning";
    },
    getMerchantOptions() {
      listMerchant({ pageNum: 1, pageSize: 500 }).then(response => {
        this.merchantOptions = response.rows || [];
      }).catch(() => {
        this.merchantOptions = [];
      });
    },
    getList() {
      this.loading = true;
      listMerchantFee(this.queryParams).then(response => {
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
        merchantId: null,
        feeType: "1",
        amount: 0,
        months: 12,
        beginTime: null,
        endTime: null,
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
        merchantId: null,
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
      this.title = "开具商户收费单";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const feeId = row.feeId || this.ids[0];
      getMerchantFee(feeId).then(response => {
        this.form = response.data;
        this.open = true;
        this.title = "修改收费单";
      });
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (!valid) {
          return;
        }
        if (this.form.feeId != null) {
          updateMerchantFee(this.form).then(() => {
            this.$modal.msgSuccess("修改成功");
            this.open = false;
            this.getList();
          });
        } else {
          addMerchantFee(this.form).then(() => {
            this.$modal.msgSuccess("开具成功，待确认收款");
            this.open = false;
            this.getList();
          });
        }
      });
    },
    handleConfirm(row) {
      const endTip = row.endTime ? `，商户服务到期将同步至 ${row.endTime.substring(0, 10)}` : "";
      this.$modal.confirm(`是否确认已收到「${row.merchantName}」的款项${endTip}？`).then(() => {
        return confirmMerchantFee(row.feeId);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("已确认收款");
      }).catch(() => {});
    },
    handleDelete(row) {
      const feeIds = row.feeId || this.ids;
      this.$modal.confirm('是否确认删除收费单编号为"' + feeIds + '"的数据项？').then(() => {
        return delMerchantFee(feeIds);
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
