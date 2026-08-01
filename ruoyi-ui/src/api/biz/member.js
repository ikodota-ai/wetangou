import request from '@/utils/request'

// 查询会员列表
export function listMember(query) {
  return request({
    url: '/biz/member/list',
    method: 'get',
    params: query
  })
}

// 查询会员详细
export function getMember(memberId) {
  return request({
    url: '/biz/member/' + memberId,
    method: 'get'
  })
}

// 新增会员
export function addMember(data) {
  return request({
    url: '/biz/member',
    method: 'post',
    data: data
  })
}

// 修改会员
export function updateMember(data) {
  return request({
    url: '/biz/member',
    method: 'put',
    data: data
  })
}

// 删除会员
export function delMember(memberId) {
  return request({
    url: '/biz/member/' + memberId,
    method: 'delete'
  })
}
