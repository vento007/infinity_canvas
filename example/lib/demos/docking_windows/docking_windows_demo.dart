import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinity_canvas/infinity_canvas.dart';

enum _DockTarget { left, right, top, bottom, center, fullscreen }

enum _DockSplitAxis { vertical, horizontal }

enum _DockWindowStyle { neon, imgui }

abstract class _DockNode {
  const _DockNode();
}

class _DockLeafNode extends _DockNode {
  final List<String> tabWindowIds;
  String? activeWindowId;

  _DockLeafNode({String? windowId})
    : tabWindowIds = windowId == null ? <String>[] : <String>[windowId],
      activeWindowId = windowId;

  bool get isEmpty => tabWindowIds.isEmpty;

  void setSingle(String id) {
    tabWindowIds
      ..clear()
      ..add(id);
    activeWindowId = id;
  }

  void addTab(String id, {bool activate = true}) {
    if (!tabWindowIds.contains(id)) {
      tabWindowIds.add(id);
    }
    if (activate || activeWindowId == null) {
      activeWindowId = id;
    }
  }

  bool removeTab(String id) {
    final removed = tabWindowIds.remove(id);
    if (!removed) return false;
    if (activeWindowId == id) {
      activeWindowId = tabWindowIds.isEmpty ? null : tabWindowIds.last;
    }
    return true;
  }
}

class _DockSplitNode extends _DockNode {
  final _DockSplitAxis axis;
  final double ratio;
  _DockNode first;
  _DockNode second;

  _DockSplitNode({
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
  });
}

class _DockLeafHit {
  final _DockLeafNode leaf;
  final Rect rect;

  const _DockLeafHit({required this.leaf, required this.rect});
}

class _DockHoverState {
  final _DockLeafNode? leaf;
  final Rect hostRect;
  final _DockTarget? target;

  const _DockHoverState({
    required this.leaf,
    required this.hostRect,
    required this.target,
  });
}

class DockingWindowsDemoPage extends StatefulWidget {
  const DockingWindowsDemoPage({super.key});

  @override
  State<DockingWindowsDemoPage> createState() => _DockingWindowsDemoPageState();
}

class _DockingWindowsDemoPageState extends State<DockingWindowsDemoPage> {
  late final CanvasController _controller;
  final GlobalKey _canvasKey = GlobalKey();
  final List<_DockWindowDef> _windows = <_DockWindowDef>[];
  final Set<String> _draggingWindowIds = <String>{};

  _DockNode? _dockRoot;
  _DockHoverState? _hoverDock;
  String? _activeTitleDragWindowId;
  Offset _titleDragGrabOffsetWorld = Offset.zero;
  Size _lastViewportSize = Size.zero;
  _DockWindowStyle _windowStyle = _DockWindowStyle.neon;
  int _nextWindowId = 1;
  static const String _imguiFontFamily = 'ProggyClean';

