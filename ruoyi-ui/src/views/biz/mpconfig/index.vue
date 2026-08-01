<template>
  <div class="app-container">
    <el-alert
      title="微信开放平台第三方平台参数（平台级唯一）"
      description="用于小程序代授权、代上传、代提审与 ext.json 生成。各商户自己的小程序 AppId 在「商户管理」中维护。"
      type="info"
      :closable="false"
      show-icon
      style="margin-bottom: 20px"
    />
    <el-form ref="form" :model="form" label-width="170px" v-loading="loading">
      <el-divider content-position="left">第三方平台凭证</el-divider>
      <el-form-item label="第三方平台AppId">
        <el-input v-model="form['wx.open.componentAppId']" placeholder="开放平台第三方平台的 AppId" style="width: 420px" />
      </el-form-item>
      <el-form-item label="第三方平台Secret">
        <el-input v-model="form['wx.open.componentSecret']" placeholder="开放平台第三方平台的 AppSecret" show-password style="width: 420px" />
      </el-form-item>
      <el-form-item label="消息校验Token">
        <el-input v-model="form['wx.open.componentToken']" placeholder="推送消息校验 Token" style="width: 420px" />
      </el-form-item>
      <el-form-item label="消息加密Key">
        <el-input v-model="form['wx.open.componentAesKey']" placeholder="43 位消息加解密 Key" show-password style="width: 420px" />
      </el-form-item>
      <el-form-item>
        <div class="tip">
          验证票据 component_verify_ticket 由微信每 10 分钟推送到「授权事件接收URL」，由服务端缓存到 Redis，无需在此填写。
        </div>
      </el-form-item>

      <el-divider content-position="left">代发布参数</el-divider>
      <el-form-item label="小程序代码模板ID">
        <el-input v-model="form['wx.open.templateId']" placeholder="草稿箱添加到模板库后得到的 template_id" style="width: 420px" />
        <div class="tip">新增发布版本时若未填写模板ID，默认取此值。</div>
      </el-form-item>
      <el-form-item label="授权回调域名">
        <el-input v-model="form['wx.open.redirectDomain']" placeholder="如 https://admin.example.com" style="width: 420px" />
        <div class="tip">生成商户扫码授权链接时的回调域名，需与开放平台配置一致。</div>
      </el-form-item>
      <el-form-item label="小程序接口域名">
        <el-input v-model="form['wx.open.apiBaseUrl']" placeholder="如 https://api.example.com" style="width: 420px" />
        <div class="tip">生成 ext.json 时写入 ext.baseUrl，作为各商户小程序请求的后端地址。</div>
      </el-form-item>

      <el-form-item>
        <el-button type="primary" @click="submit" v-hasPermi="['biz:mpconfig:edit']">保 存</el-button>
        <el-button @click="load">重 置</el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script>
import { getMpConfig, saveMpConfig } from "@/api/biz/mpconfig";

export default {
  name: "MpConfig",
  data() {
    return {
      loading: false,
      form: {}
    };
  },
  created() {
    this.load();
  },
  methods: {
    load() {
      this.loading = true;
      getMpConfig().then(res => {
        this.form = res.data || {};
        this.loading = false;
      }).catch(() => { this.loading = false; });
    },
    submit() {
      const baseUrl = (this.form["wx.open.apiBaseUrl"] || "").trim();
      if (baseUrl && !/^https?:\/\//.test(baseUrl)) {
        this.$modal.msgError("小程序接口域名需以 http:// 或 https:// 开头");
        return;
      }
      const redirect = (this.form["wx.open.redirectDomain"] || "").trim();
      if (redirect && !/^https?:\/\//.test(redirect)) {
        this.$modal.msgError("授权回调域名需以 http:// 或 https:// 开头");
        return;
      }
      this.loading = true;
      saveMpConfig(this.form).then(() => {
        this.$modal.msgSuccess("保存成功");
        this.load();
      }).catch(() => { this.loading = false; });
    }
  }
};
</script>

<style scoped>
.tip { color: #909399; font-size: 12px; line-height: 1.5; }
</style>
