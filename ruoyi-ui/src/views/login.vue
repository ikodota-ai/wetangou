<template>
  <div class="login">
    <el-form ref="loginForm" :model="loginForm" :rules="loginRules" class="login-form">
      <h3 class="title">{{title}}</h3>
      <el-tabs v-model="activeEntry" class="login-entry-tabs" stretch>
        <el-tab-pane label="平台" name="platform" />
        <el-tab-pane label="代理商" name="agent" />
        <el-tab-pane label="商户" name="merchant" />
      </el-tabs>
      <p class="login-entry-tip">{{ entryTip }}</p>
      <el-form-item prop="username">
        <el-input
          v-model="loginForm.username"
          type="text"
          auto-complete="off"
          placeholder="账号"
        >
          <svg-icon slot="prefix" icon-class="user" class="el-input__icon input-icon" />
        </el-input>
      </el-form-item>
      <el-form-item prop="password">
        <el-input
          v-model="loginForm.password"
          type="password"
          auto-complete="off"
          placeholder="密码"
          @keyup.enter.native="handleLogin"
        >
          <svg-icon slot="prefix" icon-class="password" class="el-input__icon input-icon" />
        </el-input>
      </el-form-item>
      <el-form-item prop="code" v-if="captchaEnabled">
        <el-input
          v-model="loginForm.code"
          auto-complete="off"
          placeholder="验证码"
          style="width: 63%"
          @keyup.enter.native="handleLogin"
        >
          <svg-icon slot="prefix" icon-class="validCode" class="el-input__icon input-icon" />
        </el-input>
        <div class="login-code">
          <img :src="codeUrl" @click="getCode" class="login-code-img"/>
        </div>
      </el-form-item>
      <el-checkbox v-model="loginForm.rememberMe" style="margin:0px 0px 25px 0px;">记住密码</el-checkbox>
      <el-form-item style="width:100%;">
        <el-button
          :loading="loading"
          size="medium"
          type="primary"
          style="width:100%;"
          @click.native.prevent="handleLogin"
        >
          <span v-if="!loading">登 录</span>
          <span v-else>登 录 中...</span>
        </el-button>
        <div style="float: right;" v-if="register">
          <router-link class="link-type" :to="'/register'">立即注册</router-link>
        </div>
      </el-form-item>
    </el-form>
    <!--  底部  -->
    <div class="el-login-footer">
      <span>{{ footerContent }}</span>
    </div>
  </div>
</template>

<script>
import { getCodeImg } from "@/api/login"
import Cookies from "js-cookie"
import { encrypt, decrypt } from '@/utils/jsencrypt'
import defaultSettings from '@/settings'

