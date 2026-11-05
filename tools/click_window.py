"""Click (or scroll) inside the WorldBox window at client-area coordinates.

Usage: python -I tools/click_window.py X Y [X Y ...]
       python -I tools/click_window.py --wheel X Y NOTCHES   (positive zooms in)

Brings the window to the front (Unity only reads real input events), then
left-clicks each point in turn. Coordinates are physical client pixels, the
same space as tools/capture_window.py screenshots.
"""
import ctypes
import sys
import time
from ctypes import wintypes

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from capture_window import find_window, user32  # noqa: E402

MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004

window = find_window()
if window is None:
    sys.exit("WorldBox window not found")
user32.ShowWindow(window, 9)  # SW_RESTORE
user32.SetForegroundWindow(window)
time.sleep(0.4)

if sys.argv[1] == "--drag":
    # Middle-button drag pans the map; the game zooms around the screen
    # centre, so drag a target to the centre before zooming in.
    x0, y0, x1, y1 = map(int, sys.argv[2:6])
    start, end = wintypes.POINT(x0, y0), wintypes.POINT(x1, y1)
    user32.ClientToScreen(window, ctypes.byref(start))
    user32.ClientToScreen(window, ctypes.byref(end))
    user32.SetCursorPos(start.x, start.y)
    time.sleep(0.1)
    user32.mouse_event(0x0020, 0, 0, 0, 0)  # MOUSEEVENTF_MIDDLEDOWN
    for step in range(1, 21):
        user32.SetCursorPos(start.x + (end.x - start.x) * step // 20, start.y + (end.y - start.y) * step // 20)
        time.sleep(0.02)
    user32.mouse_event(0x0040, 0, 0, 0, 0)  # MOUSEEVENTF_MIDDLEUP
    print("dragged", x0, y0, "->", x1, y1)
    sys.exit(0)

if sys.argv[1] == "--wheel":
    x, y, notches = map(int, sys.argv[2:5])
    point = wintypes.POINT(x, y)
    user32.ClientToScreen(window, ctypes.byref(point))
    user32.SetCursorPos(point.x, point.y)
    for _ in range(abs(notches)):
        user32.mouse_event(0x0800, 0, 0, 120 if notches > 0 else -120, 0)  # MOUSEEVENTF_WHEEL
        time.sleep(0.12)
    print("scrolled", notches, "at", x, y)
    sys.exit(0)

coords = list(map(int, sys.argv[1:]))
for x, y in zip(coords[0::2], coords[1::2]):
    point = wintypes.POINT(x, y)
    user32.ClientToScreen(window, ctypes.byref(point))
    user32.SetCursorPos(point.x, point.y)
    time.sleep(0.15)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.6)
    print("clicked", x, y)
