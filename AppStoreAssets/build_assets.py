#!/usr/bin/env python3
"""Build StillRain portrait marketing art and watchOS App Store exports."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FONT = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"

SLIDES = (
    {
        "source": "01-return-before-reacting.png",
        "name": "01-return-before-reacting",
        "headline": "RETURN BEFORE\nREACTING",
        "body": "A discreet grounding anchor\nfor emotionally charged moments.",
        "crop_y": 86,
    },
    {
        "source": "02-quiet-haptic-anchor.png",
        "name": "02-quiet-haptic-anchor",
        "headline": "A QUIET HAPTIC\nANCHOR",
        "body": "Gentle pulses bring attention\nback to the body.",
        "crop_y": 116,
    },
    {
        "source": "03-one-tap.png",
        "name": "03-one-tap",
        "headline": "ONE TAP.\nNO EXPLANATION.",
        "body": "Start from your watch face.\nStop with one tap anywhere.",
        "crop_y": 86,
    },
)


def font(size: int, rounded: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_ROUNDED if rounded else FONT, size=size)


def add_top_gradient(image: Image.Image, height: int, strength: int) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for y in range(height):
        alpha = int(strength * (1 - y / max(1, height - 1)) ** 1.8)
        draw.line((0, y, image.width, y), fill=(2, 13, 27, alpha))
    image.alpha_composite(overlay)


def draw_copy(image: Image.Image, headline: str, body: str, compact: bool) -> None:
    draw = ImageDraw.Draw(image)
    if compact:
        margin = 27
        brand_y = 20
        headline_y = 43
        headline_font = font(31, rounded=True)
        body_font = font(13)
        brand_font = font(9)
        line_gap = 1
        body_gap = 10
    else:
        margin = 72
        brand_y = 70
        headline_y = 135
        headline_font = font(82, rounded=True)
        body_font = font(31)
        brand_font = font(21)
        line_gap = 2
        body_gap = 28

    rain = (176, 216, 226, 255)
    white = (247, 249, 250, 255)
    muted = (203, 217, 224, 255)

    dot_r = 3 if compact else 7
    dot_y = brand_y + (2 if compact else 5)
    draw.ellipse(
        (margin, dot_y, margin + dot_r * 2, dot_y + dot_r * 2),
        fill=rain,
    )
    draw.text(
        (margin + dot_r * 3, brand_y),
        "STILLRAIN",
        font=brand_font,
        fill=muted,
        tracking=1 if compact else 3,
    )

    draw.multiline_text(
        (margin, headline_y),
        headline,
        font=headline_font,
        fill=white,
        spacing=line_gap,
    )
    box = draw.multiline_textbbox(
        (margin, headline_y), headline, font=headline_font, spacing=line_gap
    )
    draw.multiline_text(
        (margin, box[3] + body_gap),
        body,
        font=body_font,
        fill=muted,
        spacing=3 if compact else 8,
    )


def build_portrait(slide: dict[str, object]) -> None:
    source = Image.open(ROOT / "raw" / str(slide["source"])).convert("RGBA")
    add_top_gradient(source, height=710, strength=158)
    draw_copy(source, str(slide["headline"]), str(slide["body"]), compact=False)
    out = source.convert("RGB")
    out.save(ROOT / "portrait" / f"{slide['name']}-portrait.png", quality=95)


def build_watch(slide: dict[str, object], width: int, height: int) -> None:
    source = Image.open(ROOT / "raw" / str(slide["source"])).convert("RGB")
    crop_width = source.width
    crop_height = round(crop_width * height / width)
    top = int(slide["crop_y"])
    top = max(0, min(top, source.height - crop_height))
    source = source.crop((0, top, crop_width, top + crop_height))
    source = source.resize((width, height), Image.Resampling.LANCZOS).convert("RGBA")
    add_top_gradient(source, height=235, strength=178)
    draw_copy(source, str(slide["headline"]), str(slide["body"]), compact=True)
    out = source.convert("RGB")
    destination = ROOT / f"watch-{width}x{height}"
    destination.mkdir(parents=True, exist_ok=True)
    out.save(destination / f"{slide['name']}-{width}x{height}.png", quality=95)


def main() -> None:
    (ROOT / "portrait").mkdir(parents=True, exist_ok=True)
    (ROOT / "watch-416x496").mkdir(parents=True, exist_ok=True)
    for slide in SLIDES:
        build_portrait(slide)
        build_watch(slide, 416, 496)
        build_watch(slide, 422, 514)


if __name__ == "__main__":
    main()
