# AGENTS.md

## 项目说明

Ocean-P6 是一个基于 Qt 6 / QML 的 SDDM 登录主题，面向 KDE Plasma 6。

- 项目代码来源：https://github.com/EliverLara/Juno/tree/ocean/kde/sddm/Ocean-P6
- 适配状态：已完成 Plasma 6.8.2 / Qt 6.11 代码适配，并通过 SDDM 测试模式（默认与软件渲染）验证；真实注销登录验收待执行，详见 `PLASMA_6.8_ADAPTATION.md`。
- 入口由 `metadata.desktop` 中的 `MainScript=Main.qml` 指定。
- 修改时应保留原有版权、作者及来源信息，不得回退到 Qt 5 或 Plasma 5 的模块与接口。

## 目录结构

- `Main.qml`：主题根组件，负责背景、登录流程、虚拟键盘、电源操作及页脚布局。
- `Login.qml`：用户名、密码输入与登录请求。
- `Background.qml`：图片/纯色背景组件。
- `KeyboardButton.qml`、`SessionButton.qml`：键盘与会话选择控件。
- `components/`：登录界面、用户列表、电池、时钟等可复用 QML 组件。
- `assets/`：背景图与功能图标。
- `theme.conf`：背景、字体、颜色等主题配置。
- `metadata.desktop`：SDDM 主题元数据。
- `preview.png`：主题预览图。
- `install.sh`、`uninstall.sh`：系统级安装/卸载脚本，需要 sudo。
- `README.md`：中英文安装、配置与卸载说明。
- `PLASMA_6.8_ADAPTATION.md`：Plasma 6.8 适配与验证记录。

## 开发约定

1. 使用 Qt 6、Plasma 6 兼容的 QML 模块，保持现有导入别名和组件组织方式。
2. 优先复用 `theme.conf` 中的 `config` 配置项及现有组件，避免新增重复样式和硬编码配置。
3. `sddm`、`userModel`、`sessionModel`、`config` 等对象由运行环境注入，不要创建同名替代对象。
4. 登录、会话切换、虚拟键盘及电源操作属于核心流程；非任务要求不得改变其行为。
5. 保留 `i18nd` / `i18ndc` 的翻译域与上下文，新增用户可见文本时同步支持国际化。
6. 本地资源使用项目内相对路径或 `Qt.resolvedUrl()`，不要写入开发机专属绝对路径。
7. 不在代码、日志或提交中记录真实用户名、密码及其他认证信息。
8. 遵循现有 QML 风格，保持改动最小；不要为单次修改引入新的抽象层或无关重构。

## 验证方式

在项目根目录执行，优先验证本次修改涉及的文件：

```bash
qmllint Main.qml Login.qml components/*.qml
sddm-greeter-qt6 --test-mode --theme "$PWD"
```

- `qmllint` 对环境注入对象或 KDE 模块产生的警告应结合实际运行结果判断，但新增语法错误必须修复。
- 使用 SDDM 测试模式检查界面，不要通过重启真实显示管理器验证。
- 需要格式化时仅处理本次修改的 QML 文件，并检查格式化产生的差异，避免全项目无关变更。
- 涉及界面行为时，至少检查背景加载、用户选择、密码提交、会话切换、虚拟键盘、电源按钮及不同分辨率下的布局。
- 修改 `install.sh` / `uninstall.sh` 后先执行 `bash -n`，并用临时目标目录验证；不要直接对 `/usr/share/sddm/themes` 做测试安装或卸载。

## Git 约定

- 提交前检查 `git status` 与 `git diff`，确保仅包含任务相关改动。
- 每次提交只表达一个明确目的，提交信息简洁描述实际变更。
- 不提交真实用户数据、认证信息或本机临时文件。
