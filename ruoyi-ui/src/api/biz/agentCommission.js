import request from '@/utils/request'

// C1 代理商佣金概览（admin 端）
export function getAgentCommissionSummary(agentId) {
  return request({
    url: '/biz/agent/commission/summary',
    method: 'get',
    params: { agentId }
  })
}
