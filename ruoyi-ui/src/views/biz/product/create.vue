<template>
  <div class="dyl-create">
    <!-- 顶部栏（仿抖音来客"商品创建"标题 + 上品教程）-->
    <div class="dyl-header">
      <el-button icon="el-icon-back" size="medium" plain @click="goBack">返回</el-button>
      <div class="dyl-title">商品创建</div>
      <el-button type="text" size="medium" @click="openTutorial">
        <i class="el-icon-question"></i> 上品教程
      </el-button>
    </div>

    <div class="dyl-body">
      <!-- 基础信息卡（折叠/展开，第1步是这卡）-->
      <el-card class="dyl-card" shadow="never">
        <div slot="header" class="dyl-card-head" @click="basicCollapsed = !basicCollapsed">
          <span class="dyl-card-title">基础信息</span>
          <span v-if="form.productId" class="dyl-card-tag">已锁定 · {{ typeName }}</span>
          <i :class="basicCollapsed ? 'el-icon-arrow-down' : 'el-icon-arrow-up'" class="dyl-card-arrow"></i>
        </div>
        <div v-show="!basicCollapsed" class="dyl-card-body">
          <el-form :model="form" :rules="basicRules" ref="basicForm" label-width="120px" size="small">
            <el-form-item v-if="showMerchantSelect" label="所属商家" prop="merchantId">
              <biz-select v-model="form.merchantId" type="merchant" width="100%" placeholder="请选择所属商家" />
            </el-form-item>
            <el-form-item label="商品品类" prop="categoryId">
              <el-cascader
                v-model="form.categoryIdArr"
                :options="categoryTree"
                :props="{ value: 'categoryId', label: 'categoryName', children: 'children', checkStrictly: true, emitPath: false }"
                placeholder="请选择品类（购物·母婴用品·儿童服饰）"
                style="width: 100%"
                @change="onCategoryChange"
              />
            </el-form-item>
            <el-form-item label="商品发布细则" prop="industryCode">
              <el-input v-model="form.industryCode" readonly placeholder="选择品类后自动匹配">
                <template slot="append"><el-button @click="viewRules">查看详情</el-button></template>
              </el-input>
            </el-form-item>
            <el-form-item label="商品类型" prop="typeCode">
              <el-input :value="typeName" readonly placeholder="点击选择" @focus="typePickerOpen = true">
                <template slot="append"><i class="el-icon-arrow-right"></i></template>
              </el-input>
            </el-form-item>
            <el-form-item v-if="form.typeCode === 'HUIXIANG_CARD'" label="惠享卡提示">
              <el-alert type="warning" :closable="false" show-icon>
                发布此类目商品需要开通【放心付】保障服务
              </el-alert>
            </el-form-item>
            <el-form-item label="商品名称" prop="productName">
              <el-input v-model="form.productName" maxlength="60" show-word-limit :placeholder="namePlaceholder" />
            </el-form-item>
            <el-form-item v-if="form.typeCode === 'VOUCHER'" label="代金券面值" prop="faceValue">
              <el-input-number v-model="form.faceValue" :min="0.01" :precision="2" :step="1" controls-position="right" style="width: 100%" />
              <div class="dyl-tip">输入面值后，代金券名称将自动按面值生成</div>
            </el-form-item>
          </el-form>
          <div class="dyl-step1-footer">
            <el-button v-if="!form.productId" type="primary" size="medium" :loading="savingBasic" @click="goStep2" style="width: 100%">下一步</el-button>
            <el-button v-else type="primary" size="medium" @click="basicCollapsed = true" style="width: 100%">已保存 · 展开其他信息</el-button>
          </div>
        </div>
      </el-card>

      <!-- 步骤2：3 类型各自独立设计 tab 结构（不强制统一）
       团购 6 tab = 基础/商家/商品/售卖/交易/消费
       代金券 6 tab = 商品类型/商家/商品/售卖/交易/消费
       组合券包 6 tab = 基础/商品/商品资质/售卖/交易/消费 -->
      <el-card v-if="form.typeCode && form.productId" class="dyl-card dyl-card-step2" shadow="never">
        <!-- 吸顶锚点导航：点了滚到对应区块，滚动时反过来高亮当前区块。
             原先是 el-tabs，每填完一段都要手动点下一个 tab；
             改成一页连续滚动后，填写节奏不再被点击打断。 -->
        <div class="dyl-anchor-nav" ref="anchorNav">
          <div class="dyl-anchor-track">
            <span
              v-for="sec in visibleSections"
              :key="sec.name"
              class="dyl-anchor-item"
              :class="{ active: activeTab === sec.name }"
              @click="scrollToSection(sec.name)"
            >{{ sec.label }}</span>
          </div>
        </div>
        <div class="dyl-sec-list" ref="secList">
          <!-- Tab: 商家信息（团购/代金）/ 信息（组合券包，基础+商家合并）-->
                              <!-- Tab: 基础信息（团购/代金，含已锁的品类+类型+名称）-->
          <section v-if="isGroupon || isVoucher" class="dyl-sec" :ref="'sec_basicG'" data-sec="basicG">
            <div class="dyl-sec-title">基础信息</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="商品品类">
                <el-input :value="categoryNameOf(form.categoryId)" readonly />
              </el-form-item>
              <el-form-item label="商品类型">
                <el-input :value="typeName" readonly />
              </el-form-item>
              <el-form-item v-if="isVoucher" label="代金券面值" prop="faceValue">
                <el-input-number v-model="form.faceValue" :min="0.01" :precision="2" :step="1" controls-position="right" style="width: 100%" />
                <div class="dyl-tip">输入面值后，代金券名称将自动按面值生成</div>
              </el-form-item>
            </el-form>
          </section>

