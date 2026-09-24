# MountMate / 挂载管家

**直接下载：[MountMate 0.3.3 Apple Silicon 安装包（DMG）](https://github.com/xiaohardy/MountMate/releases/download/v0.3.3/MountMate-0.3.3-build6-preview-arm64.dmg)** · [版本说明](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.3)

安装包位于 GitHub 的 **Releases → Assets（资源）** 中；**Packages** 栏不会显示 DMG。

[English](README.md) · [发布检查单](RELEASING.md)

MountMate 是 macOS 菜单栏挂载工具：保持指定 SMB 共享连接，按规则手动或每日清理临时挂载。当前提供 **Apple Silicon 预览版**。

## 安装或更新

1. 下载 [Apple Silicon DMG 安装包](https://github.com/xiaohardy/MountMate/releases/download/v0.3.3/MountMate-0.3.3-build6-preview-arm64.dmg)。
2. 打开镜像，将 **MountMate.app** 拖到 **Applications** 快捷方式。
3. 从“应用程序”启动 MountMate。关闭主窗口后，菜单栏入口仍会运行；要退出，请在菜单栏选择“退出 MountMate”。

若正在使用 v0.3.2，请先到旧版“固定挂载”关闭“登录时启动 MountMate”，再从菜单栏退出旧进程，之后替换应用。v0.3.3 改用了公开的应用标识符；配置文件路径不变，但 macOS 可能重新询问网络权限或 SMB 密码。打开新版后检查固定挂载，如提示缺少密码，在共享编辑页重新填写，最后重新开启登录启动。如果“系统设置 → 通用 → 登录项”中仍有旧版条目，请移除旧条目。

### 首次打开时的 macOS 安全提示

这个预览版使用临时签名，**尚未经过 Apple 公证**。从 GitHub 下载后，macOS 可能阻止首次打开。只有确认安装包来自[本项目发布页](https://github.com/xiaohardy/MountMate/releases/tag/v0.3.3)并且你信任它时，才继续：

1. 尝试打开应用一次。如果出现拦截提示，选择“完成”（如有）。
2. 打开“系统设置 → 隐私与安全性”，在“安全性”中点击“仍要打开”。
3. 系统再次询问时点击“打开”。详见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

如果 macOS 提示 **“App 已损坏”**或**“将损坏您的电脑”**，先停止使用，并在 [Issues](https://github.com/xiaohardy/MountMate/issues)反馈；不要关闭整个系统的安全检查。

程序面向 Apple Silicon、macOS 14 或更新版本。当前预览版在 macOS 27 上构建和检查；较早的 macOS 版本、Intel Mac 和全新 Mac 的首次打开尚未实测。

## 使用说明

- **固定挂载：**可以填写 smb://服务器/共享名称 手动添加 SMB 共享，地址中不要放密码。也可以在“概览 → 从当前挂载添加”中选择已经挂载的 SMB 共享。如果挂载来源包含用户名，导入时会带入。导入后先尝试使用 macOS 已保存的 SMB 凭据；若重连时提示缺少密码，可编辑共享，将密码存入 MountMate 的钥匙串项目。
- **保持连接：**为固定挂载开启“保持连接”后，程序在启动、唤醒、网络恢复和定期检查时发现断线会尝试重连。在程序中选择“断开并暂停”会暂停自动重连，直到手动恢复。如果挂载仍在、但访问检查失败，程序会标记“连接异常”，不会强制卸载后重挂。
- **当前挂载：**概览扫描 /Volumes 下能够识别的 SMB、NFS、AFP、WebDAV、磁盘镜像和外置磁盘；只有 SMB 共享可以导入为固定挂载。
- **清理与保护：**在“清理规则”中选择参与“清理临时挂载”和每日清理的类别。默认只选择磁盘镜像和明确标记为可移除的 USB 卷；其他外置盘和网络共享默认不清理。当前挂载旁的护盾按钮可将其排除在两种清理之外。“卸载”是单独的手动操作，受保护挂载也可以手动请求卸载。保持连接的 SMB 共享始终受到批量清理保护。
- **每日时间：**每日清理默认关闭，初始时间为 Mac 本地时间 03:00。只有应用在计划时间之前就已运行且保持唤醒，才会在计划时间之后的五分钟窗口内执行一次。睡眠或退出期间错过的任务不会在之后补执行，程序也不会主动唤醒 Mac。
- **星星与语言：**菜单栏最多显示 12 个顺时针排列的星位，从顶部开始；固定挂载优先占据前面的星位。固定 SMB 挂载断开或访问检查失败时星星会变暗；其他挂载的星星反映扫描时是否仍存在。超过 12 个挂载时不会新增星位。语言选择位于“概览”顶部，提供八种界面语言。

程序只向 macOS 发起正常卸载请求。如果卷正在使用或系统因其他原因拒绝，卷会保持挂载，错误会记录在“运行记录”中。程序不会强制弹出磁盘、为清理唤醒 Mac，也不会恢复断网时失败的文件复制。自动重连目前只支持 SMB。

## 配置、隐私与恢复

配置和最近 150 条运行记录位于 **~/Library/Application Support/MountMate/settings.json**，文件权限限定为当前用户。文件可能包含共享名称、SMB 地址、用户名和挂载标识；分享前请删除这些信息。密码保存在 macOS 钥匙串中。程序不含分析统计或数据上传服务，只连接你配置的 SMB 服务器，并通过 macOS 接口检查或卸载挂载。

如果程序提示配置无法读取或保存，它会保留原配置文件，并暂停修改和清理。请先退出程序，备份上述文件；然后恢复一份可用备份，或在决定从空配置重来时将损坏文件移到别处。若问题来自磁盘空间或文件权限，先解决这些问题再启动程序。从空配置启动后，需要重新添加固定挂载。不要把原配置文件公开发布。

登录后需要自动重连时，请在“固定挂载”中开启“登录时启动 MountMate”。自动重连和每日清理都要求应用保持运行。

## 从源码构建

在 Apple Silicon Mac 上安装 Xcode 及 Swift 工具，然后运行：

~~~sh
swift test --scratch-path /tmp/mountmate-test-build --disable-sandbox
./scripts/package-dmg.sh
~~~

脚本在 dist/ 生成临时签名的预览版 DMG，并检查签名、架构、版本、图标、八种界面语言、系统权限提示的翻译和镜像校验。构建不需要连接 NAS。运行 scripts/create-icon.sh 可重新生成图标。

发现问题或有建议，请到 [GitHub Issues](https://github.com/xiaohardy/MountMate/issues)反馈。源码按 [MIT 许可证](LICENSE)发布。
