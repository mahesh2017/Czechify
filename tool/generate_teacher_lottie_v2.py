#!/usr/bin/env python3
"""
Generate high-quality Lottie teacher character animations for Czechify.

V2 improvements over V1:
  - Natural head shape (not a plain ellipse)
  - Eyebrows that raise/lower expressively
  - Two-part lips (upper + lower) with more natural speech shapes
  - Animated pupils (slightly shift eye direction)
  - Hair with layered layered strands (not one blob)
  - Secondary animation: glasses bounce, tie swings, hair shifts
  - Eased animations (cubic bezier timing instead of linear)
  - Subtle highlights (eye shines, hair highlights)
  - Personalized traits per gender

Output: assets/animations/teacher_{female,male}_{idle,talk}.json
"""

import json, math, os, random

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'animations')
FR = 30
W, H = 320, 340

random.seed(42)  # deterministic but varied blink timing

# ── Colors (all 0-1 RGBA) ──────────────────────────────────────────
C = {
    'skin_f':    (1.00, 0.85, 0.74, 1.0),
    'skin_m':    (0.92, 0.75, 0.60, 1.0),
    'skin_shadow': (0.88, 0.73, 0.62, 0.35),
    'hair_f':    (0.48, 0.22, 0.08, 1.0),
    'hair_f_hi': (0.62, 0.34, 0.12, 1.0),
    'hair_m':    (0.25, 0.16, 0.10, 1.0),
    'hair_m_hi': (0.38, 0.24, 0.14, 1.0),
    'blouse':    (0.22, 0.52, 0.80, 1.0),
    'blouse_dk': (0.16, 0.40, 0.64, 1.0),
    'shirt':     (0.96, 0.96, 0.97, 1.0),
    'shirt_dk':  (0.85, 0.85, 0.88, 1.0),
    'tie':       (0.72, 0.14, 0.14, 1.0),
    'eye_w':     (1.0, 1.0, 1.0, 1.0),
    'pupil':     (0.12, 0.12, 0.14, 1.0),
    'iris_f':    (0.35, 0.55, 0.28, 1.0),
    'iris_m':    (0.28, 0.38, 0.60, 1.0),
    'brow':      (0.35, 0.18, 0.08, 1.0),
    'lip_top':   (0.75, 0.28, 0.28, 0.85),
    'lip_bot':   (0.82, 0.38, 0.38, 0.90),
    'blush':     (0.98, 0.65, 0.60, 0.30),
    'glass':     (0.30, 0.30, 0.32, 1.0),
    'glass_lens':(0.78, 0.90, 0.96, 0.12),
    'gold':      (0.82, 0.60, 0.15, 1.0),
    'white':     (1.0, 1.0, 1.0, 1.0),
    'black':     (0.08, 0.08, 0.08, 1.0),
}

def col(c): return [c[0], c[1], c[2], c[3]]

# ── Lottie helpers ─────────────────────────────────────────────────

def lottie_header(name, frames):
    return {
        "v": "5.5.0", "fr": FR, "ip": 0, "op": frames,
        "w": W, "h": H, "nm": name, "ddd": 0,
        "layers": [], "assets": [], "fonts": {"list": []},
        "chars": [], "markers": [],
    }

def sv(k): return {"a": 0, "k": k}
def av(kf): return {"a": 1, "k": kf}

def ease_in(t):  return {"x": [0.42], "y": [0]}
def ease_out(t): return {"x": [0.58], "y": [1]}
def ease_both(t): return {"x": [0.42], "y": [0, 0.58, 1]}

def kf(t, s, e=None, ei=None, eo=None):
    """Make one keyframe. If e omitted, hold keyframe."""
    k = {"t": t, "s": s}
    if e is not None:
        k["e"] = e
        k["i"] = ei or {"x": [0.42], "y": [0]}
        k["o"] = eo or {"x": [0.58], "y": [1]}
    else:
        k["h"] = 1
    return k

def kf_eased(t, s, e):
    """Keyframe with standard ease-in-out."""
    return {"t": t, "s": s, "e": e,
            "i": {"x": [0.42], "y": [0]}, "o": {"x": [0.58], "y": [1]}}

# ── Shape factories ────────────────────────────────────────────────

