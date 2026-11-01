# Ocean-P6 Plasma 6.8 完整适配方案

> 分析日期：2026-11-01<br>
> 实施日期：2026-11-01<br>
> 项目源码：https://github.com/EliverLara/Juno/tree/ocean/kde/sddm/Ocean-P6<br>
> 当前结论：**代码适配与 SDDM 测试模式验证已完成；真实注销登录验收待执行。**<br>
> 本文保留为实施与验收记录，完成项与未验证项见第 11 节。

## 1. 结论与适配策略

当前代码的 QML 静态语法检查可以通过，但在本机 SDDM 测试模式中出现：

```text
Main.qml:174:9: VirtualKeyboardLoader is not a type
Fallback to embedded theme
```

因此，不能把“语法检查通过”或“元数据声明 QtVersion=6”视为适配完成。

推荐策略：

1. 以本机 `sddm-breeze 6.8.2` 为接口基线，以项目源码为修改对象，不直接修改系统主题。
2. 保留 Ocean 的青色强调色、深色半透明面板、背景模糊和整体视觉布局。
3. 先解决运行阻断和认证流程，再处理背景、布局、辅助功能与翻译。
4. 不批量重写仍可用的 Qt 6 接口，不为了“现代化”引入额外风险。
5. 本机依赖已经齐全，无需安装、卸载或升级软件包。

## 2. 本机环境基线

| 项目 | 本机实际情况 |
|---|---|
| 操作系统 | Fedora Linux 44，KDE Plasma Desktop Edition |
| 内核 | Linux 7.2.13-200.fc44.x86_64 |
| 当前会话 | KDE / Wayland |
| Plasma | 6.8.2 |
| Qt | 6.11.2 |
| Kirigami | 6.31.0 |
| SDDM | 0.21.0-13.fc44 |
| SDDM greeter | `sddm-greeter-qt6`，支持 `--test-mode --theme <path>` |
| 参考主题 | `sddm-breeze 6.8.2`，位于 `/usr/share/sddm/themes/breeze` |
| SDDM 显示服务 | Wayland，KWin 合成器，`plasma-keyboard` 输入法 |
| 当前显示 | eDP-1，物理 1920×1080，缩放 1.25，逻辑 1536×864 |
| 当前启用主题 | `Lavanda`，不是 Ocean-P6 |
| 自动登录 | 已配置自动登录，真实登录测试前必须注意 |
| QML 工具 | `qmllint`、`qmlformat` 已安装 |

其他环境事实：

- `org.kde.breeze.components`、`org.kde.plasma.workspace.keyboardlayout`、`Qt5Compat.GraphicalEffects` 等所需模块均存在。
- 项目与 `/usr/share/sddm/themes/Ocean-P6` 的现有代码基本一致；系统安装目录另有未被项目引用的旧文件及 `theme.conf.user`。
- 适配期间保持当前 `Lavanda` 主题不变，可确保测试失败不影响正常登录。
- SDDM 版本通过软件包信息确认；不要直接启动 `sddm` 守护进程做版本探测。

## 3. 已执行的验证

### 3.1 静态检查

- 已审查项目全部 QML、元数据、配置和资源引用。
- QML 静态语法检查通过，但运行时类型和绑定仍需 greeter 验证。
- SVG/SVGZ 的 XML 结构可解析。
- `metadata.desktop` 中入口、配置、预览图、Theme-API 2.0 和 QtVersion 6 均有效。

### 3.2 Ocean-P6 测试模式

```bash
sddm-greeter-qt6 --test-mode --theme /path/to/Ocean-P6
```

结果：明确报出 `VirtualKeyboardLoader is not a type`，随后回退到内嵌主题。（修改前基线；修复后结果见第 11 节。）

