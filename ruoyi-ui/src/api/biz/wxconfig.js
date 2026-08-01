import request from '@/utils/request'

// 获取微信配置
export function getWxConfig() {
  return request({
    url: '/biz/wxconfig',
    method: 'get'
  })
}

// 保存微信配置
export function saveWxConfig(data) {
  return request({
    url: '/biz/wxconfig',
    method: 'put',
    data: data
  })
}
