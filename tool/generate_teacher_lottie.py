#!/usr/bin/env python3
"""
Generate Lottie character animations for Czechify teacher characters.

Creates 4 files in assets/animations/:
  teacher_female_idle.json
  teacher_female_talk.json
  teacher_male_idle.json
  teacher_male_talk.json

Output: flat-vector chibi teacher characters at 300×300, 30 fps.
"""

import json
import math
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'animations')
FR = 30  # frame rate
W, H = 300, 300  # canvas

# ── Color palette ──────────────────────────────────────────────────
C_SKIN_F = (1.0, 0.84, 0.72, 1.0)   # warm light skin (female)
C_SKIN_M = (0.95, 0.78, 0.62, 1.0)  # warm medium skin (male)
C_HAIR_F = (0.55, 0.27, 0.07, 1.0)  # brown hair
C_HAIR_M = (0.30, 0.20, 0.12, 1.0)  # dark brown hair
C_BLOUSE = (0.29, 0.57, 0.85, 1.0)  # blue blouse (female)
C_SHIRT = (0.95, 0.95, 0.96, 1.0)   # white shirt (male)
C_TIE = (0.76, 0.16, 0.16, 1.0)     # red tie (male)
C_EYE_W = (1.0, 1.0, 1.0, 1.0)      # eye white
C_PUPIL = (0.15, 0.15, 0.15, 1.0)   # dark pupil
C_MOUTH = (0.80, 0.30, 0.30, 1.0)   # mouth/lip color
C_BLUSH = (1.0, 0.71, 0.71, 0.50)   # blush pink (semi-transparent)
C_GLASS = (0.40, 0.40, 0.40, 1.0)   # glasses frames
C_LAPEL = (0.25, 0.52, 0.80, 1.0)   # darker blue for collar detail
C_COLLAR = (0.90, 0.90, 0.92, 1.0)  # collar
C_GOLD = (0.85, 0.65, 0.13, 1.0)    # accessory / necklace


def rgba(r, g, b, a=1.0):
    """Normalize 0-255 values or pass 0-1 floats."""
    if r > 1 and g > 1 and b > 1:
        return (r/255.0, g/255.0, b/255.0, a)
    return (r, g, b, a)


def color_arr(c):
    return [c[0], c[1], c[2], c[3]]


# ── Lottie helpers ─────────────────────────────────────────────────

def lottie_header(name, frames):
    return {
        "v": "5.5.0",
        "fr": FR,
        "ip": 0,
        "op": frames,
        "w": W,
        "h": H,
        "nm": name,
        "ddd": 0,
        "layers": [],
        "assets": [],
        "fonts": {"list": []},
        "chars": [],
        "markers": [],
    }


def static_val(v):
    """Value that doesn't animate over time."""
    return {"a": 0, "k": v}


def animated_val(keyframes):
    """Value that changes over time. keyframes: list of {t, s, e?, i?, o?}"""
    return {"a": 1, "k": keyframes}


def make_kf(t, s, e=None, ease_in=(0.42, 0), ease_out=(0.58, 1)):
    """Single keyframe. Omit e for hold."""
    kf = {"t": t, "s": s}
    if e is not None:
        kf["e"] = e
        kf["i"] = {"x": ease_in[0], "y": ease_in[1]}
        kf["o"] = {"x": ease_out[0], "y": ease_out[1]}
    else:
        kf["h"] = 1  # hold
    return kf


# ── Shape factories ────────────────────────────────────────────────

def shape_group(items, name="group", transform=None):
    grp = {
        "ty": "gr",
        "nm": name,
        "np": len(items),
        "cix": 2,
        "it": items,
    }
    if transform:
        grp["it"].append(transform)
    return grp


def fill_shape(color, name="Fill"):
    return {
        "ty": "fl",
        "nm": name,
        "c": static_val(color_arr(color)),
        "o": static_val(color[3] * 100 if len(color) > 3 else 100),
        "r": 1,
        "bm": 0,
    }


