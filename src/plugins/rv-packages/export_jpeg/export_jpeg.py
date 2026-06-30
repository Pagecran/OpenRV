import os
import re

from rv import commands, extra_commands, qtutils, rvtypes


def _qt_modules():
    try:
        from PySide6 import QtCore, QtGui, QtWidgets
    except ImportError:
        from PySide2 import QtCore, QtGui, QtWidgets
    return QtCore, QtGui, QtWidgets


def _group_member_of_type(node, member_type):
    for member in commands.nodesInGroup(node):
        if commands.nodeType(member) == member_type:
            return member
    return None
def _sanitize_name(name):
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", name.strip())
    return safe.strip("._") or "image"


def _point_xy(point):
    try:
        return float(point[0]), float(point[1])
    except Exception:
        return float(point.x), float(point.y)


class ExportJPEGMode(rvtypes.MinorMode):
    def __init__(self):
        rvtypes.MinorMode.__init__(self)
        self.init(
            "export-jpeg-mode",
            None,
            None,
            [
                (
                    "File",
                    [
                        (
                            "Export",
                            [
                                ("_", None, None, None),
                                (
                                    "Export JPEG",
                                    [
                                        (
                                            "Current Image...",
                                            self.export_current_image,
                                            None,
                                            None,
                                        ),
                                        (
                                            "Current Sequence...",
                                            self.export_current_sequence,
                                            None,
                                            None,
                                        ),
                                        (
                                            "Visible Layout Images...",
                                            self.export_visible_layout_images,
                                            None,
                                            None,
                                        ),
                                        (
                                            "Layout Snapshot...",
                                            self.export_layout_snapshot,
                                            None,
                                            None,
                                        ),
                                    ],
                                ),
                            ],
                        )
                    ],
                )
            ],
        )

    def _window(self):
        return qtutils.sessionWindow()

    def _delay_ms(self, ms):
        import time
        time.sleep(ms / 1000.0)

    def _show_error(self, title, message):
        _, _, QtWidgets = _qt_modules()
        QtWidgets.QMessageBox.critical(self._window(), title, message)

    def _ensure_jpg_path(self, path):
        root, ext = os.path.splitext(path)
        if ext.lower() not in (".jpg", ".jpeg"):
            return root + ".jpg"
        return path

    def _choose_save_file(self, title, default_name):
        _, _, QtWidgets = _qt_modules()
        parent = self._window()
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            parent,
            title,
            default_name,
            "JPEG Files (*.jpg *.jpeg)",
        )
        if not path:
            return None
        return self._ensure_jpg_path(path)

    def _choose_folder(self, title):
        _, _, QtWidgets = _qt_modules()
        parent = self._window()
        return QtWidgets.QFileDialog.getExistingDirectory(parent, title, "") or None

    def _temp_path(self, suffix):
        import tempfile

        fd, path = tempfile.mkstemp(suffix=suffix)
        os.close(fd)
        return path

    def _render_widget_info(self):
        _, _, QtWidgets = _qt_modules()

        try:
            gl_view = qtutils.sessionGLView()
        except (NameError, AttributeError, TypeError):
            gl_view = None

        if gl_view is not None:
            try:
                global_top_left = gl_view.mapToGlobal(gl_view.rect().topLeft())
            except Exception:
                global_top_left = None
            return {
                "widget": gl_view,
                "class_name": type(gl_view).__name__,
                "object_name": gl_view.objectName(),
                "width": int(gl_view.width()),
                "height": int(gl_view.height()),
                "global_x": global_top_left.x() if global_top_left else 0,
                "global_y": global_top_left.y() if global_top_left else 0,
            }

        window = qtutils.sessionWindow()
        if window is None:
            return None

        ignore_types = (
            QtWidgets.QMenuBar,
            QtWidgets.QStatusBar,
            QtWidgets.QToolBar,
            QtWidgets.QScrollBar,
            QtWidgets.QAbstractSlider,
        )
        ignore_names = {
            "qt_scrollarea_hcontainer",
            "qt_scrollarea_vcontainer",
        }

        candidates = []
        for widget in window.findChildren(QtWidgets.QWidget):
            try:
                if not widget.isVisible():
                    continue
                if widget in (window,):
                    continue
                if isinstance(widget, ignore_types):
                    continue
                if widget.objectName() in ignore_names:
                    continue
                width = int(widget.width())
                height = int(widget.height())
                if width <= 0 or height <= 0:
                    continue
                area = width * height
                global_top_left = widget.mapToGlobal(widget.rect().topLeft())
                candidates.append(
                    {
                        "area": area,
                        "widget": widget,
                        "width": width,
                        "height": height,
                        "class_name": type(widget).__name__,
                        "object_name": widget.objectName(),
                        "global_x": global_top_left.x(),
                        "global_y": global_top_left.y(),
                    }
                )
            except Exception:
                continue

        candidates.sort(key=lambda item: item["area"], reverse=True)

        preferred = None
        large_candidates = [
            item
            for item in candidates
            if item["width"] >= int(window.width() * 0.5)
            and item["height"] >= int(window.height() * 0.5)
            and item["global_x"] >= window.mapToGlobal(window.rect().topLeft()).x()
        ]

        for item in large_candidates:
            text = f"{item['class_name']} {item['object_name']}".lower()
            if "session_manager" in text or "inputslist" in text:
                continue
            if item["object_name"] == "no session":
                preferred = item
                break

        if preferred is None and large_candidates:
            preferred = sorted(large_candidates, key=lambda item: item["area"], reverse=True)[0]

        if preferred is None and candidates:
            preferred = candidates[0]

        if preferred is None:
            return None
        return preferred

    def _widget_pixel_size(self, widget_info):
        if widget_info is None:
            return None

        widget = widget_info.get("widget")
        if widget is None:
            return float(widget_info["width"]), float(widget_info["height"])

        dpr = 1.0
        try:
            dpr = float(widget.devicePixelRatioF())
        except Exception:
            try:
                dpr = float(widget.devicePixelRatio())
            except Exception:
                dpr = 1.0

        width = float(widget_info["width"]) * dpr
        height = float(widget_info["height"]) * dpr
        return width, height

    def _capture_viewport_image(self):
        QtCore, QtGui, _ = _qt_modules()
        window = qtutils.sessionWindow()
        render_info = self._render_widget_info()
        gl_view = render_info["widget"] if render_info else None

        QtGui.QGuiApplication.processEvents()
        self._delay_ms(150)
        QtGui.QGuiApplication.processEvents()

        if render_info is not None:
            try:
                screen = None
                if window is not None and window.windowHandle() is not None:
                    screen = window.windowHandle().screen()
                if screen is None:
                    screen = QtGui.QGuiApplication.primaryScreen()

                pixmap = screen.grabWindow(
                    0,
                    int(render_info["global_x"]),
                    int(render_info["global_y"]),
                    int(render_info["width"]),
                    int(render_info["height"]),
                )
                image = pixmap.toImage()
                if image is not None and not image.isNull():
                    return image
            except Exception:
                pass

        # Try grabFramebuffer first (works in some RV 3.1 configs)
        if gl_view is not None:
            try:
                image = gl_view.grabFramebuffer()
                if image is not None and not image.isNull():
                    return image
            except Exception:
                pass

        # Fallback: capture the entire window using grabWindow
        if window is not None and gl_view is not None:
            try:
                global_top_left = gl_view.mapToGlobal(QtCore.QPoint(0, 0))
                screen = None

                if window.windowHandle() is not None:
                    screen = window.windowHandle().screen()

                if screen is None:
                    screen = QtGui.QGuiApplication.primaryScreen()

                pixmap = screen.grabWindow(
                    0,
                    global_top_left.x(),
                    global_top_left.y(),
                    gl_view.width(),
                    gl_view.height(),
                )
                image = pixmap.toImage()
                if image is not None and not image.isNull():
                    return image
            except Exception:
                pass

        # Last resort: exportCurrentFrame (returns viewport, not window)
        temp_image = self._temp_path(".png")
        commands.exportCurrentFrame(temp_image)
        image = QtGui.QImage(temp_image)
        if os.path.exists(temp_image):
            os.remove(temp_image)
        if image.isNull():
            self._show_error("Export JPEG", "Impossible de capturer le viewport courant.")
            return None
        return image

    def _save_viewport_jpeg(self, path):
        image = self._capture_viewport_image()
        if image is None:
            return False
        if not image.save(path, "JPEG", 95):
            self._show_error("Export JPEG", "Impossible d'ecrire l'image JPEG.")
            return False
        return True

    def _gl_view_size(self):
        render_info = self._render_widget_info()
        if render_info is None:
            return None

        size = self._widget_pixel_size(render_info)
        return size

    def _visible_render_items(self):
        items = []
        seen = set()
        for rendered in commands.renderedImages():
            source_node = rendered["node"]
            group = commands.nodeGroup(source_node)
            if not group or commands.nodeType(group) != "RVSourceGroup":
                continue
            if group in seen:
                continue
            seen.add(group)
            items.append((group, source_node, rendered))
        return items

    def _tile_rect_from_rendered(self, group, source_node, rendered, image_width, image_height):
        geom_name = rendered.get("name") or rendered.get("node")
        geom = commands.imageGeometry(geom_name, True)
        if (not geom or len(geom) < 4) and rendered.get("node"):
            geom = commands.imageGeometry(rendered["node"], True)
        if not geom or len(geom) < 4:
            geom = commands.imageGeometry(geom_name, False)
        if (not geom or len(geom) < 4) and rendered.get("node"):
            geom = commands.imageGeometry(rendered["node"], False)
        if not geom or len(geom) < 4:
            return None

        # Use GL view height as geom_space_height (like RV 2.0)
        geom_space_height = float(image_height)
        view_size = self._gl_view_size()
        if view_size:
            _, view_h = view_size
            if view_h > 0.0:
                geom_space_height = view_h

        xs = []
        ys = []
        for point in geom[:4]:
            x, y = _point_xy(point)
            xs.append(x)
            ys.append(y)

        left = max(0.0, min(xs))
        right = min(float(image_width), max(xs))
        top = max(0.0, min(ys))
        bottom = min(geom_space_height, max(ys))

        qt_left = int(round(left))
        qt_top = int(round(geom_space_height - bottom))
        qt_right = int(round(right))
        qt_bottom = int(round(geom_space_height - top))

        width = max(0, qt_right - qt_left)
        height = max(0, qt_bottom - qt_top)
        if width <= 0 or height <= 0:
            return None
        return qt_left, qt_top, width, height

    def _sorted_visible_items(self, viewport, items):
        ordered = []

        for group, source_node, rendered in items:
            rect = self._tile_rect_from_rendered(
                group, source_node, rendered, viewport.width(), viewport.height()
            )
            if rect is None:
                continue
            ordered.append((rect[1], rect[0], group, source_node, rendered, rect))

        ordered.sort(key=lambda item: (item[0], item[1]))
        return [(group, source_node, rendered, rect) for _, _, group, source_node, rendered, rect in ordered]

    def _current_frame(self):
        return int(round(commands.frame()))

    def _range_start_end(self):
        start = int(commands.inPoint())
        end = int(commands.outPoint())
        if end < start:
            start = int(commands.frameStart())
            end = int(commands.frameEnd())
        return start, end

    def export_current_image(self, event):
        path = self._choose_save_file("Export Current Image as JPEG", "current_image.jpg")
        if not path:
            return
        if self._save_viewport_jpeg(path):
            extra_commands.displayFeedback("JPEG exported", 2.0)

    def export_layout_snapshot(self, event):
        path = self._choose_save_file("Export Layout Snapshot as JPEG", "layout_snapshot.jpg")
        if not path:
            return
        if self._save_viewport_jpeg(path):
            extra_commands.displayFeedback("Layout snapshot exported", 2.0)

    def export_current_sequence(self, event):
        path = self._choose_save_file(
            "Export Current Sequence as JPEG", "current_sequence.jpg"
        )
        if not path:
            return

        start, end = self._range_start_end()
        root, _ = os.path.splitext(path)
        _, _, QtWidgets = _qt_modules()
        current_frame = int(round(commands.frame()))
        padding = max(4, len(str(end)))
        exported = 0

        try:
            for frame_no in range(start, end + 1):
                commands.setFrame(frame_no)
                QtWidgets.QApplication.processEvents()
                output_path = f"{root}.{frame_no:0{padding}d}.jpg"
                if self._save_viewport_jpeg(output_path):
                    exported += 1

                if exported % 5 == 0:
                    QtWidgets.QApplication.processEvents()
        finally:
            commands.setFrame(current_frame)

        if exported:
            extra_commands.displayFeedback(f"{exported} JPEG(s) exported", 2.0)

    def export_visible_layout_images(self, event):
        folder = self._choose_folder("Export Visible Layout Images as JPEG")
        if not folder:
            return

        viewport = self._capture_viewport_image()
        if viewport is None:
            return

        items = self._visible_render_items()
        if not items:
            self._show_error("Export JPEG", "No visible images found in the current layout.")
            return

        exported = 0

        for index, (group, source_node, rendered, rect) in enumerate(
            self._sorted_visible_items(viewport, items), start=1
        ):

            label = extra_commands.uiName(group) or group
            filename = f"{index:02d}_{_sanitize_name(label)}.jpg"
            output_path = os.path.join(folder, filename)
            tile = viewport.copy(*rect)
            if tile.save(output_path, "JPEG", 95):
                exported += 1

        if exported:
            extra_commands.displayFeedback(f"{exported} JPEG(s) exported", 2.0)


def createMode():
    return ExportJPEGMode()
