import request from '@/utils/request'

// 查询代理商缴费列表
export function listAgentFee(query) {
  return request({
    url: '/biz/agentfee/list',
    method: 'get',
    params: query
  })
}

// 查询代理商缴费详细
export function getAgentFee(feeId) {
  return request({
    url: '/biz/agentfee/' + feeId,
    method: 'get'
  })
}

// 新增代理商缴费
export function addAgentFee(data) {
  return request({
    url: '/biz/agentfee',
    method: 'post',
    data: data
  })
}

// 修改代理商缴费
export function updateAgentFee(data) {
  return request({
    url: '/biz/agentfee',
    method: 'put',
    data: data
  })
}

// 审核缴费单（status: 1已确认 2已驳回）
export function auditAgentFee(feeId, status) {
  return request({
    url: '/biz/agentfee/audit/' + feeId + '/' + status,
    method: 'put'
  })
}

// 删除代理商缴费
export function delAgentFee(feeId) {
  return request({
    url: '/biz/agentfee/' + feeId,
    method: 'delete'
  })
}
