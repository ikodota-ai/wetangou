import request from '@/utils/request'

// 查询商品类型字典列表（分页，admin 端管理用）
export function listProductType(query) {
  return request({ url: '/biz/productType/list', method: 'get', params: query })
}

// 取所有启用的商品类型（admin 下拉专用，pageSize 100 即可）
export function selectProductTypeList() {
  return request({ url: '/biz/productType/list', method: 'get', params: { pageNum: 1, pageSize: 100, status: '0' } })
}

// 小程序拉取可选类型（仅 app_can_create=1 的）
export function listAppCreatableProductType() {
  return request({ url: '/biz/productType/appCreatable', method: 'get' })
}

// 按 code 查一条
export function getProductType(typeCode) {
  return request({ url: '/biz/productType/' + typeCode, method: 'get' })
}

// 新增
export function addProductType(data) {
  return request({ url: '/biz/productType', method: 'post', data })
}

// 修改
export function updateProductType(data) {
  return request({ url: '/biz/productType', method: 'put', data })
}

// 删除
export function delProductType(typeCode) {
  return request({ url: '/biz/productType/' + typeCode, method: 'delete' })
}
