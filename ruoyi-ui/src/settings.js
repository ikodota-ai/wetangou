module.exports = {
  /**
   * 网页标题
   */
  title: process.env.VUE_APP_TITLE,

  /**
   * 侧边栏主题 深色主题theme-dark，浅色主题theme-light
   */
  sideTheme: 'theme-dark',

  /**
   * 系统布局配置
   */
  showSettings: true,

  /**
   * 菜单导航模式 1、纯左侧 2、混合（左侧+顶部） 3、纯顶部
   */
  navType: 1,

  /**
   * 是否显示 tagsView
   */
  tagsView: true,

  /**
   * 持久化标签页
   */
  tagsViewPersist: false,

  /**
   * 显示页签图标
   */
  tagsIcon: false,

  /**
   * 标签页样式：card 卡片（默认）、chrome 谷歌浏览器风格
   */
  tagsViewStyle: 'card',

  /**
   * 是否固定头部
   */
  fixedHeader: true,

  /**
   * 是否显示logo
   */
  sidebarLogo: true,

  /**
   * 是否显示动态标题
   */
  dynamicTitle: false,

  /**
   * 是否显示底部版权
   */
  footerVisible: false,

  /**
   * 底部版权文本内容
   */
  footerContent: 'Copyright © 2018-2026 RuoYi. All Rights Reserved.',

  /**
   * 腾讯地图 JavaScript API key（https://lbs.qq.com 申请，需启用 WebServiceAPI 才能做地址解析）
   *
   * 用 VUE_APP_TENCENT_MAP_KEY 注入，不要写死在这里：
   * key 绑域名白名单且有免费额度上限，写死意味着换 key 得改代码重新打包，
   * 而且额度是全平台共享的（不是每个商户一份），必须由平台统一管控。
   * 地理编码结果已在 components/TencentMap 做了缓存，正常使用不会触达付费额度。
   */
  tencentMapKey: process.env.VUE_APP_TENCENT_MAP_KEY || ''
}
