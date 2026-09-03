// identity.js 的行为测试（不是静态 grep）。
//
// 为什么需要它：smoke 里那些 grep 只能证明「页面调用了 showMerchantField()」，
// 证明不了这个函数还在按身份返回。实测把函数体改成 `return true`，
// 34 项 smoke 依然全绿 —— 商户会重新看到商户选择器而无人发现。
//
// 做法：identity.js 唯一的外部依赖是 `@/store`，把这行 import 换成内联 mock，
// 再用 data URL 动态导入真实源码执行，逐身份断言返回值。
import { readFileSync } from 'node:fs';

const SRC = 'ruoyi-ui/src/utils/identity.js';
const raw = readFileSync(SRC, 'utf8');

if (!/^import store from ['"]@\/store['"]/m.test(raw)) {
  console.error('identity.js 的 store 引入方式变了，本测试需同步更新');
  process.exit(1);
}

async function load(userType, merchantId) {
  const mock = `const store = { state: { user: { userType: ${JSON.stringify(userType)}, merchantId: ${JSON.stringify(merchantId)} } } };`;
  const code = raw.replace(/^import store from ['"]@\/store['"];?$/m, mock);
  return import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
}

let pass = 0, fail = 0;
const ck = (name, got, exp) => {
  const g = JSON.stringify(got), e = JSON.stringify(exp);
  if (g === e) { console.log(`PASS | ${name}`); pass++; }
  else { console.log(`FAIL | ${name} | got=${g} exp=${e}`); fail++; }
};

// 平台（userType=0）：什么都看得见
{
  const m = await load('0', null);
  ck('平台 isPlatform', m.isPlatform(), true);
  ck('平台 isMerchant', m.isMerchant(), false);
  ck('平台可见商户字段', m.showMerchantField(), true);
  ck('平台可见代理商字段', m.showAgentField(), true);
  ck('平台无自身商户', m.currentMerchantId(), null);
}

// 代理商（userType=1）：看得到商户和代理商，但那是它自己
{
  const m = await load('1', null);
  ck('代理商 isAgent', m.isAgent(), true);
  ck('代理商 isMerchant', m.isMerchant(), false);
  ck('代理商可见商户字段', m.showMerchantField(), true);
  ck('代理商可见代理商字段', m.showAgentField(), true);
}

// 商户（userType=2）：两个字段都必须隐藏，且能拿到自己的 merchantId
{
  const m = await load('2', 1);
  ck('商户 isMerchant', m.isMerchant(), true);
  ck('商户 isPlatform', m.isPlatform(), false);
  ck('商户隐藏商户字段', m.showMerchantField(), false);
  ck('商户隐藏代理商字段', m.showAgentField(), false);
  ck('商户拿得到自身 merchantId', m.currentMerchantId(), 1);
}

// 未登录 / store 未就绪：不能把商户信息当默认值暴露
{
  const m = await load('', null);
  ck('空身份不判为商户', m.isMerchant(), false);
  ck('空身份 merchantId 为 null', m.currentMerchantId(), null);
}

console.log(`=== identity PASS=${pass} FAIL=${fail} ===`);
process.exit(fail === 0 ? 0 : 1);
