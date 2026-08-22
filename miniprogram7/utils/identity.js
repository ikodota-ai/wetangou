/**
 * 双身份（会员版 / 商家版）切换工具
 *
 * 背景：一个微信可能同时是「会员」和「商家员工」，但这是**两套账号两套 token**：
 *   - 会员：biz_member（openid + merchant_id 隔离），token 由 /api/login 签发
 *   - 员工：sys_user.openid + biz_merchant_staff，token 由 /api/merchant/staff/* 签发
 * openid 是两者之间唯一的桥。所以「切换身份」本质是**换 token**，不是同一 token 换权限。
 *
 * 设计要点：
 * 1) 两个 token 各自常驻（memberToken / staffToken），切换只是改 current 指向，
 *    不再像老代码那样切回会员就 removeStorageSync('staffUser')——那会导致下次又要重新登录。
 * 2) 会员 → 商家走静默免密：wx.login() 拿 code 不弹任何授权框
 *    （只有 wx.getUserProfile 才需要用户点确认），后端按 openid 命中员工直接签发 staff token。
 * 3) 后端返 code=600 NOT_BOUND 表示该微信没绑员工，此时才需要引导去账号密码登录。
 */

const KEY_MEMBER_TOKEN = 'memberToken'
const KEY_STAFF_TOKEN = 'staffToken'
const KEY_CURRENT = 'currentIdentity'   // 'member' | 'staff'
const KEY_STAFF_USER = 'staffUser'

function safeGet(key, dft) {
  try { return wx.getStorageSync(key) || dft } catch (e) { return dft }
}
function safeSet(key, val) {
  try { wx.setStorageSync(key, val) } catch (e) {}
}
function safeDel(key) {
  try { wx.removeStorageSync(key) } catch (e) {}
}

/** 记录会员 token（会员登录成功时调）*/
function saveMemberToken(token) {
  if (!token) return
  safeSet(KEY_MEMBER_TOKEN, token)
  safeSet('token', token)
  safeSet(KEY_CURRENT, 'member')
}

/** 记录员工 token + 身份信息（商家登录/切换成功时调）*/
function saveStaffSession(token, staffUser) {
  if (!token) return
  safeSet(KEY_STAFF_TOKEN, token)
  safeSet('token', token)
  safeSet(KEY_CURRENT, 'staff')
  if (staffUser) safeSet(KEY_STAFF_USER, staffUser)
}

/** 当前处于哪个身份 */
function current() {
  return safeGet(KEY_CURRENT, 'member')
}

/** 是否有可用的商家身份（本地已缓存 staff token）*/
function hasStaffSession() {
  return !!safeGet(KEY_STAFF_TOKEN, '')
}

/** 是否有可用的会员身份 */
function hasMemberSession() {
  return !!safeGet(KEY_MEMBER_TOKEN, '')
}

/** 取已缓存的员工身份信息 */
function staffUser() {
  return safeGet(KEY_STAFF_USER, null)
}

/**
 * 切到商家版。
 *
 * 优先用本地已缓存的 staff token（零请求）；没有则静默 wx.login 换 openid 免密登录。
 *
 * @param {object} opts { api, appid, silent } silent=true 时不弹 loading/toast
 * @returns {Promise<{ok:boolean, reason?:string, userType?:string}>}
 *          reason='NOT_BOUND' 表示该微信未绑员工，调用方应引导去账号密码登录
 */
