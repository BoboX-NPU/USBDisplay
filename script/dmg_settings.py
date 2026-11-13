"""Finder layout for the USB Display drag-to-install disk image."""

from pathlib import Path

app = Path(defines["app"])
artwork = Path(defines["artwork"])

format = "UDZO"
filesystem = "HFS+"
files = [str(app)]
symlinks = {"Applications": "/Applications"}
icon = str(app / "Contents" / "Resources" / "AppIcon.icns")
background = str(artwork / "background.png")
window_rect = ((180, 140), (640, 452))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 13
label_pos = "bottom"
arrange_by = None
icon_locations = {"USB Display.app": (180, 158), "Applications": (460, 158)}
# FinderInfo changes on an already signed app fail strict code-signature checks.
# Keep the bundle untouched; Finder owns extension visibility for the user.
hide_extensions = []
