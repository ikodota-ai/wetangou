import request from '@/utils/request'

// 查询代金券模板列表
export function listVoucher(query) {
  return request({
    url: '/biz/voucher/list',
    method: 'get',
    params: query
  })
}

// 查询代金券模板详细
export function getVoucher(voucherId) {
  return request({
    url: '/biz/voucher/' + voucherId,
    method: 'get'
  })
}

// 新增代金券模板
export function addVoucher(data) {
  return request({
    url: '/biz/voucher',
    method: 'post',
    data: data
  })
}

// 修改代金券模板
export function updateVoucher(data) {
  return request({
    url: '/biz/voucher',
    method: 'put',
    data: data
  })
}

// 删除代金券模板
export function delVoucher(voucherId) {
  return request({
    url: '/biz/voucher/' + voucherId,
    method: 'delete'
  })
}
