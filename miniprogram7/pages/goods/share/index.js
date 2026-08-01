const mock = require('../../../utils/mock.js');
Page({
  data: { product: {} },
  onLoad(opts) {
    const id = opts.id;
    const product = mock.goods.find((g) => String(g.productId) === String(id)) || mock.goods[0];
    this.setData({ product });
  }
});
