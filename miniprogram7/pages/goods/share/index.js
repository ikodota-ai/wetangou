// pages/goods/share/index.js 商品分享海报页
const app = getApp();
const { api, toFullUrl } = require('../../../utils/request.js');

/**
 * 海报布局（单位 px, 600 宽 x 900 高, 适配 type="2d" canvas）：
 *
 *   [0,  0] - [600, 480]  商品图（aspectFill 居中裁剪）
 *   [0,480] - [600,560]   商家名（小灰字 + 顶部装饰条）
 *   [0,560] - [600,720]   商品名 + 价格
 *   [0,720] - [600,900]   白色背景：左侧文案"长按识别 / 扫码购买"、右侧小程序码
 *
 * 因为不一定所有商户都配了小程序 appid + 太阳码，所以小程序码区域做兼容：
 *   - 走推客邀请接口能拿到 → 用真太阳码
 *   - 拿不到 → 退化为右下角画一个简化的"二维码占位 + 文字"（不再兜底 mock，仍提示「太阳码生成失败」）
 */
const POSTER_W = 600;
const POSTER_H = 900;

Page({
  data: {
    generating: true,
    savedPath: ''
  },

  onLoad(opts) {
    this.productId = opts && opts.id;
    if (!this.productId) {
      wx.showToast({ title: '商品ID缺失', icon: 'none' });
      setTimeout(() => wx.navigateBack(), 800);
      return;
    }
    this._loadProduct();
  },

  onUnload() {
    // 清理 canvas 引用
    if (this._canvas) {
      try { this._canvas = null; } catch (e) {}
    }
  },

  _loadProduct() {
    this.setData({ generating: true });
    api.productDetail(this.productId)
      .then((res) => {
        const d = (res && res.data) || res || null;
        const p = (d && (d.data || d)) || null;
        if (!p || !p.productId) {
          this.setData({ generating: false });
          wx.showToast({ title: '商品不存在', icon: 'none' });
          return;
        }
        this.product = {
          name: p.productName || p.name || '好物',
          price: p.price != null ? String(p.price) : '0.00',
          marketPrice: p.marketPrice != null ? String(p.marketPrice) : '',
          cover: p.cover ? toFullUrl(p.cover) : '',
          images: Array.isArray(p.images) ? p.images : (p.cover ? [p.cover] : []),
          coverAbs: p.cover ? toFullUrl(p.cover) : ''
        };
        this.merchant = (app.globalData && app.globalData.merchant) || {};
        return this._loadQrcode();
      })
      .catch((err) => {
        console.error('[share] loadProduct FAIL', err);
        this.setData({ generating: false });
        wx.showToast({ title: '商品加载失败', icon: 'none' });
      });
  },

  /**
   * 调推客接口拿太阳码；若非推客或接口失败，qrcode 留空（海报右下角会显示「太阳码生成失败」）
   */
  _loadQrcode() {
    return api.promoterQrcode()
      .then((res) => {
        const url = (res && (res.url || (res.data && res.data.url))) || '';
        if (url) this.qrcodeUrl = toFullUrl(url);
      })
      .catch((err) => {
        console.warn('[share] promoterQrcode FAIL', err);
        this.qrcodeUrl = '';
      })
      .finally(() => this._render());
  },

  /**
   * 核心：拉商品图（downloadFile wxacode）→ canvas 2d 绘制 → 导出图片到临时文件
   * 真机调试时如果图或码下载失败，会在对应区域画错误占位，不再静默兜底 mock
   */
  _render() {
    const tasks = [];
    // 1) 商品图
    if (this.product && this.product.coverAbs) {
      tasks.push(this._downloadImage(this.product.coverAbs).then((path) => { this._coverPath = path; }).catch((e) => {
        console.warn('[share] cover download FAIL', e);
        this._coverPath = '';
      }));
    } else {
      this._coverPath = '';
    }
    // 2) 太阳码
    if (this.qrcodeUrl) {
      tasks.push(this._downloadImage(this.qrcodeUrl).then((path) => { this._qrPath = path; }).catch((e) => {
        console.warn('[share] qrcode download FAIL', e);
        this._qrPath = '';
      }));
    } else {
      this._qrPath = '';
    }

    Promise.all(tasks).finally(() => this._draw());
  },

  _downloadImage(url) {
    return new Promise((resolve, reject) => {
      if (!url) return reject(new Error('empty url'));
      wx.downloadFile({
        url,
        success: (res) => {
          if (res.statusCode === 200 && res.tempFilePath) resolve(res.tempFilePath);
          else reject(new Error('http ' + res.statusCode));
        },
        fail: (err) => reject(err)
      });
    });
  },

  _draw() {
    const query = wx.createSelectorQuery().in(this);
    query.select('#posterCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          console.error('[share] canvas node not ready');
          this.setData({ generating: false });
          wx.showToast({ title: '海报画布未就绪', icon: 'none' });
          return;
        }
        const canvas = res[0].node;
        const ctx = canvas.getContext('2d');
        const dpr = wx.getSystemInfoSync().pixelRatio || 2;
        canvas.width = POSTER_W * dpr;
        canvas.height = POSTER_H * dpr;
        ctx.scale(dpr, dpr);
        this._canvas = canvas;
        this._ctx = ctx;

        // 背景
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, POSTER_W, POSTER_H);

        // 商品图区域 [0, 0] - [600, 480]
        this._drawCover(ctx, 0, 0, 600, 480, this._coverPath);

        // 顶部装饰条 [480-560]
        ctx.fillStyle = '#F2F2F7';
        ctx.fillRect(0, 480, 600, 80);
        ctx.fillStyle = '#666';
        ctx.font = '24px sans-serif';
        ctx.textBaseline = 'middle';
        ctx.fillText('— ' + (this.merchant.merchantName || '洞天团购') + ' —', 30, 520);

        // 商品名 + 价格 [560-720]
        ctx.fillStyle = '#1A1A1A';
        ctx.font = 'bold 34px sans-serif';
        const name = this._clipText(ctx, this.product.name, 540);
        ctx.fillText(name, 30, 600);
        if (this.product.name.length > 14) {
          ctx.fillText(this._clipText(ctx, this.product.name.slice(14), 540), 30, 640);
        }
        ctx.fillStyle = '#E74C3C';
        ctx.font = 'bold 56px sans-serif';
        ctx.fillText('¥' + this.product.price, 30, 700);
        if (this.product.marketPrice && this.product.marketPrice !== this.product.price) {
          ctx.fillStyle = '#999';
          ctx.font = '26px sans-serif';
          const oldW = ctx.measureText('¥' + this.product.marketPrice).width;
          ctx.fillText('¥' + this.product.marketPrice, 240, 700);
          // 删除线
          ctx.beginPath();
          ctx.moveTo(240, 690);
          ctx.lineTo(240 + oldW, 690);
          ctx.strokeStyle = '#999';
          ctx.lineWidth = 2;
          ctx.stroke();
        }

        // 底部二维码区 [720-900]
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 720, 600, 180);
        ctx.fillStyle = '#1A1A1A';
        ctx.font = 'bold 28px sans-serif';
        ctx.textBaseline = 'alphabetic';
        ctx.fillText('长按识别小程序', 30, 780);
        ctx.fillStyle = '#666';
        ctx.font = '22px sans-serif';
        ctx.fillText('扫码 / 点击即可下单', 30, 820);

        // 右侧太阳码
        if (this._qrPath) {
          // 圆形裁剪画太阳码
          ctx.save();
          ctx.beginPath();
          ctx.arc(510, 810, 60, 0, Math.PI * 2);
          ctx.closePath();
          ctx.clip();
          ctx.drawImage(this._qrPath, 450, 750, 120, 120);
          ctx.restore();
          // 圆描边
          ctx.beginPath();
          ctx.arc(510, 810, 60, 0, Math.PI * 2);
          ctx.strokeStyle = '#3A6B35';
          ctx.lineWidth = 3;
          ctx.stroke();
        } else {
          // 没有太阳码：画个圆 + 提示
          ctx.beginPath();
          ctx.arc(510, 810, 60, 0, Math.PI * 2);
          ctx.strokeStyle = '#E5E5EA';
          ctx.lineWidth = 3;
          ctx.stroke();
          ctx.fillStyle = '#999';
          ctx.font = '18px sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText('太阳码', 510, 815);
          ctx.textAlign = 'left';
        }

        // 底部签名
        ctx.fillStyle = '#BBB';
        ctx.font = '20px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('洞天团购 · ' + (this.merchant.merchantName || ''), 300, 880);
        ctx.textAlign = 'left';

        this.setData({ generating: false });
      });
  },

  _drawCover(ctx, x, y, w, h, imgPath) {
    if (!imgPath) {
      ctx.fillStyle = '#E5E5EA';
      ctx.fillRect(x, y, w, h);
      ctx.fillStyle = '#999';
      ctx.font = '28px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('商品图', x + w / 2, y + h / 2);
      ctx.textAlign = 'left';
      return;
    }
    // 居中裁剪：先按比例 fit 再居中
    try {
      const img = this._canvas.createImage();
      img.onload = () => {
        const iw = img.width, ih = img.height;
        const scale = Math.max(w / iw, h / ih);
        const dw = iw * scale, dh = ih * scale;
        const dx = x + (w - dw) / 2;
        const dy = y + (h - dh) / 2;
        ctx.save();
        ctx.beginPath();
        ctx.rect(x, y, w, h);
        ctx.clip();
        ctx.drawImage(img, dx, dy, dw, dh);
        ctx.restore();
      };
      img.onerror = (e) => {
        console.warn('[share] cover img.onerror', e);
        ctx.fillStyle = '#E5E5EA';
        ctx.fillRect(x, y, w, h);
        ctx.fillStyle = '#999';
        ctx.font = '28px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('商品图加载失败', x + w / 2, y + h / 2);
        ctx.textAlign = 'left';
      };
      img.src = imgPath;
    } catch (e) {
      console.error('[share] cover draw FAIL', e);
      ctx.fillStyle = '#E5E5EA';
      ctx.fillRect(x, y, w, h);
    }
  },

  _clipText(ctx, text, maxWidth) {
    if (!text) return '';
    let t = String(text);
    if (ctx.measureText(t).width <= maxWidth) return t;
    while (t.length > 0 && ctx.measureText(t + '...').width > maxWidth) {
      t = t.slice(0, -1);
    }
    return t + '...';
  },

  /**
   * 导出 canvas 到临时文件
   * 真机 type="2d" 走 canvasToTempFilePath（注意需传 this._canvas 而不是 old canvas id）
   */
  _exportToFile() {
    return new Promise((resolve, reject) => {
      if (!this._canvas) return reject(new Error('canvas not ready'));
      wx.canvasToTempFilePath({
        canvas: this._canvas,
        fileType: 'png',
        quality: 1,
        success: (res) => {
          if (res && res.tempFilePath) resolve(res.tempFilePath);
          else reject(new Error('no tempFilePath'));
        },
        fail: (err) => reject(err)
      }, this);
    });
  },

  onPreview() {
    this._exportToFile().then((path) => {
      wx.previewImage({ urls: [path], current: path });
    }).catch((err) => {
      console.error('[share] preview FAIL', err);
      wx.showToast({ title: '预览失败', icon: 'none' });
    });
  },

  onSave() {
    if (this.data.generating) {
      wx.showToast({ title: '海报生成中…', icon: 'none' });
      return;
    }
    wx.showLoading({ title: '保存中…' });
    this._exportToFile()
      .then((path) => {
        this.setData({ savedPath: path });
        return new Promise((resolve, reject) => {
          wx.saveImageToPhotosAlbum({
            filePath: path,
            success: () => resolve(),
            fail: (err) => reject(err)
          });
        });
      })
      .then(() => {
        wx.showToast({ title: '已保存到相册', icon: 'success' });
      })
      .catch((err) => {
        console.error('[share] save FAIL', err);
        if (err && /auth deny|authorize/i.test(err.errMsg || '')) {
          wx.hideLoading();
          wx.showModal({
            title: '需要相册权限',
            content: '保存海报需要您授权访问相册',
            confirmText: '去设置',
            success: (r) => { if (r.confirm) wx.openSetting(); }
          });
        } else {
          wx.showToast({ title: '保存失败', icon: 'none' });
        }
      })
      .finally(() => wx.hideLoading());
  },

  onShareAppMessage() {
    const p = this.product || {};
    const m = this.merchant || {};
    return {
      title: (p.name || '好物') + (p.price ? ' ¥' + p.price : '') + ' | ' + (m.merchantName || '洞天团购'),
      path: '/pages/goods/detail/index?id=' + (p.productId || this.productId)
    };
  }
});
