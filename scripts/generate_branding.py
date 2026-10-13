"""Export the Open Remote mark for the dashboard, Android and Windows.

The geometry and palette below are the source of truth for the brand assets.
SPDX-License-Identifier: GPL-3.0-only
"""

from pathlib import Path
from textwrap import dedent

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "app/assets/branding"
RES = ROOT / "app/android/app/src/main/res"
ARC = "#3C9827"
DOT = "#2E6E25"
TEXT = "#26362C"
LIGHT_ARC = "#71CE56"
LIGHT_DOT = "#B5E8A8"
VIEWBOX = 32
RADIUS = 14
STROKE = 3.8
DOT_X = 5.1
DOT_RADIUS = 4.4
ARC_PATH = "M16 2 A14 14 0 0 1 16 30"
DOT_PATH = "M9.5 16 A4.4 4.4 0 1 1 0.7 16 A4.4 4.4 0 1 1 9.5 16 Z"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dedent(content).strip() + "\n", encoding="utf-8")


def svg_mark(arc: str, dot: str) -> str:
    return (
        f'<path d="{ARC_PATH}" fill="none" stroke="{arc}" '
        f'stroke-width="{STROKE}"/>'
        f'<circle cx="{DOT_X}" cy="16" r="{DOT_RADIUS}" fill="{dot}"/>'
    )


def render_mark(size: int, light: bool = False) -> Image.Image:
    scale = size * 4 / VIEWBOX
    pixels = size * 4
    mask = Image.new("L", (pixels, pixels))
    draw = ImageDraw.Draw(mask)
    outer = RADIUS + STROKE / 2
    inner = RADIUS - STROKE / 2
    bounds = lambda radius: tuple(
        value * scale for value in (16 - radius, 16 - radius, 16 + radius, 16 + radius)
    )
    draw.pieslice(bounds(outer), -90, 90, fill=255)
    draw.ellipse(bounds(inner), fill=0)
    result = Image.new("RGBA", (pixels, pixels))
    result.paste(LIGHT_ARC if light else ARC, (0, 0, pixels, pixels), mask)
    ImageDraw.Draw(result).ellipse(
        tuple(value * scale for value in (
            DOT_X - DOT_RADIUS, 16 - DOT_RADIUS,
            DOT_X + DOT_RADIUS, 16 + DOT_RADIUS,
        )),
        fill=LIGHT_DOT if light else DOT,
    )
    return result.resize((size, size), Image.Resampling.LANCZOS)


def render_icon(size: int, round_icon: bool = False, tray: bool = False) -> Image.Image:
    pixels = size * 4
    result = Image.new("RGBA", (pixels, pixels))
    draw = ImageDraw.Draw(result)
    bounds = (1, 1, pixels - 2, pixels - 2)
    if round_icon:
        draw.ellipse(bounds, fill="#FFFFFF")
    else:
        draw.rounded_rectangle(bounds, radius=pixels * 0.22, fill="#FFFFFF")
    mark_size = round(pixels * (0.74 if tray else 0.64))
    mark = render_mark(mark_size)
    inset = (pixels - mark_size) // 2
    result.alpha_composite(mark, (inset, inset))
    return result.resize((size, size), Image.Resampling.LANCZOS)


def android_vector(arc: str, dot: str, viewport: int = 32, inset: int = 0,
                   scale: float = 1, size: int = 64) -> str:
    return f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
        android:width="{size}dp" android:height="{size}dp"
        android:viewportWidth="{viewport}" android:viewportHeight="{viewport}">
        <group android:translateX="{inset}" android:translateY="{inset}"
            android:scaleX="{scale}" android:scaleY="{scale}">
            <path android:pathData="{ARC_PATH}" android:fillColor="#00000000"
                android:strokeColor="{arc}" android:strokeWidth="{STROKE}" />
            <path android:pathData="{DOT_PATH}" android:fillColor="{dot}" />
        </group>
    </vector>'''


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    for suffix, arc, dot, text in (
        ("", ARC, DOT, TEXT),
        ("-light", LIGHT_ARC, LIGHT_DOT, "#F0F5EF"),
    ):
        write(BRAND / f"mark{suffix}.svg", f'''
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img">
                <title>Open Remote Control</title>
                {svg_mark(arc, dot)}
            </svg>''')
        write(BRAND / f"logo{suffix}.svg", f'''
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 226 48" role="img">
                <title>Open Remote</title>
                <g transform="translate(0 8)">{svg_mark(arc, dot)}</g>
                <text x="46" y="32" fill="{text}" font-size="24" font-weight="600"
                    font-family="Segoe UI, Arial, sans-serif">Open Remote</text>
            </svg>''')
        render_mark(256, light=bool(suffix)).save(BRAND / f"mark{suffix}.png")

    write(ROOT / "web/server/assets/branding/mark.svg", (BRAND / "mark.svg").read_text(encoding="utf-8"))

    icon = render_icon(512)
    icon.save(BRAND / "app-icon.png")
    icon_sizes = [(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
    icon.save(ROOT / "web/server/windows/runner/resources/app_icon.ico", sizes=icon_sizes)
    render_icon(256, tray=True).save(ROOT / "web/server/assets/tray_icon.ico", sizes=icon_sizes)

    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        directory = RES / f"mipmap-{density}"
        directory.mkdir(parents=True, exist_ok=True)
        render_icon(size).save(directory / "ic_launcher.png")
        render_icon(size, round_icon=True).save(directory / "ic_launcher_round.png")

    write(RES / "drawable/brand_mark_light.xml", android_vector(LIGHT_ARC, LIGHT_DOT))
    write(RES / "drawable/brand_splash.xml", android_vector(
        LIGHT_ARC, LIGHT_DOT, viewport=96, inset=24, scale=1.5, size=96,
    ))
    write(RES / "drawable/ic_launcher_foreground.xml", android_vector(
        ARC, DOT, viewport=108, inset=28, scale=1.625, size=108,
    ))
    write(RES / "drawable/ic_launcher_monochrome.xml", android_vector(
        "#000000", "#000000", viewport=108, inset=28, scale=1.625, size=108,
    ))
    for api in (26, 33):
        monochrome = (
            '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />'
            if api >= 33 else ""
        )
        adaptive = f'''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
            <background android:drawable="@color/brand_icon_background" />
            <foreground android:drawable="@drawable/ic_launcher_foreground" />
            {monochrome}
        </adaptive-icon>'''
        for name in ("ic_launcher", "ic_launcher_round"):
            write(RES / f"mipmap-anydpi-v{api}/{name}.xml", adaptive)
    print("Updated SVG/PNG marks, Android icons and Windows icons.")


if __name__ == "__main__":
    main()
