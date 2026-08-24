import request from '@/utils/request'

// 查询小程序授权列表
export function listMpAuth(query) {
  return request({
    url: '/biz/mpauth/list',
    method: 'get',
    params: query
  })
}

// 查询小程序授权详细
export function getMpAuth(authId) {
  return request({
    url: '/biz/mpauth/' + authId,
    method: 'get'
  })
}

// 新增小程序授权
export function addMpAuth(data) {
  return request({
    url: '/biz/mpauth',
    method: 'post',
    data: data
  })
}

// 修改小程序授权
export function updateMpAuth(data) {
  return request({
    url: '/biz/mpauth',
    method: 'put',
    data: data
  })
}

// 删除小程序授权
export function delMpAuth(authId) {
  return request({
    url: '/biz/mpauth/' + authId,
    method: 'delete'
  })
}
