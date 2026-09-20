# 雄安科创园 · 施工/质量日志交互演示

一个**单文件**的交互演示页：台账（项目版父 / 个人版子）→ 填写 → 预览 → **导出带数据的 Word 日志**。
导出是在**原模板文件上只替换文字**，版式与原文件完全一致。

在线地址（部署后）：
```
https://<你的用户名>.github.io/<仓库名>/
```

---

## 仓库内容

```
index.html                       演示页（单文件，内嵌四个原模板，可离线打开）
samples/                         四个日志的导出样例（原版式 + 数据），可直接下载查看
  ├─ 施工日期（项目版）-0920.docx
  ├─ 施工日志（个人版）-0920.docx
  ├─ 质量日志-项目版-0918.docx
  └─ 质量日志-个人版_0918.docx
.github/workflows/deploy.yml     推送 main 后自动发布到 GitHub Pages
.nojekyll                        让 GitHub Pages 不做 Jekyll 处理
```

---

## 部署步骤（在本机执行）

### 1. 在 GitHub 新建一个空仓库

打开 https://github.com/new

- Repository name：例如 `xiongan-log-demo`
- 可见性：**Public**（免费版 GitHub Pages 需要公开仓库）
- **不要**勾选 Add README / .gitignore / license（保持空仓库）

### 2. 在本机把 site 目录推上去

在 PowerShell 里执行（把 `你的用户名` 和 `xiongan-log-demo` 换成实际值）：

```powershell
cd "D:\雄安\site"

git init -b main
git add -A
git commit -m "雄安科创园 施工/质量日志交互演示：台账 + 导出带数据 Word"

git remote add origin https://github.com/你的用户名/xiongan-log-demo.git
git push -u origin main
```

> 如果 push 时要求登录：GitHub 早已不支持账号密码。
> 请用 **Personal Access Token**（Settings → Developer settings → Personal access tokens → Fine-grained tokens，
> 勾上该仓库的 `Contents: Read and write`），在密码位置粘贴 token。
> 或者本机装 GitHub CLI 后执行 `gh auth login`，再用 `gh repo create` 建仓推送。

### 3. 打开 Pages

仓库页面 → **Settings** → 左侧 **Pages** → Source 选 **GitHub Actions**（不要选 Deploy from a branch）。

做完这一步，刚才的 push 会自动触发 `deploy.yml`。到仓库 **Actions** 标签页能看到运行进度，
变绿后访问：

```
https://你的用户名.github.io/xiongan-log-demo/
```

---

## 以后怎么更新

改完演示页后，把新版本复制进 `site` 再提交即可：

```powershell
# 1) 把最新的演示页覆盖到站点
Copy-Item "D:\雄安\雄安科创园_施工日志演示_v4.html" "D:\雄安\site\index.html" -Force

# 2) 提交并推送（自动重新部署）
cd "D:\雄安\site"
git add -A
git commit -m "更新演示页"
git push
```

推送后大约 30～60 秒，线上就是最新版（Actions 变绿即生效）。

> 说明：`index.html` 里内嵌了四个模板，所以每次改动都会产生约 400KB+ 的 diff，仓库体积增长偏快。
> 如果哪天觉得仓库太大，可以改成把模板放到 `templates/` 目录、页面运行时 `fetch` 加载，
> 那样页面只有 100KB 左右、模板永不改动，git 历史会干净很多。

---

## 本地预览

`index.html` 是自包含的，双击就能用（导出功能在本地 `file://` 下也能工作）。
如果想让本地预览和线上完全一致，起一个静态服务：

```powershell
cd "D:\雄安\site"
python -m http.server 8080     # 然后访问 http://127.0.0.1:8080/
```

---

## 使用说明

1. 左侧切「施工日志 / 质量日志」
2. 台账是**父子结构**：父行是项目版（每天一条、自动生成），展开后是按「人员配置」自动生成的个人版子日志
3. 操作栏统一为 **填写 / 预览 / 删除**
4. 左侧勾选框可多选，点上方 **导出** 批量导出 Word
5. 「本周施工计划执行情况」里带红色 `*` 的是必填，留空会拦截保存
6. 导出的文件名形如 `2026-09-19_施工日志_个人版_张三.docx`

导出的 Word 用四个原模板：
`施工日期（项目版）-0920.docx`、`施工日志（个人版）-0920.docx`、
`质量日志-项目版-0918.docx`、`质量日志-个人版_0918.docx`。
