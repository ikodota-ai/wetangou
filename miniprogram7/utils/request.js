// utils/request.js 网络请求封装
const { BASE_URL: BASE_URL_DEFAULT, MOCK_ENABLED, APPID, BUILD_IN_APPID, probeBaseUrl } = require('./config.js');

// 启动期一次性打印当前生效的 APPID 与构建期 APPID，便于在开发者工具 Console 排查租户解析问题

// === 启动期探测可用的 BASE_URL（异步，结果会更新 _activeBaseUrl） ===
let _activeBaseUrl = BASE_URL_DEFAULT;
probeBaseUrl().then(function (u) {
  if (u && u !== _activeBaseUrl) {
    _activeBaseUrl = u;
    try { console.log('[miniprogram] probeBaseUrl switched to', u); } catch (e) {}
  }
}).catch(function () {});

function _base() { return _activeBaseUrl || BASE_URL_DEFAULT; }

try {
  console.log('[miniprogram] APPID =>', APPID, '| BUILD_IN_APPID =>', BUILD_IN_APPID, '| BASE_URL =>', BASE_URL_DEFAULT);
} catch (e) {}

// 把后端返回的相对地址补全
function toFullUrl(url) {
  if (!url) return '';
  let u = String(url).trim();
  if (/^https?:\/\//i.test(u)) {
    // 历史脏数据修复：早期上传头像时后端把 serverConfig.getUrl() 拼进库了，
    // 于是存量记录是 http://127.0.0.1:8080/profile/... 或 http://172.31.26.216:8080/...
    // 这类地址换台设备/换个环境必然打不开，而且 <image> 不支持 http。
    // 只要认得出 /profile/ 这个后端资源前缀，就丢掉原 host 用当前 baseUrl 重拼。
    const m = u.match(/^https?:\/\/[^/]+(\/profile\/.*)$/i);
    if (m) return _base() + m[1];
    return u;
  }
  u = u.replace(/^\/dev-api/, '');
  if (u.charAt(0) !== '/') u = '/' + u;
  return _base() + u;
}

// 富文本图片补全
function fixRichText(html) {
  if (!html) return '';
  return String(html).replace(/(<img[^>]+src=["'])([^"']+)(["'])/gi, (m, p1, src, p3) => p1 + toFullUrl(src) + p3);
}

// === 401 双 token 精准清理 ===
// 后端 MemberAuthInterceptor 返 401 时带 authScope 字段：
//   member → 会员 token 过期，清 memberToken + token，保留 staffToken
//   staff  → 员工登录态失效（会员 token 访问商家端接口），仅清 staffToken
// 历史版本无 authScope → 兼容清空全部
function _clearAuth(authScope) {
  if (authScope === 'staff') {
    // 员工态失效：清员工会话，不动会员 token
    try { wx.removeStorageSync('staffToken') } catch (e) {}
    try { wx.removeStorageSync('staffUser') } catch (e) {}
    try { wx.removeStorageSync('currentIdentity') } catch (e) {}
    // 如果当前 token 是 staff token，则恢复为 memberToken
    const memberToken = wx.getStorageSync('memberToken')
    if (memberToken) {
      try { wx.setStorageSync('token', memberToken) } catch (e) {}
    }
  } else if (authScope === 'member') {
    // 会员态失效：清会员 token，保留员工会话
    try { wx.removeStorageSync('memberToken') } catch (e) {}
    try { wx.removeStorageSync('token') } catch (e) {}
  } else {
    // 老版本兼容：无 authScope 的 401，全清
    try { wx.removeStorageSync('token') } catch (e) {}
    try { wx.removeStorageSync('memberToken') } catch (e) {}
    try { wx.removeStorageSync('staffToken') } catch (e) {}
  }
}

// 从会员登录响应里取 hasStaffAccount。
// 抽成纯函数是因为有两条会员登录入口都要写这个标记：显式登录页
// (pages/login/login.js) 和下面的静默重登。它是「我的」页显示「切换到商家版」
// 入口的唯一依据，任一条漏写，已入职的店员在会员端就找不到进商家版的路。
// 兼容后端把字段放顶层或包在 data 里两种形态。
function pickHasStaffAccount(data) {
  if (!data) return false
  if (data.hasStaffAccount === true) return true
  if (data.data && data.data.hasStaffAccount === true) return true
  return false
}

