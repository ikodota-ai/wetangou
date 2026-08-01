<template>
  <div class="app-container">
    <el-form :model="queryParams" ref="queryForm" size="small" :inline="true" v-show="showSearch" label-width="80px">
      <el-form-item label="代理商" prop="agentName">
        <el-input
          v-model="queryParams.agentName"
          placeholder="请输入代理商名称"
          clearable
          style="width: 200px"
          @keyup.enter.native="handleQuery"
        />
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
      <el-form-item label="代理区域" prop="region">
        <el-input
          v-model="queryParams.region"
          placeholder="请输入代理区域"
          clearable
          style="width: 150px"
          @keyup.enter.native="handleQuery"
        />
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
          v-hasPermi="['biz:agent:add']"
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
          v-hasPermi="['biz:agent:edit']"
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
          v-hasPermi="['biz:agent:remove']"
        >删除</el-button>
      </el-col>
      <el-col :span="1.5">
        <el-button
          type="warning"
          plain
          icon="el-icon-download"
          size="mini"
          @click="handleExport"
          v-hasPermi="['biz:agent:export']"
        >导出</el-button>
      </el-col>
      <right-toolbar :showSearch.sync="showSearch" @queryTable="getList"></right-toolbar>
    </el-row>

    <el-table v-loading="loading" :data="agentList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="编号" align="center" prop="agentNo" width="120" />
      <el-table-column label="代理商名称" align="left" prop="agentName" min-width="160" show-overflow-tooltip />
      <el-table-column label="联系人" align="center" prop="contact" width="100" />
      <el-table-column label="联系电话" align="center" prop="phone" width="130" />
      <el-table-column label="代理区域" align="center" prop="region" width="120" show-overflow-tooltip />
      <el-table-column label="商户额度" align="center" width="120">
        <template slot-scope="scope">
          <el-tag :type="quotaTagType(scope.row)" size="mini">
            {{ scope.row.usedQuota || 0 }} / {{ scope.row.merchantQuota || 0 }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="累计缴费" align="center" prop="paidAmount" width="110">
        <template slot-scope="scope">
          <span>￥{{ scope.row.paidAmount || 0 }}</span>
        </template>
      </el-table-column>
      <el-table-column label="资格到期" align="center" prop="expireTime" width="160">
        <template slot-scope="scope">
          <span v-if="!scope.row.expireTime">不限期</span>
          <span v-else :class="{ 'expire-warn': isExpired(scope.row.expireTime) }">{{ scope.row.expireTime }}</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="80">
        <template slot-scope="scope">
          <el-tag :type="scope.row.status === '0' ? 'success' : 'danger'" size="mini">
            {{ scope.row.status === '0' ? '正常' : '停用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="120" class-name="small-padding fixed-width">
        <template slot-scope="scope">
          <el-button
            size="mini"
            type="text"
            icon="el-icon-edit"
            @click="handleUpdate(scope.row)"
            v-hasPermi="['biz:agent:edit']"
          >修改</el-button>
          <el-button
            size="mini"
            type="text"
            icon="el-icon-delete"
            @click="handleDelete(scope.row)"
            v-hasPermi="['biz:agent:remove']"
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

    <!-- 添加或修改代理商对话框 -->
    <el-dialog :title="title" :visible.sync="open" width="600px" append-to-body>
      <el-form ref="form" :model="form" :rules="rules" label-width="100px">
        <el-row>
          <el-col :span="24">
            <el-form-item label="代理商名称" prop="agentName">
              <el-input v-model="form.agentName" placeholder="请输入代理商名称" />
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
            <el-form-item label="邮箱" prop="email">
              <el-input v-model="form.email" placeholder="请输入邮箱" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="代理区域" prop="region">
              <el-input v-model="form.region" placeholder="如：广东省 / 全国" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="商户额度" prop="merchantQuota">
              <el-input-number v-model="form.merchantQuota" :min="0" :precision="0" controls-position="right" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="资格到期" prop="expireTime">
              <el-date-picker
                v-model="form.expireTime"
                type="datetime"
                value-format="yyyy-MM-dd HH:mm:ss"
                placeholder="留空表示不限期"
                style="width: 100%"
              />
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
          v-if="form.agentId"
          title="商户额度与资格到期建议通过「代理商缴费」审核自动发放，此处为人工校正入口。"
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
  </div>
</template>

<script>
import { listAgent, getAgent, delAgent, addAgent, updateAgent } from "@/api/biz/agent"

export default {
  name: "Agent",
  data() {
    return {
      loading: true,
      ids: [],
      single: true,
      multiple: true,
      showSearch: true,
      total: 0,
      agentList: [],
      title: "",
      open: false,
      queryParams: {
        pageNum: 1,
        pageSize: 10,
        agentName: null,
        contact: null,
        region: null,
        status: null
      },
      form: {},
      rules: {
        agentName: [
          { required: true, message: "代理商名称不能为空", trigger: "blur" }
        ],
        contact: [
          { required: true, message: "联系人不能为空", trigger: "blur" }
        ]
      }
    };
  },
  created() {
    this.getList();
  },
  methods: {
    // 额度用尽或超额时高亮提示
    quotaTagType(row) {
      const quota = row.merchantQuota || 0;
      const used = row.usedQuota || 0;
      if (used >= quota) {
        return "danger";
      }
      return used / (quota || 1) > 0.8 ? "warning" : "success";
    },
    isExpired(time) {
      return time ? new Date(time.replace(/-/g, "/")).getTime() < Date.now() : false;
    },
    getList() {
      this.loading = true;
      listAgent(this.queryParams).then(response => {
        this.agentList = response.rows || [];
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
        agentId: null,
        agentName: null,
        contact: null,
        phone: null,
        email: null,
        region: null,
        merchantQuota: 0,
        expireTime: null,
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
        agentName: null,
        contact: null,
        region: null,
        status: null
      };
      this.handleQuery();
    },
    handleSelectionChange(selection) {
      this.ids = selection.map(item => item.agentId);
      this.single = selection.length != 1;
      this.multiple = !selection.length;
    },
    handleAdd() {
      this.reset();
      this.title = "添加代理商";
      this.open = true;
    },
    handleUpdate(row) {
      this.reset();
      const agentId = row.agentId || this.ids[0];
      getAgent(agentId).then(response => {
        this.form = response.data;
        this.open = true;
        this.title = "修改代理商";
      });
    },
    submitForm() {
      this.$refs["form"].validate(valid => {
        if (!valid) {
          return;
        }
        if (this.form.agentId != null) {
          updateAgent(this.form).then(() => {
            this.$modal.msgSuccess("修改成功");
            this.open = false;
            this.getList();
          });
        } else {
          addAgent(this.form).then(() => {
            this.$modal.msgSuccess("新增成功");
            this.open = false;
            this.getList();
          });
        }
      });
    },
    handleDelete(row) {
      const agentIds = row.agentId || this.ids;
      this.$modal.confirm('删除代理商后其名下商户仍会保留，是否确认删除编号为"' + agentIds + '"的数据项？').then(() => {
        return delAgent(agentIds);
      }).then(() => {
        this.getList();
        this.$modal.msgSuccess("删除成功");
      }).catch(() => {});
    },
    handleExport() {
      this.download('biz/agent/export', {
        ...this.queryParams
      }, `agent_${new Date().getTime()}.xlsx`)
    }
  }
};
</script>

<style scoped>
.expire-warn {
  color: #f56c6c;
}
</style>
