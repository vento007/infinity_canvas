import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../schema_models.dart';

class SchemaTableCard extends StatefulWidget {
  final DbTableDef table;
  final ValueListenable<String?> selectedTableId;
  final VoidCallback onTap;

  const SchemaTableCard({
    super.key,
    required this.table,
    required this.selectedTableId,
    required this.onTap,
  });

  @override
  State<SchemaTableCard> createState() => _SchemaTableCardState();
}

class _SchemaTableCardState extends State<SchemaTableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.table.dragging,
      builder: (context, dragging, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: widget.selectedTableId,
          builder: (context, selectedId, _) {
            final selected = selectedId == widget.table.id;
            final hot = selected || _hovered || dragging;
            final border = hot
                ? Color.lerp(widget.table.color, Colors.white, 0.30)!
                : widget.table.color.withValues(alpha: 0.62);

            return SizedBox(
              width: widget.table.size.width,
              height: widget.table.size.height,
              child: MouseRegion(
                onEnter: (_) {
                  if (_hovered) return;
                  setState(() => _hovered = true);
                },
                onExit: (_) {
                  if (!_hovered) return;
                  setState(() => _hovered = false);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border, width: hot ? 2.0 : 1.1),
                      boxShadow: [
                        const BoxShadow(
                          color: Color(0xAA000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                        if (hot)
                          BoxShadow(
                            color: widget.table.color.withValues(alpha: 0.30),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderRow(
                          table: widget.table,
                          selected: selected,
                          hovered: _hovered,
                          dragging: dragging,
                        ),
                        for (final column in widget.table.columns)
                          _ColumnRow(column: column),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final DbTableDef table;
  final bool selected;
  final bool hovered;
  final bool dragging;

  const _HeaderRow({
    required this.table,
    required this.selected,
    required this.hovered,
    required this.dragging,
  });

  @override
  Widget build(BuildContext context) {
    final tone = dragging ? 0.52 : (selected ? 0.42 : (hovered ? 0.34 : 0.26));

    return Container(
      height: SchemaCardMetrics.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: table.color.withValues(alpha: tone),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(
          bottom: BorderSide(color: table.color.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              table.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF2F8FF),
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${table.columns.length} cols',
            style: const TextStyle(
              color: Color(0xFFD4E3FF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  final DbColumnDef column;

  const _ColumnRow({required this.column});

  @override
  Widget build(BuildContext context) {
    final keyColor = column.primaryKey
        ? const Color(0xFFFFD36E)
        : (column.foreignKey
              ? const Color(0xFF8BC8FF)
              : const Color(0xFF8FA6CC));

    return SizedBox(
      height: SchemaCardMetrics.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: keyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: keyColor.withValues(alpha: 0.55)),
              ),
              child: Text(
                column.primaryKey ? 'PK' : (column.foreignKey ? 'FK' : '•'),
                style: TextStyle(
                  color: keyColor,
                  fontSize: 7.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                column.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE7EEFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              column.type,
              style: TextStyle(
                color: column.nullable
                    ? const Color(0xFF8FA4C6)
                    : const Color(0xFFB7CAE8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
