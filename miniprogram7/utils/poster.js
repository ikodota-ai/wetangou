/**
 * 海报画布渲染工具（小程序 type="2d" canvas）
 * - 与 goods/share 模板同款绘制管线，但布局更精简：太阳码 + 标题 + 副标题 + 提示
 * - 提供 drawStaffInvite / drawStaffVerify 两个场景化封装
 */

const POSTER_W = 600
const POSTER_H = 900

function _downloadImage(url) {
  return new Promise((resolve, reject) => {
    if (!url) return reject(new Error('empty url'))
    wx.downloadFile({
      url,
      success: (res) => {
        if (res.statusCode === 200 && res.tempFilePath) resolve(res.tempFilePath)
        else reject(new Error('http ' + res.statusCode))
      },
      fail: reject
    })
  })
}

function _getCtx(canvasId) {
  return new Promise((resolve, reject) => {
    const query = wx.createSelectorQuery()
    query.select('#' + canvasId)
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) return reject(new Error('canvas not ready'))
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        const dpr = wx.getSystemInfoSync().pixelRatio || 2
        canvas.width = POSTER_W * dpr
        canvas.height = POSTER_H * dpr
        ctx.scale(dpr, dpr)
        resolve({ canvas, ctx })
      })
  })
}

function _saveCanvas(canvas) {
  return new Promise((resolve, reject) => {
    wx.canvasToTempFilePath({
      canvas,
      success: (res) => resolve(res.tempFilePath),
      fail: reject
    }, canvas._owner || undefined)
  })
}

function _clipText(ctx, str, max) {
  if (!str) return ''
  if (ctx.measureText(str).width <= max) return str
  let s = str
  while (s.length > 0 && ctx.measureText(s + '...').width > max) s = s.slice(0, -1)
  return s + '...'
}

/**
 * 员工邀请海报
 * opts: { canvasId, qrcodeUrl, storeName, inviteCode, roleLabel }
 */
async function drawStaffInvite(opts) {
  const { canvasId, qrcodeUrl, storeName, inviteCode, roleLabel } = opts
  const { canvas, ctx } = await _getCtx(canvasId)

  // 背景：浅绿渐变
  const grad = ctx.createLinearGradient(0, 0, 0, POSTER_H)
  grad.addColorStop(0, '#3A6B35')
  grad.addColorStop(0.4, '#5A8B45')
  grad.addColorStop(1, '#FFFFFF')
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, POSTER_W, POSTER_H)

  // 标题
  ctx.fillStyle = '#FFFFFF'
  ctx.font = 'bold 56px sans-serif'
  ctx.textBaseline = 'top'
  ctx.fillText('加入我们', 60, 100)
  ctx.font = '32px sans-serif'
  ctx.fillStyle = 'rgba(255,255,255,0.9)'
  ctx.fillText('扫码成为 ' + (storeName || '门店') + ' 的 ' + (roleLabel || '员工'), 60, 180)

  // 邀请码大字
  ctx.fillStyle = '#1A1A1A'
  ctx.font = 'bold 36px sans-serif'
  ctx.fillText('邀请码', 60, 320)
  ctx.font = 'bold 96px monospace'
  ctx.fillStyle = '#3A6B35'
  ctx.fillText(inviteCode || '------', 60, 360)

  // 副标题
  ctx.fillStyle = '#666'
  ctx.font = '26px sans-serif'
  ctx.fillText('或长按识别下方小程序码', 60, 500)

  // 白色卡片：太阳码
  ctx.fillStyle = '#FFFFFF'
  _roundRect(ctx, 100, 560, 400, 280, 24)
  ctx.fill()
  if (qrcodeUrl) {
    try {
      const path = await _downloadImage(qrcodeUrl)
      ctx.drawImage(path, 180, 600, 240, 240)
    } catch (e) {
      _drawError(ctx, '太阳码加载失败', 180, 720)
    }
  } else {
    _drawError(ctx, '太阳码生成失败', 180, 720)
  }

  // 底部
  ctx.fillStyle = '#1A1A1A'
  ctx.font = 'bold 30px sans-serif'
  ctx.textBaseline = 'top'
  ctx.fillText('7 天内有效，过期作废', 60, 870)

  return _saveCanvas(canvas)
}

/**
 * 员工核销员码海报（贴桌上）
 * opts: { canvasId, qrcodeUrl, storeName, realName }
 */
async function drawStaffVerify(opts) {
  const { canvasId, qrcodeUrl, storeName, realName } = opts
  const { canvas, ctx } = await _getCtx(canvasId)

  // 背景：暖色（"请扫我"）
  const grad = ctx.createLinearGradient(0, 0, 0, POSTER_H)
  grad.addColorStop(0, '#D9534F')
  grad.addColorStop(0.5, '#F0AD4E')
  grad.addColorStop(1, '#FFFFFF')
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, POSTER_W, POSTER_H)

  // 标题
  ctx.fillStyle = '#FFFFFF'
  ctx.font = 'bold 64px sans-serif'
  ctx.textBaseline = 'top'
  ctx.fillText('请扫我核销', 60, 100)
  ctx.font = '32px sans-serif'
  ctx.fillStyle = 'rgba(255,255,255,0.95)'
  ctx.fillText('我是 ' + (realName || '店员') + ' · ' + (storeName || '门店'), 60, 200)

  // 白色卡片
  ctx.fillStyle = '#FFFFFF'
  _roundRect(ctx, 80, 320, 440, 460, 28)
  ctx.fill()
  if (qrcodeUrl) {
    try {
      const path = await _downloadImage(qrcodeUrl)
      ctx.drawImage(path, 140, 360, 320, 320)
    } catch (e) {
      _drawError(ctx, '太阳码加载失败', 140, 520)
    }
  } else {
    _drawError(ctx, '太阳码生成失败', 140, 520)
  }
  ctx.fillStyle = '#666'
  ctx.font = '26px sans-serif'
  ctx.textBaseline = 'top'
  ctx.fillText('顾客扫一扫 → 出示团购券', 100, 700)
  ctx.fillText('店员在店内工作台完成核销', 100, 740)

  // 底部水印
  ctx.fillStyle = '#999'
  ctx.font = '22px sans-serif'
  ctx.fillText('— ' + (realName || '店员') + ' 的核销码 —', 60, 870)

  return _saveCanvas(canvas)
}

function _roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.arcTo(x + w, y, x + w, y + h, r)
  ctx.arcTo(x + w, y + h, x, y + h, r)
  ctx.arcTo(x, y + h, x, y, r)
  ctx.arcTo(x, y, x + w, y, r)
  ctx.closePath()
}

function _drawError(ctx, msg, x, y) {
  ctx.fillStyle = '#EEE'
  ctx.fillRect(x, y - 20, 240, 240)
  ctx.fillStyle = '#999'
  ctx.font = '24px sans-serif'
  ctx.textBaseline = 'middle'
  ctx.fillText(msg, x + 120, y + 100, 240)
}

module.exports = {
  POSTER_W,
  POSTER_H,
  drawStaffInvite,
  drawStaffVerify
}