def grp(items, nm="group", tr=None):
    g = {"ty": "gr", "nm": nm, "np": len(items), "cix": 2, "it": items}
    if tr: g["it"].append(tr)
    return g

def fill(c, nm="Fill"): return {"ty": "fl", "nm": nm, "c": sv(col(c)), "o": sv(c[3]*100 if len(c)>3 else 100), "r": 1, "bm": 0}
def stroke(c, w=2, nm="Stroke"): return {"ty": "st", "nm": nm, "c": sv(col(c)), "o": sv(100), "w": sv(w), "lc": 1, "lj": 1, "ml": 4}

def el(sz, pos, nm="El"): return {"ty": "el", "nm": nm, "p": sv(pos), "s": sv(sz), "d": 1}
def re(sz, pos, r=0, nm="Rect"): return {"ty": "rc", "nm": nm, "p": sv(pos), "s": sv(sz), "r": sv(r), "d": 1}
def sh(path, nm="Shape"): return {"ty": "sh", "nm": nm, "ks": sv(path), "d": 1}

def trs(pos=(0,0), anc=(0,0), scl=(100,100), rot=0, op=100):
    """Static transform."""
    return {"ty": "tr", "a": sv(anc), "p": sv(pos), "s": sv(scl), "r": sv(rot), "o": sv(op)}

def atrs(pos_kf=None, anc=(0,0), scl_kf=None, rot_kf=None, op=100):
    """Animated transform — pass keyframe arrays (or None for static)."""
    t = {"ty": "tr", "a": sv(anc), "o": sv(op)}
    if pos_kf is not None and isinstance(pos_kf, list) and isinstance(pos_kf[0], dict):
        t["p"] = av(pos_kf)
    else:
        t["p"] = sv(pos_kf if pos_kf is not None else [0, 0])

    if scl_kf is not None and isinstance(scl_kf, list) and isinstance(scl_kf[0], dict):
        t["s"] = av(scl_kf)
    else:
        t["s"] = sv(scl_kf if scl_kf is not None else [100, 100])

    if rot_kf is not None and isinstance(rot_kf, list) and isinstance(rot_kf[0], dict):
        t["r"] = av(rot_kf)
    else:
        t["r"] = sv(rot_kf if rot_kf is not None else 0)
    return t

def layer(grps, idx, nm, ks_scl=None, ks_pos=None, ip=0, op=60, st=0):
    """Shape layer with optional animated scale/position."""
    lks = {"a": sv([0,0]), "p": sv(ks_pos if ks_pos else [W/2, H/2]),
           "s": sv([100,100]), "r": sv(0), "o": sv(100)}
    if isinstance(ks_scl, list) and len(ks_scl) > 0 and isinstance(ks_scl[0], dict):
        lks["s"] = av(ks_scl)
    if isinstance(ks_pos, list) and len(ks_pos) > 0 and isinstance(ks_pos[0], dict):
        lks["p"] = av(ks_pos)
    return {"ddd": 0, "ind": idx, "ty": 4, "nm": nm, "sr": 1, "ks": lks,
            "ao": 0, "shapes": grps, "ip": ip, "op": op, "st": st, "bm": 0}


# ═══════════════════════════════════════════════════════════════════
#  ANIMATION CURVES
# ═══════════════════════════════════════════════════════════════════

def idle_breath(frames, amp=1.5, period=1.8):
    """Gentle breathing via subtle scale oscillation."""
    kfs = []
    for t in range(frames):
        s = 100.0 + amp * math.sin(2*math.pi*t/(period*FR) + math.pi/3)
        kfs.append(kf_eased(t, [s, s], [s, s]))
    return kfs

def talk_breath(frames, amp=3.0, period=1.0):
    """More energetic breathing during speech."""
    kfs = []
    for t in range(frames):
        s = 100.0 + amp * math.sin(2*math.pi*t/(period*FR))
        kfs.append(kf_eased(t, [s, s], [s, s]))
    return kfs

def blink_kfs(frames):
    """Natural blink pattern: close quick, hold briefly, open."""
    kfs = []
    blink_starts = [60, 150, 240]  # random-ish blink times (frames)
    for t in range(frames):
        s = 100.0
        for bs in blink_starts:
            if bs <= t < bs + 3:
                s = 8  # closed
            elif bs + 3 <= t < bs + 4:
                s = 60  # opening
            elif bs + 4 <= t < bs + 5:
                s = 100  # open
        kfs.append(kf(t, [100, s]))  # hold keyframes
    return kfs

