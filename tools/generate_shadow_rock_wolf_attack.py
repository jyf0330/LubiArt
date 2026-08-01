from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/images/shared/pets/sheets/slices/pet_style_006_shadow_rock_wolf.png"
OUT = ROOT / "output"
FRAME_DIR = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/preview_v11/attack"
STRIP_PATH = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/shadow_rock_wolf_attack_preview_v11.png"
GIF_PATH = OUT / "shadow_rock_wolf_frame_attack_preview_v11.gif"
UP_HEAD_SOURCE = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/sources/shadow_rock_wolf_up_head_v1.png"
CLOSED_FRAME_SOURCE = ROOT / "art/images/shared/pets/animations/shadow_rock_wolf/sources/shadow_rock_wolf_closed_neutral_v1.png"


def stepped_resize(image: Image.Image, width: int, height: int) -> Image.Image:
    return image.resize((width, height), Image.Resampling.NEAREST)


def make_open_mouth(source: Image.Image) -> Image.Image:
    image = source.copy()
    px = image.load()

    # Clear the original nose bridge, smile and whisker specks only where the
    # user's new mouth overlaps them. Rebuild the muzzle from its native edge
    # colors before drawing the polished pixel mouth.
    for y in range(69, 88):
        for x in range(109, 139):
            # Horizontal interpolation between untouched muzzle pixels.
            left = source.getpixel((108, y))
            right = source.getpixel((139, y))
            t = (x - 108) / 31.0
            px[x, y] = tuple(round(left[i] * (1.0 - t) + right[i] * t) for i in range(4))

    draw = ImageDraw.Draw(image)

    # The position and overall oval match the user's 26x17-pixel sketch. The
    # contour is rebuilt as deliberate 1-2 pixel steps rather than a smooth
    # ellipse, using colors already present in the character.
    outer = [
        (118, 69), (129, 69), (129, 70), (133, 70),
        (133, 72), (135, 72), (135, 75), (136, 75),
        (136, 80), (135, 80), (135, 82), (133, 82),
        (133, 84), (129, 84), (129, 85), (117, 85),
        (117, 84), (114, 84), (114, 82), (112, 82),
        (112, 80), (111, 80), (111, 75), (112, 75),
        (112, 72), (114, 72), (114, 70), (118, 70),
    ]
    draw.polygon(outer, fill=(15, 16, 18, 255))

    inner = [
        (118, 72), (129, 72), (129, 73), (132, 73),
        (132, 75), (134, 75), (134, 80), (132, 80),
        (132, 82), (128, 82), (128, 83), (118, 83),
        (118, 82), (115, 82), (115, 80), (113, 80),
        (113, 76), (115, 76), (115, 73), (118, 73),
    ]
    draw.polygon(inner, fill=(103, 28, 45, 255))

    tongue = [
        (120, 79), (130, 79), (130, 80), (132, 80),
        (132, 81), (128, 81), (128, 83), (118, 83),
        (118, 82), (116, 82), (116, 81), (120, 81),
    ]
    draw.polygon(tongue, fill=(240, 70, 105, 255))
    draw.rectangle((121, 79, 129, 79), fill=(255, 113, 137, 255))
    return image


def make_tight_mouth(source: Image.Image) -> Image.Image:
    image = source.copy()
    px = image.load()
    for y in range(77, 91):
        for x in range(109, 135):
            left = source.getpixel((108, y))
            right = source.getpixel((135, y))
            t = (x - 108) / 27.0
            px[x, y] = tuple(round(left[i] * (1.0 - t) + right[i] * t) for i in range(4))

    draw = ImageDraw.Draw(image)
    draw.rectangle((120, 76, 123, 81), fill=(17, 18, 20, 255))
    tight_lip = [
        (114, 82), (119, 82), (119, 84), (125, 84), (125, 82),
        (130, 82), (130, 85), (125, 85), (125, 87), (119, 87),
        (119, 85), (114, 85),
    ]
    draw.polygon(tight_lip, fill=(15, 16, 18, 255))
    return image


