from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "art/images/battle/hud/attack_timeline/pet_frame"
OUTPUT = ROOT / "output/attack_timeline_pet_frame_component_preview_v1.png"
CARD_SOURCE_SIZE = 220
CARD_RENDER_SIZE = 168

FRAME = ASSET_ROOT / "top_frames/creature_card_top_frame_bronze_001.png"
PETS = [
    {
        "name": "捣蛋猫",
        "element": "自然",
        "pet": ROOT / "art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png",
        "background": ASSET_ROOT / "backgrounds/creature_card_background_nature_001.png",
    },
    {
        "name": "企丸王",
        "element": "水",
        "pet": ROOT / "art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png",
        "background": ASSET_ROOT / "backgrounds/creature_card_background_water_001.png",
    },
    {
        "name": "荆棘魔仙",
        "element": "自然",
        "pet": ROOT / "art/images/shared/pets/sheets/slices/pet_style_004_pink_electric_wave.png",
        "background": ASSET_ROOT / "backgrounds/creature_card_background_nature_001.png",
    },
    {
        "name": "波娜兔",
        "element": "自然",
        "pet": ROOT / "art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png",
        "background": ASSET_ROOT / "backgrounds/creature_card_background_nature_001.png",
    },
]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\msyh.ttc"),
        Path(r"C:\Windows\Fonts\simhei.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def fit_pet(path: Path) -> Image.Image:
    pet = Image.open(path).convert("RGBA")
    bbox = pet.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No visible pet pixels: {path}")
    pet = pet.crop(bbox)
    max_width, max_height = 150, 145
    scale = min(max_width / pet.width, max_height / pet.height)
    size = (max(1, round(pet.width * scale)), max(1, round(pet.height * scale)))
    return pet.resize(size, Image.Resampling.NEAREST)


def compose_card(record: dict[str, object]) -> Image.Image:
    background = Image.open(record["background"]).convert("RGBA")
    pet = fit_pet(record["pet"])
    left = round((CARD_SOURCE_SIZE - pet.width) / 2)
    top = 190 - pet.height
    background.alpha_composite(pet, (left, top))
    background.alpha_composite(Image.open(FRAME).convert("RGBA"), (0, 0))
    return background.resize((CARD_RENDER_SIZE, CARD_RENDER_SIZE), Image.Resampling.LANCZOS)


def main() -> None:
    canvas = Image.new("RGB", (1920, 1080), "#e9d7ad")
    draw = ImageDraw.Draw(canvas)
    title_font = font(38)
    label_font = font(24)
    number_font = font(28)
    draw.text((96, 62), "攻击顺序精灵框组件（4只精灵 × 2轮）", font=title_font, fill="#3c5325")
    draw.text((96, 118), "背景按主元素切换，框按品质切换；当前快照均为青铜品质。", font=label_font, fill="#684b28")

    centers = [390, 770, 1150, 1530]
    row_tops = [225, 650]
    order = 1
    for row_top in row_tops:
        for index, center_x in enumerate(centers):
            record = PETS[index]
            card = compose_card(record)
            left = center_x - CARD_RENDER_SIZE // 2
            canvas.paste(card, (left, row_top), card)
            badge_center = (center_x, row_top - 20)
            radius = 25
            draw.ellipse(
                (badge_center[0] - radius, badge_center[1] - radius,
                 badge_center[0] + radius, badge_center[1] + radius),
                fill="#d7b271",
                outline="#62451f",
                width=4,
            )
            order_text = str(order)
            text_box = draw.textbbox((0, 0), order_text, font=number_font)
            draw.text(
                (badge_center[0] - (text_box[2] - text_box[0]) / 2,
                 badge_center[1] - (text_box[3] - text_box[1]) / 2 - 3),
                order_text,
                font=number_font,
                fill="#3d2b18",
            )
            label = f"{record['name']} · {record['element']}"
            label_box = draw.textbbox((0, 0), label, font=label_font)
            draw.text(
                (center_x - (label_box[2] - label_box[0]) / 2, row_top + CARD_RENDER_SIZE + 22),
                label,
                font=label_font,
                fill="#4b321d",
            )
            order += 1

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT)
    print(f"Wrote component preview: {OUTPUT}")


if __name__ == "__main__":
    main()