<!-- Tab: 基础信息（组合券包无商家 tab，基础信息独立）-->
          <section v-if="isCombo" class="dyl-sec" :ref="'sec_basic'" data-sec="basic">
            <div class="dyl-sec-title">基础信息</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="商品类型"><el-input :value="typeName" readonly /></el-form-item>
              <el-form-item label="副标题">
                <el-input v-model="form.subtitle" maxlength="100" show-word-limit placeholder="副标题" />
              </el-form-item>
            </el-form>
          </section>

          <section v-if="isGroupon || isVoucher" class="dyl-sec" :ref="'sec_merchant'" data-sec="merchant">
            <div class="dyl-sec-title">{{ merchantTabLabel }}</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="所属商家">
                <el-input :value="merchantLabel" readonly placeholder="未指定" />
              </el-form-item>
              <!-- 收款方式由所属商家的支付配置（biz_merchant.pay_mode）决定，不是建品时手选：
                   同一商户的两个商品收款方式不同，在结算上没有意义。
                   PRD 和小程序商家端都标「不可编辑」，原先这里却是可点的 radio，
                   运营能随便改 —— 库里那 2 条与商户配置不一致的值就是这么来的。 -->
              <el-form-item label="收款方式">
                <el-input :value="collectMethodLabel" readonly placeholder="未指定商家" />
                <div class="dyl-tip">跟随所属商家的支付配置，如需调整请到「商户管理」修改该商户的支付方式</div>
              </el-form-item>
              <el-form-item label="适用门店" prop="storeIdList">
                <biz-select
                  v-if="form.merchantId"
                  v-model="form.storeIdList"
                  :merchant-id="form.merchantId"
                  type="store"
                  multiple
                />
                <el-alert
                  v-else
                  title="请先在上方「基础信息」选择所属商家，再选适用门店"
                  type="info"
                  :closable="false"
                  show-icon
                />
                <div v-if="form.merchantId" class="dyl-tip">只能选该商家名下的门店，换商家会清空已选门店</div>
              </el-form-item>
            </el-form>
          </section>
          <!-- Tab: 商品资质（组合券包独有）-->
          <section v-if="isCombo" class="dyl-sec" :ref="'sec_qualify'" data-sec="qualify">
            <div class="dyl-sec-title">商品资质</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="子品类型管理">
                <el-button size="small" type="primary" plain @click="comboDrawer = true">
                  <i class="el-icon-edit"></i> 编辑子品代金券
                </el-button>
                <div class="dyl-tip">代金券类子品需配置：券类型（通兑/单品类）+ 适用规则 + 头图 + 辅助图</div>
              </el-form-item>
              <el-form-item label="券类型">
                <el-radio-group v-model="form.voucherType">
                  <el-radio label="GENERAL">通兑券</el-radio>
                  <el-radio label="CATEGORY">单品类券</el-radio>
                </el-radio-group>
              </el-form-item>
              <el-form-item label="适用规则">
                <el-checkbox-group v-model="form.voucherRules">
                  <el-checkbox label="ALL_CATEGORY">全部品类适用</el-checkbox>
                  <el-checkbox label="ALL_BRAND">全部品牌适用</el-checkbox>
                </el-checkbox-group>
              </el-form-item>
            </el-form>
          </section>

          <!-- Tab: 商品信息（团购/代金/组合券包，组合券包显示组合搭配入口+头图）-->
          <section class="dyl-sec" :ref="'sec_product'" data-sec="product">
            <div class="dyl-sec-title">商品信息</div>
            <el-form :model="form" label-width="120px" size="small">
              <!-- 商品名称放最前：它是这一组里最主要的字段，也是第 1 步填过后
                   最常需要回头改的（第 1 步已折叠，不该为了改名字再展开） -->
              <el-form-item label="商品名称" prop="productName">
                <el-input v-model="form.productName" maxlength="60" show-word-limit :placeholder="namePlaceholder" />
                <div v-if="isVoucher" class="dyl-tip">系统已按面值 {{ form.faceValue || 0 }} 元自动生成，可手动调整</div>
              </el-form-item>

              <!-- 团购：商品搭配入口 + 单品/商品组管理 -->
              <template v-if="isGroupon">
                <el-form-item label="商品搭配">
                  <el-button size="small" type="primary" plain @click="comboDrawer = true">
                    <i class="el-icon-edit"></i> 管理商品搭配（{{ subitemGroupsCount }}）
                  </el-button>
                  <div class="dyl-tip">共 {{ subitemGroupsCount }} 个项目，顾客实际可享 {{ totalPickCount }} 个</div>
                </el-form-item>
              </template>

              <!-- 组合券包：组合商品搭配入口 + 4 种子品类型 -->
              <template v-if="isCombo">
                <el-form-item label="组合商品搭配">
                  <el-button size="small" type="primary" plain @click="comboDrawer = true">
                    <i class="el-icon-edit"></i> 管理组合搭配（{{ comboItemsCount }}）
                  </el-button>
                  <div class="dyl-tip">共 {{ comboItemsCount }} 条搭配 · 总价值（用户侧划线价）¥{{ totalComboValue }}</div>
                </el-form-item>
              </template>

              <!-- 公共：售价/市场价/库存 -->
              <el-form-item label="售价" prop="price">
                <el-input-number v-model="form.price" :min="0.01" :precision="2" :step="1" controls-position="right" style="width: 100%" :disabled="isCombo" />
                <div v-if="isCombo" class="dyl-tip">组合券包售价由系统按总价值自动计算，不可编辑</div>
              </el-form-item>
              <el-form-item label="市场价">
                <el-input-number v-model="form.marketPrice" :min="0" :precision="2" :step="1" controls-position="right" style="width: 100%" />
              </el-form-item>
              <el-form-item label="库存" prop="stock">
                <el-input-number v-model="form.stock" :min="0" controls-position="right" style="width: 100%" />
              </el-form-item>
              <el-form-item label="商品头图" prop="cover">
                <image-upload v-model="form.cover" :limit="isVoucher ? 1 : 5" />
                <div class="dyl-tip">顾客详情页顶部可左右翻动的就是这组图；商品列表、订单、分享封面取第 1 张</div>
              </el-form-item>
              <el-form-item v-if="!isVoucher" label="环境图">
                <image-upload v-model="form.images" :limit="10" />
                <div class="dyl-tip">店内环境 / 菜品实拍，展示在顾客详情页的「图文详情」里（竖排大图，不上顶部轮播）</div>
              </el-form-item>
              <el-form-item label="项目补充说明">
                <el-input v-model="form.detail" type="textarea" :rows="3" maxlength="500" show-word-limit placeholder="选填，对商品的补充说明" />
              </el-form-item>
            </el-form>
          </section>

          <!-- Tab: 售卖信息（团购+代金）-->
          <section v-if="isGroupon || isVoucher" class="dyl-sec" :ref="'sec_sale'" data-sec="sale">
            <div class="dyl-sec-title">售卖信息</div>
            <el-form :model="form" label-width="120px" size="small">
              <!-- 投放渠道：从 biz_sale_channel 字典拉，按 channelGroup 分组 + 每条带规则说明。
                   原先这里硬编码「抖音/今日头条/其他」，是照抄抖音来客的渠道名，
                   与本项目（微信小程序生态）不符；而且该字段后端无属性，勾了直接丢。 -->
              <el-form-item label="投放渠道">
                <div v-if="!channelGroups.length" class="dyl-tip">渠道字典为空，请联系平台管理员在「投放渠道」中配置</div>
                <el-checkbox-group v-model="form.saleChannels">
                  <div v-for="g in channelGroups" :key="g.name" class="dyl-ch-group">
                    <div class="dyl-ch-group-title">{{ g.label }}</div>
                    <div v-for="c in g.items" :key="c.channelCode" class="dyl-ch-item">
                      <el-checkbox :label="c.channelCode">{{ c.channelName }}</el-checkbox>
                      <div v-if="c.channelDesc" class="dyl-ch-desc">{{ c.channelDesc }}</div>
                    </div>
                  </div>
                </el-checkbox-group>
              </el-form-item>
              <el-form-item label="职人带货">
                <el-switch v-model="form.staffPromote" :active-value="1" :inactive-value="0" />
              </el-form-item>
              <el-form-item label="商品售卖日期">
                <el-date-picker v-model="form.saleDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="yyyy-MM-dd HH:mm:ss" style="width: 100%" />
              </el-form-item>
            </el-form>
          </section>

          <!-- Tab: 售卖信息（组合券包独有 — 含商家平台子品ID）-->
          <section v-if="isCombo" class="dyl-sec" :ref="'sec_sale'" data-sec="sale">
            <div class="dyl-sec-title">售卖信息</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="售价（系统算）">
                <el-input :value="autoComboPrice" readonly>
                  <template slot="append">元</template>
                </el-input>
                <div class="dyl-tip">总价值 ¥{{ totalComboValue }} × 折扣 = ¥{{ autoComboPrice }}</div>
              </el-form-item>
              <el-form-item label="库存" prop="stock">
                <el-input-number v-model="form.stock" :min="0" controls-position="right" style="width: 100%" />
              </el-form-item>
              <el-form-item label="商品售卖日期">
                <el-date-picker v-model="form.saleDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="yyyy-MM-dd HH:mm:ss" style="width: 100%" />
              </el-form-item>
              <el-form-item label="商家平台子品ID">
                <el-input v-model="form.outerSubitemId" placeholder="平台子品标识（可选）" />
              </el-form-item>
            </el-form>
          </section>

          

          <!-- Tab: 交易规则（团购+代金）-->
          <section v-if="isGroupon || isVoucher" class="dyl-sec" :ref="'sec_trade'" data-sec="trade">
            <div class="dyl-sec-title">交易规则</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="顾客可消费日期">
                <el-date-picker v-model="form.consumeDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="yyyy-MM-dd HH:mm:ss" style="width: 100%" />
              </el-form-item>
              <el-form-item label="顾客不可消费日期">
                <el-date-picker v-model="form.excludeDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="yyyy-MM-dd HH:mm:ss" style="width: 100%" />
              </el-form-item>
              <el-form-item label="每日消费时段">
                <el-time-picker v-model="form.dailyTimeRange" is-range range-separator="至" start-placeholder="开始" end-placeholder="结束" placeholder="选择时段" value-format="HH:mm:ss" style="width: 100%" />
              </el-form-item>
              <el-form-item label="限购规则">
                <el-input-number v-model="form.limitPerUser" :min="0" controls-position="right" />
                <span class="dyl-tip-inline">每人限购（0=不限）</span>
              </el-form-item>
              <el-form-item label="售后政策" prop="refundPolicy">
                <el-select v-model="form.refundPolicy" style="width: 100%">
                  <el-option label="支持随时退" value="ANYTIME" />
                  <el-option label="仅过期前可退" value="BEFORE_EXPIRE" />
                  <el-option label="不可退" value="NONE" />
                </el-select>
              </el-form-item>
              <el-form-item label="预约规则">
                <el-switch v-model="form.bookingRequired" :active-value="1" :inactive-value="0" active-text="需要预约" />
              </el-form-item>
              <el-form-item label="券码类型">
                <el-radio-group v-model="form.codeType">
                  <el-radio label="MERCHANT">商家券（本商户自行核销）</el-radio>
                  <el-radio label="PLATFORM">平台券（平台统一发码）</el-radio>
                </el-radio-group>
              </el-form-item>
            </el-form>
          </section>

          <!-- Tab: 交易规则（组合券包 — 不含消费时段/不可消费日期）-->
          <section v-if="isCombo" class="dyl-sec" :ref="'sec_trade'" data-sec="trade">
            <div class="dyl-sec-title">交易规则</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="顾客可消费日期">
                <el-date-picker v-model="form.consumeDateRange" type="datetimerange" range-separator="至" start-placeholder="开始" end-placeholder="结束" value-format="yyyy-MM-dd HH:mm:ss" style="width: 100%" />
              </el-form-item>
              <el-form-item label="限购规则">
                <el-input-number v-model="form.limitPerUser" :min="0" controls-position="right" />
                <span class="dyl-tip-inline">每人限购（0=不限）</span>
              </el-form-item>
              <el-form-item label="售后政策" prop="refundPolicy">
                <el-select v-model="form.refundPolicy" style="width: 100%">
                  <el-option label="支持随时退" value="ANYTIME" />
                  <el-option label="不可退" value="NONE" />
                </el-select>
              </el-form-item>
              <el-form-item label="券码类型">
                <el-radio-group v-model="form.codeType">
                  <el-radio label="MERCHANT">商家券（本商户自行核销）</el-radio>
                  <el-radio label="PLATFORM">平台券（平台统一发码）</el-radio>
                </el-radio-group>
              </el-form-item>
            </el-form>
          </section>

          <!-- Tab: 消费规则（团购+代金+组合券包都有）-->
          <section v-if="isGroupon || isVoucher || isCombo" class="dyl-sec" :ref="'sec_consume'" data-sec="consume">
            <div class="dyl-sec-title">消费规则</div>
            <el-form :model="form" label-width="120px" size="small">
              <el-form-item label="店内其他优惠">
                <el-radio-group v-model="form.storeOtherDiscount">
                  <el-radio label="SHARE">与店内优惠同享</el-radio>
                  <el-radio label="EXCLUSIVE">不与店内优惠同享</el-radio>
                </el-radio-group>
              </el-form-item>
              <el-form-item label="额外费用">
                <el-input v-model="form.extraFee" placeholder="如有额外费用请说明" />
              </el-form-item>
              <el-form-item label="使用张数限制">
                <el-input-number v-model="form.maxPerOrder" :min="1" :max="99" controls-position="right" />
                <span class="dyl-tip-inline">单次最多使用张数</span>
              </el-form-item>
              <el-form-item v-if="isGroupon" label="使用人数限制">
                <el-input-number v-model="form.maxPersons" :min="1" :max="99" controls-position="right" />
                <span class="dyl-tip-inline">单次最多使用人数</span>
              </el-form-item>
              <el-form-item v-if="isVoucher" label="适用范围">
                <el-radio-group v-model="form.scopeType">
                  <el-radio label="ALL">全场通用</el-radio>
                  <el-radio label="CATEGORY">按品类</el-radio>
                  <el-radio label="STORE">按门店</el-radio>
                </el-radio-group>
              </el-form-item>
              <el-form-item label="其他说明信息">
                <el-input v-model="form.notice" type="textarea" :rows="3" maxlength="300" show-word-limit />
              </el-form-item>
            </el-form>
          </section>
        </div>

        <div class="dyl-step2-footer">
          <span class="dyl-status-hint">
            当前状态：
            <el-tag :type="form.status === '0' ? 'success' : 'danger'" size="small">
              {{ form.status === '0' ? '已上架' : '未上架（草稿）' }}
            </el-tag>
            <span v-if="form.status !== '0'" class="dyl-tip" style="margin-left:8px">
              草稿不会展示给顾客，填完必填项后点「保存并上架」
            </span>
          </span>
          <div>
            <el-button type="primary" size="medium" :loading="saving" @click="saveAll">保存草稿</el-button>
            <el-button
              v-if="form.status !== '0'"
              type="success"
              size="medium"
              :loading="publishing"
              @click="saveAndPublish"
            >保存并上架</el-button>
            <el-button v-else size="medium" :loading="publishing" @click="unpublish">下架</el-button>
            <el-button @click="goBack">取消</el-button>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 类型选择弹窗（240-244 截图复刻）-->
    <el-dialog title="选择商品类型" :visible.sync="typePickerOpen" width="560px" append-to-body>
      <div class="dyl-type-picker">
        <div v-for="t in enabledTypeList" :key="t.typeCode"
             class="dyl-type-item"
             :class="{ active: form.typeCode === t.typeCode, disabled: !t.appCanCreate }"
             @click="pickType(t)">
          <div class="dyl-type-name">{{ t.typeName }}</div>
          <div class="dyl-type-desc">{{ t.typeDesc || t.description }}</div>
          <el-tag v-if="!t.appCanCreate" size="mini" type="info" effect="plain">平台暂未开放</el-tag>
          <i v-if="form.typeCode === t.typeCode" class="el-icon-check dyl-type-check"></i>
        </div>
      </div>
    </el-dialog>

    <!-- 商品搭配抽屉（团购：单品+商品组）-->
    <el-drawer :visible.sync="comboDrawer" direction="rtl" size="540px" :with-header="false" append-to-body>
      <div class="dyl-combo-drawer">
        <div class="dyl-combo-head">
          <el-button icon="el-icon-back" @click="comboDrawer = false" plain>返回</el-button>
          <span class="dyl-combo-title">{{ isCombo ? '组合商品搭配' : '商品搭配' }}</span>
        </div>
        <div class="dyl-combo-tip">
          {{ isCombo ? '每条搭配可选 团购套餐/代金券/满减券/折扣券 4 种类型，混合搭' : '添加单品和商品组（组内子品 N 选 1）' }}
        </div>
        <div v-if="isCombo" class="dyl-combo-list">
          <div v-for="(c, idx) in comboItems" :key="idx" class="dyl-combo-row">
            <el-input v-model="c.name" placeholder="搭配名称" size="small" style="margin-bottom: 6px" />
            <div class="dyl-combo-row2">
              <el-select v-model="c.subitemType" placeholder="类型" size="small" style="width: 130px">
                <el-option label="团购套餐" value="GROUPON" />
                <el-option label="代金券" value="VOUCHER" />
                <el-option label="满减券" value="MANJIAN" />
                <el-option label="折扣券" value="ZHEKOU" />
              </el-select>
              <el-input-number v-model="c.pickQuantity" :min="1" size="small" controls-position="right" style="width: 90px" />
              <el-select v-model="c.pickRule" size="small" style="width: 110px">
                <el-option label="全部可享" value="ALL" />
                <el-option label="1选1" value="PICK_1" />
                <el-option label="2选2" value="PICK_2" />
              </el-select>
              <el-button type="text" icon="el-icon-delete" @click="comboItems.splice(idx, 1)" />
            </div>
            <el-input-number v-model="c.price" :min="0" :precision="2" :step="1" size="small" controls-position="right" placeholder="单价" style="width: 100%" />
          </div>
          <el-button size="small" type="primary" plain icon="el-icon-plus" @click="comboItems.push(blankCombo())" style="width: 100%">+ 添加搭配</el-button>
          <div class="dyl-combo-total">总价值（用户侧划线价）<b>¥{{ totalComboValue }}</b></div>
        </div>
        <div v-else class="dyl-combo-list">
          <div v-for="g in subitemGroups" :key="g.groupId" class="dyl-combo-group">
            <div class="dyl-combo-group-head">
              <span>{{ g.groupName }}</span>
              <el-tag size="mini" :type="isPickAll(g) ? 'success' : 'warning'">{{ pickRuleText(g) }}</el-tag>
              <el-button type="text" icon="el-icon-delete" @click="onDeleteGroup(g)" />
            </div>
            <div v-for="s in g.subitems" :key="s.subitemId" class="dyl-combo-subitem">
              {{ s.subitemName }} × {{ s.quantity }} · ¥{{ s.price }}
            </div>
            <el-button size="mini" plain icon="el-icon-plus" @click="openAddSubitem(g)">添加单品</el-button>
            <!-- 几选几放在组的最后：选项要按本组实际单品数生成，
                 所以必须等单品加完才有意义 -->
            <div v-if="groupSize(g) > 0" class="dyl-combo-group-rule">
              <span class="dyl-combo-group-rule-label">本组顾客可选</span>
              <el-select
                :value="g.pickRule || 'ALL'"
                size="mini"
                style="width: 150px"
                @change="val => onGroupRuleChange(g, val)"
              >
                <el-option
                  v-for="opt in pickRuleOptions(g)"
                  :key="opt.value"
                  :label="opt.label"
                  :value="opt.value"
                />
              </el-select>
            </div>
          </div>
          <el-button size="small" type="primary" plain icon="el-icon-plus" @click="openAddGroup" style="width: 100%; margin-top: 8px">+ 添加商品组</el-button>
        </div>
        <div class="dyl-combo-footer">
          <el-button type="primary" @click="saveCombo" :loading="savingCombo">保存</el-button>
        </div>
      </div>
    </el-drawer>

    <!-- 添加商品组/子品的内部弹窗（兼容老 index.vue 的 subitem 接口）-->
    <el-dialog title="添加商品组" :visible.sync="groupOpen" width="420px" append-to-body>
      <el-form :model="groupForm" label-width="100px" size="small">
        <el-form-item label="组名称"><el-input v-model="groupForm.groupName" placeholder="如：主食" /></el-form-item>
        <el-alert
          type="info"
          :closable="false"
          show-icon
          title="新建时默认「全部可选」，添加完单品后可在组内设置几选几"
          style="margin-bottom: 12px"
        />
        <el-form-item label="排序"><el-input-number v-model="groupForm.sort" :min="0" /></el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="groupOpen = false">取 消</el-button>
        <el-button type="primary" @click="submitAddGroup">添 加</el-button>
      </div>
    </el-dialog>
    <el-dialog title="添加子品" :visible.sync="subitemOpen" width="420px" append-to-body>
      <el-form :model="subitemForm" label-width="100px" size="small">
        <el-form-item label="所属组"><span>{{ subitemForm._groupName }}</span></el-form-item>
        <el-form-item label="子品名称">
          <el-select
            v-model="subitemForm.subitemName"
            filterable
            allow-create
            default-first-option
            remote
            :remote-method="searchSubitemName"
            :loading="nameLoading"
            placeholder="输入可筛选历史子品，也可直接输入新名称"
            style="width: 100%"
          >
            <el-option v-for="n in nameOptions" :key="n" :label="n" :value="n" />
          </el-select>
        </el-form-item>
        <el-form-item label="数量"><el-input-number v-model="subitemForm.quantity" :min="1" /></el-form-item>
        <el-form-item label="单价"><el-input-number v-model="subitemForm.price" :min="0" :precision="2" :step="1" /></el-form-item>
      </el-form>
      <div slot="footer">
        <el-button @click="subitemOpen = false">取 消</el-button>
        <el-button type="primary" @click="submitAddSubitem">添 加</el-button>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { showMerchantField, currentMerchantId as identityMerchantId } from "@/utils/identity"