def make_head_mask(source: Image.Image) -> Image.Image:
    mask = Image.new("L", source.size, 0)
    src = source.load()
    dst = mask.load()
    for y in range(100):
        for x in range(48, 178):
            r, g, b, a = src[x, y]
            if not a:
                continue
            if y <= 88:
                dst[x, y] = 255
            elif y <= 98:
                # The chin is grayscale; the saturated gold/red collar stays put.
                if max(r, g, b) - min(r, g, b) <= 58 or max(r, g, b) < 72:
                    dst[x, y] = 255
    return mask


def make_body_without_head(source: Image.Image, head_mask: Image.Image) -> Image.Image:
    body = source.copy()
    body_px = body.load()
    src_px = source.load()
    mask_px = head_mask.load()
    for y in range(source.height):
        for x in range(source.width):
            if mask_px[x, y]:
                body_px[x, y] = (0, 0, 0, 0)

    # Extend the fixed collar upward only behind the lifted chin. This prevents
    # transparent gaps while leaving the torso, tail, clothing and paws untouched.
    for x in range(55, 171):
        replacement = None
        for sample_y in range(99, 112):
            if not mask_px[x, sample_y] and src_px[x, sample_y][3]:
                replacement = src_px[x, sample_y]
                break
        if replacement is None:
            continue
        for y in range(88, 99):
            if mask_px[x, y]:
                body_px[x, y] = replacement
    return body


def fill_rect_from_face(image: Image.Image, source: Image.Image, box: tuple[int, int, int, int]) -> None:
    pixels = image.load()
    x_0, y_0, x_1, y_1 = box
    for y in range(y_0, y_1 + 1):
        left = source.getpixel((x_0 - 1, y))
        right = source.getpixel((x_1 + 1, y))
        for x in range(x_0, x_1 + 1):
            amount = (x - x_0 + 1) / (x_1 - x_0 + 2)
            pixels[x, y] = tuple(
                round(left[channel] * (1.0 - amount) + right[channel] * amount)
                for channel in range(4)
            )