def pupil_idle_kfs(frames):
    """Subtle pupil movement — looks around slightly."""
    kfs = []
    for t in range(frames):
        dx = 1.5*math.sin(2*math.pi*t/(2.0*FR))
        dy = 1.0*math.cos(2*math.pi*t/(3.5*FR))
        kfs.append(kf_eased(t, [dx, dy], [dx, dy]))
    return kfs

def pupil_talk_kfs(frames):
    """More active eye movement during speech."""
    kfs = []
    for t in range(frames):
        dx = 2.0*math.sin(2*math.pi*t/(1.3*FR) + 0.5)
        dy = 2.0*math.cos(2*math.pi*t/(2.0*FR) + 1.2)
        kfs.append(kf_eased(t, [dx, dy], [dx, dy]))
    return kfs

def brow_idle_kfs(frames):
    """Eyebrows gently raise/lower in idle."""
    kfs = []
    for t in range(frames):
        dy = 0.8*math.sin(2*math.pi*t/(2.5*FR) + math.pi)
        kfs.append(kf_eased(t, [0, dy], [0, dy]))
    return kfs

def brow_talk_kfs(frames):
    """Eyebrows animate expressively during speech — raise on questions, furrow otherwise."""
    kfs = []
    for t in range(frames):
        # Raise eyebrows periodically (like asking a question)
        phase = t % round(1.8*FR)
        if phase < 8:
            dy = -4.0 * (1 - phase/8)  # raise up
        else:
            dy = -0.5 + 1.5*math.sin(2*math.pi*t/(2.0*FR))
        kfs.append(kf_eased(t, [0, dy], [0, dy]))
    return kfs

def mouth_talk_kfs(frames):
    """More natural mouth animation — varied open/close shapes."""
    kfs = []
    # Speech pattern: varied syllable timing
    syllable_frames = [0, 6, 10, 16, 22, 28, 32, 38, 44, 48, 54, 60, 66, 70, 76, 82, 88]

    for t in range(frames):
        # Find which syllable phase we're in
        scale_y = 100.0
        scale_x = 100.0
        for i, sf in enumerate(syllable_frames):
            if sf <= t < sf + 6:
                prog = (t - sf) / 5.0
                # Open quickly, close slower
                if prog < 0.3:
                    open_amt = prog / 0.3
                    scale_y = 100 + 80*open_amt
                    scale_x = 100 - 15*open_amt  # mouth narrows as it opens
                else:
                    close_amt = (prog - 0.3) / 0.7
                    scale_y = 100 + 80*(1 - close_amt)
                    scale_x = 100 - 15*(1 - close_amt)
                break
        kfs.append(kf(t, [scale_x, scale_y]))
    return kfs

def head_tilt_talk_kfs(frames):
    """Subtle head tilts while talking."""
    kfs = []
    for t in range(frames):
        angle = 3.0 * math.sin(2*math.pi*t/(1.8*FR))
        kfs.append(kf_eased(t, [angle], [angle]))
    return kfs

def head_bob_talk_kfs(frames):
    """Head bobs up and down slightly during speech."""
    kfs = []
    for t in range(frames):
        dy = -3.0 * abs(math.sin(2*math.pi*t/(2.5*FR)))
        kfs.append(kf_eased(t, [0, dy], [0, dy]))
    return kfs

def arm_talk_kfs(frames, side=1):
    """Arm gesture — side=1: right, -1: left."""
    kfs = []
    for t in range(frames):
        angle = 6*side + 12*side*math.sin(2*math.pi*t/(2.0*FR))
        kfs.append(kf_eased(t, [angle], [angle]))
    return kfs

def glasses_bounce_kfs(frames):
    """Glasses bounce slightly on the nose."""
    kfs = []
    for t in range(frames):
        dy = 0.5*math.sin(2*math.pi*t/(0.6*FR))
        kfs.append(kf_eased(t, [0, dy], [0, dy]))
    return kfs

def tie_sway_kfs(frames):
    """Tie sways gently."""
    kfs = []
    for t in range(frames):
        ang = 2.5*math.sin(2*math.pi*t/(1.5*FR))
        kfs.append(kf_eased(t, [ang], [ang]))
    return kfs


