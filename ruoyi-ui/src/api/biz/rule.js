import request from '@/utils/request'

// 查询佣金规则列表
export function listRule(query) {
  return request({
    url: '/biz/rule/list',
    method: 'get',
    params: query
  })
}

// 查询佣金规则详细
export function getRule(ruleId) {
  return request({
    url: '/biz/rule/' + ruleId,
    method: 'get'
  })
}

// 新增佣金规则
export function addRule(data) {
  return request({
    url: '/biz/rule',
    method: 'post',
    data: data
  })
}

// 修改佣金规则
export function updateRule(data) {
  return request({
    url: '/biz/rule',
    method: 'put',
    data: data
  })
}

// 删除佣金规则
export function delRule(ruleId) {
  return request({
    url: '/biz/rule/' + ruleId,
    method: 'delete'
  })
}
