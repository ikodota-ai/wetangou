import request from '@/utils/request'

// 查询提现记录列表
export function listWithdraw(query) {
  return request({
    url: '/biz/withdraw/list',
    method: 'get',
    params: query
  })
}

// 查询提现记录详细
export function getWithdraw(withdrawId) {
  return request({
    url: '/biz/withdraw/' + withdrawId,
    method: 'get'
  })
}

// 新增提现记录
export function addWithdraw(data) {
  return request({
    url: '/biz/withdraw',
    method: 'post',
    data: data
  })
}

// 修改提现记录
export function updateWithdraw(data) {
  return request({
    url: '/biz/withdraw',
    method: 'put',
    data: data
  })
}

// 删除提现记录
export function delWithdraw(withdrawId) {
  return request({
    url: '/biz/withdraw/' + withdrawId,
    method: 'delete'
  })
}

// 提现审核（通过/驳回）
export function auditWithdraw(data) {
  return request({
    url: '/biz/withdraw/audit',
    method: 'post',
    data: data
  })
}