def stroke_shape(color, width=2, name="Stroke"):
    return {
        "ty": "st",
        "nm": name,
        "c": static_val(color_arr(color)),
        "o": static_val(100),
        "w": static_val(width),
        "lc": 1,
        "lj": 1,
        "ml": 4,
        "bm": 0,
    }


def ellipse_shape(size, position, name="Ellipse"):
    return {
        "ty": "el",
        "nm": name,
        "p": static_val(position),
        "s": static_val(size),
        "d": 1,
    }


def rect_shape(size, position, rounded=0, name="Rectangle"):
    return {
        "ty": "rc",
        "nm": name,
        "p": static_val(position),
        "s": static_val(size),
        "r": static_val(rounded),
        "d": 1,
    }


def transform_shape(position=(0, 0), anchor=(0, 0), scale=(100, 100),
                     rotation=0, opacity=100):
    return {
        "ty": "tr",
        "nm": "Transform",
        "a": static_val(anchor),
        "p": static_val(position),
        "s": static_val(scale),
        "r": static_val(rotation),
        "o": static_val(opacity),
    }


def animated_transform(position_kfs=None, scale_kfs=None, rotation_kfs=None,
                       anchor=(0, 0), opacity=100):
    t = {
        "ty": "tr",
        "nm": "Transform",
        "a": static_val(anchor),
        "p": static_val(position_kfs[0]) if position_kfs and not isinstance(position_kfs[0], dict)
             else animated_val(position_kfs) if position_kfs else static_val((0, 0)),
        "s": static_val(scale_kfs[0]) if scale_kfs and not isinstance(scale_kfs[0], dict)
             else animated_val(scale_kfs) if scale_kfs else static_val((100, 100)),
        "r": static_val(rotation_kfs[0]) if rotation_kfs and not isinstance(rotation_kfs[0], dict)
             else animated_val(rotation_kfs) if rotation_kfs else static_val(0),
        "o": static_val(opacity),
    }
    return t


# ── Layer factory ──────────────────────────────────────────────────

def shape_layer(shapes, index, name="Layer", in_point=0, out_point=60,
                position=(W/2, H/2), scale=(100, 100), auto_orient=0,
                stretch=1, start_time=0, blending=0):
    # Default transform for the whole layer
    default_ks = {
        "a": static_val([0, 0]),
        "p": static_val(position),
        "s": static_val(scale),
        "r": static_val(0),
        "o": static_val(100),
    }
    return {
        "ddd": 0,
        "ind": index,
        "ty": 4,
        "nm": name,
        "sr": stretch,
        "ks": default_ks,
        "ao": auto_orient,
        "shapes": shapes,
        "ip": in_point,
        "op": out_point,
        "st": start_time,
        "bm": blending,
    }


def animated_layer(shapes, index, name, ks_override=None,
                   in_point=0, out_point=60, start_time=0):
    """Layer with animated transforms."""
    base_ks = {
        "a": static_val([0, 0]),
        "p": static_val([W/2, H/2]),
        "s": static_val([100, 100]),
        "r": static_val(0),
        "o": static_val(100),
    }
    if ks_override:
        base_ks.update(ks_override)
    return {
        "ddd": 0,
        "ind": index,
        "ty": 4,
        "nm": name,
        "sr": 1,
        "ks": base_ks,
        "ao": 0,
        "shapes": shapes,
        "ip": in_point,
        "op": out_point,
        "st": start_time,
        "bm": 0,
    }


# ═══════════════════════════════════════════════════════════════════
#  CHARACTER DEFINITIONS
# ═══════════════════════════════════════════════════════════════════

def make_breathing_kfs(frames, amp=1.5, period=1.5):
    """Sine-wave breathing scale keyframes. Returns scale keyframes."""
    kfs = []
    for t in range(frames):
        s = 100 + amp * math.sin(2 * math.pi * t / (period * FR))
        kfs.append(make_kf(t, [s, s]))
    return kfs


def make_talk_breathing_kfs(frames, amp=2.0, period=1.2):
    """More energetic breathing for talking."""
    return make_breathing_kfs(frames, amp=amp, period=period)


