#Requires -Version 5.1
<#
  publish.ps1 —— 把雄安科创园演示页发布到 GitHub Pages
  （双击 发布更新.bat 时自动调用本脚本）

  用法（在本文件所在目录）：
    .\publish.ps1                                  # 发布当前工作区最新版
    .\publish.ps1 -Note "增加导出批量下载"            # 带更新说明
    .\publish.ps1 -Source ..\其他演示.html           # 指定其他源文件
    .\publish.ps1 -RenderOnly                      # 只重建首页，不发布
    .\publish.ps1 -NoPush                          # 提交但不推送
    .\publish.ps1 -Prompt                          # 交互式询问更新说明（bat 用）

  行为：把源 HTML 快照归档到 versions\<日期>-v<版本>\index.html，
        同时覆盖 latest.html，并把四个原模板一起归档，最后重建首页 index.html。

  版本号取自演示页里的 data-prd-version="x.y"。
  想把这次更新单独留一行历史，就把 HTML 里那个值改大（1.0 → 1.1）。
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Note = '',
    [switch]$RenderOnly,
    [switch]$NoPush,
    [switch]$Prompt
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

# 双击 bat 时带 -Prompt：中文提示放在这里而不敢放进 .bat，
# 因为 cmd.exe 用 OEM 代码页(936)解析 bat，UTF-8 中文会被拆成乱码路径。
if ($Prompt -and -not $Note -and -not $RenderOnly) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  发布雄安科创园演示站到 GitHub Pages" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    $Note = Read-Host "请输入本次更新说明（可留空直接回车）"
    Write-Host ""
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}
function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}
function ConvertTo-JsonString([string]$Value) {
    if ($null -eq $Value) { return '""' }
    $s = $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
    return '"' + $s + '"'
}

# 四个原模板（导出用）+ 两个交付说明文档，随版本一起归档，方便下载核对
$TemplateNames = @(
    '施工日期（项目版）-0920.docx',
    '施工日志（个人版）-0920.docx',
    '质量日志-项目版-0918.docx',
    '质量日志-个人版_0918.docx'
)
# 交付说明文档（与演示同版本归档，另在 docs/ 常驻一份）
$DocNames = @(
    '施工日志需求文档（0921）.docx',
    '质量日志需求文档0921.docx'
)
# 文件用途提示
$FileHints = @{
    '施工日期（项目版）-0920.docx' = '施工日志 · 项目版'
    '施工日志（个人版）-0920.docx' = '施工日志 · 个人版'
    '质量日志-项目版-0918.docx'   = '质量日志 · 项目版'
    '质量日志-个人版_0918.docx'   = '质量日志 · 个人版'
    '施工日志需求文档（0921）.docx' = '施工日志 需求与字段实现说明（最新）'
    '质量日志需求文档0921.docx'     = '质量日志 需求与字段实现说明（最新）'
}
# 已下线的旧文件：每次发布从 docs/ 与新版本目录里清掉，避免下载页残留旧版
$RetiredDocs = @(
    '施工日志_开发实现说明版_项目版和个人版_字段级蓝白_交付版.docx',
    '质量日志_开发实现说明版_项目版和个人版_字段级蓝白_交付版.docx'
)

