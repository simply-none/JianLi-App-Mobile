# -*- coding: utf-8 -*-
# 渐离App 图标与启动屏生成器（flutter_launcher_icons 与 epubx 的 image 依赖版本冲突，
# 故用 Pillow 直接产出全部原生资源；改图后重跑本脚本即可）：
#   Android: mipmap ic_launcher(传统) + mipmap-anydpi-v26 自适应(白底+62%前景) + drawable-nodpi 启动屏
#   iOS:     AppIcon.appiconset 全尺寸 + LaunchImage.imageset 三倍图
from PIL import Image, ImageChops
import os

ROOT = r"C:\cod\jianli\jianli-mobile-app"
SRC = os.path.join(ROOT, "appLogo.png")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ASSETS = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")

src = Image.open(SRC).convert("RGBA")

# logo 主体（非白包围盒裁出）
rgb = src.convert("RGB")
diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, (255, 255, 255)))
bbox = diff.convert("L").point(lambda v: 255 if v > 16 else 0).getbbox()
logo = src.crop(bbox)

def on_white(canvas, fraction):
    """logo 缩放到 canvas*fraction，居中贴到不透明白色画布"""
    side = int(canvas * fraction)
    im = logo.resize(
        (max(1, round(logo.width * side / max(logo.size))),
         max(1, round(logo.height * side / max(logo.size)))),
        Image.LANCZOS,
    )
    bg = Image.new("RGB", (canvas, canvas), (255, 255, 255))
    bg.paste(im.convert("RGB"), ((canvas - im.width) // 2, (canvas - im.height) // 2))
    return bg

def save(im, *rel):
    path = os.path.join(*rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", os.path.relpath(path, ROOT))

# ---- Android 启动图标（传统 mipmap，API<26 回退） ----
launcher = on_white(1024, 0.82)
for dpi, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    save(launcher.resize((px, px), Image.LANCZOS), RES, f"mipmap-{dpi}", "ic_launcher.png")

# ---- Android 自适应前景（108dp 画布；logo 占 62% < 66% 安全区） ----
fg = on_white(1024, 0.62)
for dpi, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
    save(fg.resize((px, px), Image.LANCZOS), RES, f"mipmap-{dpi}", "ic_launcher_foreground.png")

# ---- Android 启动屏（pre-12，bitmap 原始像素居中；nodpi 420px ≈ 140dp） ----
save(on_white(420, 0.55), RES, "drawable-nodpi", "splash_logo.png")

# ---- iOS AppIcon（Contents.json 里的全部尺寸，去掉 alpha 通道） ----
for name, px in {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}.items():
    save(on_white(px, 0.82).convert("RGB"), IOS_ASSETS, "AppIcon.appiconset", name)

# ---- iOS 启动屏（storyboard contentMode=center，1x/2x/3x = 160pt 基准） ----
for name, px in {"LaunchImage.png": 160, "LaunchImage@2x.png": 320, "LaunchImage@3x.png": 480}.items():
    save(on_white(px, 0.55).convert("RGB"), IOS_ASSETS, "LaunchImage.imageset", name)

print("done")
