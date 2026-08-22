import request from '@/utils/request'

// 商品组
export function listGroups(productId) {
  return request({ url: '/biz/productSubitem/groups', method: 'get', params: { productId } })
}
export function addGroup(data) {
  return request({ url: '/biz/productSubitem/group', method: 'post', data })
}
export function updateGroup(data) {
  return request({ url: '/biz/productSubitem/group', method: 'put', data })
}
export function delGroup(groupId) {
  return request({ url: '/biz/productSubitem/group/' + groupId, method: 'delete' })
}

// 子品分页列表（子商品管理独立页用，带 productName / groupName）
export function listProductSubitem(query) {
  return request({ url: '/biz/productSubitem/list', method: 'get', params: query })
}

// 历史子品名称候选（添加子品下拉筛选用）
export function listSubitemNameCandidates(keyword) {
  return request({ url: '/biz/productSubitem/nameCandidates', method: 'get', params: { keyword } })
}

// 子品
export function listSubitems(groupId) {
  return request({ url: '/biz/productSubitem/subitem', method: 'get', params: { groupId } })
}
export function addSubitem(data) {
  return request({ url: '/biz/productSubitem/subitem', method: 'post', data })
}
export function updateSubitem(data) {
  return request({ url: '/biz/productSubitem/subitem', method: 'put', data })
}
export function delSubitem(subitemId) {
  return request({ url: '/biz/productSubitem/subitem/' + subitemId, method: 'delete' })
}