def make_blink_kfs(frames):
    """Eye scale keyframes: blink at random-ish intervals."""
    kfs = []
    for t in range(frames):
        s = 100.0
        # Blink every ~3 seconds
        if t % round(3 * FR) in [0, 1, round(0.5 * FR)]:
            if t % round(3 * FR) == 0:
                s = 30  # blink closed
            elif t % round(3 * FR) == 1:
                s = 100  # open
        kfs.append(make_kf(t, [100, s]))
    return kfs


def make_mouth_talk_kfs(frames):
    """Mouth opens and closes in a speaking rhythm."""
    kfs = []
    talk_frames = frames
    for t in range(talk_frames):
        # Rapid open/close pattern simulating speech
        phase = (t % 12)  # ~2.5 syllables per second at 30fps
        if phase < 4:
            scale_y = 100 + 40 * math.sin(phase * math.pi / 4)
        elif phase < 8:
            scale_y = 100 + 60 * math.sin((phase - 4) * math.pi / 4)
        else:
            scale_y = 100 + 30 * math.sin((phase - 8) * math.pi / 4)
        kfs.append(make_kf(t, [100, scale_y]))
    return kfs


def make_body_talk_kfs(frames):
    """Subtle body sway while talking."""
    kfs = []
    for t in range(frames):
        sway = 3 * math.sin(2 * math.pi * t / (1.0 * FR))
        kfs.append(make_kf(t, [W/2 + sway, H/2 - 5]))
    return kfs


def make_arm_talk_kfs(frames, arm_side=1):
    """Arm gesture animation. arm_side: 1 = right, -1 = left."""
    kfs = []
    for t in range(frames):
        angle = 5 * arm_side + 8 * arm_side * math.sin(2 * math.pi * t / (1.5 * FR))
        kfs.append(make_kf(t, [angle]))
    return kfs


# ── Female Teacher ────────────────────────────────────────────────

