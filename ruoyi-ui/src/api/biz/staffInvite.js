import request from '@/utils/request'

// 邀请码列表
export function listStaffInvite(query) {
  return request({ url: '/biz/staffInvite/list', method: 'get', params: query })
}
export function getStaffInvite(id) {
  return request({ url: '/biz/staffInvite/' + id, method: 'get' })
}
export function addStaffInvite(data) {
  return request({ url: '/biz/staffInvite', method: 'post', data })
}
export function updateStaffInvite(data) {
  return request({ url: '/biz/staffInvite', method: 'put', data })
}
export function delStaffInvite(id) {
  return request({ url: '/biz/staffInvite/' + id, method: 'delete' })
}
export function qrcodeStaffInvite(id) {
  return request({ url: '/biz/staffInvite/qrcode/' + id, method: 'get' })
}

// 员工名单
export function listStaff(query) {
  return request({ url: '/biz/staffInvite/staff/list', method: 'get', params: query })
}
export function updateStaff(data) {
  return request({ url: '/biz/staffInvite/staff', method: 'put', data })
}
export function profileStaff(data) {
  return request({ url: '/biz/staffInvite/staff/profile', method: 'post', data })
}
// 解绑员工微信（admin 端）：释放 openid，员工需重新账号密码登录
export function unbindStaffWx(userId) {
  return request({ url: '/biz/staffInvite/staff/unbindWx/' + userId, method: 'put' })
}

// 重置员工登录密码：后端自动生成 8 位随机密码，明文只在响应里返回一次
export function resetStaffPwd(userId) {
  return request({ url: '/biz/staffInvite/staff/resetPwd/' + userId, method: 'put' })
}

// 待审核员工清单（扫码入职后 status=3）
export function listStaffAudit() {
  return request({ url: '/biz/staffInvite/staff/audit', method: 'get' })
}
// 审核入职：approve=true 通过（转在职）/ false 拒绝（删除关联）
export function auditStaff(data) {
  return request({ url: '/biz/staffInvite/staff/audit', method: 'post', data })
}

export function delStaff(id) {
  return request({ url: '/biz/staffInvite/staff/' + id, method: 'delete' })
}
