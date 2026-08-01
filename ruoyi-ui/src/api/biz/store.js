import request from '@/utils/request'

// 查询门店列表
export function listStore(query) {
  return request({
    url: '/biz/store/list',
    method: 'get',
    params: query
  })
}

// 查询门店详细
export function getStore(storeId) {
  return request({
    url: '/biz/store/' + storeId,
    method: 'get'
  })
}

// 新增门店
export function addStore(data) {
  return request({
    url: '/biz/store',
    method: 'post',
    data: data
  })
}

// 修改门店
export function updateStore(data) {
  return request({
    url: '/biz/store',
    method: 'put',
    data: data
  })
}

// 删除门店
export function delStore(storeId) {
  return request({
    url: '/biz/store/' + storeId,
    method: 'delete'
  })
}
