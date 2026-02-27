# RightCmdAgent

macOS 托盘常驻工具：将 **右 Command** 键映射为你指定的全局行为（包括外接蓝牙键盘）。

## 当前实现的核心行为

按你的要求，行为已经写死在 Swift 代码里，不依赖任何外部脚本文件。

- **按下右 Command（key down）**
  1. 读取当前系统输出音量与静音状态
  2. 立刻静音
  3. 注入按键：`左 Command + 1`
- **松开右 Command（key up）**
  1. 注入按键：`Return/Enter`
  2. 延迟 `100ms` 后恢复之前保存的音量与静音状态

对应实现位置：

- 行为编排：`Sources/mac-keyboard-mapping/RightCmdService.swift`
- 音量保存/恢复（脚本等价实现）：`Sources/mac-keyboard-mapping/VolumeStateController.swift`
- 按键注入：`Sources/mac-keyboard-mapping/EventSynthesizer.swift`
- 按键状态机：`Sources/mac-keyboard-mapping/RightCommandStateMachine.swift`

## 环境要求

- macOS 13+
- Xcode Command Line Tools
- Swift 6.2（`swift --version`）

## 构建

```bash
./scripts/build_app_bundle.sh
```

构建产物：`dist/RightCmdAgent.app`

## 安装到应用程序

```bash
ditto dist/RightCmdAgent.app /Applications/RightCmdAgent.app
open /Applications/RightCmdAgent.app
```

## 首次权限

应用需要两个权限：

- 辅助功能（Accessibility）
- 输入监控（Input Monitoring）

应用托盘菜单会分别显示这两个权限状态，并支持点击申请。

## 托盘菜单说明

启动后菜单栏会出现 `RC` 图标。菜单项包括：

- 运行状态
- 辅助功能权限（单独状态 + 点击申请）
- 输入监控权限（单独状态 + 点击申请）
- 刷新权限状态
- 开机启动（开/关）
- 退出 RightCmdAgent

## 配置文件

默认路径：

`~/Library/Application Support/RightCmdAgent/config.json`

示例内容：

```json
{
  "logKeyEvents": false
}
```

说明：当前版本只保留 `logKeyEvents`；行为参数（按下/抬起动作、100ms 延迟）是固定写死的。

## 开机启动

### 方式 1：托盘菜单

直接在菜单中切换“开机启动”。

### 方式 2：脚本安装 LaunchAgent

```bash
./scripts/install_launch_agent.sh /Applications/RightCmdAgent.app
```

日志路径：

- `~/Library/Logs/rightcmd-agent/stdout.log`
- `~/Library/Logs/rightcmd-agent/stderr.log`

## 常用排障

### 托盘图标未出现

```bash
pkill -f 'RightCmdAgent.app/Contents/MacOS/rightcmd-agent' || true
open /Applications/RightCmdAgent.app
```

### 进程是否在运行

```bash
pgrep -fl '/Applications/RightCmdAgent.app/Contents/MacOS/rightcmd-agent'
```

### 权限改完后仍未生效

- 在托盘菜单点击“刷新权限状态”
- 或重启应用

## 测试

```bash
swift test
```
