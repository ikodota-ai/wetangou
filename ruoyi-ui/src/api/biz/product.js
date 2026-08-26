import request from '@/utils/request'

// 查询商品列表
export function listProduct(query) {
  return request({
    url: '/biz/product/list',
    method: 'get',
    params: query
  })
}

// 查询商品详细
export function getProduct(productId) {
  return request({
    url: '/biz/product/' + productId,
    method: 'get'
  })
}

// 新增商品
export function addProduct(data) {
  return request({
    url: '/biz/product',
    method: 'post',
    data: data
  })
}

// 修改商品
export function updateProduct(data) {
  return request({
    url: '/biz/product',
    method: 'put',
    data: data
  })
}

// 上架 / 下架（status: '0' 上架 / '1' 下架）
// 上架时后端会跑完整必填校验，缺字段会返回具体缺哪一项
export function changeProductStatus(productId, status) {
  return request({
    url: '/biz/product/status',
    method: 'put',
    data: { productId, status }
  })
}

// 删除商品
export function delProduct(productId) {
  return request({
    url: '/biz/product/' + productId,
    method: 'delete'
  })
}
