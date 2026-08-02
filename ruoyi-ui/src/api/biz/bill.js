import request from '@/utils/request'

// 查询买单流水列表
export function listBill(query) {
  return request({
    url: '/biz/bill/list',
    method: 'get',
    params: query
  })
}

// 确认买单（后台 web 端）
export function confirmBill(billId) {
  return request({
    url: '/biz/bill/confirm/' + billId,
    method: 'post'
  })
}

// 查询买单流水详细
export function getBill(billId) {
  return request({
    url: '/biz/bill/' + billId,
    method: 'get'
  })
}

// 新增买单流水
export function addBill(data) {
  return request({
    url: '/biz/bill',
    method: 'post',
    data: data
  })
}

// 修改买单流水
export function updateBill(data) {
  return request({
    url: '/biz/bill',
    method: 'put',
    data: data
  })
}

// 删除买单流水
export function delBill(billId) {
  return request({
    url: '/biz/bill/' + billId,
    method: 'delete'
  })
}