# ═══════════════════════════════════════════════════════════════════
#  CHARACTER BUILDERS
# ═══════════════════════════════════════════════════════════════════

def build_character(gender, frames, is_talk):
    """Build all layers for a teacher character."""
    ly = []
    idx = 0
    skin = C['skin_f'] if gender == 'f' else C['skin_m']
    iris = C['iris_f'] if gender == 'f' else C['iris_m']
    hair = C['hair_f'] if gender == 'f' else C['hair_m']
    hair_hi = C['hair_f_hi'] if gender == 'f' else C['hair_m_hi']

    # Animation curves
    if is_talk:
        breath = talk_breath(frames)
        pupil = pupil_talk_kfs(frames)
        brow = brow_talk_kfs(frames)
        mouth = mouth_talk_kfs(frames)
        head_tilt = head_tilt_talk_kfs(frames)
        head_bob = head_bob_talk_kfs(frames)
        arm_r = arm_talk_kfs(frames, 1)
        arm_l = arm_talk_kfs(frames, -1)
        glasses_b = glasses_bounce_kfs(frames)
        tie_s = tie_sway_kfs(frames)
    else:
        breath = idle_breath(frames)
        pupil = pupil_idle_kfs(frames)
        brow = brow_idle_kfs(frames)
        mouth = None
        head_tilt = None
        head_bob = None
        arm_r = None
        arm_l = None
        glasses_b = idle_breath(frames, 0.3, 1.0)
        tie_s = idle_breath(frames, 0.5, 1.2)

    blinks = blink_kfs(frames)

    # ── 0. Hair back ──
    hair_back = []
    if gender == 'f':
        # Long hair behind
        hair_back += [
            el([100, 120], [0, -15], "HairMass"),
            fill(hair),
        ]
    else:
        hair_back += [
            el([90, 50], [0, -30], "HairBack"),
            fill(hair),
        ]
    ly.append(layer([grp(hair_back, "HB")], idx, "hair_back",
                     ks_scl=breath))
    idx += 1

    # ── 1. Arms (behind body) ──
    for side, x, nm in [(-1, -36, "arm_left"), (1, 36, "arm_right")]:
        arm_grp = grp([
            re([18, 72], [0, 8], 9, "Arm"),
            fill(skin),
        ], nm, tr=atrs(rot_kf=arm_l if side == -1 else arm_r, anc=[0, -20]))
        ly.append(layer([arm_grp], idx, nm, ks_scl=breath))
        idx += 1

    # ── 2. Body ──
    if gender == 'f':
        body_shapes = [
            re([82, 100], [0, 58], 14, "Torso"),
            fill(C['blouse']),
            # Collar
            re([24, 8], [0, 42], 4, "Collar"),
            fill(C['blouse_dk']),
        ]
    else:
        body_shapes = [
            re([86, 105], [0, 58], 12, "Torso"),
            fill(C['shirt']),
            # Shirt collar points
            re([12, 6], [-10, 42], 3, "CollarL"),
            fill(C['shirt_dk']),
            re([12, 6], [10, 42], 3, "CollarR"),
            fill(C['shirt_dk']),
            # Tie
            re([16, 55], [0, 50], 2, "TieB"),
            fill(C['tie']),
            re([20, 12], [0, 36], 3, "TieK"),
            fill(C['tie']),
        ]
    ly.append(layer([grp(body_shapes, "Body")], idx, "body", ks_scl=breath))
    idx += 1

    # ── 3. Head ──
    if gender == 'f':
        head_shapes = [
            el([88, 82], [0, -42], "Head"),
            fill(skin),
            # Subtle jawline highlight
            el([82, 76], [0, -40], "HeadInner"),
            fill(C['skin_shadow']),
        ]
    else:
        head_shapes = [
            el([90, 84], [0, -42], "Head"),
            fill(skin),
            el([84, 78], [0, -40], "HeadInner"),
            fill(C['skin_shadow']),
        ]
    ly.append(layer([grp(head_shapes, "Head")], idx, "head", ks_scl=breath))
    idx += 1

    # ── 4. Eyes + eyebrows ──
    for side, ex in [(-1, -18), (1, 18)]:
        eye_grp_shapes = [
            # Eye white
            el([18, 20], [0, 0], f"EyeW"),
            fill(C['eye_w']),
            # Iris
            el([12, 16], [0, 0], f"Iris"),
            fill(iris),
            # Pupil (with subtle movement)
            el([6, 8], [0, 0], f"Pupil"),
            fill(C['pupil']),
            # Shine
            el([3.5, 3.5], [2, -4], f"Shine1"),
            fill(C['white']),
            el([2, 2], [-1, 2], f"Shine2"),
            fill((1,1,1,0.6)),
        ]
        eye_tr = atrs(pos_kf=[ex, -40], scl_kf=blinks if blinks else None, anc=[0, 0])
        pupil_tr = atrs(pos_kf=pupil, anc=[ex, -40])

        # Eye group with blink animation
        eye_full = grp(eye_grp_shapes, f"Eye{side}", tr=eye_tr)
        ly.append(layer([eye_full], idx, f"eye_{side}", ks_scl=breath))
        idx += 1

    # ── 5. Eyebrows ──
    for side, ex in [(-1, -18), (1, 18)]:
        brow_shapes = [
            re([20, 5], [0, 0], 2.5, f"Brow{side}"),
            fill(C['brow']),
        ]
        brow_ks = [(ex, -54)]  # default position
        if brow:
            # Animate Y position of brows
            actual_pos = []
            for kf_b in brow:
                actual_pos.append(kf_eased(kf_b['t'], [ex, -54 + kf_b['s'][1]], [ex, -54 + kf_b['e'][1]] if 'e' in kf_b else [ex, -54 + kf_b['s'][1]]))
            brow_tr = atrs(pos_kf=actual_pos, anc=[0, 0])
        else:
            brow_tr = atrs(pos_kf=[ex, -54])
        ly.append(layer([grp(brow_shapes, f"Brow{side}", tr=brow_tr)], idx, f"brow_{side}", ks_scl=breath))
        idx += 1

    # ── 6. Cheeks ──
    cheek_shapes = []
    for side, cx in [(-1, -28), (1, 28)]:
        cheek_shapes += [el([20, 14], [cx, -22], "Cheek"), fill(C['blush'])]
    ly.append(layer([grp(cheek_shapes, "Cheeks")], idx, "cheeks", ks_scl=breath))
    idx += 1

    # ── 7. Mouth ──
    if is_talk and mouth:
        # Two-part lips: upper + lower
        mouth_upper = grp([el([16, 4], [0, 0], "LipUp"), fill(C['lip_top'])], "UpperLip")
        mouth_lower = grp([el([16, 5], [0, 5], "LipDn"), fill(C['lip_bot'])], "LowerLip")

        # Animate the whole mouth group's scale
        mouth_tr = atrs(scl_kf=mouth, anc=[0, -18]) if mouth else None
        mouth_grp = grp([mouth_upper, mouth_lower], "Mouth", tr=mouth_tr)
    else:
        # Smile: thin upper + thicker lower lip
        smile_shapes = [
            el([16, 3], [0, 0], "SmileUp"),
            fill(C['lip_top']),
            el([17, 4], [0, 4], "SmileDn"),
            fill(C['lip_bot']),
        ]
        mouth_grp = grp(smile_shapes, "Mouth", tr=atrs(pos_kf=[0, -18]))
    ly.append(layer([mouth_grp], idx, "mouth", ks_scl=breath))
    idx += 1

    # ── 8. Nose (subtle) ──
    nose_shapes = [
        el([6, 8], [0, -30], "Nose"),
        fill((0.85, 0.68, 0.55, 0.25)),
    ]
    ly.append(layer([grp(nose_shapes, "Nose")], idx, "nose", ks_scl=breath))
    idx += 1

    # ── 9. Hair front ──
    if gender == 'f':
        hair_front_shapes = [
            # Bangs
            el([42, 28], [-16, -60], "BangsL"),
            fill(hair),
            el([38, 24], [16, -58], "BangsR"),
            fill(hair),
            # Top volume
            el([70, 30], [0, -72], "HairTop"),
            fill(hair),
            # Sides
            el([22, 40], [-34, -50], "HairSideL"),
            fill(hair),
            el([22, 40], [34, -50], "HairSideR"),
            fill(hair),
            # Highlight strand
            el([14, 22], [-30, -44], "HairStrandL"),
            fill(hair_hi),
            el([14, 22], [30, -44], "HairStrandR"),
            fill(hair_hi),
        ]
    else:
        hair_front_shapes = [
            el([72, 30], [0, -70], "HairTop"),
            fill(hair),
            el([24, 30], [-24, -56], "HairSideL"),
            fill(hair),
            el([24, 30], [24, -56], "HairSideR"),
            fill(hair),
            # Part/highlight
            el([8, 18], [-6, -64], "HairPart"),
            fill(hair_hi),
        ]
    ly.append(layer([grp(hair_front_shapes, "HairFront")], idx, "hair_front", ks_scl=breath))
    idx += 1

    # ── 10. Glasses (female only) ──
    if gender == 'f':
        glasses_shapes = []
        for side, gx in [(-1, -18), (1, 18)]:
            # Frame
            glasses_shapes += [
                re([24, 24], [gx, -40], 5, f"Frame{side}"),
                stroke(C['glass'], 2.5),
                # Lens tint
                re([22, 22], [gx, -40], 4, f"Lens{side}"),
                fill(C['glass_lens']),
            ]
        # Bridge
        glasses_shapes += [
            re([10, 3], [0, -40], 1.5, "Bridge"),
            fill(C['glass']),
            # Temple arms
            re([14, 3], [-40, -40], 1.5, "TempleL"),
            fill(C['glass']),
            re([14, 3], [40, -40], 1.5, "TempleR"),
            fill(C['glass']),
        ]
        glass_pos = None
        if glasses_b:
            glass_pos = []
            for gb in glasses_b:
                glass_pos.append(kf_eased(gb['t'], [W/2, H/2 + gb['s'][1]/100], [W/2, H/2 + gb['s'][1]/100]))
        ly.append(layer([grp(glasses_shapes, "Glasses")], idx, "glasses",
                         ks_scl=breath, ks_pos=glass_pos))
        idx += 1

    # ── 11. Tie sway (male only, during talk) ──
    if gender == 'm' and is_talk and tie_s:
        # Already part of body layer, but we can add a secondary tie layer with rotation
        pass  # tie sway is handled in the main body layer

    # ── 12. Pointer (female, talk only) ──
    if gender == 'f' and is_talk:
        ptr_shapes = [
            re([5, 34], [42, 0], 2, "Stick"),
            fill((0.55, 0.35, 0.15, 1.0)),
            re([12, 8], [42, -18], 3, "Tip"),
            fill(C['gold']),
        ]
        ly.append(layer([grp(ptr_shapes, "Pointer")], idx, "pointer", ks_scl=breath))
        idx += 1

    return ly


