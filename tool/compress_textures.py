#!/usr/bin/env python3
"""卡片纹理集瘦身：长边压到 MAX_EDGE，JPEG 质量 QUALITY。

背景：画布「13 卡片纹理选型」的 21 张原图是 1920px 宽、单张 0.2–1.1 MB（共 ~11 MB）。
卡片实际显示尺寸 358×168，按 3x DPR 也就 1074px 宽，且叠在渐变上只有 ~20% 不透明度，
1920px 纯属浪费。压到长边 1200 @ q82 后视觉无差、包体显著变小。

幂等性：长边已 ≤ MAX_EDGE 的文件直接跳过（所以重复执行不会反复重编码掉画质）。
需要强制重压（例如想换质量参数）时加 --force。

用法（本机隔离 venv）：
  "C:/Users/风起/.workbuddy/binaries/python/envs/default/Scripts/python.exe" \
      tool/compress_textures.py            # 默认 assets/images/textures
      tool/compress_textures.py --dir <path> --max-edge 1200 --quality 82 --force
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageOps

REPO = Path(__file__).resolve().parent.parent
DEFAULT_DIR = REPO / "assets" / "images" / "textures"


def human(n: int) -> str:
    return f"{n / 1024:.0f} KB" if n < 1024 * 1024 else f"{n / 1024 / 1024:.2f} MB"


def compress(path: Path, max_edge: int, quality: int, force: bool) -> tuple[int, int, str]:
    """返回 (压前字节, 压后字节, 状态说明)。"""
    before = path.stat().st_size

    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im)  # 手机/相机拍的图可能靠 EXIF 旋转
        w, h = im.size
        long_edge = max(w, h)

        if long_edge <= max_edge and not force:
            return before, before, f"skip (long edge {long_edge} <= {max_edge})"

        if long_edge > max_edge:
            scale = max_edge / long_edge
            new_size = (max(1, round(w * scale)), max(1, round(h * scale)))
            im = im.resize(new_size, Image.LANCZOS)
        else:
            new_size = im.size

        if im.mode not in ("RGB", "L"):
            im = im.convert("RGB")

        # 保持原文件名（资源路径不变，代码零改动）
        tmp = path.with_suffix(path.suffix + ".tmp")
        im.save(
            tmp,
            format="JPEG",
            quality=quality,
            optimize=True,
            progressive=True,
        )

    # 只在确实变小的时候替换，避免把已经压好的图反而写大
    if tmp.stat().st_size >= before and not force:
        tmp.unlink()
        return before, before, f"skip (re-encode not smaller, {w}x{h})"

    tmp.replace(path)
    after = path.stat().st_size
    return before, after, f"{w}x{h} -> {new_size[0]}x{new_size[1]}"


def convert_to_webp(files: list[Path], quality: int) -> int:
    """jpg -> webp（有损，q=quality）。源图先缩到 1200 长边（与 compress 同规格），再转格式。

    只有转换产物比源图小才落盘+删源；同名 .webp 已存在则跳过（幂等）。
    """
    total_before = total_after = 0
    print("mode  : jpg -> webp (lossy)")
    print("-" * 78)
    skipped = 0
    for p in files:
        out = p.with_suffix(".webp")
        if out.exists():
            skipped += 1
            print(f"{p.name:<48} skip (webp already exists)")
            continue
        before = p.stat().st_size
        with Image.open(p) as im:
            im = ImageOps.exif_transpose(im)
            w, h = im.size
            long_edge = max(w, h)
            if long_edge > 1200:
                scale = 1200 / long_edge
                im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                               Image.LANCZOS)
            if im.mode not in ("RGB", "L"):
                im = im.convert("RGB")
            tmp = out.with_suffix(".webp.tmp")
            im.save(tmp, format="WEBP", quality=quality, method=6)
        if tmp.stat().st_size >= before:
            tmp.unlink()
            print(f"{p.name:<48} skip (webp not smaller)")
            continue
        tmp.replace(out)
        p.unlink()  # 转换成功且确实变小，才删源 jpg
        after = out.stat().st_size
        total_before += before
        total_after += after
        pct = (1 - after / before) * 100 if before else 0.0
        print(f"{p.name:<48} {human(before):>8} -> {human(after):>8}  {pct:>5.1f}%")
    print("-" * 78)
    saved = total_before - total_after
    pct = saved / total_before * 100 if total_before else 0.0
    print(f"{len(files)} files ({skipped} skipped): "
          f"{human(total_before)} -> {human(total_after)} (saved {human(saved)}, {pct:.1f}%)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    ap.add_argument("--max-edge", type=int, default=1200)
    ap.add_argument("--quality", type=int, default=82)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--webp", action="store_true",
                    help="jpg -> 同名 .webp（q 同 --quality，method=6），成功后删除源 jpg。"
                         "幂等：已存在同名 .webp 则跳过。转完后需把代码里的 .jpg 引用改成 .webp。")
    args = ap.parse_args()

    files = sorted(
        p for p in args.dir.iterdir()
        if p.suffix.lower() in (".jpg", ".jpeg") and not p.name.endswith(".tmp")
    )
    if not files:
        print(f"no jpg found in {args.dir}", file=sys.stderr)
        return 1

    if args.webp:
        return convert_to_webp(files, args.quality)

    total_before = total_after = 0
    print(f"dir   : {args.dir}")
    print(f"target: long edge <= {args.max_edge}, quality {args.quality}")
    print("-" * 78)

    for p in files:
        before, after, note = compress(p, args.max_edge, args.quality, args.force)
        total_before += before
        total_after += after
        pct = 0.0 if before == 0 else (1 - after / before) * 100
        print(f"{p.name:<48} {human(before):>8} -> {human(after):>8}  {pct:>5.1f}%  {note}")

    print("-" * 78)
    saved = total_before - total_after
    pct = 0.0 if total_before == 0 else saved / total_before * 100
    print(f"{len(files)} files: {human(total_before)} -> {human(total_after)} "
          f"(saved {human(saved)}, {pct:.1f}%)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
