// utils/mock.js 内置 mock 数据，用于无后端调试
module.exports = {
  stores: [
    {
      storeId: 1,
      name: '菌鑫来餐饮',
      storeName: '菌鑫来餐饮',
      subName: '胡苏老菌庄',
      hours: '周一至周日 09:00-22:30',
      businessHours: '周一至周日 09:00-22:30',
      address: '花城街道建设北路222号101房自编3号',
      phone: '13434123069',
      latitude: 23.405,
      longitude: 113.227,
      cover: '/assets/img/banner1.jpg',
      album: [
        { id: 1, url: '/assets/img/RestaurantImg.png', tag: '全部' },
        { id: 2, url: '/assets/img/GoodsImg.jpg', tag: '全部' }
      ],
      facilities: ['可堂食', '可预约', '提供独立包间', '提供免费停车场', '免费停车']
    }
  ],
  goods: [
    {
      productId: 1,
      name: '【大满足】野生菌6-8人餐',
      productName: '【大满足】野生菌6-8人餐',
      price: '498.00',
      sold: 0,
      cover: '/assets/img/RestaurantImg.png',
      images: ['/assets/img/RestaurantImg.png'],
      validDays: 365,
      unavailable: '',
      availableTime: '10:30至21:00',
      purchaseLimit: '不限制购买数量',
      bookingRule: '到店消费：无需预约，高峰期可能需要排队',
      usageRule: '不与店内优惠同享',
      voucherLimit: '每人最多使用1张',
      peopleLimit: '不限制人数',
      storeId: 1,
      storeName: '菌鑫来餐饮',
      storeHours: '周一至周日 09:00-22:30',
      packages: [
        { name: '山茶菌', qty: 1, price: '48.00' },
        { name: '猪肚菌', qty: 1, price: '53.00' },
        { name: '牛排菌', qty: 1, price: '58.00' },
        { name: '丛枝菌', qty: 1, price: '68.00' },
        { name: '白虎掌菌', qty: 1, price: '138.00' },
        { name: '排骨', qty: 1, price: '48.00' },
        { name: '清远麻鸡', qty: 1, price: '158.00' },
        { name: '招牌杂菌炒饭', qty: 1, price: '48.00' },
        { name: '杂菜', qty: 1, price: '10.00' },
        { name: '茶位', qty: 8, price: '3.00' },
        { name: '纸巾', qty: 1, price: '3.00' }
      ],
      moreGoods: [
        { productId: 2, name: '【到店必吃】野生菌火锅四人餐', price: '268.00', cover: '/assets/img/GoodsImg.jpg' },
        { productId: 3, name: '超值2-3人餐', price: '168.00', cover: '/assets/img/GoodsImg.jpg' },
        { productId: 4, name: '尝鲜推荐·野生菌鸡煲双人套餐', price: '138.00', cover: '/assets/img/GoodsImg.jpg' }
      ]
    },
    {
      productId: 2,
      name: '【到店必吃】野生菌火锅四人餐',
      productName: '【到店必吃】野生菌火锅四人餐',
      price: '268.00',
      sold: 0,
      cover: '/assets/img/GoodsImg.jpg',
      images: ['/assets/img/GoodsImg.jpg'],
      packages: [{ name: '火锅四人份', qty: 1, price: '268.00' }],
      moreGoods: []
    },
    {
      productId: 3,
      name: '超值2-3人餐',
      productName: '超值2-3人餐',
      price: '168.00',
      sold: 0,
      cover: '/assets/img/GoodsImg.jpg',
      images: ['/assets/img/GoodsImg.jpg'],
      packages: [{ name: '超值2-3人份', qty: 1, price: '168.00' }],
      moreGoods: []
    },
    {
      productId: 4,
      name: '尝鲜推荐·野生菌鸡煲双人套餐',
      productName: '尝鲜推荐·野生菌鸡煲双人套餐',
      price: '138.00',
      sold: 0,
      cover: '/assets/img/GoodsImg.jpg',
      images: ['/assets/img/GoodsImg.jpg'],
      packages: [{ name: '鸡煲双人份', qty: 1, price: '138.00' }],
      moreGoods: []
    }
  ],
  bookingSlots: {
    // 默认模板：早 11/12/17 晚 18/19
    day: ['11:00', '12:00', '17:00'],
    night: ['18:00', '19:00']
  },
  agreement: {
    user: '用户服务协议\n更新日期：2026年7月1日\n生效日期：2026年7月1日\n欢迎使用菌鑫来餐饮微信小程序服务。本协议是您与广州花都菌鑫来餐饮店（以下简称"我们/平台"）之间关于使用小程序服务的有效约定。您使用、登录、购买本小程序服务，即代表已阅读、理解并同意遵守本协议全部条款；若您不同意，请立即停止使用本服务。\n一、主体信息\n平台运营主体：广州花都菌鑫来餐饮店\n服务产品：菌鑫来餐饮微信小程序\n客服电话：13434123069\n联系邮箱：3621065215@qq.com\n二、服务内容\n本小程序为用户提供门店信息浏览、团购商品查看、团购券购买、券码核销、订单管理、售后退款、客服咨询等配套技术与信息服务。平台仅提供交易技术支持，商品及到店服务均由合作门店提供，门店承担对应服务履约及质量责任，平台依法履行平台管理义务。\n三、用户使用规范\n1. 用户需为具备完全民事行为能力的自然人，未成年人需在监护人同意及陪同下使用本服务。\n2. 用户承诺提交的手机号、身份信息、账户信息真实有效，不得冒用他人信息操作，因信息不实造成的损失由用户承担。',
    privacy: '用户隐私政策\n更新日期：2026年7月1日\n生效日期：2026年7月1日\n广州花都菌鑫来餐饮店（以下简称"我们"）及旗下菌鑫来餐饮微信小程序，高度重视用户隐私与个人信息保护。本隐私政策旨在告知用户我们如何收集、使用、存储、共享及保护您的个人信息，以及您所享有的相关权利。\n使用本小程序即代表您同意本政策全部内容；若您不同意，将无法使用本小程序相关服务。\n一、适用范围\n本政策适用于用户使用菌鑫来餐饮小程序全部服务场景，包括浏览、登录、购买团购、订单管理、到店核销、退款售后、客服咨询、参与活动等全部功能。\n二、信息收集与使用规则\n我们仅收集为提供服务所必需的个人信息，不会过度采集用户数据。\n1. 登录与账号识别信息\n收集：微信OpenID、昵称、头像、设备信息、网络信息、登录记录；必要时收集手机号。\n用途：用于账号识别、正常登录、保障账号安全、关联订单与售后记录。\n2. 订单与交易信息\n收集：订单号、下单门店、券码、支付金额、支付记录。\n用途：完成下单、支付、发券、核销、退款、售后处理、交易安全及财务对账。\n3. 核销服务信息\n收集：券码、核销状态、核销时间、核销门店信息。\n用途：用于核销服务记录与争议处理。'
  }
};