def extract_eye(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    layer_pixels = layer.load()
    x_0, y_0, x_1, y_1 = box
    for y in range(y_0, y_1 + 1):
        for x in range(x_0, x_1 + 1):
            red, green, blue, alpha = source_pixels[x, y]
            chroma = max(red, green, blue) - min(red, green, blue)
            if alpha and (chroma > 65 or max(red, green, blue) < 105 or min(red, green, blue) > 218):
                layer_pixels[x, y] = source_pixels[x, y]
    return layer


def draw_pursed_mouth(draw: ImageDraw.ImageDraw, top_y: int) -> None:
    outer = [
        (118, top_y), (126, top_y), (126, top_y + 2),
        (129, top_y + 2), (129, top_y + 8), (126, top_y + 8),
        (126, top_y + 10), (118, top_y + 10), (118, top_y + 8),
        (115, top_y + 8), (115, top_y + 2), (118, top_y + 2),
    ]
    draw.polygon(outer, fill=(20, 17, 20, 255))
    lip = [
        (119, top_y + 2), (125, top_y + 2), (125, top_y + 3),
        (127, top_y + 3), (127, top_y + 7), (125, top_y + 7),
        (125, top_y + 8), (119, top_y + 8), (119, top_y + 7),
        (117, top_y + 7), (117, top_y + 3), (119, top_y + 3),
    ]
    draw.polygon(lip, fill=(224, 65, 104, 255))
    draw.rectangle((120, top_y + 4, 124, top_y + 7), fill=(91, 24, 43, 255))
    draw.rectangle((121, top_y + 3, 124, top_y + 4), fill=(255, 120, 145, 255))


def make_upward_facing_charge(source: Image.Image, full: bool) -> Image.Image:
    # Do not transform the skull, ears or outline. The face is redrawn in a
    # from-below perspective, following the supplied motion reference.
    image = source.copy()
    left_eye = extract_eye(source, (80, 46, 111, 73))
    right_eye = extract_eye(source, (133, 46, 163, 73))
    fill_rect_from_face(image, source, (80, 46, 111, 74))
    fill_rect_from_face(image, source, (133, 46, 163, 74))
    fill_rect_from_face(image, source, (108, 56, 136, 91))

    draw = ImageDraw.Draw(image)
    top = 61 if full else 66
    outer = [
        (91, top), (149, top), (149, top + 2), (154, top + 2),
        (154, top + 9), (158, top + 9), (158, 84), (154, 84),
        (154, 90), (149, 90), (149, 94), (91, 94), (91, 92),
        (86, 92), (86, 86), (82, 86), (82, top + 11),
        (86, top + 11), (86, top + 4), (91, top + 4),
    ]
    draw.polygon(outer, fill=(156, 167, 175, 255))
    inner_top = top + 2
    inner = [
        (96, inner_top), (144, inner_top), (144, inner_top + 2),
        (150, inner_top + 2), (150, inner_top + 8), (154, inner_top + 8),
        (154, 82), (150, 82), (150, 88), (145, 88), (145, 92),
        (95, 92), (95, 90), (90, 90), (90, 84), (86, 84),
        (86, inner_top + 10), (90, inner_top + 10), (90, inner_top + 4),
        (96, inner_top + 4),
    ]
    draw.polygon(inner, fill=(218, 224, 228, 255))
    highlight_top = inner_top + 3
    draw.polygon(
        [
            (104, highlight_top), (136, highlight_top), (136, highlight_top + 2),
            (143, highlight_top + 2), (143, 76 if full else 79),
            (147, 76 if full else 79), (147, 84), (142, 84),
            (142, 88), (98, 88), (98, 86), (93, 86),
            (93, 77 if full else 80), (97, 77 if full else 80),
            (97, highlight_top + 3), (104, highlight_top + 3),
        ],
        fill=(236, 239, 241, 255),
    )
    draw.rectangle((100, 89, 140, 92), fill=(178, 188, 195, 255))
    draw.rectangle((106, 93, 134, 95), fill=(91, 103, 112, 255))

    eye_shift = -5 if full else -2
    image.alpha_composite(left_eye, (0, eye_shift))
    image.alpha_composite(right_eye, (0, eye_shift))
    draw = ImageDraw.Draw(image)
    nose_y = 55 if full else 61
    nose = [
        (117, nose_y), (127, nose_y), (127, nose_y + 2),
        (130, nose_y + 2), (130, nose_y + 6), (127, nose_y + 6),
        (127, nose_y + 8), (117, nose_y + 8), (117, nose_y + 6),
        (114, nose_y + 6), (114, nose_y + 2), (117, nose_y + 2),
    ]
    draw.polygon(nose, fill=(15, 16, 18, 255))
    draw.rectangle((119, nose_y, 125, nose_y + 1), fill=(63, 66, 70, 255))
    mouth_y = 67 if full else 74
    draw.rectangle((120, nose_y + 8, 123, mouth_y - 1), fill=(15, 16, 18, 255))
    draw_pursed_mouth(draw, mouth_y)
    return image


def make_forward_puffed_face(source: Image.Image) -> Image.Image:
    # After the neck returns, the stored breath remains in the muzzle for one
    # readable aiming frame before the release.
    image = source.copy()
    fill_rect_from_face(image, source, (108, 74, 136, 92))
    draw = ImageDraw.Draw(image)
    left_cheek = [
        (91, 70), (112, 70), (112, 72), (117, 72), (117, 87),
        (113, 87), (113, 91), (94, 91), (94, 89), (90, 89),
        (90, 75), (91, 75),
    ]
    right_cheek = [
        (128, 70), (149, 70), (149, 75), (150, 75), (150, 89),
        (146, 89), (146, 91), (127, 91), (127, 87), (123, 87),
        (123, 72), (128, 72),
    ]
    draw.polygon(left_cheek, fill=(235, 239, 241, 255))
    draw.polygon(right_cheek, fill=(235, 239, 241, 255))
    draw.rectangle((94, 88, 113, 91), fill=(185, 195, 201, 255))
    draw.rectangle((127, 88, 146, 91), fill=(185, 195, 201, 255))
    draw.rectangle((120, 76, 123, 78), fill=(15, 16, 18, 255))
    draw_pursed_mouth(draw, 79)
    return image


def articulate_head_around_neck(
    original: Image.Image,
    face_pose: Image.Image,
    strength: float,
) -> Image.Image:
    # Rotate the head plane around the fixed collar/neck root in front view.
    # The crown recedes downward and inward while the lower cheeks fan outward.
    # This is deliberately separate from the internal up-facing face redraw.
    head_mask = make_head_mask(original)
    body = make_body_without_head(original, head_mask)
    head = Image.new("RGBA", original.size, (0, 0, 0, 0))
    head.paste(face_pose, (0, 0), head_mask)

    projected = Image.new("RGBA", original.size, (0, 0, 0, 0))
    top_y = round(4 * strength)
    bottom_y = 98
    source_left = 45
    source_right = 180
    top_left = source_left + round(4 * strength)
    top_right = source_right - round(4 * strength)
    bottom_left = source_left - round(2 * strength)
    bottom_right = source_right

    for target_y in range(top_y, bottom_y + 1):
        amount = (target_y - top_y) / (bottom_y - top_y)
        source_y = round(98 * amount)
        left = round(top_left * (1.0 - amount) + bottom_left * amount)
        right = round(top_right * (1.0 - amount) + bottom_right * amount)
        row = head.crop((source_left, source_y, source_right, source_y + 1))
        row = row.resize((max(1, right - left), 1), Image.Resampling.NEAREST)
        projected.alpha_composite(row, (left, target_y))

    pose = body.copy()
    pose.alpha_composite(projected)
    return pose


def make_generated_up_pose(source: Image.Image) -> Image.Image:
    # This is the exact green-screen head pose approved by the user, extracted,
    # keyed and stored inside the project. Only the original head is replaced;
    # the original body, collar, tail, clothing and paws remain untouched.
    up_head = Image.open(UP_HEAD_SOURCE).convert("RGBA")
    head_mask = make_head_mask(source)
    pose = make_body_without_head(source, head_mask)
    pose.alpha_composite(up_head, (51, -2))
    return pose


def place_on_canvas(source: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    canvas.alpha_composite(source, (10, 10))
    return canvas


def build_attack_frames(
    source: Image.Image,
    open_mouth: Image.Image,
    closed_frame: Image.Image,
) -> list[Image.Image]:
    up_pose = make_generated_up_pose(source)

    # Requested storyboard: user-approved closed mouth -> approved full up-pose
    # -> hold -> head lowers while the mouth opens immediately -> hold -> the
    # exact same closed mouth. Identical endpoints prevent a loop seam.
    return [
        closed_frame.copy(),           # user-approved neutral
        place_on_canvas(up_pose),      # approved green-screen full up-pose
        place_on_canvas(up_pose),      # hold the up-pose
        place_on_canvas(open_mouth),   # lower and open in the same frame
        place_on_canvas(open_mouth),   # keep the release mouth readable
        closed_frame.copy(),           # recover to the identical endpoint
    ]


def save_strip(frames: list[Image.Image]) -> None:
    strip = Image.new("RGBA", (200 * len(frames), 200), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * 200, 0))
    STRIP_PATH.parent.mkdir(parents=True, exist_ok=True)
    strip.save(STRIP_PATH)


def save_gif(frames: list[Image.Image]) -> None:
    # Fully opaque preview frames plus disposal=2 prevent accumulated silhouettes.
    background = (43, 46, 52, 255)
    preview_frames = []
    for frame in frames:
        flattened = Image.new("RGBA", frame.size, background)
        flattened.alpha_composite(frame)
        preview_frames.append(flattened.convert("RGB"))
    GIF_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview_frames[0].save(
        GIF_PATH,
        save_all=True,
        append_images=preview_frames[1:],
        duration=[220, 240, 320, 260, 260, 280],
        loop=0,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    open_mouth = make_open_mouth(source)
    closed_frame = Image.open(CLOSED_FRAME_SOURCE).convert("RGBA")
    if closed_frame.size != (200, 200):
        raise ValueError(f"Closed frame must be 200x200, got {closed_frame.size}")

    frames = build_attack_frames(source, open_mouth, closed_frame)
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames, start=1):
        frame.save(FRAME_DIR / f"frame_{index:03d}.png")
    save_strip(frames)
    save_gif(frames)


if __name__ == "__main__":
    main()
