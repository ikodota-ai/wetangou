import store from '@/store'

/**
 * 后台三身份判定（与后端 TenantConstants 同口径）
 *
 * 0 平台 / 1 代理商 / 2 商户 —— 注意这是 TenantContext 的取值，
 * 不是 sys_user.user_type（那边是 '00'/'01'/'02'），登录接口返的是前者。
 *
 * 抽出来的原因：这个判断此前被复制到 20 个 biz 页面里各写一份
 * isShowMerchantFilter()，加一处身份规则要改 20 个文件，必漏。
 */
export function userType() {
  // 读 state 而非 getters：user 模块虽然定义了 userType getter，
  // 但 store/getters.js（根 getters）里从没暴露它，走 getters 恒为 undefined。
  return (store && store.state && store.state.user && store.state.user.userType) || ''
}

/** 平台账号（可见全平台数据） */
export function isPlatform() {
  return userType() === '0'
}

/** 代理商账号 */
export function isAgent() {
  return userType() === '1'
}

/** 商户账号 */
export function isMerchant() {
  return userType() === '2'
}

/**
 * 是否显示「商户」筛选/字段。
 * 商户账号自带 merchantId 上下文，给它看商户选择器没有意义。
 */
export function showMerchantField() {
  return !isMerchant()
}

/**
 * 是否显示「代理商」筛选/列/表单项。
 *
 * 平台不希望商户看到自己挂在哪个代理商名下（代理商是平台的渠道关系，
 * 对商户属于不该暴露的上游信息），因此商户身份一律隐藏。
 * 代理商自己看得到（就是他自己），平台当然看得到。
 */
export function showAgentField() {
  return !isMerchant()
}

/**
 * 当前登录账号的商户 ID（商户身份才有值）。
 *
 * 注意路径是 state.user.merchantId 而非 state.user.user.merchantId ——
 * user 模块的 state 里压根没有嵌套的 user 对象（见 store/modules/user.js），
 * 早先各页面复制的 `state.user.user.merchantId` 恒为 undefined，
 * 于是商户账号新建业务数据时表单 merchantId 一直是空的。
 */
export function currentMerchantId() {
  return (store && store.state && store.state.user && store.state.user.merchantId) || null
}

export default { userType, isPlatform, isAgent, isMerchant, showMerchantField, showAgentField, currentMerchantId }
