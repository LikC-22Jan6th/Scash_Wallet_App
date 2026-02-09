# SCash Wallet 项目开发文档

> 本文档面向开发者，聚焦**安全设计与开发流程**。数据库表结构细节、运维/排障内容不在本文档范围内。

本项目包含两个核心组件：

- **后端：wallet-core（Node.js）**
  - 对外提供 API
  - 处理地址生成、交易构造/广播、链上查询、数据落库等
  - 与 Scash 节点（RPC）与 MySQL 交互

- **移动端：scash_wallet（Flutter）**
  - iOS/Android 跨平台 UI
  - 通过 `flutter_rust_bridge` 调用 **Rust** 侧能力，执行高性能/高安全的密码学与协议相关逻辑
  - 使用 `flutter_secure_storage` + `local_auth` 对用户私钥进行安全存储与解锁

## Rust 相关文档

- 👉 [Rust 桥接与代码生成指南](RUST-BRIDGE.md)

---

## 1. 架构概述

### 1.1 数据与调用路径

- **App 端（Flutter）**
  - UI/交互：转账、收款、交易记录、地址管理
  - 安全：生物识别/系统口令解锁、加密存储密钥材料
  - 计算：通过 `flutter_rust_bridge` 调用 Rust 生成助记词/派生地址/签名等

- **Rust（本地库）**
  - 助记词、HD 派生、签名、协议解析等
  - 作为“可信计算域”：尽量让**私钥不离开 Rust 层**（Dart 只拿到签名结果/公钥/地址）

- **后端（wallet-core）**
  - 交易广播、链上状态查询、确认数更新、平台费识别/入库等
  - 对外提供 REST API（或等价接口）供 App 调用
  - 对接 Scash 节点 RPC

### 1.2 安全边界建议

- **私钥安全边界在客户端**：
  - 私钥/助记词只在本地存在；后端不应接触明文私钥
  - 后端只接收“已签名交易”或签名相关的最小必要信息

- **后端只做数据与网络层**：
  - 负责交易广播、链上同步、交易记录聚合
  - 不做“代签名”服务（除非明确引入 HSM/托管模型并重新做安全设计）

---

## 2. 后端服务（wallet-core）安装与运行

### 2.1 环境要求

- Node.js：建议 **v18+**（或更高 LTS）
- MySQL：**8.0+**
- 可访问的 Scash 节点 RPC（自建或第三方）

### 2.2 安装依赖

在 `wallet-core/`（或后端目录）执行：

```bash
npm install
# 或 pnpm i / yarn
```

### 2.3 关键依赖说明（以 package.json 为准）

> 下列为“常见组合”，请以仓库中实际依赖为准。

- **bitcoinjs-lib / 等价库**：地址/交易相关结构处理
- **MySQL 客户端（mysql2 等）**：连接池、参数化 SQL
- **https-proxy-agent**：支持通过代理访问外部网络/节点
- **请求库（axios / node-fetch 等）**：访问 RPC 或第三方接口

如果希望进一步强化安全，建议额外引入并启用（可选）：

- **helmet**：HTTP 安全头
- **express-rate-limit / 等价方案**：API 访问频控
- **zod / joi / 等价方案**：请求入参校验

### 2.4 启动命令

```bash
npm start
# 或 npm run dev
```

---

## 3. 前端应用（scash_wallet）安装与运行

### 3.1 环境要求

- Flutter SDK：`^3.10.4`（或项目锁定版本）
- Dart SDK：`^3.0.0`
- Rust 工具链：用于编译本地库与桥接代码
  - 建议使用最新 stable

### 3.2 安装依赖

在 `scash_wallet/` 执行：

```bash
flutter pub get
```

### 3.3 关键依赖说明（以 pubspec.yaml 为准）

- **flutter_rust_bridge**：Dart ↔ Rust FFI 桥接
- **flutter_secure_storage**：加密存储密钥材料
- **local_auth**：生物识别/系统鉴权解锁

常见的网络与状态管理依赖（具体以项目为准）：

- dio/http：API 请求
- provider/riverpod/bloc：状态管理

### 3.4 编译运行

```bash
flutter run
```

---

## 4. 目录结构建议

> 以“逻辑分层 + 安全边界清晰”为原则。

```text
repo-root/
  wallet-core/                 # Node.js 后端
    src/
      routes/                  # API 路由
      services/                # 业务服务（RPC/交易/扫描/同步）
      db/                      # DB 访问层（隐藏实现细节）
      config/                  # 配置加载、env
    package.json

  scash_wallet/                # Flutter App
    lib/
      features/                # 功能模块（转账/收款/记录/设置）
      core/                    # 通用组件、网络、路由
      security/                # 解锁、密钥管理封装
    pubspec.yaml

  rust/                        # Rust 本地库（供 FRB 调用）
    src/
      api/                     # 暴露给 Dart 的接口
      crypto/                  # 密码学/签名/派生
      types/                   # 数据结构

  RUST-BRIDGE.md               # Rust 桥接文档
```

---

## 5. 安全重点（强烈建议遵循）

### 5.1 私钥与助记词的处理

- **不在后端存储明文私钥/助记词**
- **不在日志中输出**：助记词、私钥、seed、签名原文、完整交易原文（raw tx）
- **尽量让私钥只在 Rust 层存在**：
  - Dart 侧只持有必要的“句柄/加密后材料/公钥/地址”

### 5.2 本地安全存储

- 使用 `flutter_secure_storage` 存储敏感材料
- 结合 `local_auth`：
  - 生物识别失败/不可用时，回退到系统口令
  - 处理“设备未设置生物识别”的异常分支

### 5.3 传输安全与 API 访问控制

- App ↔ 后端：
  - 生产环境必须 **HTTPS**
  - 建议使用 token / 签名 / JWT 等机制对接口做鉴权（至少保护转账、查询敏感信息的接口）

- 后端：
  - 只允许必要的 CORS 来源
  - 对敏感接口做频控（rate limit）

### 5.4 输入校验与防注入

- 所有数据库写入使用**参数化 SQL**
- 对外接口做严格校验：
  - 地址格式
  - 金额范围（上下限/精度/负数）
  - txHash 长度与字符集

### 5.5 依赖安全与供应链

- 锁定依赖版本（lockfile）并做依赖审计
- CI 中启用基础安全检查（例如：npm audit / dart pub audit 的等价策略）
- Rust crate 同样需要版本锁定与审计

### 5.6 平台费与金额显示一致性

- **前端展示时**建议始终以 `amountSat` 为“真实转账金额”，平台费单独展示（如果存在）
- 任何涉及金额展示的地方，统一使用同一套口径与精度处理（避免 1 sat 误差）

---

## 6. FAQ

### 6.1 生物识别与真机调试

前端使用 `local_auth` + `secure_storage`。

- 真机调试时，请确保手机已开启指纹/面容识别
- 如果设备未设置生物识别，需要处理“不可用/拒绝授权/多次失败锁定”的分支

### 6.2 图标更新

如果更换了 `assets/images/scash-logo.png`，通常需要刷新生成资源（以项目脚本为准）。

---

## 7. 贡献与开发规范建议

- 分支策略：main + develop + feature/*（示例）
- 代码风格：
  - Node：eslint + prettier
  - Flutter：flutter format + analysis_options
  - Rust：rustfmt + clippy
- 安全评审：涉及“密钥/签名/金额计算/交易构造”的改动必须走 code review