// === 静默重登 + 重试（仅会员态）===
// 会员 token 真过期时，自动 wx.login() 换 code 重新登录，
// 成功后用新 token 重试原请求一次。微信授权静默，用户无感。
// 防重入：同一时刻最多一个重登请求正在进行。
let _reloginPromise = null
function _reloginAndRetry(url, options, authScope) {
  if (_reloginPromise) return _reloginPromise
  _reloginPromise = (async () => {
    try {
      // 仅会员态可静默重登；员工态保持原始 401
      if (authScope !== 'member') throw new Error('skip')
      const lr = await new Promise((resolve, reject) => {
        wx.login({ success: resolve, fail: reject })
      })
      if (!lr || !lr.code) throw new Error('wx.login failed')
      // 直接调 request 而非 api.login，避免循环引用
      const data = await request('/api/auth/login', { method: 'POST', data: { code: lr.code, appid: APPID, inviteBy: null } })
      const token = (data && (data.token || data.data && data.data.token)) || ''
      if (!token) throw new Error('relogin no token')
      try { wx.setStorageSync('token', token) } catch (e) {}
      try { wx.setStorageSync('memberToken', token) } catch (e) {}
      // 和 pages/login/login.js 一样要刷 hasStaffAccount：这是「我的」页显示
      // 「切换到商家版」入口的唯一依据。只在显式登录页写的话，店员换设备或清了
      // 缓存后走这条静默重登，storage 里没这个标记 → 入口不出现，明明已入职的
      // 店员在会员端找不到任何进商家版的路。
      try { wx.setStorageSync('hasStaffAccount', pickHasStaffAccount(data)) } catch (e) {}
      // 用新 token 重试原请求
      return request(url, options)
    } catch (e) {
      throw { code: 401, msg: '登录已过期', _reloginFailed: true }
    } finally {
      _reloginPromise = null
    }
  })()
  return _reloginPromise
}