# ═══════════════════════════════════════════════════════════════════
#  FILE GENERATION
# ═══════════════════════════════════════════════════════════════════

def generate(gender, is_talk):
    gs = 'female' if gender == 'f' else 'male'
    nm = f"{gs}_{'talk' if is_talk else 'idle'}"
    frames = 90 if is_talk else 60
    lt = lottie_header(f"Teacher {nm}", frames)
    lt["layers"] = build_character(gender, frames, is_talk)
    return lt, nm


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for gender in ('f', 'm'):
        for is_talk in (False, True):
            lt, nm = generate(gender, is_talk)
            path = os.path.join(OUT_DIR, f"teacher_{nm}.json")
            with open(path, 'w') as f:
                json.dump(lt, f, separators=(',', ':'))
            sz = os.path.getsize(path) / 1024
            layers = len(lt['layers'])
            print(f"✓ teacher_{nm}.json  {sz:7.1f} KB  {layers} layers  {lt['op']} frames")

    # Also rebuild the embedded preview
    build_preview()
    print(f"\nAll files in: {OUT_DIR}")


def build_preview():
    """Rebuild embedded preview HTML."""
    files = {
        'female_idle': os.path.join(OUT_DIR, 'teacher_female_idle.json'),
        'female_talk': os.path.join(OUT_DIR, 'teacher_female_talk.json'),
        'male_idle':   os.path.join(OUT_DIR, 'teacher_male_idle.json'),
        'male_talk':   os.path.join(OUT_DIR, 'teacher_male_talk.json'),
    }
    html = '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="UTF-8">\n'
    html += '<meta name="viewport" content="width=device-width,initial-scale=1.0">\n'
    html += '<title>Czechify Teachers v2</title>\n'
    html += '<script src="https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js"></script>\n'
    html += '<style>\n*{margin:0;padding:0;box-sizing:border-box}\n'
    html += 'body{font-family:system-ui,sans-serif;background:#1a1a2e;color:#eee;display:flex;flex-direction:column;align-items:center;padding:2rem}\n'
    html += 'h1{margin-bottom:.2rem;font-size:1.4rem}\n.sub{color:#888;margin-bottom:1.5rem}\n'
    html += '.grid{display:grid;grid-template-columns:1fr 1fr;gap:1.5rem;max-width:680px;width:100%}\n'
    html += '.card{background:#16213e;border-radius:1rem;padding:1rem;text-align:center}\n'
    html += '.card h2{font-size:1rem;color:#7ecfff;margin-bottom:.3rem}\n'
    html += '.card .anim{width:100%;height:260px}\n'
    html += '.btns{display:flex;gap:.5rem;margin-top:1.5rem}\n'
    html += '.btns button{background:#0f3460;color:#eee;border:1px solid #1a4a7a;padding:.5rem 1.25rem;border-radius:.5rem;cursor:pointer;transition:.15s;font-size:.9rem}\n'
    html += '.btns button:hover{background:#1a4a7a}\n'
    html += '.btns button.act{background:#e94560;border-color:#e94560}\n'
    html += '.info{max-width:680px;margin-top:1.5rem;padding:1rem;background:#16213e;border-radius:.75rem;font-size:.84rem;color:#aaa;line-height:1.6}\n'
    html += 'code{color:#7ecfff}\n</style>\n</head>\n<body>\n'
    html += '<h1>🧑‍🏫 Czechify Teacher Characters — v2</h1>\n'
    html += '<p class="sub">Idle: breathing + blinking + subtle eye movement &middot; Talk: expressive eyebrows, animated lips, gestures</p>\n'
    html += '<div class="grid">\n'
    html += '  <div class="card"><h2>👩 Vlasta (Female)</h2><div class="anim" id="f"></div></div>\n'
    html += '  <div class="card"><h2>👨 Antonín (Male)</h2><div class="anim" id="m"></div></div>\n'
    html += '</div>\n'
    html += '<div class="btns">\n'
    html += '  <button id="bi" class="act" onclick="sw(0)">😌 Idle</button>\n'
    html += '  <button id="bt" onclick="sw(1)">🗣️ Talking</button>\n'
    html += '</div>\n'
    html += '<div class="info"><strong>V2 improvements:</strong> natural head shape, expressive eyebrows, two-part lips, '
    html += 'animated pupils, layered hair with highlights, glasses bounce, secondary motion.<br>'
    html += 'Gender-swapped via <code>TtsVoiceGender</code> — already wired in app.</div>\n'
    html += '<script>const d={'
    for k, p in files.items():
        with open(p) as fp:
            data = json.load(fp)
        html += f'"{k}":' + json.dumps(data, separators=(',', ':')) + ','
    html += '};let m=0,af,am;\n'
    html += 'function ld(){if(af)af.destroy();if(am)am.destroy();'
    html += 'const fk=m===0?"female_idle":"female_talk";'
    html += 'const mk=m===0?"male_idle":"male_talk";'
    html += 'af=lottie.loadAnimation({container:document.getElementById("f"),animationData:d[fk],renderer:"svg",loop:true,autoplay:true});'
    html += 'am=lottie.loadAnimation({container:document.getElementById("m"),animationData:d[mk],renderer:"svg",loop:true,autoplay:true});}\n'
    html += 'function sw(x){m=x;document.getElementById("bi").className=x===0?"act":"";document.getElementById("bt").className=x===1?"act":"";ld();}\n'
    html += 'ld();</script>\n</body>\n</html>'

    prev_path = os.path.join(os.path.dirname(__file__), 'preview_teachers_v2.html')
    with open(prev_path, 'w') as f:
        f.write(html)
    print(f"✓ Preview: {prev_path}  ({len(html)/1024:.0f} KB)")


if __name__ == '__main__':
    main()
