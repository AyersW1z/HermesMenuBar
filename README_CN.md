# HermesMenuBar

[English README](README.md)

macOS 菜单栏聊天应用，直接连接本地 Hermes AI 助手。

## 功能特点

- 🚀 **菜单栏常驻** - 从 macOS 菜单栏快速打开聊天窗口
- 💬 **流式输出** - 实时显示 AI 回复
- 📁 **Session 管理** - 支持搜索、置顶、归档、删除和重命名会话
- 🖼️ **图片附件** - 附加图片，让 Hermes 分析截图和视觉内容
- 📝 **Markdown 渲染** - 更适合代码块、列表和长回复阅读
- 💾 **文件持久化** - 会话保存在 Application Support 中，重启后自动恢复
- 🔗 **ACP 集成** - 直接连接本地 Hermes CLI 进程
- ⚡ **原生 Swift UI** - 使用 SwiftUI 构建，轻量、原生

## 系统要求

- macOS 14.0+
- 已安装 Hermes CLI，通常位于 `~/.local/bin/hermes`

## 安装

### 方式一：直接运行
```bash
cd ~/Documents/HermesMenuBar
./start.sh
```
脚本会先构建最新源码，再打开 `build/HermesMenuBar.app`。

### 方式二：安装到 Applications
```bash
cd ~/Documents/HermesMenuBar
./install.sh
```
脚本会先构建最新源码，再把应用安装到 `~/Applications`。

### 方式三：从打包压缩包拖拽安装
1. 下载 `HermesMenuBar-1.0.0.zip`
2. 解压到任意位置
3. 将 `HermesMenuBar.app` 拖到 Applications 文件夹

## 使用说明

### 基本操作

| 操作 | 说明 |
|------|------|
| 打开 / 关闭 | 点击菜单栏中的 💬 图标 |
| 发送消息 | 在输入框输入内容，点击 `Send` 或按 `Enter` |
| 插入换行 | 按 `Shift + Enter` |
| 添加图片 | 点击输入区中的 `Image`，或直接拖拽图片到输入区 |
| 新建会话 | 点击 `New Session` |
| 切换会话 | 点击左侧会话列表 |
| 搜索会话 | 使用左侧搜索框 |
| 置顶 / 归档 | 使用会话卡片上的操作按钮 |
| 删除会话 | 使用会话卡片上的垃圾桶图标 |
| 重命名会话 | 使用会话卡片上的铅笔图标 |
| 清空消息 | 点击 `Clear Messages` |
| 取消生成 | 点击红色 `Stop` 按钮 |
| 退出应用 | 点击 `Quit` |

### 会话模型

每个 session 都有独立的对话历史，可以分别置顶、归档、同步 ACP 或删除。

## 技术说明

### ACP 工作流

应用通过 ACP（Agent Communication Protocol）与 Hermes 通信：

1. 启动本地 `hermes acp` 子进程
2. 初始化 ACP 连接
3. 通过 `session/prompt` 发送消息
4. 将 JSON-RPC 流式更新实时显示在 UI 中
5. 可选地把 GUI 会话与 Hermes ACP 会话同步

### 数据存储

- Session 和消息保存在 Application Support 下的 JSON 文件中
- 附件图片会复制到应用数据目录中
- 启动时会自动恢复之前的状态

## 故障排除

### 应用无法打开
**问题：** macOS 提示无法验证开发者。

**解决方法：**
1. 打开“系统设置”
2. 进入“隐私与安全性”
3. 找到 HermesMenuBar 相关提示
4. 点击“仍要打开”

### Hermes 没有回复
**问题：** 发送消息后没有得到任何回复。

**检查方法：**
```bash
# 确认 Hermes 已安装
which hermes

# 确认 ACP 功能存在
hermes acp --help

# 发送一个最小 initialize 请求
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocol_version":1}}' | hermes acp
```

### 菜单栏图标没有显示
**问题：** 应用正在运行，但菜单栏里看不到图标。

**解决方法：**
- 检查是否被其他菜单栏图标挤出了可视区域
- 点击菜单栏空白区域让图标重新排列
- 到“系统设置 > 控制中心”里确认 HermesMenuBar 没被隐藏

## 开发

### 构建
```bash
swift build -c release
```

### 项目结构
```text
HermesMenuBar/
├── HermesMenuBar/           # 源代码
│   ├── HermesMenuBarApp.swift
│   ├── Models/              # 数据模型
│   ├── Views/               # SwiftUI 视图
│   ├── ViewModels/          # 视图模型
│   └── Services/            # 服务层
│       └── ACPClient.swift  # ACP 客户端
├── Package.swift            # Swift Package 配置
└── README.md
```

## 更新日志

### v1.0.0
- 初始版本
- 原生菜单栏应用
- Session 管理
- ACP 支持
- 流式回复

## License

MIT License