export default {
  name: "Login",
  data() {
    return {
      title: process.env.VUE_APP_TITLE,
      footerContent: defaultSettings.footerContent,
      codeUrl: "",
      loginForm: {
        username: "admin",
        password: "admin123",
        rememberMe: false,
        code: "",
        uuid: ""
      },
      loginRules: {
        username: [
          { required: true, trigger: "blur", message: "请输入您的账号" }
        ],
        password: [
          { required: true, trigger: "blur", message: "请输入您的密码" }
        ],
        code: [{ required: true, trigger: "change", message: "请输入验证码" }]
      },
      loading: false,
      // 验证码开关
      captchaEnabled: true,
      // 注册开关
      register: false,
      redirect: undefined,
      // 登录入口：仅文案提示，不参与鉴权
      activeEntry: "platform",
      entryTips: {
        platform: "平台账号：拥有后台完整管理权限",
        agent: "代理商账号：管理名下商户、缴费记录与额度",
        merchant: "商户账号：管理门店、订单与资金"
      }
    }
  },
  computed: {
    entryTip() {
      return this.entryTips[this.activeEntry] || ""
    }
  },
  watch: {
    $route: {
      handler: function(route) {
        const query = route.query || {}
        this.redirect = query.redirect
        // 支持从外部直接带身份进来，例如给商户的物料写 /admin/login?entry=merchant。
        // 只切 tab 文案，不参与鉴权 —— 真实身份仍由后端 getInfo 返回的 userType 决定，
        // 所以这里不做校验：拿商户链接登平台账号，照样按平台身份进后台。
        // 必须用 hasOwnProperty 判断：直接写 entryTips[query.entry] 会连原型链一起认，
        // ?entry=__proto__ / ?entry=constructor 都能取到值从而绕过白名单，
        // 导致 tab 落到一个不存在的 name 上、三个 tab 全不选中（实测复现过）。
        if (query.entry && Object.prototype.hasOwnProperty.call(this.entryTips, query.entry)) {
          this.activeEntry = query.entry
        }
      },
      immediate: true
    }
  },
  created() {
    this.getCode()
    this.getCookie()
  },
  methods: {
    getCode() {
      getCodeImg().then(res => {
        this.captchaEnabled = res.captchaEnabled === undefined ? true : res.captchaEnabled
        if (this.captchaEnabled) {
          this.codeUrl = "data:image/gif;base64," + res.img
          this.loginForm.uuid = res.uuid
        }
      })
    },
    getCookie() {
      const username = Cookies.get("username")
      const password = Cookies.get("password")
      const rememberMe = Cookies.get('rememberMe')
      this.loginForm = {
        username: username === undefined ? this.loginForm.username : username,
        password: password === undefined ? this.loginForm.password : decrypt(password),
        rememberMe: rememberMe === undefined ? false : Boolean(rememberMe)
      }
    },
    resolveEntryPath() {
      // 按身份路由分流：0 平台 → /index；1 代理商 → /agent/index；2 商户 → /merchant/index
      const userType = (this.$store && this.$store.state && this.$store.state.user && this.$store.state.user.userType) || '0'
      if (userType === '1') return '/agent/index'
      if (userType === '2') return '/merchant/index'
      return '/index'
    },
    handleLogin() {
      this.$refs.loginForm.validate(valid => {
        if (valid) {
          this.loading = true
          if (this.loginForm.rememberMe) {
            Cookies.set("username", this.loginForm.username, { expires: 30 })
            Cookies.set("password", encrypt(this.loginForm.password), { expires: 30 })
            Cookies.set('rememberMe', this.loginForm.rememberMe, { expires: 30 })
          } else {
            Cookies.remove("username")
            Cookies.remove("password")
            Cookies.remove('rememberMe')
          }
          this.$store.dispatch("Login", this.loginForm).then(() => {
            return this.$store.dispatch("GetInfo")
          }).then(() => {
            // 登录后主动拉一次路由表，确保 sidebar 菜单立即渲染
            // （permission.js 的 beforeEach 在 GetInfo 之后会因 roles 非空而走 next()，
            //   跳过 GenerateRoutes，导致首次进入页面时菜单空白）
            return this.$store.dispatch("GenerateRoutes")
          }).then(() => {
            this.$router.push({ path: this.redirect || this.resolveEntryPath() }).catch(()=>{})
          }).catch(() => {
            this.loading = false
            if (this.captchaEnabled) {
              this.getCode()
            }
          })
        }
      })
    }
  }
}
</script>

<style rel="stylesheet/scss" lang="scss" scoped>
.login {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  background-image: url("../assets/images/login-background.jpg");
  background-size: cover;
}
.title {
  margin: 0px auto 30px auto;
  text-align: center;
  color: #707070;
}
.login-entry-tabs {
  margin: 0 0 12px 0;
}
.login-entry-tabs ::v-deep .el-tabs__item {
  font-size: 14px;
  height: 36px;
  line-height: 36px;
}
.login-entry-tip {
  margin: 0 0 16px 0;
  text-align: center;
  color: #909399;
  font-size: 12px;
}

.login-form {
  border-radius: 6px;
  background: #ffffff;
  width: 400px;
  padding: 25px 25px 5px 25px;
  z-index: 1;
  .el-input {
    height: 38px;
    input {
      height: 38px;
    }
  }
  .input-icon {
    height: 39px;
    width: 14px;
    margin-left: 2px;
  }
}
.login-tip {
  font-size: 13px;
  text-align: center;
  color: #bfbfbf;
}
.login-code {
  width: 33%;
  height: 38px;
  float: right;
  img {
    cursor: pointer;
    vertical-align: middle;
  }
}
.el-login-footer {
  height: 40px;
  line-height: 40px;
  position: fixed;
  bottom: 0;
  width: 100%;
  text-align: center;
  color: #fff;
  font-family: Arial;
  font-size: 12px;
  letter-spacing: 1px;
}
.login-code-img {
  height: 38px;
}
</style>
