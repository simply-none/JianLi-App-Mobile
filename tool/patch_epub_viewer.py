#!/usr/bin/env python3
"""重放 flutter_epub_viewer 的本地补丁（幂等，可反复运行）。

背景
----
`flutter_epub_viewer` 的 JS 运行时（`lib/assets/webpage/html/epubView.js`）有两处必须
修改才能满足本项目需求，但上游未提供扩展点：

1. **滚动模式（flow=scrolled）下原生纵向滚动被屏蔽**
   插件在内容 iframe 上注册了自定义左/右滑动（`detectSwipe`），它的 `touchmove`
   监听是 `{ capture: true, passive: false }`，且在**无选区时无条件
   `e.preventDefault()`** —— 纵向拖动同样被吃掉，后果是「滚动」翻页方式整条失效；
   同时该手势不区分 flow，横滑仍调 `rendition.next()/prev()`（continuous manager 下
   = 整屏跳），表现为「只能像左右滑动那样翻页，不能上下滚动」。

2. **下划线渲染成一圈矩形边框 + 线条位置漂移**
   epub.js 的 `Underline.render()` 为每个换行片段画一个定位用 `<rect fill="none">`
   加一条真正的 `<line>`；而 `annotations.underline()` 把 `stroke:black` 写在父 `<g>`
   上，`<rect>` 继承后渲染成边框（用户反馈的「矩形」）；且 `<line>` 固定在整行盒底部，
   行距一大就漂到字形下方。PC 端（`jianli-app/src/views/ebookReader`）已用
   「rect 强制不描边 + 线的颜色走 CSS 变量 + 按字号把线锚到 baseline」解决，
   本脚本把同一套做法移植到插件 JS。

用法
----
    python tool/patch_epub_viewer.py          # 应用补丁（已应用则跳过）
    python tool/patch_epub_viewer.py --check  # 只检查状态，不写文件

⚠️ 补丁直接写在 pub 缓存里，**不是仓库源码**：`flutter pub get` 重装 / `flutter clean`
后会被还原，重跑本脚本即可。上游若发布新版本，先确认锚点仍存在（脚本会报错退出）。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

REPO_ROOT = Path(__file__).resolve().parents[1]

# 补丁落点（相对插件包根目录）
TARGET_REL = Path("lib/assets/webpage/html/epubView.js")

# 补丁标识：既用于幂等判断，也用于在 JS 里做来源注记
MARKER = "Jianli patch (2026-09-23)"

# 生成 JS 时把占位符换成 MARKER（不用 str.format，避免与 JS 的花括号打架）
PH = "@@MARKER@@"


def js(text: str) -> str:
    return text.replace(PH, MARKER)


# ---------------------------------------------------------------------------
# H1：loadBook 内推导「是否滚动流」
# ---------------------------------------------------------------------------
H1_ANCHOR = """  var useCustomSwipe = opts.useCustomSwipe;
"""

H1_PATCHED = H1_ANCHOR + js(
    """  // @@MARKER@@: `scrolled` / `scrolled-doc` / `scrolled-continuous` all collapse to
  // epub.js's continuous vertical scroll — native scrolling must win there, so the
  // custom horizontal swipe handler is skipped (see the content hook below).
  var isScrolledFlow =
    flow === "scrolled" || flow === "scrolled-doc" || flow === "scrolled-continuous";
