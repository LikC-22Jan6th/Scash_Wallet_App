# Rust 桥接与代码生成指南（flutter_rust_bridge）

本项目使用 `flutter_rust_bridge`（FRB）实现 Dart 与 Rust 的高性能互操作。

- **Dart 层**：UI 展示、扫码、本地状态、网络请求
- **Rust 层**：助记词推导、地址派生、交易签名、协议解析等敏感/高性能逻辑
- **生成代码**：由 FRB 根据 Rust API 自动生成 Dart 侧绑定代码，并处理序列化与内存管理

---

## 1. 设计原则（强烈建议）

### 1.1 私钥不出 Rust

- 私钥/seed/助记词尽量只在 Rust 内存中出现
- Dart 层仅保留：
  - 地址、公钥
  - 交易签名结果
  - 或者“加密后的密钥材料”（由 secure_storage 保存）

### 1.2 明确错误边界

- Rust API 建议返回 `Result<T, E>`
- Dart 端通过 `Future` 捕获异常并统一处理

### 1.3 类型设计

- 复杂数据结构优先在 Rust 定义 `struct` / `enum`
- 由 FRB 自动映射到 Dart 类，减少手写序列化错误

---

## 2. 代码生成流程

当修改了 Rust 层暴露给 FRB 的接口（例如 `src/api.rs` 或等价模块）后，需要重新生成绑定代码。

### 2.1 典型生成命令

> 具体命令以项目脚本/工具版本为准：有的项目使用 `flutter_rust_bridge_codegen`，有的使用 `cargo run -p ...` 封装。

常见形式之一：

```bash
# 示例：请替换为实际路径与命令
flutter_rust_bridge_codegen generate --rust-root . --rust-input crate::api --dart-output ../../src/generated/frb/
```

如果项目在 `pubspec.yaml` 或根目录提供了脚本（推荐），优先使用：

```bash
# 示例
./scripts/gen_frb.sh
```

### 2.2 生成后检查点

- Dart 侧生成文件是否更新（git diff）
- iOS/Android 原生工程是否需要重新集成产物（取决于构建方式）
- Flutter 工程是否能正常 `flutter run`

---

## 3. 交互逻辑示意

```text
Flutter(Dart)
  |  调用 FRB 生成的 Dart 绑定
  v
FRB Runtime (Dart)
  |  FFI 调用
  v
Rust 动态库/静态库
  |  执行：助记词/派生/签名/解析
  v
返回结果给 Dart（序列化/内存由 FRB 处理）
```

---

## 4. 环境配置避坑

### 4.1 Rust 工具链

- 安装 `rustup`
- 建议使用最新 stable

```bash
rustup update
rustc --version
```

### 4.2 clang/LLVM

FRB 代码生成和某些绑定过程通常依赖 clang。

- macOS：`brew install llvm`
- Windows：建议通过 `choco install llvm`
- Linux：确保系统已安装 clang（具体取决于发行版与开发环境）

### 4.3 FRB 工具安装

> 具体取决于使用的 FRB 版本与脚手架。

常见方式：

```bash
dart pub global activate flutter_rust_bridge_codegen
```

然后确保 `~/.pub-cache/bin` 已加入 PATH。

---

## 5. 最佳实践

### 5.1 线程与异步

- Rust 侧耗时操作避免阻塞主线程
- 需要时将重计算放入后台线程或使用异步 API（结合 FRB 支持）

### 5.2 安全擦除与日志

- 敏感 buffer（seed/privkey）用后尽量清理
- Rust 日志不要输出敏感材料；必要时做脱敏

### 5.3 版本一致性

- FRB、Rust crate、Dart package 的版本要保持兼容
- 升级 FRB 前先在分支验证 iOS/Android 全链路编译

### 5.4 调试建议

- 给 Rust API 增加“非敏感”的调试接口（例如：校验地址/解析交易结构的摘要）
- 出现类型/序列化问题，优先检查：
  - Rust struct/enum 定义是否变化
  - 生成代码是否重新生成并被 Flutter 工程引用