### 3.3 Breeze 对照测试

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/breeze
```

结果：没有主题类型加载错误，也没有回退，证明测试环境可用。

测试模式中的 `QLocalSocket`、事件过滤器和当前图标主题旧元数据提示在 Breeze 对照组也存在，不属于 Ocean-P6 的适配阻断。两份测试均由超时机制主动终止，退出码 124 不代表主题测试失败原因。

## 4. 问题清单与修复要求

| 优先级 | 位置 | 问题 | 修复要求 |
|---|---|---|---|
| P0 阻断 | `Main.qml:73,174-183,234-257,339-346` | Plasma 6.8.2 已无 `VirtualKeyboardLoader`，导致整个主题回退 | 迁移到 `org.kde.plasma.workspace.keyboardlayout` 的 `KWinVirtualKeyboard`，替换全部 `inputPanel` 状态与方法 |
| P1 高 | `Main.qml:168,327,332,371`、`Login.qml:21` | `units` 未定义，动画、边距和布局绑定会产生运行错误 | 全部改为 `Kirigami.Units`，并在 `Login.qml` 引入 Kirigami |
| P1 高 | `Main.qml:72-110`、`Login.qml:56-73` | 自动隐藏只改状态、不隐藏界面，却会阻止 Enter 提交 | 推荐保持登录界面常显并移除失效 gating；若保留自动隐藏，必须完整移植 `WallpaperFader` 及唤醒逻辑 |
| P1 高 | `Login.qml:62-104` | 忽略 `needsPassword`，无密码账户无法登录 | 按当前用户控制密码框可见性、按钮启用条件和焦点目标 |
| P1 高 | `components/Clock.qml:33,43` | 软件渲染分支引用未定义的 `ColorScope` | 改用 `Kirigami.Theme.backgroundColor` |
| P2 中 | `Login.qml:25-44`、`Main.qml:386-399` | 用户切换保留旧密码，认证期间可重复提交，失败后缺少统一恢复 | 清空密码、恢复焦点、提交时禁用 UI、失败时重新启用 |
| P2 中 | `Main.qml:349-354` | 键盘布局或会话变化后未恢复密码框焦点 | 连接两个变更信号并恢复焦点 |
| P2 中 | `KeyboardButton.qml:19` | 空布局或无效索引可能导致绑定错误 | 使用可选链和空值回退 |
| P2 中 | `Main.qml:58-66`、`theme.conf` | 纯色背景未实现，图片默认拉伸，配置键大小写不标准 | 支持 image/color、PreserveAspectCrop、标准 `background` 键及旧配置兼容 |
| P2 中 | `components/SessionManagementScreen.qml:74-85` | 用户列表离屏保护被注释 | 恢复 `showUserList && y > 0`，验证低高度和手动用户名页面 |
| P2 中 | `Main.qml:230-258`、`components/ActionButton.qml` | 电源和用户切换按钮缺少辅助功能名称 | 至少补充翻译后的 `Accessible.name`，可见文字与 tooltip 不得破坏现有布局 |
| P3 低 | `metadata.desktop:13` 及 QML 翻译调用 | 声明的翻译目录不存在，翻译域沿用旧实现 | 统一使用系统 `plasma-desktop-sddm-theme` catalog，或真正交付自有翻译；二选一 |
| P3 低 | `components/UserDelegate.qml:115-137` | 用户显示名称未强制纯文本 | 设置 `textFormat: Text.PlainText` |
| P3 低 | `assets/shutdown.svg:64` | `stop-color` 多出右括号 | 修正颜色值，保持现有图标外观 |

另需在运行阶段验证：

- Caps Lock 数据尚未到达时的空值行为；推荐迁移到当前 Breeze 的 `KeyboardIndicator.KeyState`。
- 全屏高斯模糊在软件渲染、高 DPI 和多屏下的性能。
- 800×600、1024×768、1368×768、超宽屏、长翻译和 RTL 下的溢出与重叠。
- 电源按钮实际可用性由 `sddm.can*` 和系统策略决定，不能在真实会话中直接点击测试。

## 5. 分阶段实施方案

### 阶段 0：建立可回滚基线

1. 保留原始源码和当前系统主题，记录初始 Git 差异。
2. 在实际修改前建立基线提交或其他可恢复快照；Git 提交需另行确认。
3. 修正文档状态：`AGENTS.md` 目前写有“已完整适配”，与实测不符；只有通过本方案验收后才能保留该结论。
4. 不修改 `/etc/sddm.conf*`，不切换当前主题，不重启 SDDM。

### 阶段 1：消除运行阻断

主要文件：`Main.qml`、`Login.qml`、`components/Clock.qml`。

虚拟键盘按 Plasma 6.8.2 接口迁移：

```qml
import org.kde.plasma.workspace.keyboardlayout as Keyboards
```

状态与操作映射：

- `inputPanel.keyboardActive` → `Keyboards.KWinVirtualKeyboard.visible`
- 显示键盘：先恢复密码框焦点，再调用 `Keyboards.KWinVirtualKeyboard.forceActivate()`
- 隐藏键盘：`Keyboards.KWinVirtualKeyboard.active = false`
- 删除 `VirtualKeyboardLoader`、`inputPanel.status == Loader.Ready` 和 `inputPanel.showHide()`
- 检查虚拟键盘显示时的页面遮挡；不能假设旧加载器的避让行为仍然存在

同时完成：

- 所有 `units.*` 改为 `Kirigami.Units.*`。
- `Clock.qml` 的 `ColorScope` 改为 Kirigami 主题色。
- 每完成一个阻断项即运行测试模式，直到不再出现 `is not a type`、`ReferenceError` 和 `Fallback to embedded theme`。

阶段验收：主题主界面能够由 Ocean-P6 自身加载，而不是内嵌回退主题。

### 阶段 2：修复认证和焦点状态

主要文件：`Login.qml`、`Main.qml`、`KeyboardButton.qml`。

1. 根据 `userList.currentItem.needsPassword` 控制密码框与登录按钮。
2. 无密码账户显示可直接提交的登录按钮，并将焦点回退到该按钮。
3. 用户切换时清空旧密码，并聚焦第一个可见输入控件。
4. 提交认证时禁用登录区域和 footer，避免双击重复提交及认证中切换会话。
5. `onLoginFailed` 中恢复 UI、选中密码并恢复焦点。
6. 会话和键盘布局变化后恢复密码框焦点。
7. 键盘布局文本使用 `keyboard.layouts[currentIndex]?.longName ?? ""`。
8. 自动隐藏采用以下一种完整策略，不保留中间状态：
   - 推荐：保持登录界面常显，移除无效计时器及提交 gating，最贴近当前实际视觉行为。
   - 可选：完整移植 `WallpaperFader`、页脚/时钟状态、鼠标和键盘唤醒逻辑。

阶段验收：密码账户、无密码账户、手动用户名、错误密码重试和焦点恢复均通过测试模式检查。

### 阶段 3：背景、布局与渲染适配

主要文件：`Main.qml`、新增 `Background.qml`、`theme.conf`、`components/SessionManagementScreen.qml`。

1. 参照 Plasma 6.8.2 Breeze 的 `Background.qml`，实现图片与纯色两种背景状态。
2. 背景图片使用 `Image.PreserveAspectCrop` 和合理 `sourceSize`，避免拉伸及不必要的显存占用。
3. 默认配置改为 `background=assets/bg.jpg`，读取时暂时兼容旧 `Background`，避免已有用户配置失效。
4. 使用 `screenModel` 为每个屏幕创建背景；保留 Ocean 模糊效果时同步检查其采样源。
5. 软件渲染时降低或关闭高成本模糊，避免启动卡顿。
6. 恢复用户列表的离屏保护。
7. 对主登录区、左右电源按钮和 footer 设置最小/最大尺寸约束，重点验证 1.25 缩放和低高度屏幕。
8. 仅在测试确认重叠后调整布局，不做无关视觉重设计。

阶段验收：背景不变形，image/color 均可切换；当前 1920×1080、1.25 缩放及低分辨率测试无重叠，软件渲染可运行。

### 阶段 4：辅助功能、翻译与资源收尾

1. 为挂起、重启、关机、切换用户和返回按钮添加翻译后的辅助功能名称。
2. 用户名按纯文本显示，修复关机 SVG 颜色值。
3. 推荐统一使用 Plasma 6.8.2 已提供的 `plasma-desktop-sddm-theme` 翻译域，并移除无效的 `TranslationsDirectory`；若改为自有翻译，则必须实际交付目录和 catalog。
4. 保留原有版权、作者和来源信息；从 Breeze 移植代码时保留对应许可证与版权头。
5. 界面视觉发生变化时更新 `preview.png`，否则不重新生成。
6. 通过全部验收后，再更新版本说明及 `AGENTS.md` 的适配状态。

## 6. 明确不需要的批量改动

以下接口在本机 Plasma 6.8.2 仍可用，不应成为首轮重写对象：

- `QtQuick 2.x`、`QtQuick.Controls 2.x`、`QtQuick.Layouts 1.x` 的版本化导入。
- `org.kde.plasma.plasma5support 2.0` 的 time、keystate、powermanagement 数据引擎。
- `Qt5Compat.GraphicalEffects`；当前系统 Breeze 也在使用。
- `sddm.login()`、会话索引和 `sddm.suspend()/reboot()/powerOff()`。
- `UserDelegate` 当前使用的系统 shader 资源路径。

可在稳定后单独评估 Clock、Battery、Caps Lock 的现代化，不与运行阻断修复混在同一提交。

## 7. 验证方案

### 7.1 每轮静态检查

```bash
cd /path/to/Ocean-P6
qmllint Main.qml Login.qml KeyboardButton.qml SessionButton.qml components/*.qml
git diff --check
git status --short
```

只对本次修改的文件使用 `qmlformat`，并审查格式差异；禁止全项目性格式化混入功能提交。

### 7.2 运行冒烟测试

```bash
sddm-greeter-qt6 --test-mode --theme "$PWD"
QT_QUICK_BACKEND=software sddm-greeter-qt6 --test-mode --theme "$PWD"
```

日志验收：

- 无 `is not a type`。
- 无新增 `ReferenceError`、空对象属性访问和绑定循环。
- 无 `Fallback to embedded theme`。
- 软件渲染下无 `ColorScope` 错误，界面能正常显示。

### 7.3 功能测试矩阵

| 类别 | 必测场景 | 通过标准 |
|---|---|---|
| 用户登录 | 单用户、多用户、手动用户名、无密码账户 | 用户名和密码来源正确，无密码账户可直接登录 |
| 密码流程 | 空密码、Enter 提交、快速双击、错误密码重试 | 无重复提交，失败后 UI 恢复且密码重新聚焦 |
| 会话 | 切换 Wayland/X11 会话条目（以本机已有条目为准） | 当前索引正确，选择后焦点恢复 |
| 键盘 | 布局切换、Caps Lock、虚拟键盘反复显示/隐藏 | 指示正确，按键进入密码框，界面不被遮挡 |
| 自动隐藏 | 按最终选择验证常显或完整隐藏/唤醒 | 不出现“界面可见但 Enter 不提交”的状态 |
| 背景 | image、color、旧 `Background` 配置兼容 | 类型正确，图片不变形，旧配置不丢失 |
| 分辨率 | 1920×1080@1.25、1368×768、1280×720、1024×768 | 登录区、按钮、footer 不重叠或溢出 |
| 文本 | 长用户名、长翻译、空键盘布局、RTL | 无绑定错误，文本合理截断或换行 |
| 渲染 | 默认 GPU、Qt Quick software | 无渲染绑定错误，模糊不造成明显卡顿 |
| 电源 | 挂起、重启、关机的 enabled 和辅助功能名称 | 状态符合 `sddm.can*`，不在测试中触发真实电源操作 |
| 多屏 | 每屏背景与登录布局 | 代码按 `screenModel` 工作；无多屏硬件时明确标记未做实机验证 |

### 7.4 真实登录验收

仅在以上测试全部通过后进行：

1. 备份系统 Ocean-P6 目录和 SDDM 配置，保留 `theme.conf.user`。
2. 同步项目文件到系统主题目录；禁止使用会删除未知文件的 `rsync --delete`。
3. 通过 KDE 系统设置选择 Ocean-P6，不直接编辑全局配置作为首选方式。
4. 保存工作并注销，验证真实 greeter；不要盲目重启显示管理器。
5. 当前配置了自动登录，若需验证冷启动登录，必须单独确认后再临时调整，并在测试后恢复。

## 8. 回滚方案

- 测试阶段不切换当前 `Lavanda`，失败不会影响正常登录。
- 部署前备份 `/usr/share/sddm/themes/Ocean-P6` 与 `/etc/sddm.conf.d/kde_settings.conf`。
- 若真实 greeter 回退或显示异常，通过 KDE 系统设置或 TTY 将主题恢复为 `Lavanda`；备用系统主题为 `01-breeze-fedora`。
- 恢复备份的系统主题目录和用户配置，不用重启整个系统作为首选排查手段。
- 代码层面按阶段提交，阻断修复、登录行为、背景和收尾分别可独立回退。

## 9. 最终验收定义

只有同时满足以下条件，才能声明“完整适配 Plasma 6.8”：

1. 本机 Plasma 6.8.2 / Qt 6.11.2 / SDDM 0.21 测试模式不再回退。
2. 默认与软件渲染均无新增运行错误。
3. 登录、无密码账户、错误重试、会话、键盘、虚拟键盘和焦点流程通过。
4. 当前 1.25 缩放及约定分辨率下布局通过，背景不变形。
5. 辅助功能、翻译声明和资源检查完成。
6. 真实注销登录验证通过，并确认回滚路径可用。
7. 未通过的项目明确记录，不把未测试的多屏、X11 greeter 或其他发行版兼容性宣称为已验证。

## 10. 实施边界与风险

- 预计涉及 `Main.qml`、`Login.qml`、`KeyboardButton.qml`、若干 `components/*.qml`、`theme.conf`、`metadata.desktop`、SVG 及一个背景组件，属于跨模块修改。
- 登录与认证行为属于高风险区域，应小步修改、逐阶段验证，不能一次性照搬整个 Breeze 主题。
- 本方案不需要变更数据库、系统包或 Plasma 安装；系统主题部署和 SDDM 配置变更必须另行确认。
- 当前仅完成分析与方案导出，项目功能代码尚未因本方案而修改。

## 11. 实施记录（2026-11-01）

### 11.1 已实施变更

| 阶段 | 文件 | 变更 |
|---|---|---|
| P0 | `Main.qml` | 移除 `VirtualKeyboardLoader`，迁移到 `org.kde.plasma.workspace.keyboardlayout` 的 `KWinVirtualKeyboard`；虚拟键盘按钮使用 `available`/`visible`/`forceActivate()`/`active`；键盘显示时隐藏电源与切换用户按钮 |
| P1 | `Main.qml`、`Login.qml` | 全部 `units.*` 改为 `Kirigami.Units.*`；移除失效的自动隐藏计时器与提交 gating，登录界面常显且 Enter 始终可提交 |
| P1 | `Login.qml` | 按 `userList.currentItem.needsPassword` 控制密码框可见性、登录按钮启用条件与焦点目标；无密码账户直接聚焦登录按钮 |
| P1 | `components/Clock.qml` | 软件渲染轮廓色改用 `Kirigami.Theme.backgroundColor` |
| P2 | `Main.qml`、`Login.qml` | 切换用户清空旧密码；提交时禁用 footer 与登录区；失败后恢复 UI、重新启用并恢复焦点；会话/键盘布局变化后恢复输入焦点 |
| P2 | `Main.qml`、`KeyboardButton.qml`、`SessionButton.qml` | 键盘布局与会话文本使用可选链和空值回退，避免空索引绑定错误 |
| P3 | `Main.qml`（Caps Lock） | 由 plasma5support `keystate` 迁移到 `KeyboardIndicator.KeyState`，避免数据未到达时的空值访问 |
| P2 | 新增 `Background.qml`、`Main.qml`、`theme.conf` | 支持 `type=image` / `type=color`、`Image.PreserveAspectCrop`、`sourceSize`、按 `screenModel` 多屏背景；标准 `background` 键，同时兼容旧 `Background` 键；新增 `background_color` |
| P2 | `Main.qml` | 主登录区增加最小/最大尺寸约束；软件渲染时关闭全屏高斯模糊，保留半透明面板可读性 |
| P2 | `components/SessionManagementScreen.qml` | 恢复用户列表离屏保护 `showUserList && y > 0` |
| P2/P3 | `Main.qml`、`components/UserDelegate.qml` | 挂起、重启、关机、切换用户、返回按钮补充翻译后的 `Accessible.name`；用户名强制 `Text.PlainText` |
| P3 | `Login.qml` | 登录按钮改为与密码框同宽同高（`Layout.fillWidth`、`Layout.preferredHeight: passwordBox.implicitHeight`），对齐 `preview.png` 的原始外观 |
| 交付 | `install.sh`、`uninstall.sh`、`README.md` | 系统级安装/卸载脚本（需要 sudo；保留 `theme.conf.user`；卸载时保护当前主题）与中英文说明文档 |
| P3 | 全部 QML、`metadata.desktop` | 翻译域统一为系统 `plasma-desktop-sddm-theme`，移除不存在的 `TranslationsDirectory` |
| P3 | `assets/shutdown.svg` | 修正 `stop-color:#ff5370)` 多余右括号 |

### 11.2 已验证结果

- 默认 QPA（Wayland）运行 `sddm-greeter-qt6 --test-mode --theme "$PWD"`：主题由自身加载，无 `is not a type`、无 `ReferenceError`、无 `Fallback to embedded theme`、无新增 QML 警告。
- `QT_QUICK_BACKEND=software`：同样无错误，软件渲染分支无 `ColorScope` 问题。
- offscreen 平台（800×800）：无 QML 错误，覆盖窄宽度布局路径。
- 背景：图片模式（保留模糊）、纯色模式（`type=color`）均正常；旧 `Background="assets/bg.jpg"` 与新版 `background` 键渲染的背景区域 RMSE 为 1.3e-05，确认旧配置兼容。
- 截图与 `preview.png` 对照：面板、输入框、头像、操作条、配色比例一致；登录按钮已按预览改为与密码框同宽同高。仍存在的差异为预览图缺少 footer/时钟/电池、预览图背景的模糊与色调强于 `assets/bg.jpg` 实际渲染（预览图疑似旧版或后期处理图），以及用户名/头像/语言/电源可用状态等环境差异。
- 背景重构回归：用临时副本恢复原始单 `Image` 背景实现后与当前实现对比，背景区域 RMSE 为 0.26%–0.86%，确认 `Background.qml` 与 `screenModel` 改造未改变原有模糊与背景外观。
- 软件渲染：模糊按设计关闭（软件后端不支持该效果），头像回退为 Breeze 的方形头像（其着色器不工作时的既有回退），无运行错误。
- 启用态对照：在临时副本中填入密码并强制电源按钮可用后，登录按钮为满宽实心青色 + 白字，电源图标恢复青/蓝/红，与 `preview.png` 的启用态一致。测试模式下的暗色电源图标和禁用按钮属于状态差异，不是样式回退。
- 背景强度：对 `preview.png` 与 `assets/bg.jpg` 做归一化模糊拟合，误差在不同模糊半径下基本持平，说明预览图背景并非当前 `assets/bg.jpg` 的直接模糊结果（疑似旧素材或后期处理）；因此保留原始 `radius: 50` 模糊实现，不以预览图背景作为像素基准。
- 安装/卸载脚本：`bash -n` 通过；非 root 运行会被拒绝；在临时目标目录完成首次安装、`theme.conf.user` 保留、重复安装和卸载测试，未触碰系统主题目录。
- 日志中仍存在 `QLocalSocket`、`Lavanda-Light` 旧元数据、跨线程事件过滤器提示；Breeze 对照组同样存在，不属于本主题适配阻断。
- 本机 `/usr/bin/qmllint` 实为 Qt 5.15 工具，无法解析 Qt 6 可选链语法（`?.`/`??`），因此语法正确性以 greeter 实际加载结果为准。

### 11.3 尚未验证

- 真实注销登录（本机配置了自动登录，未调整）；无密码账户、错误密码重试、会话切换、虚拟键盘交互、Caps Lock 真实按键状态。
- 1024×768、1280×720、1368×768 实机渲染（当前无 Xvfb，仅按布局公式核算并用 offscreen 800×800 覆盖窄宽度分支）。
- 多屏实机、X11 greeter、其他发行版 Qt/Plasma 版本。
- 辅助功能名称仅静态添加，未用屏幕阅读器验证。

### 11.4 系统操作状态

- 已按用户要求删除系统旧版 `/usr/share/sddm/themes/Ocean-P6`，未保留备份。
- 新适配版尚未部署到系统主题目录；`install.sh` / `uninstall.sh` 已提供并在临时目录完成测试。
- 未修改 `/etc/sddm.conf*` 或当前 `Lavanda` 主题，未重启 SDDM；系统级安装与真实登录验收由用户手动完成。
