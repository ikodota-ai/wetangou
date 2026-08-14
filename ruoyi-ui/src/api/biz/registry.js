// 业务 API 自动注册（D2 doc 0.3 天）
// 用 webpack require.context 自动扫描本目录下所有 *.js，
// 提取 list<X> / get<X> 函数注册到 BIZ_API_REGISTRY
// BizSelect 组件通过 BIZ_API_REGISTRY[type] 自动支持新业务类型

// 业务类型与 id/label 字段映射表
const TYPE_META = {
  store:        { idField: 'storeId',        queryField: 'storeName',        label: r => r.storeName || ('门店' + r.storeId) },
  member:       { idField: 'memberId',       queryField: 'nickname',         label: r => (r.nickname || ('会员' + r.memberId)) + (r.phone ? '（' + r.phone + '）' : '') },
  product:      { idField: 'productId',      queryField: 'productName',      label: r => r.productName },
  distributor:  { idField: 'distributorId',  queryField: 'memberId',         label: r => (r.memberName || ('会员' + r.memberId)) + '（推客' + r.distributorId + '）' },
  merchant:     { idField: 'merchantId',     queryField: 'merchantName',     label: r => r.merchantName || ('商户' + r.merchantId) },
  voucher:      { idField: 'voucherId',      queryField: 'voucherName',      label: r => r.voucherName || ('代金券' + r.voucherId) },
  order:        { idField: 'orderId',        queryField: 'orderNo',          label: r => r.orderNo || ('订单' + r.orderId) },
  booking:      { idField: 'bookingId',      queryField: 'bookingNo',        label: r => r.bookingNo || ('预约' + r.bookingId) },
  bill:         { idField: 'billId',         queryField: 'billNo',           label: r => r.billNo || ('买单' + r.billId) },
  commission:   { idField: 'commissionId',   queryField: 'orderId',          label: r => '佣金' + r.commissionId + '（订单' + r.orderId + '）' },
  withdraw:     { idField: 'withdrawId',     queryField: 'withdrawNo',       label: r => r.withdrawNo || ('提现' + r.withdrawId) },
  agreement:    { idField: 'agreementId',    queryField: 'title',            label: r => r.title || ('协议' + r.agreementId) },
  agent:        { idField: 'agentId',        queryField: 'agentName',        label: r => r.agentName || ('代理商' + r.agentId) },
  user:         { idField: 'userId',         queryField: 'userName',         label: r => r.userName || ('用户' + r.userId) }
}

// 用 webpack 提供的 require.context 扫描所有 api 模块
// 路径相对此文件（src/api/biz/），匹配 *.js（不含子目录）
const ctx = require.context('./', false, /^(?!registry).*\.js$/)
const BIZ_API_REGISTRY = {}

ctx.keys().forEach((key) => {
  // key 形如 './store.js'，提取业务类型 'store'
  const type = key.replace(/^\.\//, '').replace(/\.js$/, '')
  const mod = ctx(key)
  const meta = TYPE_META[type] || { idField: type + 'Id', queryField: 'name', label: r => r.name || (type + ' ' + r[type + 'Id']) }
  // 找 listX / getX 函数（驼峰转小写开头）
  const upper = type[0].toUpperCase() + type.slice(1)
  const listFn = mod['list' + upper]
  const getFn = mod['get' + upper]
  if (typeof listFn === 'function' && typeof getFn === 'function') {
    BIZ_API_REGISTRY[type] = {
      api: listFn,
      getById: getFn,
      idField: meta.idField,
      queryField: meta.queryField,
      label: meta.label,
      placeholder: '请选择' + upper
    }
  }
})

export default BIZ_API_REGISTRY
