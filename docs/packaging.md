# 打包与自动发布

## 当前交付

当前版本 `0.1.0-beta.2`，Windows x64 便携 EXE。普通启动直接启用手动重喂、取回原文、设置与诊断；`features-mvp.ahk` 中的已冻结自动切换仍只在显式历史入口启用。仓库不存在 `feature-mvp` 分支，无需合并 Git 分支。

使用官方 Ahk2Exe 编译脚本及所有引用模块，显式指定 AutoHotkey v2 x64 base，将运行时嵌入 EXE；使用者无需安装 AHK。构建禁用压缩，不要求 Python 或任何旁边的源码文件来运行 EXE。首次交付尚未代码签名。

## 本地构建

原生 Windows，Python 3.8+，有网络可下载固定版本工具；不修改系统 AHK 安装。

```powershell
python tools/build.py
```

脚本自动完成：上游 ZIP 的 SHA-256 核对、29 项 AHK 检查、Ahk2Exe 编译、x64/版本/七种图标尺寸核对、将单个 EXE 放入带中文及空格的空目录验证加载、生产入口/暂停/恢复/清理及指向 EXE 的私有自启快捷方式。验证不访问用户真实选区或输入法，不修改真实启动项。

输出为 `dist/Ime-2Chinese-v0.1.0-beta.2-windows-x64/` 和同名 ZIP、`.sha256`。包中包含使用说明、构建来源/校验信息、运行时许可和对应运行时源代码。工具缓存和产物不提交到 Git。

图标由用户指定头像原图转换，完整 ICO 用文本保存在 `assets/app.ico.b64`；无需 CI 访问 F 盘。工具链下载版本/哈希固定在 `tools/toolchain.json`，更新时需重新验证。版本统一维护 `src/config/AppInfo.ahk`；标签必须匹配 `v` 加 `Version`，Windows 数字版本维护 `FileVersion`。

## GitHub Actions 策略

工作流：`.github/workflows/package.yml`。

首次 main 构建已在 GitHub Windows runner [成功运行](https://github.com/ziyumieming/Ime-2Chinese/actions/runs/37417632655)，ZIP 与校验文件已上传为 Artifacts。此前 Release 步骤因普通 main 提交而跳过；本轮按用户要求尝试公开 beta.2，结果记录在 ROADMAP。

| 触发 | 行为 |
| --- | --- |
| 提交到 main | 自动检查、编译及独立启动验证；保存 ZIP 和校验文件为 Actions Artifacts，保留 30 天 |
| 手动 Run workflow，release_tag 留空 | 同上，仅构建 |
| 推送匹配版本的 v 标签 | 验证通过后由 virginialogy[bot] 创建 Release 草稿并附加文件 |
| 手动 Run workflow，填写已存在的 release_tag | 检出对应标签后重建并更新 bot 自己的草稿；拒绝覆盖已公开版本 |

推荐测试版使用 `v0.1.0-beta.2` / 后续 `beta.N`，自动标为 prerelease；UAT 后用 `v0.1.0` 等稳定标签。版本标签及指定已有标签的 Release 默认草稿，验收后在 Releases 编辑说明并点击 Publish。每次 main 提交不产生正式版本，不做版本自动递增。需要发布当前测试版时，手动运行工作流并勾选 `publish_beta`，保持 `release_tag` 留空；仅允许从 main 发布 beta/rc。此模式先创建对应版本标签和草稿，上传 ZIP/校验文件并核对大小及服务端哈希后，公开为 prerelease；失败则保留草稿，不公开不完整附件。稳定版仍须验收后手动公开。标签触发的后续运行识别完整的 bot 已发布版本并保留，不覆盖附件。

自动构建不需要额外密钥。自动 Release 需一次设置（不要把任何私钥粘贴到 Issue、代码或日志）：

1. 仓库 Settings → Actions → General，允许 Actions 以及本工作流使用的官方 Actions。
2. GitHub App `virginialogy` 安装授权包含此仓库，具备 **Contents: Read and write**。提交工作流文件还需 App 的 **Workflows: Read and write** 权限；修改 App 权限后接受安装权限更新。
3. Settings → Secrets and variables → Actions → Variables，添加 `APP_CLIENT_ID`，值为该 App 的 Client ID。
4. 同页面 Secrets 添加 `APP_PRIVATE_KEY`，值为该 App 私钥的完整 PEM 内容。Release 作业临时生成仅授予此仓库 Contents write 的安装令牌，并验证 App 名称；不使用个人 PAT 发布。
5. 按版本号创建已验收提交的标签并推送。标签必须指向包记录的源提交；缺少 Release 凭据时构建附件仍保留，补全后手动填写已有标签重跑。

源码在本地修改未提交时仍可生成测试包，`build-info.json` 会记录 `source_dirty: true`；自动 Release 拒绝这类包。工作流固定 Action 的提交 SHA，下载工具固定 SHA-256。

依据： [AHK 编译说明](https://github.com/AutoHotkey/AutoHotkeyDocs/blob/v2/docs/Scripts.htm)、[GitHub App Token Action](https://github.com/actions/create-github-app-token)、[GitHub 工作流触发](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)。
