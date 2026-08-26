<!--
腾讯地图定位组件：输入地址 → 搜索定位 → 拖动标记选点 → 回传经纬度
使用腾讯地图 JavaScript API GL（需已申请 key 并启用 WebServiceAPI 的 Geocoding）
-->
<template>
  <div class="tencent-map">
    <div class="map-search-bar">
      <el-input
        v-model="searchKeyword"
        placeholder="输入地址搜索定位"
        size="small"
        style="width: 240px; margin-right: 8px;"
        @keyup.enter.native="searchAddress()"
      />
      <el-button size="small" @click="searchAddress()">搜索</el-button>
      <el-button size="small" @click="reverseGeocode" :disabled="!lng || !lat">根据坐标获取地址</el-button>
    </div>
    <div ref="mapContainer" class="map-container" :style="{ height: height }"></div>
    <div class="map-coords">
      <span>经度：{{ lng || '—' }}</span>
      <span>纬度：{{ lat || '—' }}</span>
    </div>
  </div>
</template>

<script>
import defaultSettings from '@/settings'

const MAP_KEY = defaultSettings.tencentMapKey || 'YOUR_TENCENT_MAP_KEY'
const TMap_URL = `https://map.qq.com/api/gljs?key=${MAP_KEY}`

// ===== 地理编码结果缓存 =====
// 腾讯地图 WebService 免费额度有限（个人 key 每日几千次），超了要付费。
// 这里做两件事省配额：
//   1) 模块级 Map 缓存，同一地址/坐标只请求一次，弹窗反复开关也命中；
//   2) sessionStorage 持久化，页面刷新后仍复用。
// 缓存的是「地址 <-> 经纬度」这种稳定映射，不存在时效问题。
const GEO_CACHE_KEY = 'tmap_geo_cache_v1'
const GEO_CACHE_MAX = 200
const geoCache = new Map()
try {
  const saved = JSON.parse(sessionStorage.getItem(GEO_CACHE_KEY) || '{}')
  Object.keys(saved).forEach(k => geoCache.set(k, saved[k]))
} catch (e) { /* 缓存损坏就当空 */ }

function geoCacheGet(key) {
  return geoCache.get(key)
}
function geoCacheSet(key, value) {
  // 超上限时丢最早的键，避免 sessionStorage 无限膨胀
  if (geoCache.size >= GEO_CACHE_MAX) {
    const oldest = geoCache.keys().next().value
    if (oldest !== undefined) geoCache.delete(oldest)
  }
  geoCache.set(key, value)
  try {
    sessionStorage.setItem(GEO_CACHE_KEY, JSON.stringify(Object.fromEntries(geoCache)))
  } catch (e) { /* 写不进去不影响功能 */ }
}

