import request from '@/utils/request'

// 查询协议列表
export function listAgreement(query) {
  return request({
    url: '/biz/agreement/list',
    method: 'get',
    params: query
  })
}

// 查询协议详细
export function getAgreement(agreementId) {
  return request({
    url: '/biz/agreement/' + agreementId,
    method: 'get'
  })
}

// 新增协议
export function addAgreement(data) {
  return request({
    url: '/biz/agreement',
    method: 'post',
    data: data
  })
}

// 修改协议
export function updateAgreement(data) {
  return request({
    url: '/biz/agreement',
    method: 'put',
    data: data
  })
}

// 删除协议
export function delAgreement(agreementId) {
  return request({
    url: '/biz/agreement/' + agreementId,
    method: 'delete'
  })
}