import { treeCategory } from '@/api/biz/category'
import { addProduct, updateProduct, getProduct, changeProductStatus } from '@/api/biz/product'
import { selectProductTypeList } from '@/api/biz/productType'
import { enabledSaleChannel } from '@/api/biz/saleChannel'
import { listMerchant } from '@/api/biz/merchant'
import { listGroups, addGroup, updateGroup, delGroup, addSubitem, delSubitem, listSubitemNameCandidates } from '@/api/biz/productSubitem'

export default {
  name: 'ProductCreate',
  data() {
    return {
      // ===== 步骤 1：基础信息 =====
      basicCollapsed: false,
      typePickerOpen: false,
      categoryTree: [],
      typeList: [],
      savingBasic: false,
      basicRules: {
        // required 按身份动态取值：商户账号看不到这个下拉，
        // 若写死 required，el-form 在 v-if 移除 DOM 后仍会校验，提交会被卡死
        merchantId: [{ required: this.isShowMerchantSelect(), message: '请选择所属商家', trigger: 'change' }],
        categoryId: [{ required: true, message: '请选择商品品类', trigger: 'change' }],
        typeCode: [{ required: true, message: '请选择商品类型', trigger: 'change' }],
        productName: [{ required: true, message: '请输入商品名称', trigger: 'blur' }]
      },
      // ===== 步骤 2：tab 状态 =====
      activeTab: 'basicG',
      saving: false,
      // ===== 子品/搭配 =====
      publishing: false,
      suppressScrollSpy: false,
      scrollSpyTimer: null,
      comboDrawer: false,
      savingCombo: false,
      subitemGroups: [],
      comboItems: [],
      groupOpen: false,
      groupForm: { productId: null, groupName: '', pickRule: 'ALL', sort: 0 },
      subitemOpen: false,
      nameOptions: [],
      nameLoading: false,
      subitemForm: { productId: null, groupId: null, _groupName: '', subitemName: '', quantity: 1, price: 0 },
      // ===== 投放渠道字典 =====
      channelList: [],
      channelDefaultCodes: '',
      // ===== 表单 =====
      showMerchantSelect: this.isShowMerchantSelect(),
      merchantOptions: [],
      form: {
        productId: null,
        merchantId: null,
        categoryId: null,
        categoryIdArr: null,
        industryCode: '',
        typeCode: '',
        productName: '',
        subtitle: '',
        cover: '',
        images: '',
        price: null,
        marketPrice: null,
        stock: 0,
        sales: 0,
        sort: 0,
        validityDays: 30,
        productType: '0',
        status: '1',   // 新建先落草稿（下架态）；后端对非上架态只做基础校验
        delFlag: '0',
        // v2 字段
        faceValue: null,
        minConsume: null,
        totalTimes: null,
        periodType: null,
        periodCount: null,
        totalValue: null,
        subitemPickRule: 'ALL',
        requireXiaoxin: 0,
        // tab 字段
        storeIdList: [],
        collectMethod: 'HEAD',
        saleChannels: [],          // 由 loadChannels() 用字典的 defaultCodes 填充
        staffPromote: 0,
        saleDateRange: [],
        codeType: 'MERCHANT',
        outerSubitemId: '',
        consumeDateRange: [],
        excludeDateRange: [],
        dailyTimeRange: [],
        limitPerUser: 0,
        refundPolicy: 'ANYTIME',
        bookingRequired: 0,
        storeOtherDiscount: 'EXCLUSIVE',
        extraFee: '',
        maxPerOrder: 1,
        maxPersons: 1,
        scopeType: 'ALL',
        notice: '',
        detail: '',
        voucherType: 'GENERAL',
        voucherRules: ['ALL_CATEGORY', 'ALL_BRAND']
      }
    }
  },
  computed: {
    /** 第 2 步只读回显：按 form.merchantId 找商户名，找不到就显示 ID 而不是登录账号名 */
    merchantLabel() {
      const id = this.form.merchantId
      if (!id) return ''
      const hit = (this.merchantOptions || []).find(m => m.merchantId === id)
      return hit ? hit.merchantName : ('商户 #' + id)
    },
    /** 当前商家对应的收款方式（只读展示用） */
    collectMethodLabel() {
      if (!this.form.merchantId) return ''
      return this.form.collectMethod === 'STORE' ? '门店独立收款' : '总部统一收款'
    },
    enabledTypeList() { return (this.typeList || []).filter(t => t.status === '0' || t.status === 0) },
    typeName() {
      const t = (this.typeList || []).find(x => x.typeCode === this.form.typeCode)
      return t ? t.typeName : ''
    },
    isGroupon() { return this.form.typeCode === 'GROUPON' },
    isVoucher() { return this.form.typeCode === 'VOUCHER' },
    isCombo() { return this.form.typeCode === 'COMBO' },
    isHuixiang() { return this.form.typeCode === 'HUIXIANG_CARD' },
    // 代金券首 tab 特殊命名
    merchantTabLabel() {
      if (this.isGroupon) return '商家信息'
      if (this.isVoucher) return '商品类型'
      return '商家信息'
    },
    namePlaceholder() {
      if (this.isVoucher && this.form.faceValue) return this.autoVoucherName
      return '请输入商品名称'
    },
    autoVoucherName() {
      const v = this.form.faceValue
      if (v && Number(v) > 0) return `${Number(v).toFixed(0)}元代金券`
      return '代金券'
    },
    /**
     * 锚点导航项，条件必须与各 section 的 v-if 一致。
     * 商品类型决定显示哪些区块（团购/代金券/组合券包各不相同），
     * 所以这里按 isGroupon / isVoucher / isCombo 过滤。
     */
    visibleSections() {
      const list = []
      if (this.isGroupon || this.isVoucher) list.push({ name: 'basicG', label: '基础信息' })
      if (this.isCombo) list.push({ name: 'basic', label: '基础信息' })
      if (this.isGroupon || this.isVoucher) list.push({ name: 'merchant', label: this.merchantTabLabel })
      if (this.isCombo) list.push({ name: 'qualify', label: '商品资质' })
      list.push({ name: 'product', label: '商品信息' })
      list.push({ name: 'sale', label: '售卖信息' })
      list.push({ name: 'trade', label: '交易规则' })
      list.push({ name: 'consume', label: '消费规则' })
      return list
    },
    subitemGroupsCount() {
      return (this.subitemGroups || []).reduce((sum, g) => sum + (g.subitems || []).length, 0)
    },
    totalPickCount() {
      // 团购套餐的「实际可享」= 各组可选数之和
      return (this.subitemGroups || []).reduce((sum, g) => sum + this.groupPickCount(g), 0)
    },
    comboItemsCount() { return (this.comboItems || []).length },
    totalComboValue() {
      return (this.comboItems || []).reduce((sum, c) => sum + Number(c.pickQuantity || 0) * Number(c.price || 0), 0)
    },
    autoComboPrice() {
      // 简单：90% 折扣
      return (Number(this.totalComboValue || 0) * 0.9).toFixed(2)
    },
    /**
     * 投放渠道按 channelGroup 分组，供模板两层渲染。
     * 抖音来客的投放渠道子页就是分组列表（不是扁平多选），每条下方还有规则说明。
     */
    channelGroups() {
      const labels = { SELF: '自有渠道', SOCIAL: '社交分享', OFFLINE: '线下物料' }
      const map = {}
      const order = []
      ;(this.channelList || []).forEach(c => {
        const g = c.channelGroup || 'OTHER'
        if (!map[g]) { map[g] = []; order.push(g) }
        map[g].push(c)
      })
      return order.map(g => ({ name: g, label: labels[g] || g, items: map[g] }))
    }
  },
  created() {
    this.loadCategory()
    this.loadTypeList()
    // 商户账号：商家就是自己，直接钉住 token 里的 merchantId
    // （原先这里用 store.user.name 兜底，平台账号会显示成登录名 "admin"）
    const myMerchantId = identityMerchantId()
    if (myMerchantId) this.$set(this.form, 'merchantId', myMerchantId)
    this.loadMerchantOptions()
    this.loadChannels()
    this.applyRouteTarget()
  },
  /**
   * 本页被 keep-alive 缓存（路由 meta 没设 noCache），而 AppMain 的
   * :key 只用 $route.path、不含 query。所以第二次进来时组件是复用的，
   * created 不会再执行 —— 表现就是「点任何一行编辑，打开的都是第一次
   * 编辑过的那个商品」。必须在 activated 里重新按当前 query 对齐。
   */
  activated() {
    this.applyRouteTarget()
  },
  mounted() {
    // 必须绑在真实滚动容器上（RuoYi 里是 .app-main 而不是 window），
    // 绑错对象的话滚动时收不到任何事件，高亮完全不动。
    // nextTick 等第 2 步的 DOM 渲染出来再找容器。
    this.$nextTick(() => {
      const sp = this.scrollParent()
      // passive：只读滚动位置不阻止默认行为，避免拖慢滚动
      sp.addEventListener('scroll', this.onScrollSpy, { passive: true })
      this._boundScroller = sp
    })
  },
  /*
   * 合并自原先两个 watch 块。
   * 原来 data 之后有一个 watch（form.faceValue 自动命名），methods 之前又有一个 watch
   * （form.productId 重绑滚动容器）—— 同一个对象字面量里出现两个同名 key，
   * 后者直接覆盖前者，所以「填了面值自动带出 xx元代金券」这个功能从来没生效过。
   */
  watch: {
    'form.faceValue'(v) {
      if (this.isVoucher && v && !this.form.productName) {
        this.form.productName = this.autoVoucherName
      }
    },
    // 第 2 步是 v-if="form.typeCode && form.productId" —— 新建流程里
    // mounted 时它还不存在，容器高度不够会被判成不可滚动。
    // 等第 2 步真正渲染出来后重新探测并绑定。
    'form.productId'(val) {
      if (!val) return
      this.$nextTick(() => this.rebindScroller())
    },
    /**
     * 收款方式跟随所属商家的支付配置（biz_merchant.pay_mode：0 商户自有商户号 /
     * 1 平台统一收款），不再由运营手选。
     * 也监听 merchantOptions：商户列表是异步拉的，切商家时可能还没到手。
     */
    'form.merchantId'() { this.syncCollectMethod() },
    merchantOptions() { this.syncCollectMethod() }
  },
  beforeDestroy() {
    // 不移除会在离开页面后继续跑，并因 $refs 已销毁而报错
    if (this._boundScroller) {
      this._boundScroller.removeEventListener('scroll', this.onScrollSpy)
    }
    clearTimeout(this.scrollSpyTimer)
  },
  methods: {
    /**
     * 按当前路由 query 对齐页面要编辑的目标商品。
     *
     * created 和 activated 都会调：首次进入走 created，从缓存里复活走 activated。
     * 用 productId 比对，相同就不重复请求（避免每次切标签都白拉一次接口）。
     */
    applyRouteTarget() {
      const pid = this.$route.query.productId
      const current = this.form.productId
      if (pid) {
        // 已经是这个商品就不重复加载
        if (String(current || '') === String(pid)) return
        this.resetPageState()
        this.loadProduct(pid)
      } else {
        // 没带 productId 是「新增」。若上次编辑的残留还在，会出现
        // 点了新增却看到上一个商品数据、一保存就把它改掉的问题。
        if (current) this.resetPageState()
      }
    },
    /**
     * 把页面恢复到刚打开的状态。
     *
     * 用 $options.data() 取初始值而不是逐字段写：form 有 50+ 字段，
     * 手写重置清单一定会跟不上字段增减，漏掉的那个就会串到下一个商品上。
     * merchantId 要在重置后重新钉一次 —— 商户账号的商家就是自己。
     */
    resetPageState() {
      const fresh = this.$options.data.call(this)
      this.form = fresh.form
      this.subitemGroups = []
      this.comboItems = []
      this.comboDrawer = false
      this.basicCollapsed = false
      this.activeTab = fresh.activeTab
      const myMerchantId = identityMerchantId()
      if (myMerchantId) this.$set(this.form, 'merchantId', myMerchantId)
      if (this.$refs.basicForm) this.$refs.basicForm.clearValidate()
    },
    /** 商户账号(userType=2)看不到商家下拉：它只能给自己建商品 */
    isShowMerchantSelect() {
      return showMerchantField()
    },
    /**
     * 按所属商家的 pay_mode 推导收款方式。
     * 目前两种 pay_mode 都落 HEAD —— 只有门店各自持商户号才算 STORE，
     * 当前数据模型（商户级支付配置）还没有这种形态，等有了再扩展这里。
     */
    syncCollectMethod() {
      const id = this.form.merchantId
      if (!id) return
      const hit = (this.merchantOptions || []).find(m => Number(m.merchantId) === Number(id))
      if (!hit) return
      this.$set(this.form, 'collectMethod', 'HEAD')
    },
    /** 拉商户列表，仅用于第 2 步只读回显商家名（下拉本身由 BizSelect 自己拉） */
    loadMerchantOptions() {
      listMerchant({ pageNum: 1, pageSize: 200 }).then(res => {
        this.merchantOptions = (res && (res.rows || res.data)) || []
      }).catch(() => { this.merchantOptions = [] })
    },
    loadCategory() {
      // /biz/category/list 返回的是扁平分页数据，el-cascader 需要 children 嵌套树
      treeCategory().then(res => {
        this.categoryTree = (res && (res.data || res)) || []
      }).catch(() => { this.categoryTree = [] })
    },
    loadTypeList() {
      selectProductTypeList().then(res => {
        this.typeList = (res.rows || []).filter(t => t.status === '0' || t.status === 0)
      })
    },
    /**
     * 拉投放渠道字典。默认勾选项由服务端算（is_default=1 且启用中），
     * 不在前端写死：平台停用某个渠道后，前端不该还把它当默认值提上来。
     * 只有新建（还没有 productId）才套默认值，编辑时以商品已存的渠道为准。
     */
    loadChannels() {
      enabledSaleChannel().then(res => {
        this.channelList = (res && res.data) || []
        this.channelDefaultCodes = (res && res.defaultCodes) || ''
        if (!this.form.productId && !(this.form.saleChannels || []).length) {
          this.form.saleChannels = this.channelDefaultCodes ? this.channelDefaultCodes.split(',').filter(v => v) : []
        }
      }).catch(() => { this.channelList = [] })
    },
    loadProduct(pid) {
      getProduct(pid).then(res => {
        // request 拦截器返回整个 AjaxResult，商品在 res.data
        const p = (res && (res.data || res)) || {}
        this.form = Object.assign({}, this.form, p)
        this.form.productId = p.productId || Number(pid)
        this.form.categoryIdArr = p.categoryId
        // 多门店回填：后端返 storeIds 逗号串，表单用 storeIdList 数组
        this.form.storeIdList = p.storeIds ? String(p.storeIds).split(',').filter(v => v).map(v => Number(v)) : []
        this.basicCollapsed = true
        this.activeTab = this.isCombo ? 'basic' : 'basicG'
        // 组合搭配回显：不还原的话，编辑已有商品时抽屉是空的，
        // 一保存就会把之前配好的搭配覆盖成空数组。
        this.comboItems = this.parseComboItems(p.ext && p.ext.comboItemsJson)
        this.unpackExtToForm(p)
        if (this.isGroupon || this.isCombo) this.loadSubitems()
      }).catch(e => {
        this.$modal.msgError((e && (e.msg || e.message)) || '商品加载失败')
      })
    },

    /** 提交表单：有 productId 走 PUT 修改，否则 POST 新增 */
    saveProduct() {
      const payload = Object.assign({}, this.form)
      payload.storeIds = (this.form.storeIdList || []).join(',')
      delete payload.categoryIdArr
      this.packFormToExt(payload)
      return payload.productId ? updateProduct(payload) : addProduct(payload)
    },

    /**
     * 把表单里那些「后端属性名/结构对不上」的字段映射成后端认识的形状。
     *
     * 背景：这一批输入框在页面上早就有，但提交后被 Jackson 直接丢掉 ——
     * 因为 Product / ProductExt 域里没有同名属性。运营填完保存没有任何报错，
     * 库里却什么都没存。佐证：全库 357 个商品里只有 2 个有 extra_fee_desc、
     * 35 个有 sale_start_date，说明这些框从上线起就没生效过。
     *
     * 分两类处理：
     *  1) 主表已有同义属性，只是名字/结构不一致 → 直接改名或拆数组
     *     saleDateRange[]      → saleStartDate / saleEndDate
     *     extraFee             → extraFeeDesc
     *     storeOtherDiscount   → mutexWithStorePromotion（SHARE=0 同享 / EXCLUSIVE=1 不同享）
     *  2) 主表确实没有 → 落 biz_product_ext（v4 已加列）
     */
    packFormToExt(payload) {
      const f = this.form
      const pick = (arr, i) => (Array.isArray(arr) && arr.length > i ? arr[i] : null)

      // --- 1) 主表同义字段 ---
      payload.saleStartDate = pick(f.saleDateRange, 0)
      payload.saleEndDate = pick(f.saleDateRange, 1)
      payload.extraFeeDesc = f.extraFee || ''
      // 页面是「与店内优惠同享 / 不与店内优惠同享」，库里是 tinyint 的「互斥」语义，取值要反过来
      payload.mutexWithStorePromotion = f.storeOtherDiscount === 'SHARE' ? 0 : 1

      // --- 2) 落 ext ---
      const ext = Object.assign({}, payload.ext || {})
      ext.saleChannels = (f.saleChannels || []).join(',')
      ext.staffPromote = f.staffPromote ? 1 : 0
      ext.codeType = f.codeType || 'MERCHANT'
      ext.consumeStartDate = pick(f.consumeDateRange, 0)
      ext.consumeEndDate = pick(f.consumeDateRange, 1)
      // 不可消费日期：库里存 JSON 数组，为将来支持多段排除留出结构
      // （抖音来客这一项可以加多段，我们先存一段但用同样的容器）
      const exStart = pick(f.excludeDateRange, 0)
      const exEnd = pick(f.excludeDateRange, 1)
      ext.excludeDates = exStart && exEnd ? JSON.stringify([[exStart, exEnd]]) : ''
      ext.dailyTimeStart = pick(f.dailyTimeRange, 0) || ''
      ext.dailyTimeEnd = pick(f.dailyTimeRange, 1) || ''
      ext.voucherRules = (f.voucherRules || []).join(',')
      // 券类型（通兑/单品类）与「适用范围」共用 ext.voucherScopeType：
      // 代金券类型走 voucherType，消费规则里的适用范围走 scopeType，两者不会同屏出现
      ext.voucherScopeType = this.isVoucher ? (f.scopeType || 'ALL') : (f.voucherType || 'GENERAL')
      payload.ext = ext

      // 这些 key 后端没有，留着只会在日志里刷未知属性告警
      ;['saleDateRange', 'extraFee', 'storeOtherDiscount', 'consumeDateRange',
        'excludeDateRange', 'dailyTimeRange', 'voucherRules', 'voucherType',
        'scopeType', 'saleChannels', 'staffPromote', 'codeType'
      ].forEach(k => { delete payload[k] })
      return payload
    },

    /** packFormToExt 的逆操作：编辑已有商品时把库里的值还原成表单形状 */
    unpackExtToForm(p) {
      const ext = (p && p.ext) || {}
      const range = (a, b) => (a && b ? [a, b] : [])

      this.$set(this.form, 'saleDateRange', range(p.saleStartDate, p.saleEndDate))
      this.$set(this.form, 'extraFee', p.extraFeeDesc || '')
      this.$set(this.form, 'storeOtherDiscount', p.mutexWithStorePromotion === 0 ? 'SHARE' : 'EXCLUSIVE')

      // 渠道：库里有值就用库里的；为空（老数据）才退回字典默认，
      // 否则编辑一个老商品会看到「一个渠道都没勾」的假象
      const chs = ext.saleChannels ? String(ext.saleChannels).split(',').filter(v => v) : []
      this.$set(this.form, 'saleChannels', chs.length ? chs : (this.channelDefaultCodes ? this.channelDefaultCodes.split(',').filter(v => v) : []))
      this.$set(this.form, 'staffPromote', ext.staffPromote ? 1 : 0)
      this.$set(this.form, 'codeType', ext.codeType || 'MERCHANT')
      this.$set(this.form, 'consumeDateRange', range(ext.consumeStartDate, ext.consumeEndDate))
      this.$set(this.form, 'excludeDateRange', this.parseExcludeDates(ext.excludeDates))
      this.$set(this.form, 'dailyTimeRange', range(ext.dailyTimeStart, ext.dailyTimeEnd))
      this.$set(this.form, 'voucherRules', ext.voucherRules ? String(ext.voucherRules).split(',').filter(v => v) : [])
      const scope = ext.voucherScopeType || ''
      if (this.isVoucher) {
        this.$set(this.form, 'scopeType', scope || 'ALL')
      } else {
        this.$set(this.form, 'voucherType', scope || 'GENERAL')
      }
    },

    /** ext.excludeDates 存的是 [[start,end], ...]，表单目前只用第一段 */
    parseExcludeDates(json) {
      if (!json) return []
      try {
        const arr = JSON.parse(json)
        if (Array.isArray(arr) && arr.length && Array.isArray(arr[0]) && arr[0].length === 2) {
          return [arr[0][0], arr[0][1]]
        }
      } catch (e) { /* 脏数据当空处理，不要因为一条坏 JSON 打不开编辑页 */ }
      return []
    },
    onCategoryChange(v) {
      // cascader 绑的是 categoryIdArr，但表单校验和提交用的是 categoryId，必须同步
      const id = Array.isArray(v) ? v[v.length - 1] : v
      this.$set(this.form, 'categoryId', id || null)
      const findIndustry = (tree, target) => {
        for (const n of (tree || [])) {
          if (n.categoryId === target) return n.industryCode || ''
          if (n.children) { const r = findIndustry(n.children, target); if (r) return r }
        }
        return ''
      }
      this.form.industryCode = findIndustry(this.categoryTree, id) || ''
      if (this.$refs.basicForm) {
        this.$refs.basicForm.validateField('categoryId')
      }
    },
    /** 按 categoryId 找品类名（供只读回显用；带参数不能放 computed）*/
    categoryNameOf(id) {
      if (!id) return ''
      const find = (tree) => {
        for (const n of (tree || [])) {
          if (n.categoryId === id) return n.categoryName
          if (n.children) { const r = find(n.children); if (r) return r }
        }
        return ''
      }
      return find(this.categoryTree)
    },
    pickType(t) {
      if (!t.appCanCreate) {
        this.$alert('该类型暂不支持在抖音来客App创建', '提示', { type: 'warning' })
        return
      }
      this.form.typeCode = t.typeCode
      this.typePickerOpen = false
    },
    viewRules() {
      this.$alert('该品类对应平台的发布细则要求', '商品发布细则', { type: 'info' })
    },
    openTutorial() {
      this.$alert('抖音来客风格商品创建流程：第1步选类型 → 第2步6个tab填写 → 保存', '上品教程', { type: 'info' })
    },
    goBack() { this.$router.back() },
    goStep2() {
      this.$refs.basicForm.validate(valid => {
        if (!valid) return
        // 校验名称
        if (this.isVoucher && !this.form.faceValue) {
          this.$modal.msgError('代金券请输入面值')
          return
        }
        this.savingBasic = true
        this.saveProduct().then(res => {
          // 后端 POST /biz/product 回传自增主键（data 即 productId）
          if (!this.form.productId) {
            const d = res && res.data
            this.form.productId = (d && d.productId) || d
          }
          if (!this.form.productId) {
            this.$modal.msgError('保存成功但未取到商品ID，请返回列表用「高级编辑」继续')
            return
          }
          this.basicCollapsed = true
          this.$modal.msgSuccess('基础信息已保存，请继续填写商品详情')
          if (this.isGroupon || this.isCombo) this.loadSubitems()
        }).catch(e => {
          this.$modal.msgError((e && (e.msg || e.message)) || '保存失败')
        }).finally(() => { this.savingBasic = false })
      })
    },
    saveAll() {
      if (!this.form.productId) {
        this.$modal.msgError('请先完成基础信息')
        return
      }
      this.saving = true
      this.saveProduct().then(() => {
        this.$modal.msgSuccess('保存成功')
        this.goBack()
      }).catch(e => {
        this.$modal.msgError((e && (e.msg || e.message)) || '保存失败')
      }).finally(() => { this.saving = false })
    },
    /**
     * 保存并上架。
     *
     * 新建商品一律先落草稿（下架态）—— 第 1 步只填品类/类型/名称就要落库拿
     * productId，那时必填项还没填完，不可能直接上架。所以上架是个独立动作，
     * 这里把「保存 + 上架」串起来，避免用户填完了还得回列表再点一次上架。
     *
     * 先 saveProduct 落当前填写内容，再单独调 status 端点上架：
     * 上架端点会跑完整必填校验，缺字段会明确返回缺哪一项，用户留在本页即可补。
     */
    saveAndPublish() {
      if (!this.form.productId) {
        this.$modal.msgError('请先完成基础信息')
        return
      }
      this.publishing = true
      this.saveProduct().then(() => {
        return changeProductStatus(this.form.productId, '0')
      }).then(() => {
        this.$set(this.form, 'status', '0')
        this.$modal.msgSuccess('已上架，顾客现在可以在小程序看到该商品')
        this.goBack()
      }).catch(e => {
        // 上架校验失败时不跳走，让用户就地补字段
        this.$modal.msgError((e && (e.msg || e.message)) || '上架失败')
      }).finally(() => { this.publishing = false })
    },
    /** 下架：不跑必填校验，已经有问题的商品必须允许随时撤下来 */
    unpublish() {
      if (!this.form.productId) return
      this.publishing = true
      changeProductStatus(this.form.productId, '1').then(() => {
        this.$set(this.form, 'status', '1')
        this.$modal.msgSuccess('已下架，顾客将不再看到该商品')
      }).catch(e => {
        this.$modal.msgError((e && (e.msg || e.message)) || '下架失败')
      }).finally(() => { this.publishing = false })
    },
    // ===== 锚点导航（滚动 ↔ 高亮 双向联动）=====

    /** 取某个 section 的真实 DOM（:ref 在 v-for/v-if 下可能是数组） */
    sectionEl(name) {
      const r = this.$refs['sec_' + name]
      if (!r) return null
      return Array.isArray(r) ? r[0] : r
    },
    /**
     * 找真正在滚动的祖先容器。
     *
     * 这里不能想当然用 window：RuoYi 的布局里 .app-main 自己是
     * overflow-y: auto，页面滚动发生在它内部，window 根本不会触发 scroll，
     * 吸顶和高亮就都不工作。所以往上找第一个真正可滚动的祖先，
     * 找不到才回退到 window（比硬编码 '.app-main' 稳，布局改了也不会失效）。
     */
    scrollParent() {
      if (this._scrollParent) return this._scrollParent
      let node = this.$el && this.$el.parentElement
      while (node && node !== document.body) {
        const oy = window.getComputedStyle(node).overflowY
        if ((oy === 'auto' || oy === 'scroll') && node.scrollHeight > node.clientHeight) {
          this._scrollParent = node
          return node
        }
        node = node.parentElement
      }
      // 没找到时不缓存：第 2 步还没渲染（新建流程缺 productId）时内容不够高，
      // 会被判成不可滚动，缓存下来就再也不会重新探测了
      return window
    },
    /** 重新探测滚动容器并搬移监听（第 2 步渲染后调用） */
    rebindScroller() {
      const prev = this._boundScroller
      this._scrollParent = null
      const sp = this.scrollParent()
      if (prev === sp) return
      if (prev) prev.removeEventListener('scroll', this.onScrollSpy)
      sp.addEventListener('scroll', this.onScrollSpy, { passive: true })
      this._boundScroller = sp
    },
    /** 容器当前滚动距离（window 和普通元素取法不同） */
    scrollTopOf(sp) {
      return sp === window ? (window.pageYOffset || document.documentElement.scrollTop) : sp.scrollTop
    },
    /** 点导航 → 滚到对应区块 */
    scrollToSection(name) {
      const el = this.sectionEl(name)
      if (!el) return
      // 点击期间暂停滚动监听：平滑滚动过程会连续穿过中间区块，
      // 不抑制的话高亮会一路乱跳，最后才落到目标上。
      this.suppressScrollSpy = true
      this.activeTab = name
      const sp = this.scrollParent()
      const offset = this.anchorOffset()
      if (sp === window) {
        const top = el.getBoundingClientRect().top + this.scrollTopOf(sp) - offset
        window.scrollTo({ top, behavior: 'smooth' })
      } else {
        // 元素容器要换算成「相对容器」的偏移，不能直接用视口坐标
        const top = el.getBoundingClientRect().top - sp.getBoundingClientRect().top + sp.scrollTop - offset
        sp.scrollTo({ top, behavior: 'smooth' })
      }
      clearTimeout(this.scrollSpyTimer)
      this.scrollSpyTimer = setTimeout(() => { this.suppressScrollSpy = false }, 600)
    },
    /** 吸顶导航自身的高度，滚动定位要把它让出来，否则标题被盖住 */
    anchorOffset() {
      const nav = this.$refs.anchorNav
      return (nav ? nav.offsetHeight : 0) + 12
    },
    /**
     * 滚动 → 高亮当前区块。
     *
     * 判定方式是「最后一个顶部已越过判定线的区块」，而不是找最接近的：
     * 区块高度差异很大（商品信息很长、商品资质很短），按距离最近算会在
     * 长区块内部就提前跳到下一个。
     */
    onScrollSpy() {
      if (this.suppressScrollSpy) return
      const sp = this.scrollParent()
      // 判定线用「容器顶部 + 导航高度」，容器不是 window 时视口坐标 0 并不是
      // 容器的顶部，必须减掉容器自身的位置
      const baseTop = sp === window ? 0 : sp.getBoundingClientRect().top
      const line = baseTop + this.anchorOffset() + 20
      let current = null
      for (const sec of this.visibleSections) {
        const el = this.sectionEl(sec.name)
        if (!el) continue
        if (el.getBoundingClientRect().top - line <= 0) current = sec.name
      }
      // 滚到底部时把最后一个区块点亮：最后一块可能不够高，
      // 顶部永远越不过判定线，不特殊处理就永远高亮不到它。
      const atBottom = sp === window
        ? window.innerHeight + this.scrollTopOf(sp) >= document.body.scrollHeight - 40
        : sp.scrollTop + sp.clientHeight >= sp.scrollHeight - 40
      if (atBottom && this.visibleSections.length) {
        current = this.visibleSections[this.visibleSections.length - 1].name
      }
      if (current && current !== this.activeTab) this.activeTab = current
    },

    // ===== 商品组「几选几」=====
    // pickRule 统一用 'ALL'（全部可选）或 'PICK_N'（可选 N 个）。
    // 存量数据里还有小程序端写进去的中文 '1选1' / '3选2'，读的时候要兼容。
    //
    // 注意「个数」按单品品种数算，不看 quantity：
    // 一个组里有「红烧肉 ×2」「可乐 ×1」，是 2 个单品而不是 3 个 ——
    // quantity 是这道菜给几份，跟顾客能挑几样是两件事。

    /** 本组单品品种数 */
    groupSize(g) {
      return ((g && g.subitems) || []).length
    },
    /** 解析 pickRule 得到"可选几个"；无规则/ALL/超出范围都按全选 */
    groupPickCount(g) {
      const size = this.groupSize(g)
      const rule = g && g.pickRule
      if (!rule || rule === 'ALL') return size
      const m = String(rule).match(/^PICK_(\d+)$/)
      let n = m ? Number(m[1]) : null
      if (n == null) {
        // 兼容存量中文格式 'N选M'，取"选"后面那个数
        const cn = String(rule).match(/选\s*(\d+)$/)
        if (cn) n = Number(cn[1])
      }
      // 规则比实际单品数还大（改过单品但没改规则）按全选处理，不能返回比 size 大的数
      if (n == null || n <= 0 || n >= size) return size
      return n
    },
    isPickAll(g) {
      return this.groupPickCount(g) >= this.groupSize(g)
    },
    /** 标签文案：3 个单品全选 → 「共3个单品：3选3」；选 2 → 「共3个单品：3选2」 */
    pickRuleText(g) {
      const size = this.groupSize(g)
      if (size === 0) return '未添加单品'
      return '共' + size + '个单品：' + size + '选' + this.groupPickCount(g)
    },
    /**
     * 可选规则按本组单品数动态生成：3 个单品 → 全部可选(3选3) / 3选2 / 3选1。
     * 原先是硬编码 1选1/2选2/3选2，跟实际单品数完全脱节 ——
     * 2 个单品的组也能设成「3选2」，存进去就是没法履约的脏数据。
     */
    pickRuleOptions(g) {
      const size = this.groupSize(g)
      const opts = [{ value: 'ALL', label: '全部可选（' + size + '选' + size + '）' }]
      for (let n = size - 1; n >= 1; n--) {
        opts.push({ value: 'PICK_' + n, label: size + '选' + n })
      }
      return opts
    },
    /** 改规则立即落库，避免用户以为改了其实没保存 */
    onGroupRuleChange(g, val) {
      const old = g.pickRule
      this.$set(g, 'pickRule', val)
      updateGroup({ groupId: g.groupId, pickRule: val }).then(() => {
        this.$modal.msgSuccess('已设为「' + this.pickRuleText(g) + '」')
      }).catch(e => {
        this.$set(g, 'pickRule', old)
        this.$modal.msgError((e && (e.msg || e.message)) || '设置失败')
      })
    },

    // ===== 商品搭配 =====
    loadSubitems() {
      if (!this.form.productId) return
      listGroups(this.form.productId).then(res => {
        this.subitemGroups = (res && (res.data || res)) || []
      }).catch(() => { this.subitemGroups = [] })
    },
    openAddGroup() {
      this.groupForm = { productId: this.form.productId, groupName: '', pickRule: 'ALL', sort: 0 }
      this.groupOpen = true
    },
    submitAddGroup() {
      if (!this.groupForm.groupName) { this.$modal.msgError('请输入组名称'); return }
      addGroup(this.groupForm).then(() => {
        this.$modal.msgSuccess('已添加')
        this.groupOpen = false
        this.loadSubitems()
      })
    },
    onDeleteGroup(g) {
      this.$modal.confirm('确认删除商品组「' + g.groupName + '」？').then(() => delGroup(g.groupId)).then(() => {
        this.$modal.msgSuccess('已删除'); this.loadSubitems()
      }).catch(() => {})
    },
    openAddSubitem(g) {
      this.subitemForm = { productId: this.form.productId, groupId: g.groupId, _groupName: g.groupName, subitemName: '', quantity: 1, price: 0 }
      this.subitemOpen = true
      this.searchSubitemName('')
    },
    /** 拉取历史子品名称候选（el-select remote） */
    searchSubitemName(keyword) {
      this.nameLoading = true
      listSubitemNameCandidates(keyword || '').then(res => {
        this.nameOptions = (res && (res.data || res)) || []
      }).catch(() => { this.nameOptions = [] })
        .finally(() => { this.nameLoading = false })
    },
    submitAddSubitem() {
      if (!this.subitemForm.subitemName) { this.$modal.msgError('请输入子品名称'); return }
      addSubitem(this.subitemForm).then(() => {
        this.$modal.msgSuccess('已添加'); this.subitemOpen = false; this.loadSubitems()
      })
    },
    onDeleteSubitem(g, s) {
      this.$modal.confirm('确认删除子品「' + s.subitemName + '」？').then(() => delSubitem(s.subitemId)).then(() => {
        this.$modal.msgSuccess('已删除'); this.loadSubitems()
      }).catch(() => {})
    },
    blankCombo() { return { name: '', subitemType: 'GROUPON', pickQuantity: 1, pickRule: 'ALL', price: 0 } },
    /** 解析库里存的搭配 JSON；脏数据不能让整个编辑页打不开，所以异常一律退回空列表 */
    parseComboItems(raw) {
      if (!raw) return []
      try {
        const arr = JSON.parse(raw)
        return Array.isArray(arr) ? arr : []
      } catch (e) {
        return []
      }
    },
    saveCombo() {
      // 团购走的是商品组/单品接口，加子品时就已经各自落库了，这里只需关抽屉。
      // 继续发商品 PUT 只会白跑一次请求。
      if (!this.isCombo) {
        this.comboDrawer = false
        return
      }
      this.savingCombo = true
      // 搭配明细存 ext.comboItemsJson（对应 biz_product_ext.combo_items_json）。
      // 以前写的是 subitemPickRuleJson —— 后端 Product 上根本没有这个属性，
      // Jackson 直接把它丢掉，所以搭配从来没真的存进过数据库。
      const payload = {
        productId: this.form.productId,
        typeCode: this.form.typeCode,
        totalValue: this.totalComboValue,
        ext: { comboItemsJson: JSON.stringify(this.comboItems) }
      }
      updateProduct(payload).then(() => {
        this.form.totalValue = this.totalComboValue
        this.$modal.msgSuccess('搭配已保存')
        this.comboDrawer = false
      }).catch(e => this.$modal.msgError((e && (e.msg || e.message)) || '保存失败'))
        .finally(() => { this.savingCombo = false })
    }
  }
}
</script>

