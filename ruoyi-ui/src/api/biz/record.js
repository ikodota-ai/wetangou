import request from '@/utils/request'

// 查询分账明细列表
export function listRecord(query) {
  return request({
    url: '/biz/record/list',
    method: 'get',
    params: query
  })
}

// 查询分账明细详细
export function getRecord(recordId) {
  return request({
    url: '/biz/record/' + recordId,
    method: 'get'
  })
}

// 新增分账明细
export function addRecord(data) {
  return request({
    url: '/biz/record',
    method: 'post',
    data: data
  })
}

// 修改分账明细
export function updateRecord(data) {
  return request({
    url: '/biz/record',
    method: 'put',
    data: data
  })
}

// 删除分账明细
export function delRecord(recordId) {
  return request({
    url: '/biz/record/' + recordId,
    method: 'delete'
  })
}
