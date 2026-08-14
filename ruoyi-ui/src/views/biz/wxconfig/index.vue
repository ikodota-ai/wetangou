<template>
  <div class="app-container">
    <el-form ref="form" :model="form" label-width="160px" v-loading="loading">
      <el-divider content-position="left">小程序登录配置</el-divider>
      <el-form-item label="小程序AppId">
        <el-input v-model="form['wx.miniapp.appId']" placeholder="请输入小程序AppId" style="width: 420px" />
      </el-form-item>
      <el-form-item label="小程序AppSecret">
        <el-input v-model="form['wx.miniapp.secret']" placeholder="请输入小程序AppSecret" show-password style="width: 420px" />
      </el-form-item>
      <el-divider content-position="left">微信支付配置</el-divider>
      <el-form-item label="商户号">
        <el-input v-model="form['wx.pay.mchId']" placeholder="请输入微信支付商户号" style="width: 420px" />
      </el-form-item>
      <el-form-item label="支付AppId">
        <el-input v-model="form['wx.pay.appId']" placeholder="一般与小程序AppId一致" style="width: 420px" />
      </el-form-item>
      <el-form-item label="证书序列号">
        <el-input v-model="form['wx.pay.certSerialNo']" placeholder="请输入商户API证书序列号" style="width: 420px" />
      </el-form-item>
      <el-form-item label="私钥文件路径">
        <el-input v-model="form['wx.pay.privateKeyPath']" placeholder="apiclient_key.pem 的服务器绝对路径" style="width: 420px" />
      </el-form-item>
      <el-form-item label="APIv3密钥">
        <el-input v-model="form['wx.pay.apiV3Key']" placeholder="请输入APIv3密钥" show-password style="width: 420px" />
      </el-form-item>
      <el-form-item label="支付回调地址">
        <el-input v-model="form['wx.pay.notifyUrl']" placeholder="需公网可访问的 https 地址" style="width: 420px" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" @click="submit" v-hasPermi="['biz:wxconfig:edit']">保 存</el-button>
        <el-button @click="load">重 置</el-button>
      </el-form-item>
    </el-form>
  </div>
</template>

<script>
import { getWxConfig, saveWxConfig } from "@/api/biz/wxconfig";

export default {
  name: "WxConfig",
  data() {
    return {
      loading: false,
      form: {}
    };
  },
  computed: {
  },
  created() {
    this.load();
  },
  methods: {
    load() {
      this.loading = true;
      getWxConfig().then(res => {
        this.form = res.data || {};
        this.loading = false;
      }).catch(() => { this.loading = false; });
    },
    submit() {
      this.loading = true;
      saveWxConfig(this.form).then(() => {
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
