import request from '@/utils/request'

// 查询账号门店关联列表
export function listUser(query) {
  return request({
    url: '/biz/storeUser/list',
    method: 'get',
    params: query
  })
}

// 查询账号门店关联详细
export function getUser(id) {
  return request({
    url: '/biz/storeUser/' + id,
    method: 'get'
  })
}

// 新增账号门店关联
export function addUser(data) {
  return request({
    url: '/biz/storeUser',
    method: 'post',
    data: data
  })
}

// 修改账号门店关联
export function updateUser(data) {
  return request({
    url: '/biz/storeUser',
    method: 'put',
    data: data
  })
}

// 删除账号门店关联
export function delUser(id) {
  return request({
    url: '/biz/storeUser/' + id,
    method: 'delete'
  })
}
