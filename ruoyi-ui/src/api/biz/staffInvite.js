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
export function delStaff(id) {
  return request({ url: '/biz/staffInvite/staff/' + id, method: 'delete' })
}
