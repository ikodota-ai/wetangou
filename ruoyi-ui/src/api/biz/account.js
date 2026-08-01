import request from '@/utils/request'

// 查询分账接收方列表
export function listAccount(query) {
  return request({
    url: '/biz/account/list',
    method: 'get',
    params: query
  })
}

// 查询分账接收方详细
export function getAccount(accountId) {
  return request({
    url: '/biz/account/' + accountId,
    method: 'get'
  })
}

// 新增分账接收方
export function addAccount(data) {
  return request({
    url: '/biz/account',
    method: 'post',
    data: data
  })
}

// 修改分账接收方
export function updateAccount(data) {
  return request({
    url: '/biz/account',
    method: 'put',
    data: data
  })
}

// 删除分账接收方
export function delAccount(accountId) {
  return request({
    url: '/biz/account/' + accountId,
    method: 'delete'
  })
}
