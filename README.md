# RightCmdAgent

macOS 托盘常驻工具：将 **右 Command** 键映射为你指定的全局行为（包括外接蓝牙键盘）。

## 当前实现的核心行为

按你的要求，行为已经写死在 Swift 代码里，不依赖任何外部脚本文件。

- **按下右 Command（key down）**
  1. 自动保存当前剪贴板内容
  2. 读取当前系统输出音量与静音状态
  3. 立刻静音
  4. 注入按键：`左 Command + Shift + 0`
- **松开右 Command（key up）**
  1. 延迟 `rightCommandUpEnterDelayMilliseconds`（默认 `16ms`）后注入按键：`Return/Enter`
  2. 在注入 `Return/Enter` 后再延迟 `100ms` 恢复之前保存的音量与静音状态
  3. 在恢复音量后，还原按下时保存的剪贴板内容
对应实现位置：

- 行为编排：`Sources/mac-keyboard-mapping/RightCmdService.swift`
- 音量保存/恢复（脚本等价实现）：`Sources/mac-keyboard-mapping/VolumeStateController.swift`
- 剪贴板保存/恢复：`Sources/mac-keyboard-mapping/ClipboardStateController.swift`
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

应用托盘菜单会分别显示这两个权限状态，并支持点击申请。剪贴板读写不需要新增系统授权项。

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
  "logKeyEvents": false,
  "rightCommandUpEnterDelayMilliseconds": 16
}
```

说明：`rightCommandUpEnterDelayMilliseconds` 用于缓解右 Command 抬起瞬间的时序竞争，默认 `16`；`100ms` 的音量恢复延迟仍固定写死。

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
