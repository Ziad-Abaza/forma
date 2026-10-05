import os
from PIL import Image, ImageDraw

def generate_icons():
    logo_path = os.path.join('mobile', 'assets', 'logo.png')
    if not os.path.exists(logo_path):
        raise FileNotFoundError(f"Logo not found at {logo_path}")
    
    logo = Image.open(logo_path).convert('RGBA')
    print(f"Loaded logo: {logo.size}, mode: {logo.mode}")

    # Color palette
    bg_rgb = (13, 17, 23)        # #0D1117 Obsidian background
    bg_rgba = (13, 17, 23, 255)

    def make_icon(size, bg_color=None, padding_ratio=0.12, round_mask=False):
        w, h = size
        if bg_color is None:
            canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        elif len(bg_color) == 3:
            canvas = Image.new('RGB', (w, h), bg_color)
        else:
            canvas = Image.new('RGBA', (w, h), bg_color)

        avail_w = int(w * (1 - 2 * padding_ratio))
        avail_h = int(h * (1 - 2 * padding_ratio))

        scale = min(avail_w / logo.width, avail_h / logo.height)
        nw = max(1, int(logo.width * scale))
        nh = max(1, int(logo.height * scale))

        resized = logo.resize((nw, nh), Image.Resampling.LANCZOS)
        px = (w - nw) // 2
        py = (h - nh) // 2

        if canvas.mode == 'RGB':
            # Create a temporary RGBA canvas with bg_color, paste with mask, then convert to RGB
            temp = Image.new('RGBA', (w, h), bg_rgba)
            temp.paste(resized, (px, py), mask=resized)
            canvas = temp.convert('RGB')
        else:
            canvas.paste(resized, (px, py), mask=resized)

        if round_mask:
            # Apply circular mask
            mask = Image.new('L', (w, h), 0)
            draw = ImageDraw.Draw(mask)
            draw.ellipse((0, 0, w, h), fill=255)
            output = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            output.paste(canvas, (0, 0), mask=mask)
            return output

        return canvas

    # 1. Android Icons
    android_res = os.path.join('mobile', 'android', 'app', 'src', 'main', 'res')
    android_densities = {
        'mipmap-mdpi': (48, 108),
        'mipmap-hdpi': (72, 162),
        'mipmap-xhdpi': (96, 216),
        'mipmap-xxhdpi': (144, 324),
        'mipmap-xxxhdpi': (192, 432),
    }

    for folder, (icon_sz, fg_sz) in android_densities.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)

        # Standard launcher icon (obsidian bg, padding 0.12)
        ic_launcher = make_icon((icon_sz, icon_sz), bg_color=bg_rgba, padding_ratio=0.12)
        ic_launcher.save(os.path.join(folder_path, 'ic_launcher.png'), format='PNG')

        # Round launcher icon
        ic_launcher_round = make_icon((icon_sz, icon_sz), bg_color=bg_rgba, padding_ratio=0.12, round_mask=True)
        ic_launcher_round.save(os.path.join(folder_path, 'ic_launcher_round.png'), format='PNG')

        # Adaptive icon foreground (transparent, safe area ~60% -> padding 0.20)
        fg_icon = make_icon((fg_sz, fg_sz), bg_color=None, padding_ratio=0.20)
        fg_icon.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), format='PNG')

    # Android anydpi-v26 adaptive icon XMLs
    anydpi_folder = os.path.join(android_res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi_folder, exist_ok=True)
    with open(os.path.join(anydpi_folder, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/obsidian_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')

    with open(os.path.join(anydpi_folder, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/obsidian_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')

    # Android Launch Image (Splash)
    drawable_folder = os.path.join(android_res, 'drawable')
    drawable_v21 = os.path.join(android_res, 'drawable-v21')
    os.makedirs(drawable_folder, exist_ok=True)
    os.makedirs(drawable_v21, exist_ok=True)

    launch_img = make_icon((256, 256), bg_color=None, padding_ratio=0.08)
    launch_img.save(os.path.join(drawable_folder, 'launch_image.png'), format='PNG')
    launch_img.save(os.path.join(drawable_v21, 'launch_image.png'), format='PNG')

    # 2. iOS App Icons
    ios_appiconset = os.path.join('mobile', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    ios_specs = [
        ('Icon-App-20x20@1x.png', (20, 20)),
        ('Icon-App-20x20@2x.png', (40, 40)),
        ('Icon-App-20x20@3x.png', (60, 60)),
        ('Icon-App-29x29@1x.png', (29, 29)),
        ('Icon-App-29x29@2x.png', (58, 58)),
        ('Icon-App-29x29@3x.png', (87, 87)),
        ('Icon-App-40x40@1x.png', (40, 40)),
        ('Icon-App-40x40@2x.png', (80, 80)),
        ('Icon-App-40x40@3x.png', (120, 120)),
        ('Icon-App-60x60@2x.png', (120, 120)),
        ('Icon-App-60x60@3x.png', (180, 180)),
        ('Icon-App-76x76@1x.png', (76, 76)),
        ('Icon-App-76x76@2x.png', (152, 152)),
        ('Icon-App-83.5x83.5@2x.png', (167, 167)),
        ('Icon-App-1024x1024@1x.png', (1024, 1024)),
    ]

    for filename, (w, h) in ios_specs:
        ios_icon = make_icon((w, h), bg_color=bg_rgb, padding_ratio=0.14)
        ios_icon.save(os.path.join(ios_appiconset, filename), format='PNG')

    # iOS Launch Images
    ios_launchimage_folder = os.path.join('mobile', 'ios', 'Runner', 'Assets.xcassets', 'LaunchImage.imageset')
    os.makedirs(ios_launchimage_folder, exist_ok=True)
    make_icon((120, 120), bg_color=None, padding_ratio=0.05).save(
        os.path.join(ios_launchimage_folder, 'LaunchImage.png'), format='PNG'
    )
    make_icon((240, 240), bg_color=None, padding_ratio=0.05).save(
        os.path.join(ios_launchimage_folder, 'LaunchImage@2x.png'), format='PNG'
    )
    make_icon((360, 360), bg_color=None, padding_ratio=0.05).save(
        os.path.join(ios_launchimage_folder, 'LaunchImage@3x.png'), format='PNG'
    )

    # 3. Web Icons & Favicon
    web_folder = os.path.join('mobile', 'web')
    web_icons_folder = os.path.join(web_folder, 'icons')
    os.makedirs(web_icons_folder, exist_ok=True)

    # favicon
    make_icon((48, 48), bg_color=None, padding_ratio=0.04).save(
        os.path.join(web_folder, 'favicon.png'), format='PNG'
    )

    # Icon-192 & Icon-512
    make_icon((192, 192), bg_color=bg_rgb, padding_ratio=0.12).save(
        os.path.join(web_icons_folder, 'Icon-192.png'), format='PNG'
    )
    make_icon((512, 512), bg_color=bg_rgb, padding_ratio=0.12).save(
        os.path.join(web_icons_folder, 'Icon-512.png'), format='PNG'
    )

    # Maskable icons (padded for safe zone circle)
    make_icon((192, 192), bg_color=bg_rgba, padding_ratio=0.20).save(
        os.path.join(web_icons_folder, 'Icon-maskable-192.png'), format='PNG'
    )
    make_icon((512, 512), bg_color=bg_rgba, padding_ratio=0.20).save(
        os.path.join(web_icons_folder, 'Icon-maskable-512.png'), format='PNG'
    )

    # 4. macOS App Icons
    macos_appiconset = os.path.join('mobile', 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(macos_appiconset, exist_ok=True)
    macos_specs = [
        ('app_icon_16.png', (16, 16)),
        ('app_icon_32.png', (32, 32)),
        ('app_icon_64.png', (64, 64)),
        ('app_icon_128.png', (128, 128)),
        ('app_icon_256.png', (256, 256)),
        ('app_icon_512.png', (512, 512)),
        ('app_icon_1024.png', (1024, 1024)),
    ]

    for filename, (w, h) in macos_specs:
        mac_icon = make_icon((w, h), bg_color=bg_rgba, padding_ratio=0.12)
        mac_icon.save(os.path.join(macos_appiconset, filename), format='PNG')

    # 5. Windows app_icon.ico
    win_res = os.path.join('mobile', 'windows', 'runner', 'resources')
    os.makedirs(win_res, exist_ok=True)
    win_icon = make_icon((256, 256), bg_color=None, padding_ratio=0.08)
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    win_icon.save(os.path.join(win_res, 'app_icon.ico'), format='ICO', sizes=ico_sizes)

    print("All app icons successfully generated!")

if __name__ == '__main__':
    generate_icons()
