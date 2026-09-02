// 5 角色工具（v2.5 V5-4/5/6）
// 后端 BizRole: PLATFORM / AGENT / OWNER / MANAGER / STAFF
// 前端 userType: 'platform' / 'agent' / 'owner' / 'manager' / 'staff'
const BizRole = {
  PLATFORM: 'PLATFORM',
  AGENT: 'AGENT',
  OWNER: 'OWNER',
  MANAGER: 'MANAGER',
  STAFF: 'STAFF'
};

const UserType = {
  PLATFORM: 'platform',
  AGENT: 'agent',
  OWNER: 'owner',
  MANAGER: 'manager',
  STAFF: 'staff'
};

/** 从 wx.getStorageSync('member') 或 app.globalData.member 拿 LoginMember */
function getMember() {
  try {
    const app = getApp && getApp();
    if (app && app.globalData && app.globalData.member) return app.globalData.member;
  } catch (e) {}
  try {
    const m = wx.getStorageSync('member');
    if (m) return m;
  } catch (e) {}
  return null;
}

function getRoles() {
  const m = getMember();
  if (!m) return [];
  return m.roles || [];
}

function getUserType() {
  const m = getMember();
  if (!m) return '';
  return m.userType || '';
}

function isPlatform() { return getRoles().indexOf(BizRole.PLATFORM) >= 0; }
function isAgent()    { return getRoles().indexOf(BizRole.AGENT)    >= 0; }
function isOwner()    { return getRoles().indexOf(BizRole.OWNER)    >= 0; }
function isManager()  { return getRoles().indexOf(BizRole.MANAGER)  >= 0; }
function isStaff()    { return getRoles().indexOf(BizRole.STAFF)    >= 0; }
/**
 * 是否店长及以上。
 *
 * <p>必须与后端 LoginMember.isManagerOrAbove() 同口径 ——
 * 后端算的是 hasAnyRole(OWNER, MANAGER)，不含 PLATFORM。
 * 这里原先多算了一个 isPlatform()，比后端宽松：平台账号密码登录商家端是能
 * 拿到 token 的（/api/merchant/staff/login 明确放行「平台/代理商可无员工关联」），
 * 于是它进得了商家端首页，却因为 RoleAuthInterceptor 收口后对整片商家端一律
 * 403，看到的是「建商品 / 到店买单 / 今日流水」三个点进去必然报无权限的入口，
 * 加上首页请求全被 catch 吞掉后渲染成一屏 0 —— 像是功能坏了而不是没权限。
 *
 * <p>PLATFORM 与 OWNER 叠加的账号（运营把自己挂到某商户下）仍然为 true：
 * 那是靠 isOwner() 命中的，走的是真实商家身份，后端也会放行。</p>
 */
function isManagerOrAbove() { return isOwner() || isManager(); }
/**
 * 是否商家端管人角色（老板 / 店长），用于店员管理入口。
 *
 * <p>现在与 isManagerOrAbove() 等价，保留独立命名是因为语义不同：
 * 管人（招聘/审核/重置密码）和看经营数据未必永远同一批角色，
 * 以后加「财务」这类只看数不管人的职务时，这两个会分叉。</p>
 */
function canManageStaff() { return isOwner() || isManager(); }
function isOwnerOnly()      { return isOwner() && !isPlatform(); } // 纯商家 owner（平台超管不算）

/** 商家端：OWNER/MANAGER/STAFF 任一都算商家端登录（含平台超管） */
function isMerchantSide() { return isOwner() || isManager() || isStaff(); }

module.exports = {
  BizRole, UserType,
  getMember, getRoles, getUserType,
  isPlatform, isAgent, isOwner, isManager, isStaff,
  isManagerOrAbove, isOwnerOnly, isMerchantSide, canManageStaff
};
