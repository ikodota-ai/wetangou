import request from '@/utils/request'

// 获取小程序平台配置
export function getMpConfig() {
  return request({
    url: '/biz/mpconfig',
    method: 'get'
  })
}

// 保存小程序平台配置
export function saveMpConfig(data) {
  return request({
    url: '/biz/mpconfig',
    method: 'put',
    data: data
  })
}
