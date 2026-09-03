<template>
  <div class="app-container">
    <el-alert
      type="warning"
      :closable="false"
      show-icon
      title="小程序审核要求：提现页面必须清晰展示提现规则"
      description="此处配置会同时用于「小程序提现页展示」和「后端申请提现时的实际校验」，两边读同一份配置，不会出现页面写最低 10 元、实际提 1 元也能提的情况。"
      style="margin-bottom: 20px"
    />
    <el-form ref="form" :model="form" label-width="180px" v-loading="loading">
      <el-divider content-position="left">额度与次数</el-divider>
      <el-form-item label="单笔最低提现金额">
        <el-input v-model="form['withdraw.minAmount']" placeholder="如 10" style="width: 220px">
          <template slot="append">元</template>
        </el-input>
        <span class="tip">低于该金额不允许提交申请。留空取默认 10 元。</span>
      </el-form-item>
      <el-form-item label="单笔最高提现金额">
        <el-input v-model="form['withdraw.maxAmount']" placeholder="如 5000，填 0 表示不限" style="width: 220px">
          <template slot="append">元</template>
        </el-input>
        <span class="tip">填 0 表示单笔不限额。</span>
      </el-form-item>
      <el-form-item label="每日提现次数上限">
        <el-input v-model="form['withdraw.dailyTimes']" placeholder="如 3，填 0 表示不限" style="width: 220px">
          <template slot="append">次/天</template>
        </el-input>
        <span class="tip">已驳回的申请不占用次数；处理中与已成功都计入。次日 00:00 重置。</span>
      </el-form-item>

      <el-divider content-position="left">受理时间与到账</el-divider>
      <el-form-item label="提现受理时段">
        <el-input v-model="form['withdraw.startHour']" placeholder="9" style="width: 110px" />
        <span style="margin: 0 8px">时 至</span>
        <el-input v-model="form['withdraw.endHour']" placeholder="21" style="width: 110px" />
        <span style="margin-left: 8px">时</span>
        <span class="tip">两者相同（或 0 至 24）表示全天受理。非受理时段用户无法提交申请。</span>
      </el-form-item>
      <el-form-item label="到账时效说明">
        <el-input v-model="form['withdraw.arrivalDesc']" placeholder="审核通过后 1-3 个工作日到账" style="width: 420px" />
        <span class="tip">该文案会原样展示在小程序提现页的「到账时间」。</span>
      </el-form-item>
      <el-form-item label="提现手续费率">
        <el-input v-model="form['withdraw.feeRate']" placeholder="0" style="width: 220px">
          <template slot="append">%</template>
        </el-input>
        <span class="tip">填 0 表示不收取手续费，页面会展示「本平台不收取提现手续费」。</span>
      </el-form-item>

      <el-divider content-position="left">用户端展示效果</el-divider>
      <el-form-item label="提现页规则文案">
        <div class="preview">
          <div v-for="(item, idx) in preview" :key="idx" class="preview-li">· {{ item }}</div>
          <div v-if="!preview.length" class="tip">保存后可查看</div>
        </div>
      </el-form-item>

      <el-form-item>
        <el-button type="primary" @click="submit" v-hasPermi="['biz:withdrawRule:edit']">保存</el-button>
        <el-button @click="load">重置</el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script>
import { getWithdrawRule, saveWithdrawRule } from "@/api/biz/withdrawRule";

export default {
  name: "WithdrawRule",
  data() {
    return {
      loading: false,
      form: {},
      preview: []
    };
  },
  created() {
    this.load();
  },
  methods: {
    load() {
      this.loading = true;
      getWithdrawRule().then(res => {
        const data = res.data || {};
        this.preview = data.preview || [];
        // preview 只是展示用，不能混进待保存的表单里被当成配置项回写
        const form = Object.assign({}, data);
        delete form.preview;
        this.form = form;
        this.loading = false;
      }).catch(() => { this.loading = false; });
    },
    submit() {
      this.loading = true;
      saveWithdrawRule(this.form).then(() => {
        this.$modal.msgSuccess("保存成功");
        this.load();
      }).catch(() => { this.loading = false; });
    }
  }
};
</script>

<style scoped>
.tip { color: #909399; font-size: 12px; margin-left: 12px; }
.preview { background: #F5F7FA; border-radius: 4px; padding: 12px 16px; line-height: 1.9; }
.preview-li { color: #606266; font-size: 13px; }
</style>