  @override
  void initState() {
    super.initState();
    _controller = CanvasController(minZoom: 1.0, maxZoom: 1.0);
    _spawnWindowAt(const Offset(120, 110));
    _spawnWindowAt(const Offset(420, 140));
    _spawnWindowAt(const Offset(740, 170));
    _spawnWindowAt(const Offset(220, 340));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnWindowAt(Offset worldPosition) {
    final id = 'win_${_nextWindowId++}';
    _windows.add(
      _DockWindowDef(
        id: id,
        title: 'Window ${id.split('_').last}',
        floatingWorldPosition: worldPosition,
        size: const Size(290, 196),
      ),
    );
  }

  _DockWindowDef? _windowById(String id) {
    for (final window in _windows) {
      if (window.id == id) return window;
    }
    return null;
  }

  Offset _globalToCanvasLocal(Offset globalPosition) {
    final context = _canvasKey.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return globalPosition;
    return box.globalToLocal(globalPosition);
  }

  Size? _canvasSize() {
    final statsSize = _controller.camera.renderStats?.viewportSize;
    if (statsSize != null && !statsSize.isEmpty) {
      return statsSize;
    }
    final context = _canvasKey.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size;
  }

  void _spawnWindow() {
    setState(() {
      final index = _windows.length;
      final col = index % 4;
      final row = (index ~/ 4) % 4;
      _spawnWindowAt(Offset(140 + col * 300, 120 + row * 230));
    });
  }

  void _resetLayout() {
    _dockRoot = null;
    _hoverDock = null;
    _activeTitleDragWindowId = null;
    _draggingWindowIds.clear();

    for (var i = 0; i < _windows.length; i++) {
      final col = i % 4;
      final row = (i ~/ 4) % 4;
      final world = Offset(140 + col * 300, 120 + row * 230);
      final window = _windows[i];
      window.docked = false;
      window.floatingWorldPosition = world;
      window.size = const Size(290, 196);
      _controller.items.setWorldPosition(window.id, world);
    }

    setState(() {});
  }

  void _removeWindowFromTree(String windowId) {
    if (_dockRoot == null) return;
    _dockRoot = _removeWindowAndCompact(_dockRoot!, windowId);
  }

  void _collectDockedWindowIds(_DockNode node, Set<String> out) {
    if (node is _DockLeafNode) {
      out.addAll(node.tabWindowIds);
      return;
    }
    final split = node as _DockSplitNode;
    _collectDockedWindowIds(split.first, out);
    _collectDockedWindowIds(split.second, out);
  }

  void _collectActiveDockedWindowIds(_DockNode node, Set<String> out) {
    if (node is _DockLeafNode) {
      final id = node.activeWindowId;
      if (id != null) out.add(id);
      return;
    }
    final split = node as _DockSplitNode;
    _collectActiveDockedWindowIds(split.first, out);
    _collectActiveDockedWindowIds(split.second, out);
  }

  _DockNode? _removeWindowAndCompact(_DockNode node, String windowId) {
    if (node is _DockLeafNode) {
      node.removeTab(windowId);
      return node.isEmpty ? null : node;
    }

    final split = node as _DockSplitNode;
    final first = _removeWindowAndCompact(split.first, windowId);
    final second = _removeWindowAndCompact(split.second, windowId);

    if (first == null && second == null) {
      return null;
    }
    if (first == null) {
      return second;
    }
    if (second == null) {
      return first;
    }

    split.first = first;
    split.second = second;
    return split;
  }

  _DockLeafHit? _findLeafAt(_DockNode node, Rect rect, Offset point) {
    if (!rect.contains(point)) return null;
    if (node is _DockLeafNode) {
      return _DockLeafHit(leaf: node, rect: rect);
    }

    final split = node as _DockSplitNode;
    final parts = _DockLayout.splitRects(rect, split.axis, split.ratio);

    final firstHit = _findLeafAt(split.first, parts.$1, point);
    if (firstHit != null) return firstHit;
    return _findLeafAt(split.second, parts.$2, point);
  }

  _DockNode _replaceLeafNode(
    _DockNode node,
    _DockLeafNode target,
    _DockNode replacement,
  ) {
    if (node is _DockLeafNode) {
      if (identical(node, target)) {
        return replacement;
      }
      return node;
    }

    final split = node as _DockSplitNode;
    split.first = _replaceLeafNode(split.first, target, replacement);
    split.second = _replaceLeafNode(split.second, target, replacement);
    return split;
  }

  _DockLeafNode? _findLeafByWindowId(_DockNode? node, String windowId) {
    if (node == null) return null;
    if (node is _DockLeafNode) {
      return node.tabWindowIds.contains(windowId) ? node : null;
    }
    final split = node as _DockSplitNode;
    final first = _findLeafByWindowId(split.first, windowId);
    if (first != null) return first;
    return _findLeafByWindowId(split.second, windowId);
  }

  void _setDocked(String id, bool docked) {
    final window = _windowById(id);
    if (window == null) return;
    window.docked = docked;
  }

  void _updateHoverDockState(Offset canvasLocal) {
    final size = _canvasSize();
    if (size == null || size.isEmpty) {
      if (_hoverDock != null) {
        setState(() => _hoverDock = null);
      }
      return;
    }

    final rootRect = _DockLayout.rootRect(size);
    if (!rootRect.contains(canvasLocal)) {
      if (_hoverDock != null) {
        setState(() => _hoverDock = null);
      }
      return;
    }

    _DockLeafNode? hostLeaf;
    Rect hostRect = rootRect;

    if (_dockRoot != null) {
      final hit = _findLeafAt(_dockRoot!, rootRect, canvasLocal);
      if (hit != null) {
        hostLeaf = hit.leaf;
        hostRect = hit.rect;
      }
    }

    final fullscreenRect = _DockLayout.fullscreenIndicatorRect(rootRect);
    if (fullscreenRect.contains(canvasLocal)) {
      final next = _DockHoverState(
        leaf: null,
        hostRect: rootRect,
        target: _DockTarget.fullscreen,
      );
      final current = _hoverDock;
      final same =
          current != null &&
          current.target == next.target &&
          current.hostRect == next.hostRect;
      if (!same) {
        setState(() {
          _hoverDock = next;
        });
      }
      return;
    }

    final indicators = _DockLayout.indicatorRects(hostRect);
    _DockTarget? target;
    for (final entry in indicators.entries) {
      if (entry.value.contains(canvasLocal)) {
        target = entry.key;
        break;
      }
    }

    final next = _DockHoverState(
      leaf: hostLeaf,
      hostRect: hostRect,
      target: target,
    );
    final current = _hoverDock;
    final same =
        current != null &&
        identical(current.leaf, next.leaf) &&
        current.hostRect == next.hostRect &&
        current.target == next.target;
    if (!same) {
      setState(() {
        _hoverDock = next;
      });
    }
  }

  void _onTitlePointerDown(String windowId, PointerDownEvent event) {
    final window = _windowById(windowId);
    if (window == null) return;

    if (window.docked) {
      window.docked = false;
      _removeWindowFromTree(windowId);
      _applyDockLayout();
    }

    _controller.items.bringToFront(windowId);

    final current =
        _controller.items.getWorldPosition(windowId) ??
        window.floatingWorldPosition;
    final canvasLocal = _globalToCanvasLocal(event.position);
    final pointerWorld = _controller.camera.screenToWorld(canvasLocal);
    _titleDragGrabOffsetWorld = current - pointerWorld;
    _activeTitleDragWindowId = windowId;

    setState(() {
      _draggingWindowIds.add(windowId);
    });

    _updateHoverDockState(canvasLocal);
  }

  void _onTitlePointerMove(String windowId, PointerMoveEvent event) {
    if (_activeTitleDragWindowId != windowId) return;
    final canvasLocal = _globalToCanvasLocal(event.position);
    final pointerWorld = _controller.camera.screenToWorld(canvasLocal);
    _controller.items.setWorldPosition(
      windowId,
      pointerWorld + _titleDragGrabOffsetWorld,
    );
    _updateHoverDockState(canvasLocal);
  }

  void _dockWindowFromHover(String windowId, _DockHoverState hover) {
    final target = hover.target;
    if (target == null) return;

    if (target == _DockTarget.fullscreen) {
      final previouslyDocked = <String>{};
      if (_dockRoot != null) {
        _collectDockedWindowIds(_dockRoot!, previouslyDocked);
      }
      _dockRoot = _DockLeafNode(windowId: windowId);
      for (final id in previouslyDocked) {
        if (id == windowId) continue;
        final displaced = _windowById(id);
        if (displaced == null) continue;
        displaced.docked = false;
        displaced.floatingWorldPosition =
            _controller.items.getWorldPosition(id) ??
            displaced.floatingWorldPosition;
      }
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    if (_dockRoot == null) {
      if (target == _DockTarget.center) {
        _dockRoot = _DockLeafNode(windowId: windowId);
      } else {
        final incoming = _DockLeafNode(windowId: windowId);
        final empty = _DockLeafNode(windowId: null);
        final axis = (target == _DockTarget.left || target == _DockTarget.right)
            ? _DockSplitAxis.vertical
            : _DockSplitAxis.horizontal;
        final incomingFirst =
            target == _DockTarget.left || target == _DockTarget.top;
        _dockRoot = _DockSplitNode(
          axis: axis,
          ratio: 0.5,
          first: incomingFirst ? incoming : empty,
          second: incomingFirst ? empty : incoming,
        );
      }
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    final leaf = hover.leaf;
    if (leaf == null) {
      final oldRoot = _dockRoot!;
      final incoming = _DockLeafNode(windowId: windowId);
      final axis = (target == _DockTarget.left || target == _DockTarget.right)
          ? _DockSplitAxis.vertical
          : _DockSplitAxis.horizontal;
      final incomingFirst =
          target == _DockTarget.left || target == _DockTarget.top;
      _dockRoot = _DockSplitNode(
        axis: axis,
        ratio: 0.5,
        first: incomingFirst ? incoming : oldRoot,
        second: incomingFirst ? oldRoot : incoming,
      );
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    if (target == _DockTarget.center) {
      leaf.addTab(windowId, activate: true);
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    if (leaf.isEmpty) {
      final incomingLeaf = _DockLeafNode(windowId: windowId);
      final emptyLeaf = _DockLeafNode(windowId: null);
      final axis = (target == _DockTarget.left || target == _DockTarget.right)
          ? _DockSplitAxis.vertical
          : _DockSplitAxis.horizontal;
      final incomingFirst =
          target == _DockTarget.left || target == _DockTarget.top;
      final split = _DockSplitNode(
        axis: axis,
        ratio: 0.5,
        first: incomingFirst ? incomingLeaf : emptyLeaf,
        second: incomingFirst ? emptyLeaf : incomingLeaf,
      );
      _dockRoot = _replaceLeafNode(_dockRoot!, leaf, split);
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    if (leaf.tabWindowIds.contains(windowId)) {
      _setDocked(windowId, true);
      _applyDockLayout();
      return;
    }

    final existingLeaf = _DockLeafNode(windowId: null);
    for (final id in leaf.tabWindowIds) {
      existingLeaf.addTab(id, activate: id == leaf.activeWindowId);
    }
    final incomingLeaf = _DockLeafNode(windowId: windowId);

    final axis = (target == _DockTarget.left || target == _DockTarget.right)
        ? _DockSplitAxis.vertical
        : _DockSplitAxis.horizontal;
    final incomingFirst =
        target == _DockTarget.left || target == _DockTarget.top;

    final split = _DockSplitNode(
      axis: axis,
      ratio: 0.5,
      first: incomingFirst ? incomingLeaf : existingLeaf,
      second: incomingFirst ? existingLeaf : incomingLeaf,
    );

    _dockRoot = _replaceLeafNode(_dockRoot!, leaf, split);
    _setDocked(windowId, true);
    _applyDockLayout();
  }

  void _applyDockLayout() {
    final size = _canvasSize();
    if (_dockRoot == null || size == null || size.isEmpty) return;

    final assignments = <String, Rect>{};
    final rootRect = _DockLayout.rootRect(size);
    _collectDockRects(_dockRoot!, rootRect, assignments);

    for (final window in _windows) {
      if (!window.docked) continue;
      final screenRect = assignments[window.id];
      if (screenRect == null ||
          screenRect.width < 20 ||
          screenRect.height < 20) {
        continue;
      }

      final worldTopLeft = _controller.camera.screenToWorld(screenRect.topLeft);
      final worldBottomRight = _controller.camera.screenToWorld(
        screenRect.bottomRight,
      );
      final worldRect = Rect.fromPoints(worldTopLeft, worldBottomRight);

      window.size = worldRect.size;
      // Keep model position in sync even for inactive tabs that are not
      // currently mounted as CanvasItems.
      window.floatingWorldPosition = worldRect.topLeft;
      _controller.items.setWorldPosition(window.id, worldRect.topLeft);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _collectDockRects(_DockNode node, Rect rect, Map<String, Rect> out) {
    if (node is _DockLeafNode) {
      final slotRect = rect.deflate(1);
      for (final id in node.tabWindowIds) {
        out[id] = slotRect;
      }
      return;
    }

    final split = node as _DockSplitNode;
    final parts = _DockLayout.splitRects(rect, split.axis, split.ratio);
    _collectDockRects(split.first, parts.$1, out);
    _collectDockRects(split.second, parts.$2, out);
  }

  void _onTitlePointerUpOrCancel(String windowId, Offset? globalPosition) {
    if (_activeTitleDragWindowId != windowId) return;

    if (globalPosition != null) {
      _updateHoverDockState(_globalToCanvasLocal(globalPosition));
    }

    final window = _windowById(windowId);
    if (window != null) {
      window.floatingWorldPosition =
          _controller.items.getWorldPosition(windowId) ??
          window.floatingWorldPosition;
    }

    final hover = _hoverDock;
    if (hover != null && hover.target != null) {
      _dockWindowFromHover(windowId, hover);
    } else {
      _setDocked(windowId, false);
    }

    _activeTitleDragWindowId = null;
    setState(() {
      _draggingWindowIds.remove(windowId);
      _hoverDock = null;
    });
  }

  CanvasItem _buildWindowItem(_DockWindowDef window) {
    final leaf = window.docked
        ? _findLeafByWindowId(_dockRoot, window.id)
        : null;
    final tabIds = leaf?.tabWindowIds ?? <String>[window.id];
    final tabs = <_DockTabInfo>[
      for (final id in tabIds)
        _DockTabInfo(id: id, title: _windowById(id)?.title ?? id),
    ];
    final activeTabId = leaf?.activeWindowId ?? window.id;

    return CanvasItem(
      id: window.id,
      worldPosition:
          _controller.items.getWorldPosition(window.id) ??
          window.floatingWorldPosition,
      size: CanvasItemSize.fixed(window.size.width, window.size.height),
      behavior: const CanvasItemBehavior(
        draggable: false,
        bringToFront: CanvasBringToFrontBehavior.never,
      ),
      child: _DockWindowWidget(
        title: window.title,
        tabs: tabs,
        activeTabId: activeTabId,
        dragging: _draggingWindowIds.contains(window.id),
        style: _windowStyle,
        fontFamily: _windowStyle == _DockWindowStyle.imgui
            ? _imguiFontFamily
            : null,
        onTitlePointerDown: (event) => _onTitlePointerDown(window.id, event),
        onTitlePointerMove: (event) => _onTitlePointerMove(window.id, event),
        onTitlePointerUp: (event) =>
            _onTitlePointerUpOrCancel(window.id, event.position),
        onTitlePointerCancel: (event) =>
            _onTitlePointerUpOrCancel(window.id, event.position),
        onSelectTab: (tabId) {
          final hostLeaf = _findLeafByWindowId(_dockRoot, window.id);
          if (hostLeaf == null) return;
          if (!hostLeaf.tabWindowIds.contains(tabId)) return;
          hostLeaf.activeWindowId = tabId;
          _applyDockLayout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docking Windows Prototype'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_DockWindowStyle>(
                value: _windowStyle,
                borderRadius: BorderRadius.circular(8),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _windowStyle = value;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: _DockWindowStyle.neon,
                    child: Text('Style: Neon'),
                  ),
                  DropdownMenuItem(
                    value: _DockWindowStyle.imgui,
                    child: Text('Style: ImGui'),
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: _spawnWindow,
            child: const Text('Add window'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _resetLayout, child: const Text('Reset')),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (viewport != _lastViewportSize) {
            _lastViewportSize = viewport;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _dockRoot == null) return;
              _applyDockLayout();
            });
          }

          final dockAreaRect = _DockLayout.rootRect(viewport);
          final activeDockedWindowIds = <String>{};
          if (_dockRoot != null) {
            _collectActiveDockedWindowIds(_dockRoot!, activeDockedWindowIds);
          }

          return InfinityCanvas(
            key: _canvasKey,
            controller: _controller,
            inputBehavior: const CanvasInputBehavior.locked(),
            enableCulling: false,
            layers: [
              CanvasLayer.painter(
                id: 'docking-bg-grid',
                painterBuilder: (_) => _DockBackgroundPainter(),
              ),
              CanvasLayer.positionedItems(
                id: 'docking-windows-docked',
                items: [
                  for (final window in _windows.where(
                    (w) => w.docked && activeDockedWindowIds.contains(w.id),
                  ))
                    _buildWindowItem(window),
                ],
              ),
              CanvasLayer.positionedItems(
                id: 'docking-windows-floating',
                items: [
                  for (final window in _windows.where((w) => !w.docked))
                    _buildWindowItem(window),
                ],
              ),
              CanvasLayer.overlay(
                id: 'docking-overlay',
                ignorePointer: true,
                builder: (context, transform, controller) {
                  return _DockOverlay(
                    activeDrag: _activeTitleDragWindowId != null,
                    dockAreaRect: dockAreaRect,
                    hover: _hoverDock,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DockWindowDef {
  final String id;
  final String title;
  Offset floatingWorldPosition;
  Size size;
  bool docked = false;

  _DockWindowDef({
    required this.id,
    required this.title,
    required this.floatingWorldPosition,
    required this.size,
  });
}

class _DockTabInfo {
  final String id;
  final String title;

  const _DockTabInfo({required this.id, required this.title});
}

class _DockWindowWidget extends StatefulWidget {
  final String title;
  final List<_DockTabInfo> tabs;
  final String activeTabId;
  final bool dragging;
  final _DockWindowStyle style;
  final String? fontFamily;
  final ValueChanged<PointerDownEvent> onTitlePointerDown;
  final ValueChanged<PointerMoveEvent> onTitlePointerMove;
  final ValueChanged<PointerUpEvent> onTitlePointerUp;
  final ValueChanged<PointerCancelEvent> onTitlePointerCancel;
  final ValueChanged<String> onSelectTab;

  const _DockWindowWidget({
    required this.title,
    required this.tabs,
    required this.activeTabId,
    required this.dragging,
    required this.style,
    this.fontFamily,
    required this.onTitlePointerDown,
    required this.onTitlePointerMove,
    required this.onTitlePointerUp,
    required this.onTitlePointerCancel,
    required this.onSelectTab,
  });

  @override
  State<_DockWindowWidget> createState() => _DockWindowWidgetState();
}

class _DockWindowWidgetState extends State<_DockWindowWidget> {
  bool _titleHovered = false;

  String _windowNumberFromId(String id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    return match?.group(1) ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.dragging
        ? const Color(0xFFDBEAFE)
        : (_titleHovered ? const Color(0xFFBFDBFE) : const Color(0xFF94A3B8));
    _DockTabInfo? activeTab;
    for (final tab in widget.tabs) {
      if (tab.id == widget.activeTabId) {
        activeTab = tab;
        break;
      }
    }
    activeTab ??= widget.tabs.isNotEmpty
        ? widget.tabs.first
        : _DockTabInfo(id: widget.activeTabId, title: widget.title);
    final numberText = _windowNumberFromId(activeTab.id);
    if (widget.style == _DockWindowStyle.imgui) {
      return _buildImguiWindow(activeTab, numberText);
    }
    return _buildNeonWindow(activeTab, numberText, borderColor);
  }

  Widget _buildNeonWindow(
    _DockTabInfo activeTab,
    String numberText,
    Color borderColor,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: widget.dragging ? 1.7 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x70000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
          BoxShadow(
            color: Color(0x2622D3EE),
            blurRadius: 12,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.basic,
              onEnter: (_) => setState(() => _titleHovered = true),
              onExit: (_) => setState(() => _titleHovered = false),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.dragging
                        ? const [Color(0xFF0284C7), Color(0xFF1E3A5F)]
                        : const [Color(0xFF64748B), Color(0xFF334155)],
                  ),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFF94A3B8), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: widget.onTitlePointerDown,
                        onPointerMove: widget.onTitlePointerMove,
                        onPointerUp: widget.onTitlePointerUp,
                        onPointerCancel: widget.onTitlePointerCancel,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: Icon(
                              Icons.drag_indicator,
                              size: 14,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tab in widget.tabs)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _DockTabChip(
                                  title: tab.title,
                                  active: tab.id == widget.activeTabId,
                                  style: widget.style,
                                  fontFamily: widget.fontFamily,
                                  draggable: tab.id == widget.activeTabId,
                                  onTap: () => widget.onSelectTab(tab.id),
                                  onDragStart: tab.id == widget.activeTabId
                                      ? widget.onTitlePointerDown
                                      : null,
                                  onDragUpdate: tab.id == widget.activeTabId
                                      ? widget.onTitlePointerMove
                                      : null,
                                  onDragEnd: tab.id == widget.activeTabId
                                      ? widget.onTitlePointerUp
                                      : null,
                                  onDragCancel: tab.id == widget.activeTabId
                                      ? widget.onTitlePointerCancel
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _WindowTrafficLights(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF243247),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        numberText,
                        style: const TextStyle(
                          color: Color(0x447DD3FC),
                          fontSize: 86,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 10,
                      child: Text(
                        activeTab.title,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 10,
                      child: Text(
                        widget.dragging
                            ? 'Dragging by title bar'
                            : 'Window content placeholder',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImguiWindow(_DockTabInfo activeTab, String numberText) {
    final borderColor = widget.dragging
        ? const Color(0xFF7F9DB9)
        : (_titleHovered ? const Color(0xFF6A8CAF) : const Color(0xFF4A4A4A));
    final titleColor = widget.dragging
        ? const Color(0xFF355886)
        : const Color(0xFF2B2B2B);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _titleHovered = true),
            onExit: (_) => setState(() => _titleHovered = false),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: titleColor,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF454545), width: 1),
                ),
              ),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: widget.onTitlePointerDown,
                      onPointerMove: widget.onTitlePointerMove,
                      onPointerUp: widget.onTitlePointerUp,
                      onPointerCancel: widget.onTitlePointerCancel,
                      child: const SizedBox(
                        width: 18,
                        height: 22,
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Color(0xFFD8D8D8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in widget.tabs)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: _DockTabChip(
                                title: tab.title,
                                active: tab.id == widget.activeTabId,
                                style: widget.style,
                                fontFamily: widget.fontFamily,
                                draggable: tab.id == widget.activeTabId,
                                onTap: () => widget.onSelectTab(tab.id),
                                onDragStart: tab.id == widget.activeTabId
                                    ? widget.onTitlePointerDown
                                    : null,
                                onDragUpdate: tab.id == widget.activeTabId
                                    ? widget.onTitlePointerMove
                                    : null,
                                onDragEnd: tab.id == widget.activeTabId
                                    ? widget.onTitlePointerUp
                                    : null,
                                onDragCancel: tab.id == widget.activeTabId
                                    ? widget.onTitlePointerCancel
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: 'Close not implemented',
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Color(0xFFCFCFCF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFF101010),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      numberText,
                      style: TextStyle(
                        color: const Color(0x335A8AC0),
                        fontSize: 82,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: Text(
                      activeTab.title,
                      style: TextStyle(
                        color: const Color(0xFFE4E4E4),
                        fontSize: 11,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Text(
                      widget.dragging
                          ? 'Dragging title'
                          : 'ImGui-style placeholder',
                      style: TextStyle(
                        color: const Color(0xFFB7B7B7),
                        fontSize: 10,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockTabChip extends StatefulWidget {
  final String title;
  final bool active;
  final _DockWindowStyle style;
  final String? fontFamily;
  final bool draggable;
  final VoidCallback onTap;
  final ValueChanged<PointerDownEvent>? onDragStart;
  final ValueChanged<PointerMoveEvent>? onDragUpdate;
  final ValueChanged<PointerUpEvent>? onDragEnd;
  final ValueChanged<PointerCancelEvent>? onDragCancel;

  const _DockTabChip({
    required this.title,
    required this.active,
    required this.style,
    this.fontFamily,
    required this.draggable,
    required this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  @override
  State<_DockTabChip> createState() => _DockTabChipState();
}

class _DockTabChipState extends State<_DockTabChip> {
  static const double _dragStartDistance = 4.0;
  PointerDownEvent? _downEvent;
  int? _pointer;
  bool _dragging = false;

  void _reset() {
    _downEvent = null;
    _pointer = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final cursor = widget.draggable
        ? SystemMouseCursors.move
        : SystemMouseCursors.click;
    final imgui = widget.style == _DockWindowStyle.imgui;
    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _downEvent = event;
          _pointer = event.pointer;
          _dragging = false;
        },
        onPointerMove: (event) {
          if (_pointer != event.pointer) return;
          final down = _downEvent;
          if (down == null) return;

          if (!_dragging && widget.draggable) {
            final distance = (event.position - down.position).distance;
            if (distance >= _dragStartDistance) {
              _dragging = true;
              widget.onDragStart?.call(down);
            }
          }
          if (_dragging) {
            widget.onDragUpdate?.call(event);
          }
        },
        onPointerUp: (event) {
          if (_pointer != event.pointer) return;
          if (_dragging) {
            widget.onDragEnd?.call(event);
          } else {
            widget.onTap();
          }
          _reset();
        },
        onPointerCancel: (event) {
          if (_pointer != event.pointer) return;
          if (_dragging) {
            widget.onDragCancel?.call(event);
          }
          _reset();
        },
        child: Container(
          height: imgui ? 18 : 22,
          constraints: BoxConstraints(minWidth: imgui ? 56 : 68),
          padding: EdgeInsets.symmetric(horizontal: imgui ? 6 : 8),
          decoration: BoxDecoration(
            color: imgui
                ? (widget.active
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFF1B1B1B))
                : (widget.active
                      ? const Color(0xFF0F172A)
                      : const Color(0x1A0F172A)),
            borderRadius: BorderRadius.circular(imgui ? 2 : 6),
            border: Border.all(
              color: imgui
                  ? (widget.active
                        ? const Color(0xFF7F9DB9)
                        : const Color(0xFF3E3E3E))
                  : (widget.active
                        ? const Color(0xFFA5F3FC)
                        : const Color(0x3FFFFFFF)),
              width: 1.0,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: imgui
                  ? (widget.active
                        ? const Color(0xFFE4E4E4)
                        : const Color(0xFFBDBDBD))
                  : (widget.active
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFCBD5E1)),
              fontWeight: imgui
                  ? FontWeight.w500
                  : (widget.active ? FontWeight.w700 : FontWeight.w600),
              fontSize: imgui ? 10 : 11,
              fontFamily: widget.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowTrafficLights extends StatelessWidget {
  const _WindowTrafficLights();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return Tooltip(
      message: 'Window controls not implemented',
      child: Opacity(
        opacity: 0.82,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot(const Color(0xFFF97316)),
              const SizedBox(width: 6),
              dot(const Color(0xFFEAB308)),
              const SizedBox(width: 6),
              dot(const Color(0xFF10B981)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockBackgroundPainter extends CustomPainter {
  _DockBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF313D4F),
    );

    const step = 34.0;
    const majorEvery = 6;

    final minor = Paint()
      ..color = const Color(0x25344758)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x44344758)
      ..strokeWidth = 1.0;

    var i = 0;
    for (double x = 0; x <= size.width; x += step) {
      final paint = (i % majorEvery == 0) ? major : minor;
      i++;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    i = 0;
    for (double y = 0; y <= size.height; y += step) {
      final paint = (i % majorEvery == 0) ? major : minor;
      i++;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DockBackgroundPainter oldDelegate) {
    return false;
  }
}

class _DockLayout {
  static const double rootPadding = 16;
  static const double indicatorSize = 44;
  static const double indicatorGap = 14;
  static const double fullscreenIndicatorHeight = 30;

  static Rect rootRect(Size size) {
    return Rect.fromLTWH(
      rootPadding,
      rootPadding,
      size.width - rootPadding * 2,
      size.height - rootPadding * 2,
    );
  }

  static (Rect, Rect) splitRects(Rect rect, _DockSplitAxis axis, double ratio) {
    final clampedRatio = ratio.clamp(0.2, 0.8);
    if (axis == _DockSplitAxis.vertical) {
      final firstWidth = rect.width * clampedRatio;
      return (
        Rect.fromLTWH(rect.left, rect.top, firstWidth, rect.height),
        Rect.fromLTWH(
          rect.left + firstWidth,
          rect.top,
          rect.width - firstWidth,
          rect.height,
        ),
      );
    }

    final firstHeight = rect.height * clampedRatio;
    return (
      Rect.fromLTWH(rect.left, rect.top, rect.width, firstHeight),
      Rect.fromLTWH(
        rect.left,
        rect.top + firstHeight,
        rect.width,
        rect.height - firstHeight,
      ),
    );
  }

  static Map<_DockTarget, Rect> indicatorRects(Rect hostRect) {
    final shortest = math.min(hostRect.width, hostRect.height);
    final indicator = shortest.clamp(24.0, indicatorSize).toDouble();
    final gap = math.min(indicatorGap, math.max(6.0, shortest * 0.18));
    final spread = indicator + gap;

    final center = hostRect.center;
    return <_DockTarget, Rect>{
      _DockTarget.center: Rect.fromCenter(
        center: center,
        width: indicator,
        height: indicator,
      ),
      _DockTarget.left: Rect.fromCenter(
        center: center.translate(-spread, 0),
        width: indicator,
        height: indicator,
      ),
      _DockTarget.right: Rect.fromCenter(
        center: center.translate(spread, 0),
        width: indicator,
        height: indicator,
      ),
      _DockTarget.top: Rect.fromCenter(
        center: center.translate(0, -spread),
        width: indicator,
        height: indicator,
      ),
      _DockTarget.bottom: Rect.fromCenter(
        center: center.translate(0, spread),
        width: indicator,
        height: indicator,
      ),
    };
  }

  static Rect fullscreenIndicatorRect(Rect rootRect) {
    const width = 132.0;
    final w = math.min(width, rootRect.width * 0.36);
    return Rect.fromCenter(
      center: Offset(rootRect.center.dx, rootRect.top + 24),
      width: w,
      height: fullscreenIndicatorHeight,
    );
  }

  static Rect previewRect(Rect hostRect, _DockTarget target) {
    switch (target) {
      case _DockTarget.left:
        return Rect.fromLTWH(
          hostRect.left,
          hostRect.top,
          hostRect.width * 0.5,
          hostRect.height,
        );
      case _DockTarget.right:
        return Rect.fromLTWH(
          hostRect.left + hostRect.width * 0.5,
          hostRect.top,
          hostRect.width * 0.5,
          hostRect.height,
        );
      case _DockTarget.top:
        return Rect.fromLTWH(
          hostRect.left,
          hostRect.top,
          hostRect.width,
          hostRect.height * 0.5,
        );
      case _DockTarget.bottom:
        return Rect.fromLTWH(
          hostRect.left,
          hostRect.top + hostRect.height * 0.5,
          hostRect.width,
          hostRect.height * 0.5,
        );
      case _DockTarget.center:
        return hostRect;
      case _DockTarget.fullscreen:
        return hostRect;
    }
  }
}

class _DockOverlay extends StatelessWidget {
  final bool activeDrag;
  final Rect dockAreaRect;
  final _DockHoverState? hover;

  const _DockOverlay({
    required this.activeDrag,
    required this.dockAreaRect,
    required this.hover,
  });

  @override
  Widget build(BuildContext context) {
    if (!activeDrag || dockAreaRect.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _DockOverlayPainter(dockAreaRect: dockAreaRect, hover: hover),
    );
  }
}

class _DockOverlayPainter extends CustomPainter {
  final Rect dockAreaRect;
  final _DockHoverState? hover;

  _DockOverlayPainter({required this.dockAreaRect, required this.hover});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      dockAreaRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22E2E8F0),
    );

    final hostRect = hover?.hostRect;
    if (hostRect == null) return;

    final target = hover?.target;
    if (target != null) {
      final preview = _DockLayout.previewRect(hostRect, target);
      canvas.drawRect(preview, Paint()..color = const Color(0x5538BDF8));
      canvas.drawRect(
        preview,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF7DD3FC),
      );
    }

    final fullscreenRect = _DockLayout.fullscreenIndicatorRect(dockAreaRect);
    final fullscreenHovered = target == _DockTarget.fullscreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fullscreenRect, const Radius.circular(8)),
      Paint()
        ..color = fullscreenHovered
            ? const Color(0xEE0E7490)
            : const Color(0xCC334155),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fullscreenRect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fullscreenHovered ? 2.0 : 1.2
        ..color = fullscreenHovered
            ? const Color(0xFF7DD3FC)
            : const Color(0xFF94A3B8),
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'FULL',
        style: TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        fullscreenRect.center.dx - textPainter.width / 2,
        fullscreenRect.center.dy - textPainter.height / 2,
      ),
    );

    final indicators = _DockLayout.indicatorRects(hostRect);
    for (final entry in indicators.entries) {
      final hovered = entry.key == target;
      final rect = entry.value;
      final border = hovered
          ? const Color(0xFF7DD3FC)
          : const Color(0xFF94A3B8);
      final fill = hovered ? const Color(0xEE0E7490) : const Color(0xCC334155);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()..color = fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hovered ? 2.0 : 1.2
          ..color = border,
      );

      final iconPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      _drawTargetIcon(canvas, rect, entry.key, iconPaint);
    }
  }

  void _drawTargetIcon(
    Canvas canvas,
    Rect rect,
    _DockTarget target,
    Paint paint,
  ) {
    final c = rect.center;
    final dx = rect.width * 0.24;
    final dy = rect.height * 0.24;
    switch (target) {
      case _DockTarget.left:
        canvas.drawLine(c + Offset(dx, -dy), c + Offset(-dx, 0), paint);
        canvas.drawLine(c + Offset(dx, dy), c + Offset(-dx, 0), paint);
        break;
      case _DockTarget.right:
        canvas.drawLine(c + Offset(-dx, -dy), c + Offset(dx, 0), paint);
        canvas.drawLine(c + Offset(-dx, dy), c + Offset(dx, 0), paint);
        break;
      case _DockTarget.top:
        canvas.drawLine(c + Offset(-dx, dy), c + Offset(0, -dy), paint);
        canvas.drawLine(c + Offset(dx, dy), c + Offset(0, -dy), paint);
        break;
      case _DockTarget.bottom:
        canvas.drawLine(c + Offset(-dx, -dy), c + Offset(0, dy), paint);
        canvas.drawLine(c + Offset(dx, -dy), c + Offset(0, dy), paint);
        break;
      case _DockTarget.center:
        final inner = Rect.fromCenter(
          center: c,
          width: rect.width * 0.42,
          height: rect.height * 0.42,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, const Radius.circular(4)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE2E8F0),
        );
        break;
      case _DockTarget.fullscreen:
        canvas.drawRect(
          Rect.fromCenter(
            center: c,
            width: rect.width * 0.48,
            height: rect.height * 0.48,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE2E8F0),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DockOverlayPainter oldDelegate) {
    return oldDelegate.dockAreaRect != dockAreaRect ||
        oldDelegate.hover != hover;
  }
}
