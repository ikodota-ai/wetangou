import request from '@/utils/request'

// 获取提现规则配置
export function getWithdrawRule() {
  return request({
    url: '/biz/withdrawRule',
    method: 'get'
  })
}

// 保存提现规则配置
export function saveWithdrawRule(data) {
  return request({
    url: '/biz/withdrawRule',
    method: 'put',
    data: data
  })
}
