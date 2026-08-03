import request from '@/utils/request'

// 查询小程序发布记录列表
export function listMpRelease(query) {
  return request({
    url: '/biz/mprelease/list',
    method: 'get',
    params: query
  })
}

// 查询小程序发布记录详细
export function getMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/' + releaseId,
    method: 'get'
  })
}

// 按商户微信配置生成 ext.json
export function buildExtJson(merchantId) {
  return request({
    url: '/biz/mprelease/extjson/' + merchantId,
    method: 'get'
  })
}

// 代上传：新增待提交版本
export function addMpRelease(data) {
  return request({
    url: '/biz/mprelease',
    method: 'post',
    data: data
  })
}

// 修改待提交版本
export function updateMpRelease(data) {
  return request({
    url: '/biz/mprelease',
    method: 'put',
    data: data
  })
}

// 提交审核
export function submitMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/submit/' + releaseId,
    method: 'put'
  })
}

// 撤回审核
export function undoMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/undo/' + releaseId,
    method: 'put'
  })
}

// 发布上线
export function releaseMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/release/' + releaseId,
    method: 'put'
  })
}

// 版本回退
export function rollbackMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/rollback/' + releaseId,
    method: 'put'
  })
}

// 删除小程序发布记录
export function delMpRelease(releaseId) {
  return request({
    url: '/biz/mprelease/' + releaseId,
    method: 'delete'
  })
}

// 微信开放平台状态
export function getPlatformStatus() {
  return request({
    url: '/biz/mprelease/platform-status',
    method: 'get'
  })
}

// 拉商户太阳码（用于代上传：拉取 authorizer_access_token 后生成 wxacode）
export function getMpAuth(appid) {
  return request({
    url: '/biz/mpauth/appid/' + appid,
    method: 'get'
  })
}
