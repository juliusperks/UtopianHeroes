#!/usr/bin/env python3
"""Remove flat/near-flat icon backgrounds by flood-filling from corners.

This works better than pure "white pixel" removal when generated images use off-white
or tinted backdrops.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
from PIL import Image


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--dir", default="assets/art/units")
    p.add_argument("--threshold", type=int, default=26, help="RGB distance from corner color")
    p.add_argument("--alpha-feather", type=int, default=0, help="reserved")
    return p.parse_args()


def color_dist(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def main() -> int:
    args = parse_args()
    root = Path(args.dir)
    if not root.exists():
        print(f"missing dir: {root}")
        return 1

    changed = 0
    for p in sorted(root.glob("*.png")):
        img = Image.open(p).convert("RGBA")
        w, h = img.size
        px = img.load()

        # Sample 4 corner colors as background anchors.
        corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
        corner_rgb = [(c[0], c[1], c[2]) for c in corners]

        vis = [[False] * h for _ in range(w)]
        q = deque()

        # Seed BFS from corners.
        for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
            if not vis[x][y]:
                vis[x][y] = True
                q.append((x, y))

        removed = 0
        while q:
            x, y = q.popleft()
            r, g, b, a = px[x, y]
            if a == 0:
                pass
            else:
                rgb = (r, g, b)
                if min(color_dist(rgb, c) for c in corner_rgb) <= args.threshold:
                    px[x, y] = (r, g, b, 0)
                    removed += 1
                else:
                    # foreground edge reached
                    continue

            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and not vis[nx][ny]:
                    vis[nx][ny] = True
                    q.append((nx, ny))

        if removed > 0:
            img.save(p)
            changed += 1
            print(f"[fix] {p.name}: removed {removed} bg pixels")

    print(f"[done] changed {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
