# HermesMenuBar 开发完成总结

## 项目概述

已成功开发一个原生 macOS 菜单栏聊天应用，具备以下特性：

### 核心功能
- ✅ 菜单栏常驻应用（点击 💬 图标打开）
- ✅ 流式消息输出（打字机效果）
- ✅ Session 管理（新建、切换、删除、重命名）
- ✅ 数据持久化（自动保存到 UserDefaults）
- ✅ 消息历史记录
- ✅ 取消正在生成的回复
- ✅ **ACP 协议支持** - 直接连接本地 Hermes CLI

### 技术栈
- **语言**: Swift 5.9
- **UI 框架**: SwiftUI
- **架构**: MVVM (Model-View-ViewModel)
- **数据存储**: UserDefaults + Codable
- **通信协议**: ACP (Agent Communication Protocol) via stdio

## ACP 协议实现

应用通过 ACP 协议与本地 Hermes CLI 通信：

1. **启动 hermes acp 子进程**
   - 自动查找 `~/.local/bin/hermes`
   - 启动 `hermes acp` 命令

2. **初始化流程**
   ```json
   // Initialize Request
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "initialize",
     "params": {
       "protocol_version": 1,
       "client_info": {
         "name": "HermesMenuBar",
         "version": "1.0.0"
       }
     }
   }
   
   // Initialized Notification
   {
     "jsonrpc": "2.0",
     "method": "initialized",
     "params": {}
   }
   ```

3. **发送消息**
   ```json
   {
     "jsonrpc": "2.0",
     "id": 2,
     "method": "prompt",
     "params": {
       "session_id": "uuid",
       "prompt": [
         {"type": "text", "text": "用户消息"}
       ]
     }
   }
   ```

4. **接收流式响应**
   - 解析 JSON-RPC 响应
   - 提取 `result.content` 中的文本
   - 处理 `agent/message` 和 `agent/thinking` 通知

## 项目结构

```
HermesMenuBar/
├── HermesMenuBar/                    # 源代码
│   ├── HermesMenuBarApp.swift        # 应用入口，菜单栏设置
│   ├── Info.plist
│   ├── Models/                       # 数据模型
│   │   ├── ChatSession.swift         # Session 模型
│   │   └── Message.swift             # Message 模型
│   ├── Views/                        # UI 视图
│   │   ├── ChatView.swift            # 主聊天界面
│   │   ├── MessageBubble.swift       # 消息气泡
│   │   └── SessionPickerView.swift   # Session 选择器
│   ├── ViewModels/                   # 视图模型
│   │   └── ChatViewModel.swift       # 聊天逻辑
│   └── Services/                     # 服务层
│       ├── SessionManager.swift      # Session 管理
│       ├── HermesClient.swift        # HTTP API 客户端（备用）
│       └── ACPClient.swift           # ACP 协议客户端 ✅ 当前使用
├── HermesMenuBar.app/                # 应用包（可直接运行）
├── build/HermesMenuBar.app/          # 构建版本
├── dist/                             # 分发包
│   ├── HermesMenuBar/                # 完整分发目录
│   └── HermesMenuBar-1.0.0.zip       # ZIP 压缩包
├── Package.swift                     # Swift Package 配置
├── install.sh                        # 安装脚本
├── start.sh                          # 启动脚本
├── package.sh                        # 打包脚本
└── README.md                         # 使用说明
```

## 快速开始

### 1. 直接运行（测试）
```bash
cd ~/Documents/HermesMenuBar
./start.sh

# 或
open build/HermesMenuBar.app
```

### 2. 安装到 Applications
```bash
cd ~/Documents/HermesMenuBar
./install.sh
```

### 3. 分发给别人
```bash
cd ~/Documents/HermesMenuBar
./package.sh
# 生成的 dist/HermesMenuBar-1.0.0.zip 可以分享
```

## 使用说明

### 界面说明
- **菜单栏图标**: 💬 点击打开/关闭聊天窗口
- **顶部工具栏**: 显示当前 Session 名称，点击可切换 Session
- **中间区域**: 消息列表，支持滚动
- **底部输入区**: 输入消息，点击 ↑ 发送

### Session 管理
- **新建**: 点击齿轮图标 → New Session
- **切换**: 点击顶部 Session 名称 → 选择要切换的 Session
- **删除**: 在 Session 列表中点击垃圾桶图标
- **重命名**: 在 Session 列表中点击铅笔图标

### 其他操作
- **清空消息**: 齿轮图标 → Clear Messages
- **取消生成**: 发送消息后，按钮变为红色停止按钮，点击可取消
- **退出应用**: 齿轮图标 → Quit

## 故障排除

### 应用无法启动
- 检查系统版本是否为 macOS 14.0+
- 检查 `HermesMenuBar.app/Contents/MacOS/HermesMenuBar` 是否有执行权限

### 无法连接到 Hermes
- 确认 Hermes CLI 已安装: `which hermes`
- 确认 Hermes 在 `~/.local/bin/hermes` 或 PATH 中
- 检查应用中的错误提示

### ACP 连接失败
- 检查 hermes acp 是否正常工作: `hermes acp --help`
- 查看控制台日志了解详细错误

### 菜单栏图标不显示
- 应用作为 LSUIElement 运行，不会在 Dock 显示
- 检查屏幕右上角是否有 💬 图标
- 可能被其他菜单栏图标挤到左侧

## 开发

### 构建
```bash
swift build              # Debug 构建
swift build -c release   # Release 构建
```

### 运行
```bash
swift run
```

### 调试
```bash
open Package.swift  # 用 Xcode 打开
```

## 注意事项

1. **首次运行**: 系统可能提示"无法验证开发者"，前往 系统设置 → 隐私与安全性 → 安全性，点击"仍要打开"

2. **ACP 协议**: 应用使用 ACP 协议与 Hermes 通信，需要 Hermes 支持 ACP 模式

3. **Session 数据**: Session 和消息保存在 UserDefaults，卸载应用会丢失数据

4. **系统要求**: macOS 14.0+

## 后续优化建议

1. **Markdown 渲染**: 支持代码块、列表等 Markdown 格式
2. **图片支持**: 支持粘贴和显示图片
3. **全局快捷键**: Cmd+Shift+H 快速打开
4. **导出功能**: 导出聊天记录为 Markdown
5. **主题切换**: 深色/浅色模式
6. **自动更新**: 集成 Sparkle 框架
7. **多后端支持**: 支持 OpenAI、Claude 等 API

## 许可证

MIT License