<style scoped>
/* 不能用 100vh：本页渲染在 .app-main 内部，而 .app-main 的可视高度已经
   减掉了固定头（navbar 50 + tagsView 34），用 100vh 会多撑出 84px 空白。 */
.dyl-create { max-width: 960px; margin: 0 auto; padding: 12px; background: #f5f5f7; min-height: 100%; }
.dyl-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: #fff; border-radius: 8px; margin-bottom: 12px; }
.dyl-title { font-size: 18px; font-weight: 600; color: #161823; }
.dyl-card { margin-bottom: 12px; border-radius: 8px; }
.dyl-card-head { display: flex; align-items: center; cursor: pointer; }
.dyl-card-title { font-size: 16px; font-weight: 600; color: #161823; }
.dyl-card-tag { margin-left: 12px; font-size: 12px; color: #fe2c55; background: #ffe7eb; padding: 2px 8px; border-radius: 4px; }
.dyl-card-arrow { margin-left: auto; color: #999; }
.dyl-step1-footer { margin-top: 16px; padding-top: 16px; border-top: 1px solid #f0f0f0; }
/* overflow: visible 是吸顶能否生效的关键，不是样式偏好。
   element-ui 给 .el-card 设了 overflow: hidden，而吸顶导航就在这张卡片里。
   祖先一旦裁剪内容，它就成了 sticky 的"滚动容器"，可这张卡片自己从不滚动，
   于是导航会跟着内容一路向上跑出可视区 —— 表现就是滚动时导航冲到页签
   底下不见了，像是"吸顶位置偏高被页签挡住"。
   Chrome 实测：祖先 hidden 时滚 800px，导航 top 从 157 掉到 -643（完全失效）；
   改 visible 后稳定停在容器顶部 84px。
   注意这条必须落在 .el-card 这一层，写在导航自己身上是无效的（同样实测过：
   导航自身有没有 overflow 对吸顶毫无影响，起决定作用的只有祖先）。 */
.dyl-card-step2 { padding-bottom: 60px; overflow: visible; }
/* 吸顶锚点导航（替代原 el-tabs）*/
/* 横向滚动放在内层 track 而不是导航本身：纯粹为了让滚动条只出现在按钮那一行，
   不影响导航整体的内边距和圆角。 */
/* z-index 只需压住卡片内跟着滚动的表单内容即可。
   不必担心盖住外层页签：本页渲染在 .app-main 内，而 .app-main 自己
   overflow-y: auto 会裁剪内容，导航不可能溢出到固定头区域。 */
.dyl-anchor-nav {
  position: sticky; top: 0; z-index: 8;
  background: #fff; border-bottom: 1px solid #ebeef5;
  margin: -20px -20px 16px; padding: 12px 20px;
  /* 吸顶时补回卡片圆角，否则贴住时上缘会露出方角 */
  border-radius: 8px 8px 0 0;
}
.dyl-anchor-track {
  display: flex; gap: 4px; overflow-x: auto; white-space: nowrap;
}
/* 细横条滚动条，避免导航条被系统滚动条压高 */
.dyl-anchor-track::-webkit-scrollbar { height: 4px; }
.dyl-anchor-track::-webkit-scrollbar-thumb { background: #dcdfe6; border-radius: 2px; }
.dyl-anchor-item {
  flex-shrink: 0; padding: 6px 14px; font-size: 13px; color: #606266;
  cursor: pointer; border-radius: 4px; transition: all .2s;
}
.dyl-anchor-item:hover { color: #409EFF; background: #ecf5ff; }
.dyl-anchor-item.active { color: #fff; background: #409EFF; font-weight: 500; }

/* 连续区块：区块之间给足留白，滚动时能明显看出分段 */
.dyl-sec { padding-bottom: 8px; }
.dyl-sec + .dyl-sec { margin-top: 28px; border-top: 1px dashed #ebeef5; padding-top: 20px; }
.dyl-sec-title { font-size: 15px; font-weight: 600; color: #303133; margin-bottom: 16px; padding-left: 9px; border-left: 3px solid #409EFF; }
/* 锚点滚动时把吸顶导航的高度让出来，否则标题被导航盖住 */
.dyl-sec { scroll-margin-top: 60px; }

.dyl-tip { color: #999; font-size: 12px; margin-top: 4px; }
.dyl-tip-inline { color: #999; font-size: 12px; margin-left: 12px; }
.dyl-ch-group { margin-bottom: 10px; }
.dyl-ch-group + .dyl-ch-group { padding-top: 8px; border-top: 1px dashed #f0f0f0; }
.dyl-ch-group-title { font-size: 12px; color: #909399; margin-bottom: 4px; }
.dyl-ch-item { line-height: 1.4; margin-bottom: 6px; }
/* 字段级说明：抖音来客每个渠道条目下方都有一行灰字解释投放规则，
   我们原先一条说明都没有，运营只能靠猜 */
.dyl-ch-desc { color: #999; font-size: 12px; padding-left: 24px; }
.dyl-step2-footer { position: fixed; left: 0; right: 0; bottom: 0; background: #fff; padding: 12px 16px; box-shadow: 0 -2px 8px rgba(0,0,0,.04); z-index: 100; display: flex; align-items: center; justify-content: space-between; }
.dyl-status-hint { font-size: 13px; color: #606266; }
.dyl-step2-footer .el-button + .el-button { margin-left: 8px; }
.dyl-type-picker { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; max-height: 500px; overflow-y: auto; }
.dyl-type-item { position: relative; padding: 16px; border: 1px solid #f0f0f0; border-radius: 8px; cursor: pointer; transition: all .2s; }
.dyl-type-item:hover { border-color: #fe2c55; }
.dyl-type-item.active { border-color: #fe2c55; background: #fff5f7; }
.dyl-type-item.disabled { opacity: .45; cursor: not-allowed; }
.dyl-type-name { font-size: 15px; font-weight: 600; color: #161823; }
.dyl-type-desc { font-size: 12px; color: #999; margin-top: 4px; line-height: 1.5; }
.dyl-type-check { position: absolute; right: 12px; top: 12px; color: #fe2c55; font-size: 18px; }
.dyl-combo-drawer { padding: 16px; }
.dyl-combo-head { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.dyl-combo-title { font-size: 16px; font-weight: 600; }
.dyl-combo-tip { color: #999; font-size: 12px; padding: 8px 12px; background: #f5f5f7; border-radius: 4px; margin-bottom: 12px; }
.dyl-combo-row { padding: 10px; background: #fafafa; border-radius: 6px; margin-bottom: 8px; }
.dyl-combo-row2 { display: flex; gap: 6px; align-items: center; margin-bottom: 6px; }
.dyl-combo-total { text-align: right; padding: 12px 0; color: #161823; }
.dyl-combo-total b { color: #fe2c55; font-size: 18px; margin-left: 8px; }
.dyl-combo-group { padding: 10px; background: #fafafa; border-radius: 6px; margin-bottom: 8px; }
.dyl-combo-group-head { display: flex; align-items: center; gap: 8px; font-weight: 500; margin-bottom: 6px; }
.dyl-combo-group-head .el-button { margin-left: auto; }
.dyl-combo-subitem { padding: 4px 8px; color: #555; font-size: 13px; }
.dyl-combo-footer { text-align: center; padding: 16px 0; border-top: 1px solid #f0f0f0; }
</style>
