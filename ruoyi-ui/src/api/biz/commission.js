import request from '@/utils/request'

// 查询佣金明细列表
export function listCommission(query) {
  return request({
    url: '/biz/commission/list',
    method: 'get',
    params: query
  })
}

// 查询佣金明细详细
export function getCommission(commissionId) {
  return request({
    url: '/biz/commission/' + commissionId,
    method: 'get'
  })
}

// 新增佣金明细
export function addCommission(data) {
  return request({
    url: '/biz/commission',
    method: 'post',
    data: data
  })
}

// 修改佣金明细
export function updateCommission(data) {
  return request({
    url: '/biz/commission',
    method: 'put',
    data: data
  })
}

// 删除佣金明细
export function delCommission(commissionId) {
  return request({
    url: '/biz/commission/' + commissionId,
    method: 'delete'
  })
}

// 结算到期佣金（冻结转可提现）
export function settleCommission() {
  return request({
    url: '/biz/commission/settle',
    method: 'post'
  })
}
