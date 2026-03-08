import 'package:flutter/material.dart';

class SchemaCardMetrics {
  static const double width = 282;
  static const double headerHeight = 36;
  static const double rowHeight = 22;
  static const double footerPadding = 10;

  static double tableHeight(int columnCount) {
    return headerHeight + rowHeight * columnCount + footerPadding;
  }
}

class DbColumnDef {
  final String name;
  final String type;
  final bool primaryKey;
  final bool nullable;
  final String? referencesTableId;
  final String? referencesColumnName;

  const DbColumnDef({
    required this.name,
    required this.type,
    this.primaryKey = false,
    this.nullable = true,
    this.referencesTableId,
    this.referencesColumnName,
  });

  bool get foreignKey => referencesTableId != null;
}

class DbTableDef {
  final String id;
  final String name;
  final Color color;
  final List<DbColumnDef> columns;
  final ValueNotifier<Offset> position;
  final ValueNotifier<bool> dragging = ValueNotifier<bool>(false);

  DbTableDef({
    required this.id,
    required this.name,
    required this.color,
    required this.columns,
    required Offset initialPosition,
  }) : position = ValueNotifier<Offset>(initialPosition);

  Size get size => Size(
    SchemaCardMetrics.width,
    SchemaCardMetrics.tableHeight(columns.length),
  );

  void dispose() {
    position.dispose();
    dragging.dispose();
  }
}

class DbRelation {
  final String id;
  final String fromTableId;
  final String fromColumnName;
  final String toTableId;
  final String toColumnName;

  const DbRelation({
    required this.id,
    required this.fromTableId,
    required this.fromColumnName,
    required this.toTableId,
    required this.toColumnName,
  });

  bool get selfReference => fromTableId == toTableId;
}

class DbSchemaScene {
  final List<DbTableDef> tables;
  final List<DbRelation> relations;
  final Rect bounds;

  const DbSchemaScene({
    required this.tables,
    required this.relations,
    required this.bounds,
  });

  void dispose() {
    for (final table in tables) {
      table.dispose();
    }
  }
}
