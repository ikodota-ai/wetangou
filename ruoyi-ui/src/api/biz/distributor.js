import request from '@/utils/request'

// 查询推客列表
export function listDistributor(query) {
  return request({
    url: '/biz/distributor/list',
    method: 'get',
    params: query
  })
}

// 查询推客详细
export function getDistributor(distributorId) {
  return request({
    url: '/biz/distributor/' + distributorId,
    method: 'get'
  })
}

// 新增推客
export function addDistributor(data) {
  return request({
    url: '/biz/distributor',
    method: 'post',
    data: data
  })
}

// 修改推客
export function updateDistributor(data) {
  return request({
    url: '/biz/distributor',
    method: 'put',
    data: data
  })
}

// 删除推客
export function delDistributor(distributorId) {
  return request({
    url: '/biz/distributor/' + distributorId,
    method: 'delete'
  })
}

// 推客太阳码（admin 端预览）
export function getDistributorQrcode(distributorId) {
  return request({
    url: '/biz/distributor/qrcode', params: { distributorId: distributorId },
    method: 'get'
  })
}
