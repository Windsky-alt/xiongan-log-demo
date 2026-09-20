# 雄安科创园 · 施工/质量日志 演示站

一个**版本化发布**的静态站点：地址固定不变，每次发布只更新内容。
做法与「北京无线局项目 / demo-site」完全一致。

- 打开演示：`latest.html`（永远是最新版）
- 历史版本：`versions/<日期>-v<版本>/`（每一版都能单独打开、单独下载）
- 首次配置：双击 `首次配置.bat`
- 日常更新：双击 `发布更新.bat`，填写更新说明即可

---

## 一、首次配置（只做一次）

### 1. 在 GitHub 建一个空仓库

打开 https://github.com/new

- Repository name：例如 `xiongan-log-demo`
- 可见性：**Public**（免费版 GitHub Pages 需要公开仓库）
- **不要**勾选 Add README / .gitignore / license（保持空仓库）

### 2. 双击 `首次配置.bat`

会依次问你：

| 提示 | 填什么 |
|---|---|
| GitHub 账号名 | `Windsky-alt` |
| 仓库名 | 你刚建的名字，例如 `xiongan-log-demo` |
| 提交用的姓名 | 你的名字（只用于 git 提交记录） |
| 提交用的邮箱 | 你的邮箱（只用于 git 提交记录） |
| 粘贴令牌 | **直接回车跳过**（推荐） |

> 跳过令牌后，第一次推送会弹出浏览器登录窗口，选 **Browser / 浏览器**，
> 在网页里点一下 **Authorize** 授权即可，不用去建令牌。
> 授权一次以后就记住了，以后发布不再登录。

脚本会顺带设好两个**必须**的本地配置：

```
http.sslBackend = openssl                    # 本机 schannel 握手会失败
credential.gitHubAuthModes = browser         # 避免被要求输入账号密码
```

### 3. 双击 `发布更新.bat` 推第一次

填个更新说明（可留空），跑完仓库里才会有 `main` 分支。

### 4. 开启 GitHub Pages

仓库页面 → **Settings** → 左侧 **Pages**

- **Source** 选 **Deploy from a branch**
- **Branch** 选 **main**，目录选 **/ (root)**
- 点 **Save**

> 注意：是 **Deploy from a branch**，**不是** GitHub Actions。
> 这套站点是纯静态文件，用分支发布最简单；反而第一次跑之前分支还不存在，选不到。

等 1～2 分钟，访问：

```
https://Windsky-alt.github.io/你的仓库名/
https://Windsky-alt.github.io/你的仓库名/latest.html
```

---

## 二、日常更新

1. 改好工作区里的演示页（`D:\雄安\雄安科创园_施工日志演示_v4.html`）
2. 双击本目录下的 **`发布更新.bat`**
3. 按提示输入本次更新说明（可留空直接回车）

脚本会自动：

- 把演示页快照归档到 `versions\<今天>-v<版本>\`
- 覆盖 `latest.html`
- 把四个原模板 docx 一起归档（方便在网页上下载核对）
- 重建首页 `index.html`（最新版卡片 + 历史版本表格）
- `git add / commit / push`

**地址不变**，约 30 秒后线上即最新版。

### 想让这次更新单独占一行历史？

改演示页里的版本号：

```html
<div class="app" data-prd-version="1.0" data-updated="2026-09-20">
```

把它改成 `1.1` 再发布，历史列表就会多一行 `V1.1`。
不改的话，同一天发布会**覆盖当天那一版**（脚本会提示）。

---

## 三、目录说明

```
index.html                      首页（由 publish.ps1 自动生成，不要手改）
latest.html                     最新版演示（固定入口）
versions/
  2026-09-20-v1.0/
    index.html                  该版本的演示页（浏览器打开直接显示）
    施工日志演示-V1.0.html        同一份内容，带扩展名，供「下载」用
    施工日期（项目版）-0920.docx   四个原模板，随版本归档
    施工日志（个人版）-0920.docx
    质量日志-项目版-0918.docx
    质量日志-个人版_0918.docx
    meta.json                   版本号 / 日期 / 更新说明
publish.ps1                     发布脚本（双击 bat 时调用）
setup.ps1                       首次配置脚本
fix-auth.ps1                    认证修复脚本
首次配置.bat / 发布更新.bat / 修复登录.bat
.nojekyll                       让 GitHub Pages 不做 Jekyll 处理
```

---

## 四、出问题怎么办

### 推送失败

脚本会打印原始报错并给出对应处理。常见几种：

| 报错 | 原因与处理 |
|---|---|
| `Authentication failed` / `Repository not found` | 令牌过期，或令牌没勾选这个仓库 → 重新跑 `首次配置.bat` |
| 弹出登录窗口 | 选 **Browser / 浏览器** → 网页里点 **Authorize** |
| 被要求输入 Username / Password | Username 填账号名，Password **粘贴令牌**（不是账号密码） |
| `Connection was reset` / `timeout` | 网络抖动，重跑一次；国内访问 GitHub 不稳时多试几次 |
| `schannel: AcquireCredentialsHandle failed` | 双击 **`修复登录.bat`**，或执行 `git config --local http.sslBackend openssl` |

### 网页打开是 404

- Settings → Pages 里 Source 是否选了 **Deploy from a branch** + **main** + **/ (root)**
- 仓库是否 **Public**
- 第一次开启后要等 **1～2 分钟**
- 刚 push 完看仓库里有没有 `index.html`（首页）—— 它是发布脚本生成的

### 国内访问 github.io 很慢

GitHub Pages 在国内确实不稳。如果实在打不开，
可以把同一个仓库再推一份到 Gitee，用 Gitee Pages（国内秒开）：

```powershell
git remote add gitee https://gitee.com/你的用户名/仓库名.git
git push gitee main
```

然后在 Gitee 仓库「服务 → Gitee Pages」里开启部署（需实名，且每次推送后要在网页点一次「更新」）。

---

## 五、这个演示是什么

施工 / 质量日志的交互原型：

- **台账**是父子结构：父行 = 项目版（每天一条，自动生成），展开后是按「人员配置」自动生成的个人版子日志
- 操作栏统一为 **填写 / 预览 / 删除**
- 左侧勾选框可多选，点上方 **导出** 批量导出 Word
- 「本周施工计划执行情况」里带红色 `*` 的是必填，留空会拦截保存
- 演示是**完全自包含的单文件 HTML**（四个 Word 模板以 base64 内嵌），无外部依赖，可离线打开、可直接转发
- **导出**是在**原模板文件上只替换文字**，生成带数据的 Word 日志 ——
  版式、字体、页边距、分页全部沿用原文件，一个字符都没动
