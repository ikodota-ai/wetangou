Component({
  data: { selected: 0, color: '#AAAAAA', selectedColor: '#5A8A4A', list: [
    { pagePath: '/pages/home/index', text: '首页' },
    { pagePath: '/pages/album/index', text: '贴图' },
    { pagePath: '/pages/booking/index', text: '预约' },
    { pagePath: '/pages/mine/index/index', text: '我的' }
  ]},
  methods: {
    onTap(e) {
      const idx = e.currentTarget.dataset.index;
      const url = this.data.list[idx].pagePath;
      wx.switchTab({ url });
      this.setData({ selected: idx });
    }
  }
});
