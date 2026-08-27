import request from '@/utils/request'

// 查询投放渠道字典列表
export function listSaleChannel(query) {
  return request({
    url: '/biz/saleChannel/list',
    method: 'get',
    params: query
  })
}

// 启用中的渠道 + 默认勾选项（商品编辑页用，只要登录就能读）
export function enabledSaleChannel() {
  return request({
    url: '/biz/saleChannel/enabled',
    method: 'get'
  })
}

// 查询渠道详情
export function getSaleChannel(channelCode) {
  return request({
    url: '/biz/saleChannel/' + channelCode,
    method: 'get'
  })
}

// 新增渠道
export function addSaleChannel(data) {
  return request({
    url: '/biz/saleChannel',
    method: 'post',
    data: data
  })
}

// 修改渠道
export function updateSaleChannel(data) {
  return request({
    url: '/biz/saleChannel',
    method: 'put',
    data: data
  })
}

// 删除渠道
export function delSaleChannel(channelCode) {
  return request({
    url: '/biz/saleChannel/' + channelCode,
    method: 'delete'
  })
}