def build_female_character(frames, is_talk):
    """Build all shapes for female teacher, returning a list of layers."""
    layers = []
    idx = 0

    bx, by = W/2, H/2  # body center

    if is_talk:
        breathing_kfs = make_talk_breathing_kfs(frames, amp=2.5)
        body_kfs = make_body_talk_kfs(frames)
        mouth_kfs = make_mouth_talk_kfs(frames)
        arm_kfs_r = make_arm_talk_kfs(frames, 1)
        arm_kfs_l = make_arm_talk_kfs(frames, -1)
    else:
        breathing_kfs = make_breathing_kfs(frames, amp=1.5)
        body_kfs = None
        mouth_kfs = None
        arm_kfs_r = None
        arm_kfs_l = None

    # ── Layer 0: Arms (back) ──
    arm_height = 70
    arm_width = 16

    # Left arm
    left_arm_shapes = [
        rect_shape([arm_width, arm_height], [-32, 10], rounded=8),
        fill_shape(C_SKIN_F, "Left Arm Fill"),
    ]
    left_arm_grp = shape_group(left_arm_shapes, "Left Arm")
    left_arm_ks = {}
    if arm_kfs_l:
        # Fudge: rotation keyframe on the arm
        left_arm_ks["r"] = animated_val(arm_kfs_l)
    layers.append(animated_layer(
        [left_arm_grp], idx, "arm_left",
        ks_override=left_arm_ks if left_arm_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # Right arm
    right_arm_shapes = [
        rect_shape([arm_width, arm_height], [32, 10], rounded=8),
        fill_shape(C_SKIN_F, "Right Arm Fill"),
    ]
    right_arm_grp = shape_group(right_arm_shapes, "Right Arm")
    right_arm_ks = {}
    if arm_kfs_r:
        right_arm_ks["r"] = animated_val(arm_kfs_r)
    layers.append(animated_layer(
        [right_arm_grp], idx, "arm_right",
        ks_override=right_arm_ks if right_arm_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 1: Hair (back) ──
    hair_back_shapes = [
        # Main hair mass behind head
        ellipse_shape([96, 110], [0, -20], "Hair Back"),
        fill_shape(C_HAIR_F, "Hair Fill"),
    ]
    hair_back_grp = shape_group(hair_back_shapes, "Hair Back")
    hair_back_ks = {}
    if breathing_kfs:
        # Scale everything slightly
        pass  # Inherit layer breathing from common transform
    # Actually, for breathing to work, the whole character needs one parent group.
    # Let me instead make a common approach: apply breathing to each layer's position/scale

    hair_back_layer_ks = {}
    if breathing_kfs:
        hair_back_layer_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [hair_back_grp], idx, "hair_back",
        ks_override=hair_back_layer_ks if hair_back_layer_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 2: Body (blouse) ──
    # Body: rounded rect for torso
    torso_shapes = [
        rect_shape([80, 95], [0, 55], rounded=12, name="Torso"),
        fill_shape(C_BLOUSE, "Blouse Fill"),
        # Collar detail - small V shape
    ]
    torso_grp = shape_group(torso_shapes, "Body")

    body_layer_ks = {}
    if breathing_kfs:
        body_layer_ks["s"] = animated_val(breathing_kfs)
    if body_kfs:
        body_layer_ks["p"] = animated_val(body_kfs)
    layers.append(animated_layer(
        [torso_grp], idx, "body",
        ks_override=body_layer_ks if body_layer_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 3: Necklace / Collar detail ──
    collar_shapes = [
        # Small V-neck collar indicator
        rect_shape([20, 6], [0, 40], rounded=3, name="Collar"),
        fill_shape(C_LAPEL, "Collar Fill"),
    ]
    collar_grp = shape_group(collar_shapes, "Collar Detail")
    layers.append(animated_layer(
        [collar_grp], idx, "collar",
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 4: Head ──
    head_shapes = [
        ellipse_shape([84, 78], [0, -42], "Head"),
        fill_shape(C_SKIN_F, "Skin Fill"),
    ]
    head_grp = shape_group(head_shapes, "Head")
    head_ks = {}
    if breathing_kfs:
        head_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [head_grp], idx, "head",
        ks_override=head_ks if head_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 5: Eyes ──
    eye_group_shapes = []
    for side, ex in [(-1, -16), (1, 16)]:
        # Eye white
        eye_group_shapes.append(ellipse_shape([16, 18], [ex, -40], f"Eye {side}"))
        eye_group_shapes.append(fill_shape(C_EYE_W, f"Eye White {side}"))
        # Pupil
        eye_group_shapes.append(ellipse_shape([6, 8], [ex, -40], f"Pupil {side}"))
        eye_group_shapes.append(fill_shape(C_PUPIL, f"Pupil Fill {side}"))
        # Shine dot
        eye_group_shapes.append(ellipse_shape([3, 3], [ex + 3, -43], f"Shine {side}"))
        eye_group_shapes.append(fill_shape((1, 1, 1, 1), f"Shine Fill {side}"))

    # Blink animation on eye scale Y
    eye_kfs = make_blink_kfs(frames)
    eye_tr = animated_transform(scale_kfs=eye_kfs, anchor=[0, -40])

    eye_grp = shape_group(eye_group_shapes, "Eyes", transform=eye_tr)

    eyes_ks = {}
    if breathing_kfs:
        eyes_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [eye_grp], idx, "eyes",
        ks_override=eyes_ks if eyes_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 6: Cheeks (blush) ──
    cheek_shapes = []
    for side, cx in [(-1, -26), (1, 26)]:
        cheek_shapes.append(ellipse_shape([18, 12], [cx, -26], f"Cheek {side}"))
        cheek_shapes.append(fill_shape(C_BLUSH, f"Blush {side}"))
    cheek_grp = shape_group(cheek_shapes, "Cheeks")
    cheek_ks = {}
    if breathing_kfs:
        cheek_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [cheek_grp], idx, "cheeks",
        ks_override=cheek_ks if cheek_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 7: Mouth ──
    if is_talk and mouth_kfs:
        # Talking mouth: ellipse that scales Y
        mouth_shapes = [
            ellipse_shape([18, 10], [0, -18], "Mouth"),
            fill_shape(C_MOUTH, "Mouth Fill"),
        ]
        mouth_tr = animated_transform(scale_kfs=mouth_kfs, anchor=[0, -18])
        mouth_grp = shape_group(mouth_shapes, "Mouth", transform=mouth_tr)
    else:
        # Smile: small arc - use a thin ellipse
        mouth_shapes = [
            ellipse_shape([18, 4], [0, -18], "Smile"),
            fill_shape(C_MOUTH, "Mouth Fill"),
        ]
        mouth_grp = shape_group(mouth_shapes, "Mouth")

    mouth_ks = {}
    if breathing_kfs:
        mouth_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [mouth_grp], idx, "mouth",
        ks_override=mouth_ks if mouth_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 8: Hair (bangs / front) ──
    # Curved bangs using ellipses
    bangs_shapes = [
        # Left bang sweep
        ellipse_shape([40, 24], [-18, -62], "Bangs Left"),
        fill_shape(C_HAIR_F, "Hair Fill"),
        # Right bang sweep
        ellipse_shape([36, 20], [14, -60], "Bangs Right"),
        fill_shape(C_HAIR_F, "Hair Fill"),
        # Top hair volume
        ellipse_shape([68, 26], [0, -72], "Hair Top"),
        fill_shape(C_HAIR_F, "Hair Fill"),
    ]
    bangs_grp = shape_group(bangs_shapes, "Bangs")
    bangs_ks = {}
    if breathing_kfs:
        bangs_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [bangs_grp], idx, "bangs",
        ks_override=bangs_ks if bangs_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 9: Glasses ──
    glasses_shapes = []
    for side, gx in [(-1, -16), (1, 16)]:
        # Frame
        glasses_shapes.append(rect_shape([22, 22], [gx, -40], rounded=4, name=f"Glass {side}"))
        glasses_shapes.append(stroke_shape(C_GLASS, 2.5, name=f"Frame {side}"))
        # Bridge
    # Bridge between lenses
    glasses_shapes.append(rect_shape([8, 2], [0, -40], rounded=0, name="Bridge"))
    glasses_shapes.append(fill_shape(C_GLASS, "Bridge Fill"))

    glasses_grp = shape_group(glasses_shapes, "Glasses")
    glasses_ks = {}
    if breathing_kfs:
        glasses_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [glasses_grp], idx, "glasses",
        ks_override=glasses_ks if glasses_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 10: Pointer (in right hand, talk only) ──
    if is_talk:
        pointer_shapes = [
            rect_shape([4, 30], [40, -5], rounded=2, name="Pointer"),
            fill_shape((0.6, 0.3, 0.1, 1.0), "Pointer Fill"),
            rect_shape([8, 6], [40, -20], rounded=2, name="Pointer Tip"),
            fill_shape(C_GOLD, "Pointer Tip Fill"),
        ]
        pointer_grp = shape_group(pointer_shapes, "Pointer")
        layers.append(animated_layer(
            [pointer_grp], idx, "pointer",
            in_point=0, out_point=frames,
        ))
        idx += 1

    return layers


# ── Male Teacher ─────────────────────────────────────────────────

def build_male_character(frames, is_talk):
    """Build all shapes for male teacher."""
    layers = []
    idx = 0

    if is_talk:
        breathing_kfs = make_talk_breathing_kfs(frames, amp=2.5)
        body_kfs = make_body_talk_kfs(frames)
        mouth_kfs = make_mouth_talk_kfs(frames)
        arm_kfs_r = make_arm_talk_kfs(frames, 1)
        arm_kfs_l = make_arm_talk_kfs(frames, -1)
    else:
        breathing_kfs = make_breathing_kfs(frames, amp=1.5)
        body_kfs = None
        mouth_kfs = None
        arm_kfs_r = None
        arm_kfs_l = None

    # ── Layer 0: Arms (back) ──
    arm_width, arm_height = 18, 75

    left_arm_shapes = [
        rect_shape([arm_width, arm_height], [-34, 10], rounded=9),
        fill_shape(C_SKIN_M, "Left Arm Fill"),
    ]
    left_arm_grp = shape_group(left_arm_shapes, "Left Arm")
    left_arm_ks = {}
    if arm_kfs_l:
        left_arm_ks["r"] = animated_val(arm_kfs_l)
    layers.append(animated_layer(
        [left_arm_grp], idx, "arm_left",
        ks_override=left_arm_ks if left_arm_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    right_arm_shapes = [
        rect_shape([arm_width, arm_height], [34, 10], rounded=9),
        fill_shape(C_SKIN_M, "Right Arm Fill"),
    ]
    right_arm_grp = shape_group(right_arm_shapes, "Right Arm")
    right_arm_ks = {}
    if arm_kfs_r:
        right_arm_ks["r"] = animated_val(arm_kfs_r)
    layers.append(animated_layer(
        [right_arm_grp], idx, "arm_right",
        ks_override=right_arm_ks if right_arm_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 1: Hair (back, minimal) ──
    hair_back_shapes = [
        ellipse_shape([88, 60], [0, -38], "Hair Back"),
        fill_shape(C_HAIR_M, "Hair Fill"),
    ]
    hair_back_grp = shape_group(hair_back_shapes, "Hair Back")
    hair_back_ks = {}
    if breathing_kfs:
        hair_back_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [hair_back_grp], idx, "hair_back",
        ks_override=hair_back_ks if hair_back_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 2: Body (shirt + tie) ──
    # Shirt
    body_shapes = [
        rect_shape([84, 100], [0, 55], rounded=10, name="Torso"),
        fill_shape(C_SHIRT, "Shirt Fill"),
    ]
    body_grp = shape_group(body_shapes, "Body")

    body_ks = {}
    if breathing_kfs:
        body_ks["s"] = animated_val(breathing_kfs)
    if body_kfs:
        body_ks["p"] = animated_val(body_kfs)
    layers.append(animated_layer(
        [body_grp], idx, "body",
        ks_override=body_ks if body_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # Tie
    tie_shapes = [
        # Tie body (simple triangle-ish - use rect)
        rect_shape([14, 50], [0, 50], rounded=2, name="Tie Body"),
        fill_shape(C_TIE, "Tie Fill"),
        # Tie knot
        rect_shape([18, 10], [0, 32], rounded=3, name="Tie Knot"),
        fill_shape(C_TIE, "Tie Knot Fill"),
    ]
    tie_grp = shape_group(tie_shapes, "Tie")
    tie_ks = {}
    if breathing_kfs:
        tie_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [tie_grp], idx, "tie",
        ks_override=tie_ks if tie_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # Collar
    collar_shapes = [
        rect_shape([30, 8], [0, 32], rounded=3, name="Collar"),
        fill_shape(C_COLLAR, "Collar Fill"),
    ]
    collar_grp = shape_group(collar_shapes, "Collar")
    layers.append(animated_layer(
        [collar_grp], idx, "collar",
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 3: Head ──
    head_shapes = [
        ellipse_shape([86, 80], [0, -42], "Head"),
        fill_shape(C_SKIN_M, "Skin Fill"),
    ]
    head_grp = shape_group(head_shapes, "Head")
    head_ks = {}
    if breathing_kfs:
        head_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [head_grp], idx, "head",
        ks_override=head_ks if head_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 4: Eyes ──
    eye_shapes = []
    for side, ex in [(-1, -16), (1, 16)]:
        eye_shapes.append(ellipse_shape([16, 18], [ex, -40], f"Eye {side}"))
        eye_shapes.append(fill_shape(C_EYE_W, f"Eye White {side}"))
        eye_shapes.append(ellipse_shape([6, 8], [ex, -40], f"Pupil {side}"))
        eye_shapes.append(fill_shape(C_PUPIL, f"Pupil Fill {side}"))
        eye_shapes.append(ellipse_shape([3, 3], [ex + 3, -43], f"Shine {side}"))
        eye_shapes.append(fill_shape((1, 1, 1, 1), f"Shine Fill {side}"))

    eye_kfs = make_blink_kfs(frames)
    eye_tr = animated_transform(scale_kfs=eye_kfs, anchor=[0, -40])
    eye_grp = shape_group(eye_shapes, "Eyes", transform=eye_tr)

    eyes_ks = {}
    if breathing_kfs:
        eyes_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [eye_grp], idx, "eyes",
        ks_override=eyes_ks if eyes_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 5: Cheeks ──
    cheek_shapes = []
    for side, cx in [(-1, -26), (1, 26)]:
        cheek_shapes.append(ellipse_shape([18, 12], [cx, -26], f"Cheek {side}"))
        cheek_shapes.append(fill_shape(C_BLUSH, f"Blush {side}"))
    cheek_grp = shape_group(cheek_shapes, "Cheeks")
    cheek_ks = {}
    if breathing_kfs:
        cheek_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [cheek_grp], idx, "cheeks",
        ks_override=cheek_ks if cheek_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 6: Mouth ──
    if is_talk and mouth_kfs:
        mouth_shapes = [
            ellipse_shape([20, 10], [0, -18], "Mouth"),
            fill_shape(C_MOUTH, "Mouth Fill"),
        ]
        mouth_tr = animated_transform(scale_kfs=mouth_kfs, anchor=[0, -18])
        mouth_grp = shape_group(mouth_shapes, "Mouth", transform=mouth_tr)
    else:
        mouth_shapes = [
            ellipse_shape([20, 4], [0, -18], "Smile"),
            fill_shape(C_MOUTH, "Mouth Fill"),
        ]
        mouth_grp = shape_group(mouth_shapes, "Mouth")

    mouth_ks = {}
    if breathing_kfs:
        mouth_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [mouth_grp], idx, "mouth",
        ks_override=mouth_ks if mouth_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    # ── Layer 7: Hair (top) ──
    hair_top_shapes = [
        ellipse_shape([70, 28], [0, -72], "Hair Top"),
        fill_shape(C_HAIR_M, "Hair Fill"),
        # Side hair
        ellipse_shape([24, 30], [-28, -58], "Hair Side L"),
        fill_shape(C_HAIR_M, "Hair Fill"),
        ellipse_shape([24, 30], [28, -58], "Hair Side R"),
        fill_shape(C_HAIR_M, "Hair Fill"),
    ]
    hair_grp = shape_group(hair_top_shapes, "Hair")
    hair_ks = {}
    if breathing_kfs:
        hair_ks["s"] = animated_val(breathing_kfs)
    layers.append(animated_layer(
        [hair_grp], idx, "hair",
        ks_override=hair_ks if hair_ks else None,
        in_point=0, out_point=frames,
    ))
    idx += 1

    return layers


# ═══════════════════════════════════════════════════════════════════
#  GENERATE FILES
# ═══════════════════════════════════════════════════════════════════

def generate(gender, is_talk):
    """Generate one Lottie file."""
    name = f"{gender}_{'talk' if is_talk else 'idle'}"
    frames = 90 if is_talk else 60  # 3s talk, 2s idle

    lottie = lottie_header(f"Teacher {name}", frames)

    if gender == "female":
        layers = build_female_character(frames, is_talk)
    else:
        layers = build_male_character(frames, is_talk)

    lottie["layers"] = layers
    return lottie


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    for gender in ("female", "male"):
        for is_talk in (False, True):
            name = f"teacher_{gender}_{'talk' if is_talk else 'idle'}"
            lottie = generate(gender, is_talk)
            path = os.path.join(OUT_DIR, f"{name}.json")
            with open(path, "w") as f:
                json.dump(lottie, f, indent=2)
            file_size = os.path.getsize(path)
            print(f"✓ {name}.json  ({file_size / 1024:.1f} KB)")

    print(f"\nAll files in: {OUT_DIR}")


if __name__ == "__main__":
    main()