export default {
  name: 'TencentMap',
  props: {
    value: { type: Object, default: () => ({ lng: null, lat: null }) },
    address: { type: String, default: '' },
    height: { type: String, default: '360px' }
  },
  data() {
    return {
      searchKeyword: '',
      lng: this.value.lng,
      lat: this.value.lat,
      map: null,
      marker: null,
      geocoder: null,
      loaded: false
    }
  },
  watch: {
    value(val) {
      if (val) {
        this.lng = val.lng
        this.lat = val.lat
      }
    },
    address(val) {
      if (!val || !this.loaded) return
      // 只在地址文本真的改变时才重新定位；父组件重渲染导致的同值赋值不触发请求
      if (val === this.searchKeyword) return
      this.searchKeyword = val
      this.searchAddress(true)
    }
  },
  mounted() {
    this.loadScript()
  },
  methods: {
    loadScript() {
      if (window.TMap) { this.initMap(); return }
      if (document.querySelector(`script[src="${TMap_URL}"]`)) { return }
      const script = document.createElement('script')
      script.src = TMap_URL
      script.onload = () => { this.initMap() }
      script.onerror = () => { this.$message.error('腾讯地图加载失败，请检查 key 是否正确') }
      document.head.appendChild(script)
    },
    async initMap() {
      this.loaded = true
      try {
        const center = (this.lng && this.lat)
          ? new TMap.LatLng(this.lat, this.lng)
          : new TMap.LatLng(23.405, 113.227) // 默认广州/深圳
        this.map = new TMap.Map(this.$refs.mapContainer, {
          center,
          zoom: 15,
          mapStyle: 'style1'
        })
        this.marker = new TMap.MultiMarker({
          map: this.map,
          styles: { marker: new TMap.MarkerStyle({ width: 30, height: 42, anchor: { x: 15, y: 42 } }) },
          geometries: [{ id: 'pin', styleId: 'marker', position: center }]
        })
        // 拖动标记
        this.marker.on('dragend', (evt) => {
          const pos = evt.geometry.position
          this.lng = pos.lng.toFixed(6)
          this.lat = pos.lat.toFixed(6)
          this.emitValue()
        })
        // 点击地图移动标记
        this.map.on('click', (evt) => {
          const pos = evt.latLng
          this.lng = pos.lng.toFixed(6)
          this.lat = pos.lat.toFixed(6)
          this.marker.setGeometries([{ id: 'pin', styleId: 'marker', position: pos }])
          this.emitValue()
        })
        // 允许拖动标记
        this.marker.setMap(this.map)
        this.marker.setGeometries(this.marker.geometries.map(g => ({ ...g, draggable: true })))

        // 已有经纬度（编辑存量门店）→ 只回显地址文本，不再发地理编码请求。
        // 原先无条件 searchAddress()，等于每次打开编辑弹窗都白烧一次配额，
        // 而库里的坐标本来就是准的（且可能是人工拖动微调过的，反查结果反而会覆盖掉）。
        if (this.address) {
          this.searchKeyword = this.address
          if (!this.lng || !this.lat) {
            this.searchAddress(true)
          }
        }
      } catch (e) {
        console.error('地图初始化失败', e)
      }
    },
    emitValue() {
      this.$emit('input', { lng: this.lng, lat: this.lat, address: this.searchKeyword })
    },
    // JSONP 调用腾讯地图 WebService（规避浏览器跨域）
    jsonp(url) {
      return new Promise((resolve, reject) => {
        const cbName = 'tmapCb_' + Date.now() + '_' + Math.floor(Math.random() * 1000)
        const timer = setTimeout(() => { cleanup(); reject(new Error('timeout')) }, 10000)
        function cleanup() {
          clearTimeout(timer)
          delete window[cbName]
          if (script && script.parentNode) script.parentNode.removeChild(script)
        }
        window[cbName] = (data) => { cleanup(); resolve(data) }
        const script = document.createElement('script')
        script.src = url + (url.indexOf('?') > -1 ? '&' : '?') + 'output=jsonp&callback=' + cbName
        script.onerror = () => { cleanup(); reject(new Error('network')) }
        document.head.appendChild(script)
      })
    },
    // 地址 → 经纬度
    async searchAddress(silent = false) {
      const keyword = this.searchKeyword.trim()
      if (!keyword) { return }
      // 命中缓存直接用，不发请求（省配额）
      const cached = geoCacheGet('addr:' + keyword)
      if (cached) {
        this.setPoint(cached.lng, cached.lat)
        if (!silent) this.$message.success('定位成功（缓存）')
        return
      }
      try {
        const url = `https://apis.map.qq.com/ws/geocoder/v1/?address=${encodeURIComponent(keyword)}&key=${MAP_KEY}`
        const res = await this.jsonp(url)
        if (res.status === 0 && res.result && res.result.location) {
          const loc = res.result.location
          geoCacheSet('addr:' + keyword, { lng: loc.lng, lat: loc.lat })
          this.setPoint(loc.lng, loc.lat)
          if (!silent) this.$message.success('定位成功')
        } else if (!silent) {
          this.$message.warning(res.message || '未找到该地址')
        }
      } catch (e) {
        if (!silent) this.$message.error('地址解析失败，请检查地图 key 及域名白名单')
      }
    },
    // 经纬度 → 地址
    async reverseGeocode() {
      if (!this.lng || !this.lat) return
      const locKey = 'loc:' + Number(this.lat).toFixed(6) + ',' + Number(this.lng).toFixed(6)
      const cached = geoCacheGet(locKey)
      if (cached && cached.address) {
        this.searchKeyword = cached.address
        this.$emit('addressResolved', cached.address)
        this.emitValue()
        this.$message.success('地址获取成功（缓存）')
        return
      }
      try {
        const url = `https://apis.map.qq.com/ws/geocoder/v1/?location=${this.lat},${this.lng}&key=${MAP_KEY}`
        const res = await this.jsonp(url)
        if (res.status === 0 && res.result && res.result.address) {
          geoCacheSet(locKey, { address: res.result.address })
          this.searchKeyword = res.result.address
          this.$emit('addressResolved', res.result.address)
          this.emitValue()
          this.$message.success('地址获取成功')
        } else {
          this.$message.warning(res.message || '未获取到地址')
        }
      } catch (e) {
        this.$message.error('逆地址解析失败')
      }
    },
    // 统一设置坐标并同步地图/标记
    setPoint(lng, lat) {
      this.lng = Number(lng).toFixed(6)
      this.lat = Number(lat).toFixed(6)
      if (this.map && window.TMap) {
        const pos = new TMap.LatLng(Number(lat), Number(lng))
        this.map.setCenter(pos)
        this.marker.setGeometries([{ id: 'pin', styleId: 'marker', position: pos, draggable: true }])
      }
      this.emitValue()
    }
  }
}
</script>

<style scoped>
.tencent-map { width: 100%; }
.map-search-bar { display: flex; align-items: center; margin-bottom: 8px; }
.map-container { width: 100%; border: 1px solid #DCDFE6; border-radius: 4px; }
.map-coords { display: flex; gap: 24px; margin-top: 6px; font-size: 13px; color: #606266; }
</style>
