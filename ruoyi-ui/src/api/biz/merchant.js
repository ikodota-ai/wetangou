import request from '@/utils/request'

// 查询商户列表
export function listMerchant(query) {
  return request({
    url: '/biz/merchant/list',
    method: 'get',
    params: query
  })
}

// 查询商户详细
export function getMerchant(merchantId) {
  return request({
    url: '/biz/merchant/' + merchantId,
    method: 'get'
  })
}

// 新增商户
export function addMerchant(data) {
  return request({
    url: '/biz/merchant',
    method: 'post',
    data: data
  })
}

// 修改商户
export function updateMerchant(data) {
  return request({
    url: '/biz/merchant',
    method: 'put',
    data: data
  })
}

// 删除商户
export function delMerchant(merchantId) {
  return request({
    url: '/biz/merchant/' + merchantId,
    method: 'delete'
  })
}

// 生成支付回调地址（含 merchantId，便于回调时直接定位商户密钥解密）
export function getPayNotifyUrl(merchantId) {
  return request({
    url: '/biz/merchant/cert/notifyUrl',
    method: 'get',
    params: { merchantId }
  })
}