# ---------------------------------------------------------------- 1. 归档源文件
$verName = ''
if (-not $RenderOnly) {
    $workspace = Split-Path $root -Parent
    if (-not $Source) { $Source = Join-Path $workspace '雄安科创园_施工日志演示_v4.html' }
    if (-not (Test-Path $Source)) { throw "找不到源文件：$Source" }
    $Source = (Resolve-Path $Source).Path

    $html = Read-Utf8 $Source
    $m = [regex]::Match($html, 'data-prd-version="([^"]+)"')
    $prdVer = if ($m.Success) { $m.Groups[1].Value } else { '1.0' }
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $verName = "$today-v$prdVer"
    $verDir = Join-Path $root "versions\$verName"

    if (Test-Path $verDir) {
        Write-Host "提示：versions\$verName 已存在，本次将覆盖该日期的快照，历史列表不会新增一行。" -ForegroundColor Yellow
        Write-Host "      若要把这次更新单独留存，请先把 HTML 里的 data-prd-version 改成新值（例如 1.0 → 1.1）。" -ForegroundColor DarkGray
    }

    New-Item -ItemType Directory -Force -Path $verDir | Out-Null
    Copy-Item $Source (Join-Path $verDir 'index.html') -Force
    Copy-Item $Source (Join-Path $root 'latest.html') -Force

    # 带扩展名的独立文件名：浏览器点「下载演示文件」时才能存成 .html
    $htmlFile = "施工日志演示-V$prdVer.html"
    Copy-Item $Source (Join-Path $verDir $htmlFile) -Force

    # 归档四个原模板
    $tplCount = 0
    foreach ($tn in $TemplateNames) {
        $tp = Join-Path $workspace $tn
        if (Test-Path $tp) {
            Copy-Item $tp (Join-Path $verDir $tn) -Force
            $tplCount++
        }
    }
    if ($tplCount -eq 0) {
        Write-Host "提示：工作区里没找到四个原模板 docx，本次未归档模板。" -ForegroundColor Yellow
    }

    # 交付说明文档：归档进版本目录，并在 docs/ 常驻一份（地址不变，便于长期引用）
    $docCount = 0
    $docsRoot = Join-Path $root 'docs'
    New-Item -ItemType Directory -Force -Path $docsRoot | Out-Null
    foreach ($dn in $DocNames) {
        $dp = Join-Path $workspace $dn
        if (Test-Path $dp) {
            Copy-Item $dp (Join-Path $verDir $dn) -Force
            Copy-Item $dp (Join-Path $docsRoot $dn) -Force
            $docCount++
        }
    }
    if ($docCount -eq 0) {
        Write-Host "提示：工作区里没找到交付说明文档，本次未归档。" -ForegroundColor Yellow
    } else {
        Write-Host "已归档交付说明文档 $docCount 个（另存 docs/）" -ForegroundColor Green
    }

    # 清理已下线的旧文档：docs/ 里删掉；版本目录里也删掉（保持归档与新口径一致）
    foreach ($rn in $RetiredDocs) {
        $old1 = Join-Path $docsRoot $rn
        $old2 = Join-Path $verDir $rn
        if (Test-Path $old1) { Remove-Item $old1 -Force; Write-Host "已下线 docs\$rn" -ForegroundColor DarkGray }
        if (Test-Path $old2) { Remove-Item $old2 -Force }
    }

    $meta = '{' + "`n" +
            '  "version": ' + (ConvertTo-JsonString $prdVer) + ',' + "`n" +
            '  "date": ' + (ConvertTo-JsonString $today) + ',' + "`n" +
            '  "note": ' + (ConvertTo-JsonString $Note) + ',' + "`n" +
            '  "source": ' + (ConvertTo-JsonString (Split-Path $Source -Leaf)) + ',' + "`n" +
            '  "htmlFile": ' + (ConvertTo-JsonString $htmlFile) + ',' + "`n" +
            '  "templates": ' + $tplCount + ',' + "`n" +
            '  "docs": ' + $docCount + "`n" +
            '}' + "`n"
    Write-Utf8NoBom (Join-Path $verDir 'meta.json') $meta
    Write-Host "已归档版本：$verName（模板 $tplCount 个）" -ForegroundColor Green
}

