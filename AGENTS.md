# Repository Guidelines

## Project Structure & Module Organization
This is a RuoYi-Vue admin platform: a multi-module Maven backend plus a Vue 2 frontend.
- `ruoyi-admin/` — Spring Boot entry point, controllers under `src/main/java/com/ruoyi/web/controller`, configs in `src/main/resources`.
- `ruoyi-framework/` — security, web, and framework config; `ruoyi-system/` — business services, mappers, and MyBatis XML.
- `ruoyi-common/` — shared utils, annotations, constants; `ruoyi-quartz/` — scheduled jobs; `ruoyi-generator/` — code generator.
- `ruoyi-ui/` — Vue 2 client (`src/`, `public/`); `sql/` — DB scripts; `doc/`, `bin/` — docs and helper scripts.

## Build, Test, and Development Commands
- `mvn clean package` — build all backend modules and produce `ruoyi-admin/target/ruoyi-admin.jar`.
- `mvn spring-boot:run -pl ruoyi-admin` — run the API locally (default port 8080).
- `./ry.sh start|stop|restart|status` — manage the packaged jar on Linux/macOS; `ry.bat` on Windows.
- `cd ruoyi-ui && npm install` — install frontend deps; `npm run dev` — serve UI at `localhost:80`.
- `npm run build:prod` — produce production frontend assets in `ruoyi-ui/dist`.

## Coding Style & Naming Conventions
- Java: 4-space indent, `PascalCase` classes, `camelCase` methods/fields; controllers end in `Controller`, services in `ServiceImpl`, mappers in `Mapper`.
- Frontend: 2-space indent, LF endings, UTF-8, final newline (see `ruoyi-ui/.editorconfig`); Vue components in `PascalCase`, API modules under `src/api`.
- Keep MyBatis XML alongside mapper packages; match `<mapper namespace>` to the Java interface.

## Testing Guidelines
- No formal test suite ships with the project; `TestController.java` is a demo endpoint, not a unit test.
- Add backend tests with JUnit under `src/test/java` mirroring the source package, named `*Test.java`, and run via `mvn test`.
- Validate UI changes manually through `npm run dev` before submitting.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative summaries (often Chinese), e.g. `优化代码` / `修复脱敏不生效问题`; keep to one focused change per commit.
- PRs should include a clear description, linked issue when applicable, affected modules, and screenshots for UI changes.
- Confirm `mvn clean package` and `npm run build:prod` succeed before requesting review.

## Security & Configuration Tips
- Configure datasource, Redis, and tokens in `ruoyi-admin/src/main/resources/application*.yml`; never commit real credentials.
- Run `sql/*.sql` scripts to initialize the database before first launch.

## Pending Work（用户授权稍后再做，2026-08-01 登记）

### 1. 平台 / 代理商 / 商户登录入口分流
- 现状：`/login` 单入口、三种身份共用 `sys_user`，登录后无 `userType` 路由分流
- 待做：
  - `LoginUser`/`getInfo` 返回体补 `userType / agentId / merchantId`
  - `ruoyi-ui/src/views/login.vue` 顶部加「平台 / 代理商 / 商户」三选一 tabs（仅文案提示，不参与鉴权）
  - `ruoyi-ui/src/store/modules/user.js` 登录成功按 `userType` 跳转：
    - 平台 → `/index`
    - 代理商 → `/agent/index`（新建代理商工作台：名下商户 / 缴费记录 / 额度）
    - 商户 → `/merchant/index`（新建商户工作台：门店 / 订单 / 资金）
  - 路由 + 菜单按 `userType` 过滤
- 估计工作量：0.6 天（0.1 后端 + 0.5 前端）
