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
 *   - 过审期间推客已摘除，不再请求太阳码 → 一律走占位分支
 *   - 占位：右下角画一个简化的"二维码占位 + 文字"（不兜底 mock）
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
   * 拉商品小程序码。
   *
   * <p>原先这里调 /api/distributor/qrcode（推客太阳码），但那个端点第一件事
   * 就是 currentDistributor()，不是推客直接抛「您还不是推客」—— 普通会员
   * 分享商品必然拿不到码，海报右下角永远画的是占位圆 + 「太阳码」三个字。
   * 推客摘除后代码把请求整段注释掉了，症状没变（一样是占位）。</p>
   *
   * <p>改走 /api/product/{id}/qrcode：跟身份无关，人人可用，扫码直落商品详情。
   * 返回的是 dataUrl，canvas 的 createImage 能直接吃，不用 downloadFile
   * （downloadFile 受 request 合法域名限制，本地/未备案域名会失败）。</p>
   */
  _loadQrcode() {
    return api.productQrcode(this.productId)
      .then((res) => {
        const d = (res && (res.data || res)) || {};
        this.qrcodeUrl = d.dataUrl || (d.url ? toFullUrl(d.url) : '');
      })
      .catch((err) => {
        console.warn('[share] productQrcode FAIL', err);
        this.qrcodeUrl = '';
      })
      .then(() => this._render());
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
    // 2) 小程序码。dataUrl（data:image/png;base64,...）不能走 downloadFile，
    // 它本身就是图片内容，直接交给 canvas.createImage 即可
    if (this.qrcodeUrl && this.qrcodeUrl.indexOf('data:') === 0) {
      this._qrPath = this.qrcodeUrl;
    } else if (this.qrcodeUrl) {
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

        // 图片必须先 decode 完再进入绘制。原先 _drawCover / 太阳码那段都是
        // img.onload 里异步 drawImage，而本函数同步跑到底就 setData({generating:false})，
        // 用户此时点「保存」，canvasToTempFilePath 导出的是还没画上图的那一帧 ——
        // 这就是「弹出的对话框中商品图为空（只有灰底『商品图』字样）」的根因。
        Promise.all([
          this._decode(canvas, this._coverPath),
          this._decode(canvas, this._qrPath)
        ]).then((imgs) => {
          this._paint(ctx, imgs[0], imgs[1]);
          this.setData({ generating: false });
        });
      });
  },

  /**
   * 把图片路径/dataUrl 解成 canvas 可 drawImage 的 image 对象。
   * 失败一律 resolve(null)（由调用方画占位），不让整张海报卡在 pending。
   */
  _decode(canvas, src) {
    return new Promise((resolve) => {
      if (!src) return resolve(null);
      try {
        const img = canvas.createImage();
        img.onload = () => resolve(img);
        img.onerror = (e) => {
          console.warn('[share] image decode FAIL', src && src.slice(0, 40), e);
          resolve(null);
        };
        img.src = src;
      } catch (e) {
        console.warn('[share] createImage FAIL', e);
        resolve(null);
      }
    });
  },

  /**
   * 真正的绘制，全同步 —— 图已 decode 完，画完即可安全导出
   */
  _paint(ctx, coverImg, qrImg) {
    {
        // 背景
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, POSTER_W, POSTER_H);

        // 商品图区域 [0, 0] - [600, 480]
        this._drawCover(ctx, 0, 0, 600, 480, coverImg);

        // 顶部装饰条 [480-560]
        ctx.fillStyle = '#F2F2F7';
        ctx.fillRect(0, 480, 600, 80);
        ctx.fillStyle = '#666';
        ctx.font = '24px sans-serif';
        ctx.textBaseline = 'middle';
        // 商家名拿不到时留空，不能写死「洞天团购」—— 多商户平台每家有自己的品牌
        if (this.merchant.merchantName) {
          ctx.fillText('— ' + this.merchant.merchantName + ' —', 30, 520);
        }

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
          // 原价要画在现价右边，位置得按现价实际宽度算。写死 x=240 时，
          // 现价位数一多（比如 ¥1288.00）就会被压在下面重叠。
          ctx.font = 'bold 56px sans-serif';
          const nowW = ctx.measureText('¥' + this.product.price).width;
          ctx.font = '26px sans-serif';
          const oldX = 30 + nowW + 20;
          const oldText = '¥' + this.product.marketPrice;
          const oldW = ctx.measureText(oldText).width;
          ctx.fillText(oldText, oldX, 700);
          // 删除线要压在字的垂直中线上。原先固定 y=690 而基线在 700、
          // 字号 26px（约 x-height 一半 ≈ 9px），690 恰好偏到字的上沿外面，
          // 看着像下划线而不是删除线。
          ctx.beginPath();
          ctx.moveTo(oldX, 700 - 9);
          ctx.lineTo(oldX + oldW, 700 - 9);
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

        // 右侧小程序码。不做圆形裁剪：微信小程序码本身是方形带白边的图案，
        // 裁成圆会把四角的定位图案切掉，实际扫不出来（原先就是圆形 clip）。
        if (qrImg) {
          ctx.drawImage(qrImg, 450, 750, 120, 120);
        } else {
          // 拿不到码：画方框 + 提示，文案说清是「小程序码」而不是内部叫法「太阳码」
          ctx.strokeStyle = '#E5E5EA';
          ctx.lineWidth = 3;
          ctx.strokeRect(450, 750, 120, 120);
          ctx.fillStyle = '#999';
          ctx.font = '18px sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText('小程序码', 510, 815);
          ctx.textAlign = 'left';
        }

        // 底部签名：只在有商家名时画，不写死平台名
        if (this.merchant.merchantName) {
          ctx.fillStyle = '#BBB';
          ctx.font = '20px sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText(this.merchant.merchantName, 300, 880);
          ctx.textAlign = 'left';
        }
    }
  },

  /**
   * 画商品图。收的是已 decode 完的 image 对象而不是路径 ——
   * 路径版本必须 img.onload 异步画，会晚于导出（见 _draw 注释）。
   */
  _drawCover(ctx, x, y, w, h, img) {
    if (!img) {
      ctx.fillStyle = '#E5E5EA';
      ctx.fillRect(x, y, w, h);
      ctx.fillStyle = '#999';
      ctx.font = '28px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('暂无图片', x + w / 2, y + h / 2);
      ctx.textAlign = 'left';
      return;
    }
    // 居中裁剪（aspectFill）：按较大比例缩放后居中，超出部分裁掉
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
      // 商家名拿不到时只发商品名，不写死平台名
      title: (p.name || '好物') + (p.price ? ' ¥' + p.price : '') + (m.merchantName ? ' | ' + m.merchantName : ''),
      path: '/pages/goods/detail/index?id=' + (p.productId || this.productId)
    };
  }
});
