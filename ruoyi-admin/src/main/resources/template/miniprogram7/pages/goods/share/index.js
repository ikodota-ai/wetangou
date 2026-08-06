const { api, toFullUrl } = require('../../../utils/request.js');
Page({
  data: { product: null, loading: true },
  onLoad(opts) {
    this.loadProduct(opts.id);
  },
  loadProduct(id) {
    if (!id) {
      this.setData({ loading: false });
      return;
    }
    api.productDetail(id).then((res) => {
      const d = (res && res.data) || res || null;
      const p = (d && (d.data || d)) || null;
      if (p && p.productId) {
        this.setData({
          product: {
            name: p.productName || p.name,
            price: p.price != null ? String(p.price) : '0.00',
            cover: p.cover ? toFullUrl(p.cover) : '/assets/img/RestaurantImg.png'
          },
          loading: false
        });
      } else {
        this.setData({ loading: false });
      }
    }).catch(() => this.setData({ loading: false }));
  }
});