function request(url, options = {}) {
  // 当前身份决定用哪个 token：会员用 memberToken/当前 token，员工用 staffToken
  const currentId = wx.getStorageSync('currentIdentity')
  const staffToken = wx.getStorageSync('staffToken')
  const memberToken = wx.getStorageSync('memberToken')
  const token = currentId === 'staff' && staffToken
    ? staffToken
    : (memberToken || wx.getStorageSync('token'))

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
            const authScope = d.authScope || ''
            _clearAuth(authScope)
            // 静默重登：仅会员态 401 自动重试一次
            if (authScope === 'member' && !options._retry) {
              _reloginAndRetry(url, { ...options, _retry: true }, authScope)
                .then(resolve).catch(reject)
              return
            }
            reject({ code: 401, msg: d.msg || '未登录', authScope: authScope });
          } else {
            resolve(d);
          }
        } else if (res.statusCode === 401) {
          _clearAuth('')
          reject({ code: 401 });
        } else {
          reject(res);
        }
      },
      fail: (err) => {
        console.error('[request] FAIL', BASE_URL_DEFAULT + url, 'X-App-Id=', APPID, 'err=', err);
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
  // 商家端商品列表：分页 + 能查草稿。顾客端那个 /api/product/list 写死 status=0
  // 且不分页，商家端拿它做列表看不到自己的草稿、也拿不到 total 做 tab 角标。
  merchantProductList: (params) => request('/api/product/merchant/list', { data: params }),
  productDetail: (id) => request(`/api/product/${id}`),
  categoryList: (params) => request('/api/product/category/list', { data: params }),
  // 商家端-创建商品（P1-2）
  productTypeAppCreatable: () => request('/biz/productType/appCreatable'),
  // 投放渠道字典（商家端建品勾选用；平台级配置，商户只读）
  saleChannelEnabled: () => request('/biz/saleChannel/enabled'),
  productAdd: (data) => request('/api/product/add', { method: 'POST', data }),
  // 商品编辑（小程序建品后回填 totalValue / ext.comboItemsJson 等）
  productUpdate: (data) => request('/api/product', { method: 'PUT', data }),
  // 上下架
  productToggle: (data) => request('/api/product/status', { method: 'PUT', data }),
  // 商品搭配-商品组
  // 必须打 /api/product/subitem/**，不能打 PC 那套 /biz/productSubitem/**：
  // /biz/** 挂 Spring Security + @PreAuthorize，判的是后台 sys_user 的 perms；
  // 小程序员工 token 走 MemberAuthInterceptor 这条独立链路，拿它打 /biz/**
  // 一律 401（实测「请求访问 /biz/productSubitem/groups 认证失败」）。
  // 打错地址的后果是商品搭配页每个按钮都失败 —— 团购在手机上永远配不了套餐内容。
  productSubitemGroups: (params) => request('/api/product/subitem/groups', { data: params }),
  productSubitemGroupAdd: (data) => request('/api/product/subitem/group', { method: 'POST', data }),
  productSubitemGroupUpdate: (data) => request('/api/product/subitem/group', { method: 'PUT', data }),
  productSubitemGroupDel: (id) => request('/api/product/subitem/group/' + id, { method: 'DELETE' }),
  // 商品搭配-单品
  productSubitemAdd: (data) => request('/api/product/subitem', { method: 'POST', data }),
  productSubitemDel: (id) => request('/api/product/subitem/' + id, { method: 'DELETE' }),
  // 订单
  createOrder: (data) => request('/api/order', { method: 'POST', data }),
  prepayOrder: (id) => request(`/api/order/prepay/${id}`, { method: 'POST' }),
  payOrder: (id) => request(`/api/order/pay/${id}`, { method: 'POST' }),
  orderList: (params) => request('/api/order/list', { data: params }),
  orderDetail: (id) => request(`/api/order/${id}`),
  // 按商户订单号查（微信支付「商品订单详情path」跳回来时只有 order_no）
  orderDetailByNo: (no) => request(`/api/order/no/${no}`),
  // 待支付订单换券：memberVoucherId 传 null = 取消用券。
  // 后端会重算 discount/pay_amount，并换一个 order_no（旧的已被微信预支付单锁住金额）
  orderChangeVoucher: (id, memberVoucherId) =>
    request(`/api/order/${id}/voucher`, { method: 'POST', data: { memberVoucherId: memberVoucherId || null } }),
  orderQrcodeData: (id) => request(`/api/order/${id}/qrcode-data`),
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
  merchantStaffSwitchStore: (storeId) => request('/api/merchant/staff/switch-store', { method: 'POST', data: { storeId } }),
  // 商家工作台（对标旧 /api/store/staff/{home,today/*,booking/*}）
  merchantStaffHome: () => request('/api/merchant/staff/home'),
  platformFinanceSummary: (params) => {
    const qs = Object.keys(params || {})
      .filter(k => params[k] !== '' && params[k] !== null && params[k] !== undefined)
      .map(k => k + '=' + encodeURIComponent(params[k]))
      .join('&');
    return request('/api/merchant/staff/platform/finance/summary' + (qs ? '?' + qs : ''));
  },
  merchantStaffTodayOrders: () => request('/api/merchant/staff/today/orders'),
  merchantStaffTodayBills: () => request('/api/merchant/staff/today/bills'),
  merchantStaffTodayBookings: () => request('/api/merchant/staff/today/bookings'),
  // 核销记录：商家端首页「核销记录」入口的数据源。
  // 之前那个入口点进去调的是 today/bills（买单流水），核销和买单是两码事；
  // verify 页里的「最近核销」只存本机 storage，换台手机就没了。
  // params: { date:'yyyy-MM-dd', mine:1 只看自己核的, storeId 指定门店 }
  merchantStaffVerifyRecords: (params) => {
    const p = params || {}
    const qs = Object.keys(p)
      .filter((k) => p[k] !== undefined && p[k] !== null && p[k] !== '')
      .map((k) => k + '=' + encodeURIComponent(p[k]))
      .join('&')
    return request('/api/merchant/staff/verify/records' + (qs ? '?' + qs : ''))
  },
  merchantStaffBookingSignupList: () => request('/api/merchant/staff/booking/signup/list'),
  merchantStaffBookingConfirm: (signupId, body) => request('/api/merchant/staff/booking/confirm/' + signupId, { method: 'POST', data: body || {} }),
  merchantStaffBookingReject:  (signupId, body) => request('/api/merchant/staff/booking/reject/'  + signupId, { method: 'POST', data: body || {} }),
  // 商家端店员管理（OWNER/MANAGER）：店里就地招人/审核/重置密码，不必回 PC 后台
  merchantStaffTeamList: (status) => request('/api/merchant/staff/staff/list' + (status ? '?status=' + encodeURIComponent(status) : '')),
  merchantStaffAuditList: () => request('/api/merchant/staff/staff/audit/list'),
  merchantStaffAudit: (id, approve) => request('/api/merchant/staff/staff/audit', { method: 'POST', data: { id, approve } }),
  merchantStaffInviteCreate: (data) => request('/api/merchant/staff/staff/invite', { method: 'POST', data: data || {} }),
  merchantStaffInviteList: () => request('/api/merchant/staff/staff/invite/list'),
  merchantStaffResetPwd: (userId) => request('/api/merchant/staff/staff/resetPwd', { method: 'POST', data: { userId } }),
  merchantStaffDismiss: (id) => request('/api/merchant/staff/staff/dismiss', { method: 'POST', data: { id } }),
  merchantStaffRestore: (id) => request('/api/merchant/staff/staff/restore', { method: 'POST', data: { id } }),
  // 海报页画图用：已有小程序码则复用，不重复烧微信 wxacode 配额
  merchantStaffInviteQrcode: (inviteId) => request('/api/merchant/staff/staff/invite/qrcode/' + inviteId),
  // 预约
  bookingSlots: (params) => request('/api/booking/slots', { data: params }),
  // 可预约日期：天数取门店「可提前预约天数」，歇业日会标 closed。
  // 原先前端 getNextDays(7) 写死 7 天，运营调不了也排不掉歇业日。
  bookingDays: (params) => request('/api/booking/days', { data: params }),
  // 可选预约类型：后台「字典管理 → 预约类型」维护，前端不再写死「堂食预约」
  bookingTypes: () => request('/api/booking/types'),
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
  BASE_URL: BASE_URL_DEFAULT,
  APPID,
  toFullUrl,
  fixRichText,
  pickHasStaffAccount,
  mockEnabled: MOCK_ENABLED
};