function switchToStaff(opts) {
  const o = opts || {}
  const api = o.api
  const silent = !!o.silent

  // 1) 本地已有 staff token：直接切，不发请求
  const cached = safeGet(KEY_STAFF_TOKEN, '')
  if (cached) {
    safeSet('token', cached)
    safeSet(KEY_CURRENT, 'staff')
    const su = staffUser() || {}
    return Promise.resolve({ ok: true, userType: su.userType })
  }

  if (!api || !api.merchantStaffWxLogin) {
    return Promise.resolve({ ok: false, reason: 'NO_API' })
  }

  // 2) 静默 wx.login 拿 code（不弹授权框）→ 后端按 openid 命中员工
  return new Promise((resolve) => {
    wx.login({
      success: (lr) => {
        if (!lr || !lr.code) {
          resolve({ ok: false, reason: 'WX_LOGIN_FAIL' })
          return
        }
        if (!silent) wx.showLoading({ title: '切换中', mask: true })
        api.merchantStaffWxLogin({ code: lr.code, appid: o.appid })
          .then((data) => {
            if (!silent) wx.hideLoading()
            const d = data || {}
            const token = d.token || (d.data && d.data.token)
            if (!token) {
              resolve({ ok: false, reason: 'NO_TOKEN' })
              return
            }
            // 备份当前会员 token，切回来时要用
            const cur = safeGet('token', '')
            if (cur && current() === 'member') safeSet(KEY_MEMBER_TOKEN, cur)
            saveStaffSession(token, {
              token: token,
              userId: d.userId || d.memberId,
              userType: d.userType,
              staffRole: d.staffRole,
              roles: d.roles || [],
              isOwner: !!d.isOwner,
              isManagerOrAbove: !!d.isManagerOrAbove,
              isAgent: !!d.isAgent,
              merchantId: d.merchantId,
              storeId: d.storeId,
              storeIds: d.storeIds || [],
              storeName: d.storeName,
              realName: d.realName || d.nickName,
              avatarUrl: d.avatarUrl,
              logged: true
            })
            resolve({ ok: true, userType: d.userType })
          })
          .catch((err) => {
            if (!silent) wx.hideLoading()
            // 后端约定 code=600 / msg=NOT_BOUND：该微信没绑员工账号
            const code = err && (err.code || (err.data && err.data.code))
            const msg = (err && (err.msg || err.message)) || ''
            const notBound = code === 600 || msg.indexOf('NOT_BOUND') > -1 || msg.indexOf('未关联商家') > -1
            // 后端约定 code=601：员工关联存在但处于待审核（status=3），需店长后台通过
            const pending = code === 601 || msg.indexOf('待店长审核') > -1
            if (pending) { resolve({ ok: false, reason: 'PENDING_AUDIT' }); return }
            resolve({ ok: false, reason: notBound ? 'NOT_BOUND' : (msg || 'FAIL') })
          })
      },
      fail: () => resolve({ ok: false, reason: 'WX_LOGIN_FAIL' })
    })
  })
}

/**
 * 切回会员版。
 *
 * 保留 staff token（不删 staffUser），这样下次切过去还是零请求。
 * @returns {{ok:boolean, reason?:string}}
 */
function switchToMember() {
  const memberToken = safeGet(KEY_MEMBER_TOKEN, '')
  if (!memberToken) {
    return { ok: false, reason: 'NO_MEMBER_SESSION' }
  }
  safeSet('token', memberToken)
  safeSet(KEY_CURRENT, 'member')
  return { ok: true }
}

/** 退出登录：两套身份一起清 */
function clearAll() {
  safeDel(KEY_MEMBER_TOKEN)
  safeDel(KEY_STAFF_TOKEN)
  safeDel(KEY_CURRENT)
  safeDel(KEY_STAFF_USER)
  safeDel('token')
  safeDel('memberTokenBackup')
}

/** 只退出商家身份（保留会员登录态）*/
function clearStaff() {
  safeDel(KEY_STAFF_TOKEN)
  safeDel(KEY_STAFF_USER)
  const memberToken = safeGet(KEY_MEMBER_TOKEN, '')
  if (memberToken) {
    safeSet('token', memberToken)
    safeSet(KEY_CURRENT, 'member')
  } else {
    safeDel('token')
    safeDel(KEY_CURRENT)
  }
}

module.exports = {
  saveMemberToken,
  saveStaffSession,
  current,
  hasStaffSession,
  hasMemberSession,
  staffUser,
  switchToStaff,
  switchToMember,
  clearAll,
  clearStaff,
  KEY_MEMBER_TOKEN,
  KEY_STAFF_TOKEN,
  KEY_CURRENT,
  KEY_STAFF_USER
}
