#!/usr/bin/env python3
"""Turns an auto-traced Lottie flame (solid layers cut by animated masks)
into SVG silhouettes, one folder per layer.

    python3 scripts/lottie_mask_frames.py animation.json out_folder

Each layer becomes out_folder/<n>/flame-NN.svg (n = 0 for the bottom layer),
one SVG per frame, all cropped to one shared box so frames line up. The
masks' hold keyframes give each frame's shapes; masks switched off by their
opacity are skipped, and overlapping masks combine like the "difference"
mode (even-odd fill). Feed each folder to scripts/morph_flame_frames.swift
for smooth in-betweens and the app's PNG masks.
"""
import json
import os
import sys

PAD = 12


def at(prop, frame):
    """Value of a (hold-keyframed) property at a frame."""
    if not prop.get("a"):
        return prop["k"]
    value = prop["k"][0]["s"]
    for key in prop["k"]:
        if key["t"] <= frame and "s" in key:
            value = key["s"]
    return value


def mapper(layer):
    ks = layer["ks"]
    ax, ay = at(ks["a"], 0)[:2]
    px, py = at(ks["p"], 0)[:2]
    sx, sy = (v / 100 for v in at(ks["s"], 0)[:2])
    return lambda x, y: ((x - ax) * sx + px, (y - ay) * sy + py)


def path_data(shape, m):
    vs, ins, outs = shape["v"], shape["i"], shape["o"]
    if not vs:
        return "", []
    n = len(vs)
    pts = [m(*v) for v in vs]
    d = [f"M{pts[0][0]:.1f} {pts[0][1]:.1f}"]
    segments = n if shape.get("c", True) else n - 1
    for j in range(segments):
        a, b = vs[j], vs[(j + 1) % n]
        c1 = m(a[0] + outs[j][0], a[1] + outs[j][1])
        c2 = m(b[0] + ins[(j + 1) % n][0], b[1] + ins[(j + 1) % n][1])
        e = m(*b)
        d.append(f"C{c1[0]:.1f} {c1[1]:.1f} {c2[0]:.1f} {c2[1]:.1f} {e[0]:.1f} {e[1]:.1f}")
    d.append("Z")
    return " ".join(d), pts


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    anim = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    frames = range(int(anim["ip"]), int(anim["op"]))
    layers = list(reversed(anim["layers"]))  # bottom layer first
    shapes = []  # [layer][frame] -> (paths, points)
    for layer in layers:
        m = mapper(layer)
        per_frame = []
        for f in frames:
            paths, points = [], []
            for mask in layer.get("masksProperties", []):
                opacity = at(mask.get("o", {"k": 100}), f)
                if (opacity[0] if isinstance(opacity, list) else opacity) <= 0:
                    continue
                shape = at(mask["pt"], f)
                shape = shape[0] if isinstance(shape, list) else shape
                d, pts = path_data(shape, m)
                if d:
                    paths.append(d)
                    points += pts
            per_frame.append((paths, points))
        shapes.append(per_frame)

    xs = [x for layer in shapes for _, pts in layer for x, _ in pts]
    ys = [y for layer in shapes for _, pts in layer for _, y in pts]
    x0, y0 = min(xs) - PAD, min(ys) - PAD
    w, h = max(xs) - x0 + PAD, max(ys) - y0 + PAD
    for index, layer in enumerate(shapes):
        folder = os.path.join(out, str(index))
        os.makedirs(folder, exist_ok=True)
        for f, (paths, _) in enumerate(layer):
            svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.0f} {y0:.0f} {w:.0f} {h:.0f}" '
                   f'width="{w:.0f}" height="{h:.0f}"><path fill="#000" fill-rule="evenodd" '
                   f'd="{" ".join(paths)}"/></svg>')
            open(os.path.join(folder, f"flame-{f:02d}.svg"), "w").write(svg)
    print(f"{len(shapes)} layers x {len(frames)} frames at {anim['fr']} fps, box {w:.0f}x{h:.0f} "
          f"(aspect {w / h:.3f}) -> {out}")


if __name__ == "__main__":
    main()
