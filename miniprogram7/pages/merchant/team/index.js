// pages/merchant/team/index.js 商家端店员管理（OWNER / MANAGER）
//
// 为什么要这个页：招店员的四个动作此前只有 PC 后台有。店长的实际工作场景在店里、
// 手上只有手机 —— 新人站柜台前扫码入职，店长得跑去开电脑登后台才能点通过，
// 真实门店没人会走这个流程。
//
// 权限在后端 @RequireRole(OWNER, MANAGER) 卡死；前端只负责不把入口显示给店员。
const { api, toFullUrl } = require('../../../utils/request.js')

const ROLE_LABEL = { OWNER: '老板', MANAGER: '店长', STAFF: '店员' }
const STATUS_LABEL = { '0': '在职', '1': '离职', '3': '待审核' }

// 后端只允许邀请 MANAGER / STAFF（不能邀请 OWNER，否则可自我提权）；
// 且店长只能邀请店员 —— 与后端 canManageRole 的 rank 严格大于保持一致。
function assignableRoles(myRole) {
  return myRole === 'OWNER'
    ? [{ code: 'STAFF', label: '店员' }, { code: 'MANAGER', label: '店长' }]
    : [{ code: 'STAFF', label: '店员' }]
}

Page({
  data: {
    loading: true,
    myRole: '',
    tab: 'audit',            // audit 待审核 / team 员工 / invite 邀请码
    auditList: [],
    teamList: [],
    inviteList: [],
    roleOptions: [],
    // 邀请码弹窗
    invitePanel: false,
    inviteRole: 'STAFF',
    inviteResult: null,
    submitting: false
  },

  onLoad() {
    this._loadMe()
  },

  onShow() {
    // 从扫码页/审核回来要刷新，否则待审核数量对不上
    if (this.data.myRole) this._reload()
  },

  onPullDownRefresh() {
    this._reload().finally(() => wx.stopPullDownRefresh())
  },

  _loadMe() {
    return api.merchantStaffMe()
      .then((d) => {
        const me = d || {}
        const myRole = me.role || ''
        if (myRole !== 'OWNER' && myRole !== 'MANAGER') {
          // 店员误入（比如从历史页面栈返回）：明确告知而不是留个空白页
          this.setData({ loading: false, myRole })
          wx.showModal({
            title: '无权访问',
            content: '店员管理仅店长与老板可用',
            showCancel: false,
            success: () => wx.navigateBack()
          })
          return
        }
        this.setData({ myRole, roleOptions: assignableRoles(myRole) })
        return this._reload()
      })
      .catch((err) => {
        this.setData({ loading: false })
        this._toastErr(err, '加载失败')
      })
  },

  _reload() {
    this.setData({ loading: true })
    return Promise.all([
      api.merchantStaffAuditList().catch(() => []),
      api.merchantStaffTeamList().catch(() => []),
      api.merchantStaffInviteList().catch(() => [])
    ]).then(([audit, team, invites]) => {
      this.setData({
        loading: false,
        auditList: this._decorate(audit),
        // 待审核的人已经单列在审核 tab，员工名单里不再重复
        teamList: this._decorate(team).filter(x => x.status !== '3'),
        inviteList: this._decorateInvites(invites)
      })
    })
  },

  _decorate(list) {
    return (list || []).map((x) => Object.assign({}, x, {
      roleLabel: ROLE_LABEL[x.role] || x.role || '店员',
      statusLabel: STATUS_LABEL[x.status] || x.status,
      displayName: x.realName || x.nickName || x.userName || ('员工' + (x.userId || '')),
      // 店长不能操作另一个店长/老板，按钮直接不给（后端也会拒）
      canOperate: this._canOperate(x.role)
    }))
  },

  _decorateInvites(list) {
    const now = Date.now()
    return (list || []).map((x) => {
      const expired = x.expireAt ? (new Date(String(x.expireAt).replace(/-/g, '/')).getTime() < now) : false
      return Object.assign({}, x, {
        roleLabel: ROLE_LABEL[x.role] || x.role || '店员',
        wxacodeFull: x.wxacodeUrl ? toFullUrl(x.wxacodeUrl) : '',
        // status: 0 未使用 / 1 已使用 / 2 已过期
        stateLabel: x.status === '1' ? '已使用' : (x.status === '2' || expired ? '已失效' : '待扫码')
      })
    })
  },

  _canOperate(targetRole) {
    const rank = { OWNER: 3, MANAGER: 2, STAFF: 1 }
    return (rank[this.data.myRole] || 0) > (rank[targetRole] || 0)
  },

  switchTab(e) {
    this.setData({ tab: e.currentTarget.dataset.tab })
  },

  // ---- 审核 ----
  onApprove(e) {
    this._audit(e.currentTarget.dataset.id, true, '通过入职申请？')
  },

  onReject(e) {
    this._audit(e.currentTarget.dataset.id, false, '拒绝后该申请会被删除，需重新扫码入职')
  },

  _audit(id, approve, tip) {
    if (!id || this.data.submitting) return
    wx.showModal({
      title: approve ? '确认通过' : '确认拒绝',
      content: tip,
      success: (r) => {
        if (!r.confirm) return
        this.setData({ submitting: true })
        api.merchantStaffAudit(id, approve)
          .then(() => {
            wx.showToast({ title: approve ? '已通过' : '已拒绝', icon: 'success' })
            return this._reload()
          })
          .catch((err) => this._toastErr(err, '操作失败'))
          .finally(() => this.setData({ submitting: false }))
      }
    })
  },

  // ---- 邀请码 ----
  openInvite() {
    this.setData({ invitePanel: true, inviteResult: null, inviteRole: 'STAFF' })
  },

  closeInvite() {
    this.setData({ invitePanel: false })
    // 关闭时刷新邀请码列表，让刚发的码出现在列表里
    if (this.data.inviteResult) this._reload()
  },

  pickInviteRole(e) {
    this.setData({ inviteRole: e.currentTarget.dataset.role })
  },

  onCreateInvite() {
    if (this.data.submitting) return
    this.setData({ submitting: true })
    api.merchantStaffInviteCreate({ role: this.data.inviteRole })
      .then((res) => {
        const d = (res && res.data) || res || {}
        this.setData({
          inviteResult: {
            inviteId: d.inviteId || '',
            inviteCode: d.inviteCode || '',
            role: d.role || 'STAFF',
            roleLabel: ROLE_LABEL[d.role] || '店员',
            wxacodeFull: d.wxacodeUrl ? toFullUrl(d.wxacodeUrl) : '',
            expireAt: d.expireAt || ''
          }
        })
      })
      .catch((err) => this._toastErr(err, '生成失败'))
      .finally(() => this.setData({ submitting: false }))
  },

  copyCode(e) {
    const code = e.currentTarget.dataset.code || (this.data.inviteResult && this.data.inviteResult.inviteCode)
    if (!code) return
    wx.setClipboardData({ data: code })
  },

  /**
   * 去海报页：把邀请码画成可保存到相册的图，店长发微信给远程候选人。
   * 带上 role 让海报写对被邀请人的职位（海报页自己也会用接口返回的 role 兜底）。
   */
  goPoster(e) {
    const inviteId = e.currentTarget.dataset.id
    const role = e.currentTarget.dataset.role || ''
    if (!inviteId) {
      wx.showToast({ title: '缺少邀请码ID', icon: 'none' })
      return
    }
    wx.navigateTo({ url: '/pages/merchant/poster-invite/index?inviteId=' + inviteId + '&role=' + role })
  },

  previewQrcode(e) {
    const url = e.currentTarget.dataset.url
    if (!url) {
      wx.showToast({ title: '该码没有图片，可口述 6 位短码', icon: 'none' })
      return
    }
    wx.previewImage({ urls: [url], current: url })
  },

  // ---- 员工操作 ----
  onResetPwd(e) {
    const userId = e.currentTarget.dataset.userid
    const name = e.currentTarget.dataset.name || '该员工'
    if (!userId || this.data.submitting) return
    wx.showModal({
      title: '重置密码',
      content: '为「' + name + '」生成新密码？新密码只显示一次，请当场记录。',
      success: (r) => {
        if (!r.confirm) return
        this.setData({ submitting: true })
        api.merchantStaffResetPwd(userId)
          .then((res) => {
            const d = (res && res.data) || res || {}
            wx.showModal({
              title: '新密码',
              content: '账号：' + (d.userName || '-') + '\n密码：' + (d.newPassword || '-')
                + '\n\n关闭后无法再次查看，请立即告知员工。',
              confirmText: '复制密码',
              success: (rr) => {
                if (rr.confirm && d.newPassword) wx.setClipboardData({ data: d.newPassword })
              }
            })
          })
          .catch((err) => this._toastErr(err, '重置失败'))
          .finally(() => this.setData({ submitting: false }))
      }
    })
  },

  onDismiss(e) {
    const id = e.currentTarget.dataset.id
    const name = e.currentTarget.dataset.name || '该员工'
    if (!id || this.data.submitting) return
    wx.showModal({
      title: '办理离职',
      content: '「' + name + '」离职后将无法登录商家版，历史核销记录保留。',
      success: (r) => {
        if (!r.confirm) return
        this.setData({ submitting: true })
        api.merchantStaffDismiss(id)
          .then(() => {
            wx.showToast({ title: '已办理离职', icon: 'success' })
            return this._reload()
          })
          .catch((err) => this._toastErr(err, '操作失败'))
          .finally(() => this.setData({ submitting: false }))
      }
    })
  },

  onRestore(e) {
    const id = e.currentTarget.dataset.id
    if (!id || this.data.submitting) return
    this.setData({ submitting: true })
    api.merchantStaffRestore(id)
      .then(() => {
        wx.showToast({ title: '已复职', icon: 'success' })
        return this._reload()
      })
      .catch((err) => this._toastErr(err, '操作失败'))
      .finally(() => this.setData({ submitting: false }))
  },

  _toastErr(err, fallback) {
    const msg = (err && (err.msg || err.message)) || fallback
    wx.showToast({ title: msg, icon: 'none' })
  }
})