"""
)

# ---------------------------------------------------------------------------
# H2：滚动流不装自定义滑动（根治 preventDefault 吃滚动 + 横滑误翻页）
# ---------------------------------------------------------------------------
H2_ANCHOR = """    if (useCustomSwipe) {
      const el = contents.document.documentElement;
"""

H2_PATCHED = js(
    """    // @@MARKER@@: the custom swipe handler MUST NOT be installed in scrolled flow.
    // Its touchmove listener is non-passive and calls preventDefault() on **every**
    // move while no selection is active, which kills native vertical scrolling inside
    // the content iframe (scroll chaining to the epub container is cancelled too).
    // It also pages on horizontal swipes, which is wrong here — continuous scrolling
    // IS the navigation in this mode.
    if (useCustomSwipe && !isScrolledFlow) {
      const el = contents.document.documentElement;
"""
)

# ---------------------------------------------------------------------------
# H3：标注样式工具函数（注入 CSS / 着色 / 下划线锚到基线）
# ---------------------------------------------------------------------------
H3_ANCHOR = """// adds highlight with given color
function addHighlight(cfiRange, color, opacity) {
"""

H3_PATCHED = js(
    """// ===========================================================================
// @@MARKER@@: annotation styling
// ===========================================================================
// epub.js renders annotation SVGs into the **parent** document (marks-pane appends to
// the view element), never inside the epub iframe — so the stylesheet and the DOM
// queries below run in this document, not in the book's content document.
var jianliAnnoCssId = 'jianli-anno-css';
var jianliUnderlineColor = '#FFEB3B';
var jianliFontSize = 0;

// An underline mark carries a positioning <rect> plus the real <line>. The <rect>
// inherits the group's stroke and would otherwise render as a box around the text,
// so it is forced to stay invisible; the line takes its colour from the group's
// inline --hl-stroke variable (written by addUnderLine, and kept across view
// re-render because epub.js re-attaches annotations together with their styles).
function ensureAnnotationCss() {
  try {
    var style = document.getElementById(jianliAnnoCssId);
    if (!style) {
      style = document.createElement('style');
      style.id = jianliAnnoCssId;
      document.head.appendChild(style);
    }
    style.textContent =
      'g[ref="epubjs-ul"] > rect { stroke: none !important; fill: none !important; }' +
      'g[ref="epubjs-ul"] > line { stroke: var(--hl-stroke, ' + jianliUnderlineColor +
      ') !important; stroke-opacity: 1 !important; stroke-width: 2 !important;' +
      ' stroke-linecap: square; }';
  } catch (e) {
    console.error('[Jianli] ensureAnnotationCss failed', e);
  }
}

// Push the current colour onto every rendered underline group.
function paintUnderlineGroups() {
  try {
    var groups = document.querySelectorAll('g[ref="epubjs-ul"]');
    for (var i = 0; i < groups.length; i++) {
      groups[i].style.setProperty('--hl-stroke', jianliUnderlineColor);
    }
  } catch (e) {
    // ignore
  }
}

// epub.js anchors the underline to the bottom of the whole line box (y + height),
// which drifts below the glyphs as soon as line-height / paragraph spacing grows.
// Re-anchor each <line> onto (baseline + gap), same maths as the desktop reader
// (gap = 2px, ascent = 0.8em, half-leading = (lineBox - fontSize) / 2).
function decorateUnderlines() {
  try {
    var gap = 2;
    var groups = document.querySelectorAll('g[ref="epubjs-ul"]');
    for (var i = 0; i < groups.length; i++) {
      var rects = groups[i].querySelectorAll('rect');
      var lines = groups[i].querySelectorAll('line');
      for (var j = 0; j < rects.length && j < lines.length; j++) {
        var ry = parseFloat(rects[j].getAttribute('y') || '0');
        var rh = parseFloat(rects[j].getAttribute('height') || '0');
        // 拿不到字号时退化为「行盒高 * 0.7」（约等于字号）
        var f = jianliFontSize > 0 ? jianliFontSize : rh * 0.7;
        var halfLeading = Math.max(0, (rh - f) / 2);
        var baseline = ry + halfLeading + f * 0.8;
        var delta = baseline + gap - (ry + rh - 1);
        lines[j].setAttribute('transform', 'translate(0,' + delta.toFixed(2) + ')');
      }
    }
  } catch (e) {
    console.error('[Jianli] decorateUnderlines failed', e);
  }
}

function refreshUnderlineMarks() {
  paintUnderlineGroups();
  decorateUnderlines();
}

// Called from Dart via EpubController.webViewController.callMethod:
//   setAnnotationStyle(colorHex, fontSizePx)
function setAnnotationStyle(color, fontSize) {
  if (color && color !== '') jianliUnderlineColor = color;
  if (fontSize > 0) jianliFontSize = fontSize;
  ensureAnnotationCss();
  refreshUnderlineMarks();
}

// adds highlight with given color
function addHighlight(cfiRange, color, opacity) {
"""
)

# ---------------------------------------------------------------------------
# H4：addUnderLine 带颜色 + 立即重锚
# ---------------------------------------------------------------------------
H4_ANCHOR = """function addUnderLine(cfiString) {
  rendition.annotations.underline(cfiString)
}
"""

H4_PATCHED = js(
    """function addUnderLine(cfiString) {
  // @@MARKER@@: per-mark colour via an inline CSS variable, plus `stroke: none` on the
  // group so the positioning <rect> can never be stroked into a box around the text.
  rendition.annotations.underline(cfiString, {}, null, 'epubjs-ul', {
    'stroke': 'none',
    'stroke-opacity': '0',
    'mix-blend-mode': 'normal',
    'style': '--hl-stroke:' + jianliUnderlineColor
  });
  ensureAnnotationCss();
  refreshUnderlineMarks();
}
"""
)

# ---------------------------------------------------------------------------
# H5：loadBook 里注入样式表并记录字号
# ---------------------------------------------------------------------------
H5_ANCHOR = """  // Apply initial theme
  updateTheme(backgroundColor, foregroundColor, customCss);
"""

H5_PATCHED = js(
    """  // @@MARKER@@: inject the annotation stylesheet into this (parent) document and
  // remember the font size used by the underline baseline maths.
  if (fontSize > 0) jianliFontSize = fontSize;
  ensureAnnotationCss();

  // Apply initial theme
  updateTheme(backgroundColor, foregroundColor, customCss);
"""
)

# ---------------------------------------------------------------------------
# H6：updateTheme 末尾重刷（主题 / 字号变化会重建标注几何）
# ---------------------------------------------------------------------------
H6_ANCHOR = """    if (viewerEl) viewerEl.style.backgroundColor = viewerBg;
  }
}
"""

H6_PATCHED = js(
    """    if (viewerEl) viewerEl.style.backgroundColor = viewerBg;
  }

  // @@MARKER@@: theme / font-size changes rebuild mark geometry → repaint.
  refreshUnderlineMarks();
}
"""
)

# ---------------------------------------------------------------------------
# H7：rendered 回调补一次重绘
# ---------------------------------------------------------------------------
H7_ANCHOR = """  rendition.on("rendered", function () {
    window.flutter_inappwebview.callHandler('rendered');
  })
