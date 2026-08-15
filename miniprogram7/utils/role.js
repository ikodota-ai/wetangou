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
function isManagerOrAbove() { return isOwner() || isManager() || isPlatform(); }
function isOwnerOnly()      { return isOwner() && !isPlatform(); } // 纯商家 owner（平台超管不算）

/** 商家端：OWNER/MANAGER/STAFF 任一都算商家端登录（含平台超管） */
function isMerchantSide() { return isOwner() || isManager() || isStaff(); }

module.exports = {
  BizRole, UserType,
  getMember, getRoles, getUserType,
  isPlatform, isAgent, isOwner, isManager, isStaff,
  isManagerOrAbove, isOwnerOnly, isMerchantSide
};
