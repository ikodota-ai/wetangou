import request from '@/utils/request'

// 查询商户收费列表
export function listMerchantFee(query) {
  return request({
    url: '/biz/merchantfee/list',
    method: 'get',
    params: query
  })
}

// 查询商户收费详细
export function getMerchantFee(feeId) {
  return request({
    url: '/biz/merchantfee/' + feeId,
    method: 'get'
  })
}

// 新增商户收费
export function addMerchantFee(data) {
  return request({
    url: '/biz/merchantfee',
    method: 'post',
    data: data
  })
}

// 修改商户收费
export function updateMerchantFee(data) {
  return request({
    url: '/biz/merchantfee',
    method: 'put',
    data: data
  })
}

// 确认收款
export function confirmMerchantFee(feeId) {
  return request({
    url: '/biz/merchantfee/confirm/' + feeId,
    method: 'put'
  })
}

// 删除商户收费
export function delMerchantFee(feeId) {
  return request({
    url: '/biz/merchantfee/' + feeId,
    method: 'delete'
  })
}
