/**
 * 门店 / 商家 联系方式的降级取值
 *
 * 规则统一是「门店优先、商家兜底」，但四项各自独立降级 ——
 * 不能因为门店填了电话就认为二维码、服务时间也该用门店的（门店往往只填了电话）。
 * 所以下面每个字段单独 pick，不做整体二选一。
 *
 * 另外「拨打电话」和「客服电话」是两条链，别混用：
 *   拨打电话  store.phone        -> merchant.phone
 *              这是门店/商家的对外座机，打过去是店里
 *   客服电话  store.servicePhone -> merchant.servicePhone
 *              这是客服热线，可能是总部 400
 * 之前两者共用一个 data.phone，导致点「拨打电话」实际拨的是客服热线，
 * 门店没配客服热线时还会直接提示「暂无」——明明门店电话是有的。
 */

// 空串、纯空格、null、undefined 都算没填。
// 后端对未填字段的表现不统一：门店返 ''，商家返 null，所以两种都要挡。
function firstFilled() {
  for (var i = 0; i < arguments.length; i++) {
    var v = arguments[i]
    if (v === null || v === undefined) continue
    var t = String(v).trim()
    if (t) return t
  }
  return ''
}

/**
 * @param {Object} store    当前门店（可为空）
 * @param {Object} merchant 当前商家（可为空）
 * @returns {{callPhone,servicePhone,qrcode,serviceHours,isStoreService}}
 */
function resolveContact(store, merchant) {
  var s = store || {}
  var m = merchant || {}

  // 门店电话优先 phone；有些门店只填了 servicePhone 没填 phone，
  // 这时拿 servicePhone 打过去也比提示「暂无」强，所以放在第二顺位。
  var callPhone = firstFilled(s.phone, s.servicePhone, m.phone, m.servicePhone)
  var servicePhone = firstFilled(s.servicePhone, s.phone, m.servicePhone, m.phone)
  var qrcode = firstFilled(s.serviceQrcode, m.serviceQrcode)
  // 服务时间没有门店级时用商家客服时间，再没有才退到商家营业时间 ——
  // 营业时间不等于客服时间，只能垫底不能优先。
  var serviceHours = firstFilled(s.serviceHours, m.serviceHours, m.businessHours)

  return {
    callPhone: callPhone,
    servicePhone: servicePhone,
    qrcode: qrcode,
    serviceHours: serviceHours,
    // 只要客服三项里有任意一项来自门店，弹窗标题就显示「门店客服」。
    // 注意判断的是「门店那一项非空」而不是「最终结果非空」——
    // 后者在降级到商家时也非空，会把商家客服误标成门店客服。
    isStoreService: !!(firstFilled(s.servicePhone) || firstFilled(s.serviceQrcode) || firstFilled(s.serviceHours))
  }
}

module.exports = { resolveContact: resolveContact, firstFilled: firstFilled }
