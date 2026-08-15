/**
 * 解析微信小程序码 (wxacode) 的扫描结果为 invite scene
 *
 * 二维码内容有两种格式:
 *  1) 普通短码: "invite:1:100:ABC123"
 *  2) 小程序码 (path+query): "pages/merchant/scan/index?scene=invite%3A1%3A100%3AABC123"
 *
 * 边界:
 *  - url 含多个参数: ?scene=invite:1:100:ABC&foo=bar
 *  - scene 已 URL 编码: invite%3A1%3A100%3AABC
 *  - 空 scene / 非 invite 前缀
 *
 * @param {string} raw wx.scanCode 返回的 result/path
 * @returns {{ok: boolean, scene?: string, reason?: string}}
 */
function parseInviteScene(raw) {
  if (!raw || typeof raw !== 'string') {
    return { ok: false, reason: 'empty' }
  }
  let scene = raw.trim()

  // 格式 2: 小程序码 path?query
  if (scene.startsWith('pages/')) {
    const queryIdx = scene.indexOf('?')
    if (queryIdx < 0) return { ok: false, reason: 'no_query' }
    const qs = scene.substring(queryIdx + 1)
    // 解析 query（避免 URLSearchParams 在小程序老版本不可用）
    const params = {}
    qs.split('&').forEach((kv) => {
      const eq = kv.indexOf('=')
      if (eq > 0) {
        const k = decodeURIComponent(kv.substring(0, eq).replace(/\+/g, ' '))
        const v = decodeURIComponent(kv.substring(eq + 1).replace(/\+/g, ' '))
        params[k] = v
      }
    })
    if (!params.scene) return { ok: false, reason: 'no_scene' }
    scene = params.scene
  }

  // 必须 invite: 前缀
  if (!scene.startsWith('invite:')) {
    return { ok: false, reason: 'not_invite' }
  }

  // 校验段数 (invite:mid:sid:code) — 4 段
  const parts = scene.split(':')
  if (parts.length !== 4) return { ok: false, reason: 'bad_format' }
  if (!/^\d+$/.test(parts[1]) || !/^\d+$/.test(parts[2])) {
    return { ok: false, reason: 'bad_nums' }
  }
  if (!parts[3] || parts[3].length < 4 || parts[3].length > 8) {
    return { ok: false, reason: 'bad_code_len' }
  }

  return { ok: true, scene }
}

module.exports = { parseInviteScene }
