/**
 * 商品图片的口径（会员端详情页 + 商家端预览 + 各列表 共用）。
 *
 * 两个字段的真实语义（以 PC 建品页为准，不是列名字面意思）：
 *   biz_product.cover  → 「商品头图」，image-upload :limit=5（代金券 1）
 *                        即详情页顶部可翻动的那组图。这是一个
 *                        【逗号串】，不是单张 URL。
 *   biz_product.images → 「环境图」，image-upload :limit=10
 *                        属于商品内容（店内环境/菜品实拍），属于图文详情。
 *
 * 为什么要抽这个文件：列名 cover 看着像单张封面（comment 就写着
 * 「封面图」），于是全仓 20+ 处直接把它塞进 <image src>：
 * 商品列表、订单列表、下单页、分享封面、海报。商家只要传了
 * 第二张头图，src 就变成 "urlA,urlB"，所有这些位置全部变白图。
 * 本地库当下 cover 含逗号的是 0 条，所以还没爆 —— 它是定时炸弹，
 * 而不是已发生故障。口径只能有一份，否则每处各自 toFullUrl 早晚漂。
 */

/** 逗号串 / 数组 / 空值 → 干净的 URL 数组。与 PC detail.vue 的 splitUrls 同口径。 */
function splitUrls(raw) {
  if (!raw) return [];
  var arr = Array.isArray(raw) ? raw : String(raw).split(',');
  return arr.map(function (u) { return String(u).trim(); }).filter(function (u) { return !!u; });
}

/**
 * 头图首张。列表页 / 订单 / 分享封面 / 海报 这类只能放一张图的位置用它。
 * 拿不到头图时回落到环境图首张 —— 这比直接上占位图强：
 * 老商品（本地 1001/1002）就是只有其中一个字段有值。
 */
function firstCover(product) {
  var p = product || {};
  var c = splitUrls(p.cover);
  if (c.length) return c[0];
  var i = splitUrls(p.images);
  return i.length ? i[0] : '';
}

/**
 * 顶部轮播图（可翻动那组）= 商品头图全部。
 *
 * 原先这里用的是 images（环境图），cover 只当 images 为空时的兑底，
 * 正好把两个字段的职责说反了：商家在「商品头图」传的 5 张一张也上不了顶，
 * 而「环境图」（店内实拍）却被当主图轮播。本地 10 条商品都是
 * cover 与 images 首张相同，所以胮眼看不出差别 —— 一旦商家真按
 * PC 页提示分开传，顶部展示的就不是他选的主图。
 * 回落顺序保留 images：老数据里真有只填了 images 的。
 */
function heroImages(product) {
  var p = product || {};
  var c = splitUrls(p.cover);
  if (c.length) return c;
  return splitUrls(p.images);
}

/**
 * 环境图（图文详情里那组竖排大图）。
 * 头图已经在顶部轮播展过，要把与头图重复的剔掉，
 * 否则本地这批商品（cover 与 images 首张相同）会在一屏内
 * 把同一张图给顾客看两遍。
 */
function contentImages(product) {
  var p = product || {};
  // 必须拿 heroImages 的结果去重，不能只拿 p.cover：
  // 无 cover 的老商品（本地 1001/1002）heroImages 会回落到 images，
  // 此时只比 cover 等于一条也没剔，同一批图会在顶部轮播和
  // 图文详情里各展一遍。（这一条是单测拓出来的。）
  var hero = {};
  heroImages(p).forEach(function (u) { hero[u] = 1; });
  return splitUrls(p.images).filter(function (u) { return !hero[u]; });
}

module.exports = {
  splitUrls: splitUrls,
  firstCover: firstCover,
  heroImages: heroImages,
  contentImages: contentImages
};