"""

H7_PATCHED = js(
    """  rendition.on("rendered", function () {
    window.flutter_inappwebview.callHandler('rendered');
    // @@MARKER@@: annotations are re-attached together with each new view.
    refreshUnderlineMarks();
  })
"""
)

HUNKS = [
    ("H1 滚动流判定", H1_ANCHOR, H1_PATCHED),
    ("H2 滚动流不装自定义滑动", H2_ANCHOR, H2_PATCHED),
    ("H3 标注样式工具函数", H3_ANCHOR, H3_PATCHED),
    ("H4 addUnderLine 带色 + 重锚", H4_ANCHOR, H4_PATCHED),
    ("H5 loadBook 注入样式表", H5_ANCHOR, H5_PATCHED),
    ("H6 updateTheme 末尾重刷", H6_ANCHOR, H6_PATCHED),
    ("H7 rendered 回调重绘", H7_ANCHOR, H7_PATCHED),
]


def resolve_plugin_root() -> Path:
    """从 .dart_tool/package_config.json 取 flutter_epub_viewer 的解析后路径。

    rootUri 可能是相对路径（`../../AppData/...`）也可能是 `file:///C:/...` 绝对 URI，
    且含百分号编码的中文用户名 —— 两种情况都要处理。
    """
    cfg = REPO_ROOT / ".dart_tool" / "package_config.json"
    if not cfg.is_file():
        sys.exit("[patch] 找不到 %s，请先在项目根目录跑一次 `flutter pub get`。" % cfg)
    data = json.loads(cfg.read_text(encoding="utf-8"))
    for pkg in data.get("packages", []):
        if pkg.get("name") != "flutter_epub_viewer":
            continue
        root_uri = pkg["rootUri"]
        if root_uri.startswith("file:"):
            raw = url2pathname(urlparse(root_uri).path)
            # Windows 下 path 形如 `/C:/Users/...`，去掉前导斜杠
            if len(raw) > 2 and raw[0] == "/" and raw[2] == ":":
                raw = raw[1:]
            root = Path(unquote(raw))
        else:
            root = Path(unquote(root_uri))
            if not root.is_absolute():
                root = cfg.parent / root
        root = root.resolve()
        if not root.is_dir():
            sys.exit("[patch] 包目录不存在：%s" % root)
        return root
    sys.exit("[patch] package_config.json 里没有 flutter_epub_viewer（依赖被移除？）")


def apply_hunks(text: str):
    """返回 (新文本, 已跳过列表, 已应用列表)。"""
    applied = []
    skipped = []
    for name, anchor, patched in HUNKS:
        if patched in text:
            skipped.append(name)
            continue
        count = text.count(anchor)
        if count == 0:
            sys.exit(
                "[patch] 锚点未命中：%s\n"
                "        插件版本可能已升级或补丁已被改动，请人工核对后更新本脚本。" % name
            )
        if count != 1:
            sys.exit("[patch] 锚点不唯一（%d 处）：%s" % (count, name))
        text = text.replace(anchor, patched, 1)
        applied.append(name)
    return text, skipped, applied


def main() -> int:
    parser = argparse.ArgumentParser(description="重放 flutter_epub_viewer 本地补丁")
    parser.add_argument("--check", action="store_true", help="只检查，不写文件")
    args = parser.parse_args()

    root = resolve_plugin_root()
    target = root / TARGET_REL
    if not target.is_file():
        sys.exit("[patch] 目标文件不存在：%s" % target)

    original = target.read_text(encoding="utf-8")
    patched_text, skipped, applied = apply_hunks(original)

    print("[patch] 插件目录：%s" % root)
    for name in skipped:
        print("[patch]   已是最新，跳过：%s" % name)
    for name in applied:
        print("[patch]   已应用：%s" % name)

    if args.check:
        print("[patch] --check 模式，未写入文件。")
        return 0

    if not applied:
        print("[patch] 无需改动。")
        return 0

    target.write_text(patched_text, encoding="utf-8", newline="")
    print("[patch] 写入完成：%s" % target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
