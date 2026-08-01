import request from '@/utils/request'

// 查询在线预约列表
export function listBooking(query) {
  return request({
    url: '/biz/booking/list',
    method: 'get',
    params: query
  })
}

// 查询在线预约详细
export function getBooking(bookingId) {
  return request({
    url: '/biz/booking/' + bookingId,
    method: 'get'
  })
}

// 新增在线预约
export function addBooking(data) {
  return request({
    url: '/biz/booking',
    method: 'post',
    data: data
  })
}

// 修改在线预约
export function updateBooking(data) {
  return request({
    url: '/biz/booking',
    method: 'put',
    data: data
  })
}

// 删除在线预约
export function delBooking(bookingId) {
  return request({
    url: '/biz/booking/' + bookingId,
    method: 'delete'
  })
}

// 查询某场次的报名会员明细
export function listBookingMembers(bookingId) {
  return request({
    url: '/biz/booking/members/' + bookingId,
    method: 'get'
  })
}

// 查询预约报名明细列表（分页）
export function listBookingMember(query) {
  return request({
    url: '/biz/booking/member/list',
    method: 'get',
    params: query
  })
}
