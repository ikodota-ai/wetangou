// utils/request.js 网络请求封装
const { BASE_URL, MOCK_ENABLED, APPID, BUILD_IN_APPID, probeBaseUrl } = require('./config.js');

// 启动期一次性打印当前生效的 APPID 与构建期 APPID，便于在开发者工具 Console 排查租户解析问题

// === 启动期探测可用的 BASE_URL（异步，结果会更新 _activeBaseUrl） ===
let _activeBaseUrl = BASE_URL;
probeBaseUrl().then(function (u) {
  if (u && u !== _activeBaseUrl) {
    _activeBaseUrl = u;
    try { console.log('[miniprogram] probeBaseUrl switched to', u); } catch (e) {}
  }
}).catch(function () {});

function _base() { return _activeBaseUrl || BASE_URL; }

try {
  console.log('[miniprogram] APPID =>', APPID, '| BUILD_IN_APPID =>', BUILD_IN_APPID, '| BASE_URL =>', BASE_URL);
} catch (e) {}

// 把后端返回的相对地址补全
function toFullUrl(url) {
  if (!url) return '';
  let u = String(url).trim();
  if (/^https?:\/\//i.test(u)) return u;
  u = u.replace(/^\/dev-api/, '');
  if (u.charAt(0) !== '/') u = '/' + u;
  return _base() + u;
}

// 富文本图片补全
function fixRichText(html) {
  if (!html) return '';
  return String(html).replace(/(<img[^>]+src=["'])([^"']+)(["'])/gi, (m, p1, src, p3) => p1 + toFullUrl(src) + p3);
}

function request(url, options = {}) {
  const token = wx.getStorageSync('token');
  return new Promise((resolve, reject) => {
    wx.request({
      url: _base() + url,
      method: options.method || 'GET',
      data: options.data || {},
      header: {
        'content-type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : '',
        'X-App-Id': APPID
      },
      success: (res) => {
        if (res.statusCode === 200) {
          const d = res.data || {};
          if (d.code === 200 || d.code === 0 || d.success) {
            resolve(d.data || d);
          } else if (d.code === 401) {
            wx.removeStorageSync('token');
            reject({ code: 401, msg: '未登录' });
          } else {
            resolve(d);
          }
        } else if (res.statusCode === 401) {
          wx.removeStorageSync('token');
          reject({ code: 401 });
        } else {
          reject(res);
        }
      },
      fail: (err) => {
        console.error('[request] FAIL', BASE_URL + url, 'X-App-Id=', APPID, 'err=', err);
        reject(err);
      }
    });
  });
}

function uploadFile(url, filePath, name = 'file', formData = {}) {
  const token = wx.getStorageSync('token');
  return new Promise((resolve, reject) => {
    wx.uploadFile({
      url: _base() + url,
      filePath, name, formData,
      header: { 'Authorization': token ? `Bearer ${token}` : '', 'X-App-Id': APPID },
      success: (res) => {
        let d = res.data;
        try { d = JSON.parse(res.data); } catch (e) {}
        if (res.statusCode === 200 && (d.code === 200 || d.code === 0)) resolve(d.data || d);
        else reject(d);
      },
      fail: reject
    });
  });
}

// 接口封装
// 路径与后端 Api*Controller 一一对应，改动前请对照 doc/小程序API文档.md，
// 避免再次出现前端声明路径与后端实现不一致导致的静默失败。
const api = {
  // 认证
  login: (data) => request('/api/auth/login', { method: 'POST', data }),
  logout: () => request('/api/auth/logout', { method: 'POST' }),
  getUserInfo: () => request('/api/member/profile'),
  // 会员
  updateMember: (data) => request('/api/member', { method: 'PUT', data }),
  // 微信新版 getPhoneNumber：传 e.detail.code，由后端换取手机号
  updatePhone: (data) => request('/api/member/phone', { method: 'POST', data }),
  uploadAvatar: (p) => uploadFile('/api/member/avatar', p, 'avatarfile'),
  // 门店
  storeList: (params) => request('/api/store/list', { data: params }),
  storeNearest: (params) => request('/api/store/nearest', { data: params }),
  storeDetail: (id) => request(`/api/store/${id}`),
  storeAlbum: (id) => request(`/api/store/${id}/album`),
  storeServices: (id) => request(`/api/store/${id}/services`),
  // 首页 Banner
  bannerList: (params) => request('/api/banner/list', { data: params }),
  // 商品
  productList: (params) => request('/api/product/list', { data: params }),
  productDetail: (id) => request(`/api/product/${id}`),
  categoryList: (params) => request('/api/product/category/list', { data: params }),
  // 订单
  createOrder: (data) => request('/api/order', { method: 'POST', data }),
  prepayOrder: (id) => request(`/api/order/prepay/${id}`, { method: 'POST' }),
  payOrder: (id) => request(`/api/order/pay/${id}`, { method: 'POST' }),
  orderList: (params) => request('/api/order/list', { data: params }),
  orderDetail: (id) => request(`/api/order/${id}`),
  verifyOrder: (data) => request('/api/order/verify', { method: 'POST', data }),
  // 员工工作台
  staffMe: () => request('/api/store/staff/me'),
  staffLogout: () => request('/api/store/staff/logout', { method: 'POST' }),
  staffHome: () => request('/api/store/staff/home'),
  staffTodayOrders: () => request('/api/store/staff/today/orders'),
  staffTodayBills: () => request('/api/store/staff/today/bills'),
  staffTodayBookings: () => request('/api/store/staff/today/bookings'),
  staffBookingSignupList: () => request('/api/store/staff/booking/signup/list'),
  staffBookingConfirm: (signupId, body) => request('/api/store/staff/booking/confirm/' + signupId, { method: 'POST', data: body || {} }),
  staffBookingReject:  (signupId, body) => request('/api/store/staff/booking/reject/'  + signupId, { method: 'POST', data: body || {} }),
  // 商家端 v2（基于 sys_user.openid + biz_merchant_staff）
  merchantStaffLogin: (data) => request('/api/merchant/staff/login', { method: 'POST', data }),
  merchantStaffWxLogin: (data) => request('/api/merchant/staff/wxLogin', { method: 'POST', data }),
  merchantStaffAcceptInvite: (data) => request('/api/merchant/staff/acceptInvite', { method: 'POST', data }),
  merchantStaffBindWx: (data) => request('/api/merchant/staff/bindWx', { method: 'POST', data }),
  merchantStaffMe: () => request('/api/merchant/staff/me'),
  merchantStaffProfile: (data) => request('/api/merchant/staff/profile', { method: 'POST', data }),
  merchantStaffLogout: () => request('/api/merchant/staff/logout', { method: 'POST' }),
  // 商家工作台（对标旧 /api/store/staff/{home,today/*,booking/*}）
  merchantStaffHome: () => request('/api/merchant/staff/home'),
  merchantStaffTodayOrders: () => request('/api/merchant/staff/today/orders'),
  merchantStaffTodayBills: () => request('/api/merchant/staff/today/bills'),
  merchantStaffTodayBookings: () => request('/api/merchant/staff/today/bookings'),
  merchantStaffBookingSignupList: () => request('/api/merchant/staff/booking/signup/list'),
  merchantStaffBookingConfirm: (signupId, body) => request('/api/merchant/staff/booking/confirm/' + signupId, { method: 'POST', data: body || {} }),
  merchantStaffBookingReject:  (signupId, body) => request('/api/merchant/staff/booking/reject/'  + signupId, { method: 'POST', data: body || {} }),
  // 预约
  bookingSlots: (params) => request('/api/booking/slots', { data: params }),
  createBooking: (data) => request('/api/booking', { method: 'POST', data }),
  bookingList: (params) => request('/api/booking/list', { data: params }),
  bookingDetail: (id) => request(`/api/booking/${id}`),
  bookingSignupDetail: (signupId) => request(`/api/booking/signup/${signupId}`),
  cancelBooking: (signupId) => request(`/api/booking/cancel/${signupId}`, { method: 'POST' }),
  // 买单
  createBill: (data) => request('/api/bill', { method: 'POST', data }),
  billDetail: (id) => request(`/api/bill/${id}`),
  confirmBill: (id) => request(`/api/bill/confirm/${id}`, { method: 'POST' }),
  billPrepay: (id) => request(`/api/bill/prepay/${id}`, { method: 'POST' }),
  payBill: (id) => request(`/api/bill/pay/${id}`, { method: 'POST' }),
  // 代金券
  voucherList: (params) => request('/api/voucher/list', { data: params }),
  receiveVoucher: (id) => request(`/api/voucher/receive/${id}`, { method: 'POST' }),
  myVoucher: (params) => request('/api/voucher/my', { data: params }),
  // 推客 / 提现（后端实现在 /api/distributor 下）
  promoterInfo: () => request('/api/distributor/center'),
  joinPromoter: () => request('/api/distributor/join', { method: 'POST' }),
  commissionList: (params) => request('/api/distributor/commission/list', { data: params }),
  withdrawList: () => request('/api/distributor/withdraw/list'),
  applyWithdraw: (data) => request('/api/distributor/withdraw', { method: 'POST', data }),
  // 推客邀请：太阳码 + 粉丝列表（后端生成 wxacode，图片保存到 /upload/distributor/）
  promoterQrcode: () => request('/api/distributor/qrcode'),
  promoterFans: () => request('/api/distributor/fans'),
  // 已登录用户回填邀请人（用于扫码进入时未携带 inviteBy 的补单场景）
  bindInvite: (inviteBy) => request('/api/auth/bind-invite', { method: 'POST', data: { inviteBy } }),
  // 协议：后端为单接口按 type 区分
  agreement: (type) => request('/api/agreement', { data: { type } }),
  agreementUser: () => request('/api/agreement', { data: { type: 'user' } }),
  agreementPrivacy: () => request('/api/agreement', { data: { type: 'privacy' } }),
  // 当前商家公开信息（匿名接口，根据 X-App-Id 解析）
  merchantInfo: () => request('/api/merchant/info')
};

module.exports = {
  request,
  uploadFile,
  api,
  BASE_URL,
  APPID,
  toFullUrl,
  fixRichText,
  mockEnabled: MOCK_ENABLED
};