# ---------------------------------------------------------------- 2. 重建首页
$versionsRoot = Join-Path $root 'versions'
$items = @()
if (Test-Path $versionsRoot) {
    foreach ($dir in (Get-ChildItem $versionsRoot -Directory | Sort-Object Name -Descending)) {
        $metaPath = Join-Path $dir.FullName 'meta.json'
        # 注意：PowerShell 变量名不区分大小写，局部变量绝不能叫 $note/$ver/$date，
        # 否则会覆盖同名参数，导致提交信息用错。
        $mv = $dir.Name; $md = $dir.Name; $mn = ''; $mh = ''; $mt = 0
        if (Test-Path $metaPath) {
            try {
                $obj = (Read-Utf8 $metaPath) | ConvertFrom-Json
                if ($obj.version) { $mv = $obj.version }
                if ($obj.date) { $md = $obj.date }
                if ($obj.note) { $mn = $obj.note }
                if ($obj.htmlFile) { $mh = $obj.htmlFile }
                if ($obj.templates) { $mt = [int]$obj.templates }
            } catch { Write-Warning "meta.json 解析失败：$metaPath" }
        }
        if (-not $mh) {
            $fallback = Get-ChildItem $dir.FullName -Filter '*.html' -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne 'index.html' } | Select-Object -First 1
            $mh = if ($fallback) { $fallback.Name } else { 'index.html' }
        }
        $items += [pscustomobject]@{ Dir = $dir.Name; Ver = $mv; Date = $md; Note = $mn; Html = $mh; Tpl = $mt }
    }
}

$latest = if ($items.Count -gt 0) { $items[0] } else { $null }
$rows = ''
foreach ($it in $items) {
    $link = "versions/$($it.Dir)/index.html"
    $htmlLink = "versions/$($it.Dir)/$($it.Html)"
    $tplCell = if ($it.Tpl -gt 0) {
        '<a class="dl" href="templates.html">4 个模板</a>'
    } else { '<span class="muted">—</span>' }
    $noteCell = if ($it.Note) { [System.Net.WebUtility]::HtmlEncode($it.Note) } else { '<span class="muted">—</span>' }
    $rows += '<tr><td class="ver">V' + $it.Ver + '</td><td>' + $it.Date + '</td><td>' + $noteCell + '</td>' +
             '<td class="nowrap"><a class="open" href="' + $link + '">打开</a><span class="sep"></span>' +
             '<a class="dl" href="' + $htmlLink + '" download>下载HTML</a></td><td>' + $tplCell + '</td></tr>' + "`n"
}
if (-not $rows) { $rows = '<tr><td colspan="5" class="muted" style="text-align:center;padding:28px">暂无版本</td></tr>' }

$latestVer = if ($latest) { 'V' + $latest.Ver } else { '—' }
$latestDate = if ($latest) { $latest.Date } else { '—' }
$latestNote = if ($latest -and $latest.Note) { [System.Net.WebUtility]::HtmlEncode($latest.Note) } else { '暂无更新说明' }
$latestHtml = if ($latest) {
    '<a class="btn ghost" href="versions/' + $latest.Dir + '/' + $latest.Html + '" download>下载演示文件（HTML）</a>'
} else { '' }
# 「下载原模板」指向独立的模板页（四个文件各一个下载按钮）
$latestTpl = if ($latest -and $latest.Tpl -gt 0) {
    '<a class="btn ghost" href="templates.html">下载原模板（Word，共 4 个）</a>'
} else { '' }

# 模板页要用的四个文件列表（含字节数，缺失的标出来）
$tplFileRows = ''
foreach ($tn in $TemplateNames) {
    $tp = if ($latest) { Join-Path (Join-Path $root "versions\$($latest.Dir)") $tn } else { '' }
    $size = if ($tp -and (Test-Path $tp)) { '{0:N0} KB' -f ((Get-Item $tp).Length / 1KB) } else { '未归档' }
    $href = if ($latest) { "versions/$($latest.Dir)/$tn" } else { '#' }
    $hint = if ($FileHints.ContainsKey($tn)) { $FileHints[$tn] } else { '' }
    $tplFileRows += '<li class="tplrow"><span class="tplname">' + [System.Net.WebUtility]::HtmlEncode($tn) +
                    '<span class="tplhint">' + [System.Net.WebUtility]::HtmlEncode($hint) + '</span></span>' +
                    '<span class="tplsize">' + $size + '</span>' +
                    '<a class="btn ghost" href="' + $href + '" download>下载</a></li>' + "`n"
}
if (-not $tplFileRows) {
    $tplFileRows = '<li class="tplrow"><span class="tplname">暂无归档模板</span></li>' + "`n"
}

