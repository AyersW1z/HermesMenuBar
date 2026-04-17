# HermesMenuBar

macOS 菜单栏聊天应用 - 直接连接 Hermes AI 助手

## 功能特点

- 🚀 **菜单栏常驻** - 点击 💬 图标快速打开聊天窗口
- 💬 **流式输出** - 实时显示 AI 回复，打字机效果
- 📁 **Session 管理** - 搜索、置顶、归档、删除、重命名对话
- 🖼️ **图片附件** - 直接附加图片，让 Hermes 分析截图和视觉内容
- 📝 **Markdown 渲染** - 更适合代码块、列表和长回复阅读
- 💾 **文件持久化** - 自动保存到 Application Support，下次打开依然保留
- 🔗 **ACP 协议** - 直接连接本地 Hermes CLI 进程
- ⚡ **原生 Swift** - 使用 SwiftUI 构建，性能优异

## 系统要求

- macOS 14.0+
- Hermes CLI 已安装 (`~/.local/bin/hermes`)

## 安装

### 方法一：直接运行
```bash
cd ~/Documents/HermesMenuBar
./start.sh
```
脚本会先构建当前源码，再打开 `build/HermesMenuBar.app`。

### 方法二：安装到 Applications
```bash
cd ~/Documents/HermesMenuBar
./install.sh
```
脚本会先构建当前源码，再把最新 app 安装到 `~/Applications`。

### 方法三：手动安装
1. 下载 `HermesMenuBar-1.0.0.zip`
2. 解压到任意位置
3. 将 `HermesMenuBar.app` 拖到 Applications 文件夹

## 使用说明

### 基本操作

| 操作 | 说明 |
|------|------|
| 打开/关闭 | 点击菜单栏 💬 图标 |
| 发送消息 | 底部输入框输入，点击 Send 或按 Enter |
| 插入换行 | Shift + Enter |
| 添加图片 | 底部输入区点击 Image，或直接拖拽图片 |
| 新建 Session | 齿轮图标 → New Session |
| 切换 Session | 左侧 Session 列表点击切换 |
| 搜索 Session | 左侧搜索框实时过滤 |
| 置顶 / 归档 | Session 卡片上点击对应图标 |
| 删除 Session | Session 卡片上点击 🗑️ |
| 重命名 Session | Session 卡片上点击 ✏️ |
| 清空消息 | 齿轮图标 → Clear Messages |
| 取消生成 | 点击红色 ⏹ 按钮 |
| 退出应用 | 齿轮图标 → Quit |

### Session 管理

应用支持多个 Session，每个 Session 有独立的对话历史：

1. **新建 Session**: 创建新的对话上下文
2. **切换 Session**: 在不同对话间快速切换
3. **删除 Session**: 删除不需要的对话
4. **重命名 Session**: 给 Session 起个有意义的名字

## 技术实现

### ACP 协议

应用通过 ACP (Agent Communication Protocol) 与 Hermes 通信：

1. 启动 `hermes acp` 子进程
2. 发送 `initialize` 请求建立连接
3. 使用 `session/prompt` 发送消息，并为每个本地 session 绑定独立 ACP session
4. 接收流式 JSON-RPC 响应，并实时更新对应会话

### 数据存储

- Session 和消息保存在 Application Support 下的 JSON 文件
- 附件图片会复制到应用数据目录中
- 应用重启后自动恢复

## 故障排除

### 应用无法打开
**问题**: 系统提示"无法验证开发者"

**解决**: 
1. 前往 系统设置 → 隐私与安全性 → 安全性
2. 找到 HermesMenuBar 相关提示
3. 点击"仍要打开"

### 无法连接到 Hermes
**问题**: 发送消息后无响应

**检查**:
```bash
# 确认 Hermes 已安装
which hermes

# 确认 Hermes 支持 ACP
hermes acp --help

# 测试 ACP 是否正常工作
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocol_version":1}}' | hermes acp
```

### 菜单栏图标不显示
**问题**: 应用运行但看不到图标

**解决**:
- 检查屏幕右上角是否被其他图标挤到左侧
- 尝试点击菜单栏空白区域
- 检查系统设置 → 控制中心，确认 HermesMenuBar 未被隐藏

## 开发

### 构建
```bash
swift build -c release
```

### 项目结构
```
HermesMenuBar/
├── HermesMenuBar/           # 源代码
│   ├── HermesMenuBarApp.swift
│   ├── Models/              # 数据模型
│   ├── Views/               # SwiftUI 视图
│   ├── ViewModels/          # 视图模型
│   └── Services/            # 服务层
│       └── ACPClient.swift  # ACP 协议客户端
├── Package.swift            # Swift Package 配置
└── README.md
```

## 更新日志

### v1.0.0
- 初始版本
- 菜单栏常驻应用
- Session 管理
- ACP 协议支持
- 流式消息输出

## 许可证

MIT License
