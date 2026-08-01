import request from '@/utils/request'

// 查询门店相册列表
export function listAlbum(query) {
  return request({
    url: '/biz/album/list',
    method: 'get',
    params: query
  })
}

// 查询门店相册详细
export function getAlbum(albumId) {
  return request({
    url: '/biz/album/' + albumId,
    method: 'get'
  })
}

// 新增门店相册
export function addAlbum(data) {
  return request({
    url: '/biz/album',
    method: 'post',
    data: data
  })
}

// 修改门店相册
export function updateAlbum(data) {
  return request({
    url: '/biz/album',
    method: 'put',
    data: data
  })
}

// 删除门店相册
export function delAlbum(albumId) {
  return request({
    url: '/biz/album/' + albumId,
    method: 'delete'
  })
}