$docFileRows = ''
foreach ($dn in $DocNames) {
    $dp = Join-Path (Join-Path $root 'docs') $dn
    $size = if (Test-Path $dp) { '{0:N0} KB' -f ((Get-Item $dp).Length / 1KB) } else { '未归档' }
    $hint = if ($FileHints.ContainsKey($dn)) { $FileHints[$dn] } else { '' }
    $docFileRows += '<li class="tplrow"><span class="tplname">' + [System.Net.WebUtility]::HtmlEncode($dn) +
                    '<span class="tplhint">' + [System.Net.WebUtility]::HtmlEncode($hint) + '</span></span>' +
                    '<span class="tplsize">' + $size + '</span>' +
                    '<a class="btn ghost" href="docs/' + $dn + '" download>下载</a></li>' + "`n"
}
if (-not $docFileRows) {
    $docFileRows = '<li class="tplrow"><span class="tplname">暂无交付说明文档</span></li>' + "`n"
}
$tplVerLabel = if ($latest) { 'V' + $latest.Ver + '（' + $latest.Date + '）' } else { '—' }
$updatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')

$tpl = @'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>雄安科创园 · 施工/质量日志 演示站</title>
<style>
*{box-sizing:border-box}
body{margin:0;font:14px/1.7 "Microsoft YaHei",system-ui,sans-serif;color:#26364d;background:#f4f7fb}
.wrap{max-width:940px;margin:0 auto;padding:32px 20px 60px}
h1{font-size:24px;margin:0 0 6px;color:#162a44}
.sub{color:#6b7c92;margin:0 0 26px}
.card{background:#fff;border:1px solid #dce7f7;border-radius:8px;padding:22px 24px;box-shadow:0 6px 20px rgba(23,91,221,.06)}
.card h2{margin:0 0 4px;font-size:19px;color:#175bdd}
.meta{color:#6b7c92;font-size:13px;margin-bottom:14px}
.note{margin:0 0 18px;padding:10px 12px;background:#f7faff;border:1px solid #e2ebf7;border-radius:4px;color:#45648f}
.actions{display:flex;flex-wrap:wrap;gap:10px}
.btn{display:inline-block;padding:10px 18px;border-radius:4px;background:#175bdd;color:#fff;text-decoration:none;font-weight:500}
.btn:hover{background:#1450c4}
.btn.ghost{background:#fff;color:#175bdd;border:1px solid #b9cff5}
.btn.ghost:hover{background:#f2f7ff}
h3{font-size:16px;margin:34px 0 12px;color:#162a44}
table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #e2e9f3;border-radius:6px;overflow:hidden}
th,td{padding:11px 12px;border-bottom:1px solid #eef2f8;text-align:left;font-size:13px;vertical-align:top}
th{background:#eef3fa;color:#263e61;font-weight:600;white-space:nowrap}
tr:last-child td{border-bottom:0}
td.ver{font-weight:600;color:#175bdd;white-space:nowrap}
td.nowrap{white-space:nowrap}
span.sep{display:inline-block;width:1px;height:12px;margin:0 8px;background:#dbe3ee;vertical-align:-1px}
a.open{color:#175bdd;text-decoration:none;white-space:nowrap}
a.open:hover{text-decoration:underline}
a.dl{color:#1677a8;text-decoration:none;white-space:nowrap}
a.dl:hover{text-decoration:underline}
.muted{color:#9aa6b6}
.tips{margin-top:26px;padding:16px 18px;background:#fff;border:1px solid #e2e9f3;border-radius:6px;color:#4e5969;font-size:13px}
.tips b{color:#175bdd}
code{background:#f2f4f7;padding:1px 5px;border-radius:3px;font-family:Consolas,monospace}
footer{margin-top:30px;color:#86909c;font-size:12px;text-align:center}
</style>
</head>
<body>
<div class="wrap">
  <h1>雄安科创园 · 施工/质量日志 演示站</h1>
  <p class="sub">本地址固定不变，每次发布只更新内容，请直接收藏本页。</p>

  <div class="card">
    <h2>最新版本 {{LATESTVER}}</h2>
    <div class="meta">发布日期：{{LATESTDATE}} ｜ 站点更新时间：{{UPDATED}}</div>
    <p class="note">{{LATESTNOTE}}</p>
    <div class="actions">
      <a class="btn" href="latest.html">打开演示</a>
      {{LATESTHTML}}
      <a class="btn ghost" href="versions/{{LATESTDIR}}/index.html">固定版本快照</a>
      {{LATESTTPL}}
    </div>
  </div>

  <h3>历史版本</h3>
  <table>
    <thead><tr><th>版本</th><th>日期</th><th>更新说明</th><th>演示</th><th>原模板</th></tr></thead>
    <tbody>
{{ROWS}}    </tbody>
  </table>

  <div class="tips">
    <p><b>地址说明</b>：<code>latest.html</code> 始终指向最新版，可长期作为固定入口；<code>versions/</code> 下是按日期归档的历史快照，用于回溯「当时那一版长什么样」。</p>
    <p><b>下载演示文件</b>：演示是<b>完全自包含的单文件 HTML</b>（四个 Word 模板已内嵌为 base64，无外部 JS/CSS/图片依赖）。点「下载演示文件（HTML）」保存到本地后，双击即可离线打开，也能直接转发给别人。</p>
    <p><b>关于导出</b>：演示里的「导出」会在<b>原模板文件上只替换文字</b>，生成带数据的 Word 日志，版式与原文件完全一致。</p>
    <p><b>原模板下载</b>：四个原模板随版本一起归档 —— 点上方「下载原模板（Word，共 4 个）」进入模板页，可分别下载：施工日期（项目版）、施工日志（个人版）、质量日志（项目版）、质量日志（个人版）。</p>
    <p><b>如何更新</b>：在本地 <code>demo-site</code> 目录双击 <code>发布更新.bat</code>，填写更新说明即可。地址不变，无需再逐个发文件。</p>
  </div>

  <footer>雄安科创园指挥工地 · 施工/质量日志 演示原型</footer>
</div>
</body>
</html>
'@

$latestDir = if ($latest) { $latest.Dir } else { '' }
$out = $tpl
$out = $out.Replace('{{LATESTVER}}', $latestVer)
$out = $out.Replace('{{LATESTDATE}}', $latestDate)
$out = $out.Replace('{{UPDATED}}', $updatedAt)
$out = $out.Replace('{{LATESTNOTE}}', $latestNote)
$out = $out.Replace('{{LATESTHTML}}', $latestHtml)
$out = $out.Replace('{{LATESTDIR}}', $latestDir)
$out = $out.Replace('{{LATESTTPL}}', $latestTpl)
$out = $out.Replace('{{ROWS}}', $rows)
Write-Utf8NoBom (Join-Path $root 'index.html') $out
Write-Host "已重建首页（共 $($items.Count) 个版本）" -ForegroundColor Green

# 重建模板下载页
$tplPage = @'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>原模板下载 · 雄安科创园 施工/质量日志</title>
<style>
*{box-sizing:border-box}
body{margin:0;font:14px/1.7 "Microsoft YaHei",system-ui,sans-serif;color:#26364d;background:#f4f7fb}
.wrap{max-width:760px;margin:0 auto;padding:32px 20px 60px}
h1{font-size:22px;margin:0 0 6px;color:#162a44}
.sub{color:#6b7c92;margin:0 0 24px}
.back{display:inline-block;margin-bottom:18px;color:#175bdd;text-decoration:none;font-size:13px}
.back:hover{text-decoration:underline}
.card{background:#fff;border:1px solid #dce7f7;border-radius:8px;padding:18px 22px;box-shadow:0 6px 20px rgba(23,91,221,.06)}
.meta{color:#6b7c92;font-size:13px;margin-bottom:14px}
ul.tplist{list-style:none;margin:0;padding:0}
li.tplrow{display:flex;align-items:center;gap:14px;padding:12px 0;border-bottom:1px solid #eef2f8}
li.tplrow:last-child{border-bottom:0}
.tplname{flex:1;font-weight:500;color:#162a44;word-break:break-all}
.tplsize{color:#9aa6b6;font-size:12px;white-space:nowrap}
.tplhint{display:block;color:#6b7c92;font-size:12px;font-weight:400;margin-top:2px}
h3{font-size:16px;margin:26px 0 12px;color:#162a44}
.btn{display:inline-block;padding:8px 16px;border-radius:4px;background:#175bdd;color:#fff;text-decoration:none;font-weight:500;white-space:nowrap}
.btn:hover{background:#1450c4}
.btn.ghost{background:#fff;color:#175bdd;border:1px solid #b9cff5}
.btn.ghost:hover{background:#f2f7ff}
.tips{margin-top:22px;padding:16px 18px;background:#fff;border:1px solid #e2e9f3;border-radius:6px;color:#4e5969;font-size:13px}
.tips b{color:#175bdd}
code{background:#f2f4f7;padding:1px 5px;border-radius:3px;font-family:Consolas,monospace}
footer{margin-top:28px;color:#86909c;font-size:12px;text-align:center}
</style>
</head>
<body>
<div class="wrap">
  <a class="back" href="index.html">← 返回首页</a>
  <h1>原模板下载</h1>
  <p class="sub">演示里的「导出」就是在下面这四个原模板上只替换文字生成的，版式与原文件完全一致。</p>

  <div class="card">
    <div class="meta">对应版本：{{TPLVER}}</div>
    <ul class="tplist">
{{TPLFILES}}    </ul>
  </div>

  <h3>交付说明文档</h3>
  <div class="card">
    <div class="meta">字段级实现说明，与演示同版本归档；另在 <code>docs/</code> 下常驻一份，地址长期不变</div>
    <ul class="tplist">
{{DOCFILES}}    </ul>
  </div>

  <div class="tips">
    <p><b>四个模板分别对应</b>：<code>施工日期（项目版）</code> → 施工日志·项目版；<code>施工日志（个人版）</code> → 施工日志·个人版；<code>质量日志-项目版</code> → 质量日志·项目版；<code>质量日志-个人版</code> → 质量日志·个人版。</p>
    <p><b>用途</b>：可以拿它们和演示里导出的 Word 逐字比对 —— 除了被替换成数据的字段，其余版式应当一模一样。</p>
    <p><b>提示</b>：浏览器可能会问「是否保留多个文件」，逐个点下载即可。</p>
  </div>

  <footer>雄安科创园指挥工地 · 施工/质量日志 演示原型</footer>
</div>
</body>
</html>
'@
$tplOut = $tplPage
$tplOut = $tplOut.Replace('{{TPLVER}}', $tplVerLabel)
$tplOut = $tplOut.Replace('{{TPLFILES}}', $tplFileRows)
$tplOut = $tplOut.Replace('{{DOCFILES}}', $docFileRows)
Write-Utf8NoBom (Join-Path $root 'templates.html') $tplOut
Write-Host "已重建模板下载页（$($TemplateNames.Count) 个模板 + $($DocNames.Count) 个交付说明文档）" -ForegroundColor Green

if ($RenderOnly) { return }

# ---------------------------------------------------------------- 3. 提交并推送
if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Warning "当前目录还不是 git 仓库，已跳过提交与推送。请先双击运行 首次配置.bat。"
    return
}

# git 往 stderr 写内容时，Stop 模式会中断脚本；这里局部降级并显式查退出码
function Invoke-Git {
    param([string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = & git @Arguments 2>&1
        $code = $LASTEXITCODE
        $text = ($raw | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { $_ } }) -join "`n"
        $text = $text.Trim()
    } finally { $ErrorActionPreference = $prev }
    return [pscustomobject]@{ Code = $code; Text = $text }
}

# 认证方式预检：GCM 若走 basic（用户名+密码）会被 GitHub 拒绝
$authMode = (Invoke-Git @('config', '--local', '--get', 'credential.gitHubAuthModes')).Text
if (-not $authMode) {
    Invoke-Git @('config', '--local', 'credential.gitHubAuthModes', 'browser') | Out-Null
    Write-Host "已设置 GitHub 认证方式为浏览器授权（避免弹出用户名/密码）" -ForegroundColor DarkGray
}
# 本机 schannel 握手会失败（SEC_E_NO_CREDENTIALS），必须走 openssl
Invoke-Git @('config', '--local', 'http.sslBackend', 'openssl') | Out-Null

$message = if ($Note) { "发布 V$($latest.Ver)：$Note" } else { "发布 V$($latest.Ver)" }

$add = Invoke-Git @('add', '-A')
if ($add.Code -ne 0) { throw "git add 失败：$($add.Text)" }

# 没有实际改动时不硬提交，但必须继续往下走——
# 本地可能还有从未推送成功的历史提交，这次要把它们推上去。
$staged = Invoke-Git @('diff', '--cached', '--quiet')
if ($staged.Code -eq 0) {
    Write-Host "本次没有内容变化，跳过提交，继续尝试推送。" -ForegroundColor Yellow
} else {
    $commit = Invoke-Git @('-c', 'http.sslBackend=openssl', 'commit', '-m', $message)
    if ($commit.Code -ne 0) { throw "git commit 失败：$($commit.Text)" }
    Write-Host "已提交：$message" -ForegroundColor Green
}
if ($NoPush) { Write-Host "已跳过推送（-NoPush）" -ForegroundColor Yellow; return }

$push = Invoke-Git @('-c', 'http.sslBackend=openssl', 'push', '-u', 'origin', 'HEAD')

# 网络类失败（连不上 / 超时 / 重置）自动重试：国内访问 github.com 经常间歇性抽风。
# 只对网络类错误重试，认证类错误不重试（重试也没用）。
$netErr = 'Could not connect to server|Connection was reset|Failed to connect|timed out|timeout|Recv failure|Empty reply from server|The remote end hung up'
if ($push.Code -ne 0 -and $push.Text -match $netErr) {
    $delays = @(3, 8, 15, 25)
    for ($i = 0; $i -lt $delays.Count; $i++) {
        Write-Host ""
        Write-Host "连不上 github.com（第 $($i + 1) 次）。$($delays[$i]) 秒后自动重试……" -ForegroundColor Yellow
        Start-Sleep -Seconds $delays[$i]
        $push = Invoke-Git @('-c', 'http.sslBackend=openssl', 'push', '-u', 'origin', 'HEAD')
        if ($push.Code -eq 0) {
            Write-Host "重试成功。" -ForegroundColor Green
            break
        }
    }
}

# 远程已有提交（通常是建仓库时勾了 Add README）→ 自动合并后再推一次。
# 报错形如：! [rejected]  HEAD -> main (fetch first)
if ($push.Code -ne 0 -and $push.Text -match 'fetch first|non-fast-forward|\[rejected\]') {
    Write-Host ""
    Write-Host "远程仓库里已有提交（建仓库时勾了 Add README？），正在自动合并后重推……" -ForegroundColor Yellow
    $pull = Invoke-Git @('-c', 'http.sslBackend=openssl', 'pull', '--rebase', '--no-edit', 'origin', 'main')
    if ($pull.Code -eq 0) {
        $push = Invoke-Git @('-c', 'http.sslBackend=openssl', 'push', '-u', 'origin', 'HEAD')
    } else {
        Write-Host "自动合并失败（可能有文件冲突）。请在本目录手动处理：" -ForegroundColor Red
        Write-Host "  git pull --rebase origin main" -ForegroundColor Yellow
        Write-Host "  git status        # 有冲突就改文件，然后 git add <文件> / git rebase --continue" -ForegroundColor Yellow
        Write-Host "  处理完重新双击 发布更新.bat" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "原始报错：$($pull.Text)" -ForegroundColor DarkGray
        throw "自动合并未完成"
    }
}

if ($push.Code -ne 0 -and $push.Text -match $netErr) {
    Write-Host ""
    Write-Host "暂时连不上 github.com（网络问题，不是内容或令牌的问题）。" -ForegroundColor Red
    Write-Host "本次内容已经提交到本地，一条都不会丢。三种办法任选：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ① 稍后重试：过几分钟再双击一次 发布更新.bat（脚本会先把本地待推送的提交推上去）" -ForegroundColor Cyan
    Write-Host "  ② 换网络：手机热点 / 关掉代理或 VPN 再试（国内到 github.com 经常被间歇性阻断）" -ForegroundColor Cyan
    Write-Host "  ③ 先只提交不推送：以后网络好了再推" -ForegroundColor Cyan
    Write-Host "       git -C `"$root`" push -u origin HEAD" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  诊断命令（在 PowerShell 里跑）：" -ForegroundColor Cyan
    Write-Host "       Test-NetConnection github.com -Port 443 -InformationLevel Detailed" -ForegroundColor DarkGray
    Write-Host "       Resolve-DnsName github.com -Type A | Select-Object IPAddress" -ForegroundColor DarkGray
    Write-Host "  如果换 DNS 能通：把本机 DNS 改成 223.5.5.5 / 119.29.29.29 再试" -ForegroundColor Cyan
    Write-Host "  如果 SSH 22 通、443 不通：改用 SSH 推送（首次配置.bat 里换成 git@github.com:账号/仓库.git）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "原始报错：$($push.Text)" -ForegroundColor DarkGray
    throw "推送未完成（网络原因）"
}

if ($push.Code -ne 0) {
    Write-Host ""
    Write-Host "推送失败。内容已提交到本地，没有丢，按下面排查后重新双击本脚本即可：" -ForegroundColor Red
    Write-Host "  1) Authentication failed / Repository not found" -ForegroundColor Yellow
    Write-Host "     → 令牌过期，或令牌没勾选这个仓库：重新运行一次 首次配置.bat" -ForegroundColor Yellow
    Write-Host "  2) 弹出 Git Credential Manager 登录窗口" -ForegroundColor Yellow
    Write-Host "     → 选 Browser / 浏览器，在网页里点 Authorize 授权即可（推荐，不需要令牌）" -ForegroundColor Yellow
    Write-Host "  2b) 被要求输入 Username / Password" -ForegroundColor Yellow
    Write-Host "     → Username 填 GitHub 账号名；Password 处粘贴令牌（不是账号密码）" -ForegroundColor Yellow
    Write-Host "  3) Connection was reset / timeout" -ForegroundColor Yellow
    Write-Host "     → 网络抖动，直接重跑本脚本；国内访问 GitHub 不稳时可多试几次" -ForegroundColor Yellow
    Write-Host "  4) schannel: AcquireCredentialsHandle failed" -ForegroundColor Yellow
    Write-Host "     → 在本目录执行：git config --local http.sslBackend openssl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "原始报错：$($push.Text)" -ForegroundColor DarkGray
    throw "推送未完成"
}

$remote = ((Invoke-Git @('remote', 'get-url', 'origin')).Text) -replace '\.git$', ''
$pages = $remote -replace 'https://github\.com/([^/]+)/([^/]+)', 'https://$1.github.io/$2/'
Write-Host ""
Write-Host "发布完成，稳定地址：" -ForegroundColor Green
Write-Host "  $pages" -ForegroundColor Cyan
Write-Host "  ${pages}latest.html" -ForegroundColor Cyan
Write-Host "（Pages 首次生效约需 1-2 分钟，之后每次发布约 30 秒）" -ForegroundColor DarkGray
