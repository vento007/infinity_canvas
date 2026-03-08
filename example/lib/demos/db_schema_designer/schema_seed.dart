import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'schema_models.dart';

enum DbSchemaPreset {
  studio('Studio', modules: 1),
  scale('Scale', modules: 2),
  enterprise('Enterprise', modules: 4);

  final String label;
  final int modules;

  const DbSchemaPreset(this.label, {required this.modules});
}

DbSchemaScene generateDbSchemaScene({
  required int seed,
  required DbSchemaPreset preset,
}) {
  final _ = seed;
  final templates = _baseTemplates();
  final tables = <DbTableDef>[];
  final tableById = <String, DbTableDef>{};

  final moduleCount = preset.modules;
  final moduleColumns = math.sqrt(moduleCount).ceil();

  for (var moduleIndex = 0; moduleIndex < moduleCount; moduleIndex++) {
    final suffix = moduleIndex == 0 ? '' : '_m$moduleIndex';
    final moduleName = moduleIndex == 0 ? '' : ' m$moduleIndex';
    final moduleCol = moduleIndex % moduleColumns;
    final moduleRow = moduleIndex ~/ moduleColumns;
    final moduleOffset = Offset(moduleCol * 2320.0, moduleRow * 1760.0);

    for (final template in templates) {
      final position = template.anchor + moduleOffset;

      final columns = [
        for (final c in template.columns)
          DbColumnDef(
            name: c.name,
            type: c.type,
            primaryKey: c.primaryKey,
            nullable: c.nullable,
            referencesTableId: c.referencesTableId == null
                ? null
                : '${c.referencesTableId}$suffix',
            referencesColumnName: c.referencesColumnName,
          ),
      ];

      final table = DbTableDef(
        id: '${template.id}$suffix',
        name: '${template.name}$moduleName',
        color: template.color,
        columns: columns,
        initialPosition: position,
      );

      tables.add(table);
      tableById[table.id] = table;
    }
  }

  final relations = <DbRelation>[];
  for (final table in tables) {
    for (final column in table.columns) {
      final toTableId = column.referencesTableId;
      if (toTableId == null) continue;
      if (!tableById.containsKey(toTableId)) continue;
      relations.add(
        DbRelation(
          id: '${table.id}.${column.name}->$toTableId',
          fromTableId: table.id,
          fromColumnName: column.name,
          toTableId: toTableId,
          toColumnName: column.referencesColumnName ?? 'id',
        ),
      );
    }
  }

  var left = double.infinity;
  var top = double.infinity;
  var right = -double.infinity;
  var bottom = -double.infinity;

  for (final table in tables) {
    final size = table.size;
    final pos = table.position.value;
    left = math.min(left, pos.dx);
    top = math.min(top, pos.dy);
    right = math.max(right, pos.dx + size.width);
    bottom = math.max(bottom, pos.dy + size.height);
  }

  if (!left.isFinite) {
    left = -2000;
    top = -1200;
    right = 2000;
    bottom = 1200;
  }

  final bounds = Rect.fromLTRB(
    left - 340,
    top - 300,
    right + 340,
    bottom + 300,
  );

  return DbSchemaScene(tables: tables, relations: relations, bounds: bounds);
}

class _TableTemplate {
  final String id;
  final String name;
  final Color color;
  final Offset anchor;
  final List<_ColumnTemplate> columns;

  const _TableTemplate({
    required this.id,
    required this.name,
    required this.color,
    required this.anchor,
    required this.columns,
  });
}

class _ColumnTemplate {
  final String name;
  final String type;
  final bool primaryKey;
  final bool nullable;
  final String? referencesTableId;
  final String? referencesColumnName;

  const _ColumnTemplate({
    required this.name,
    required this.type,
    this.primaryKey = false,
    this.nullable = true,
    this.referencesTableId,
    this.referencesColumnName,
  });
}

List<_TableTemplate> _baseTemplates() {
  const auth = Color(0xFF3A7BD5);
  const catalog = Color(0xFF7E57C2);
  const sales = Color(0xFF2D9C8B);
  const ops = Color(0xFFDE8B2D);

  return const [
    _TableTemplate(
      id: 'account',
      name: 'account',
      color: auth,
      anchor: Offset(-1280, -640),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(name: 'email', type: 'varchar(240)', nullable: false),
        _ColumnTemplate(
          name: 'password_hash',
          type: 'varchar(128)',
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'created_at',
          type: 'timestamptz',
          nullable: false,
        ),
      ],
    ),
    _TableTemplate(
      id: 'organization',
      name: 'organization',
      color: auth,
      anchor: Offset(-1280, -360),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(name: 'name', type: 'varchar(160)', nullable: false),
        _ColumnTemplate(
          name: 'owner_account_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'account',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'parent_org_id',
          type: 'uuid',
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
      ],
    ),
    _TableTemplate(
      id: 'role',
      name: 'role',
      color: auth,
      anchor: Offset(-1280, -80),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(name: 'name', type: 'varchar(80)', nullable: false),
        _ColumnTemplate(
          name: 'parent_role_id',
          type: 'uuid',
          referencesTableId: 'role',
          referencesColumnName: 'id',
        ),
      ],
    ),
    _TableTemplate(
      id: 'membership',
      name: 'membership',
      color: auth,
      anchor: Offset(-1280, 180),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'account_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'account',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'role_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'role',
          referencesColumnName: 'id',
        ),
      ],
    ),
    _TableTemplate(
      id: 'category',
      name: 'category',
      color: catalog,
      anchor: Offset(-760, -640),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'parent_category_id',
          type: 'uuid',
          referencesTableId: 'category',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'name', type: 'varchar(160)', nullable: false),
        _ColumnTemplate(name: 'slug', type: 'varchar(160)', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'product',
      name: 'product',
      color: catalog,
      anchor: Offset(-760, -300),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'category_id',
          type: 'uuid',
          referencesTableId: 'category',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'sku', type: 'varchar(80)', nullable: false),
        _ColumnTemplate(name: 'name', type: 'varchar(160)', nullable: false),
        _ColumnTemplate(name: 'price_cents', type: 'int', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'employee',
      name: 'employee',
      color: sales,
      anchor: Offset(-240, -640),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'manager_id',
          type: 'uuid',
          referencesTableId: 'employee',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'full_name',
          type: 'varchar(160)',
          nullable: false,
        ),
        _ColumnTemplate(name: 'title', type: 'varchar(120)', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'customer',
      name: 'customer',
      color: sales,
      anchor: Offset(-240, -300),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'account_manager_id',
          type: 'uuid',
          referencesTableId: 'employee',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'name', type: 'varchar(160)', nullable: false),
        _ColumnTemplate(name: 'tier', type: 'smallint', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'sales_order',
      name: 'sales_order',
      color: sales,
      anchor: Offset(280, -500),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'customer_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'customer',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'created_by',
          type: 'uuid',
          referencesTableId: 'employee',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'status', type: 'varchar(24)', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'sales_order_item',
      name: 'sales_order_item',
      color: sales,
      anchor: Offset(760, -500),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'order_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'sales_order',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'product_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'product',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'qty', type: 'int', nullable: false),
        _ColumnTemplate(name: 'unit_price_cents', type: 'int', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'comment',
      name: 'comment',
      color: ops,
      anchor: Offset(280, -120),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'uuid',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'order_id',
          type: 'uuid',
          nullable: false,
          referencesTableId: 'sales_order',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'parent_comment_id',
          type: 'uuid',
          referencesTableId: 'comment',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'author_account_id',
          type: 'uuid',
          referencesTableId: 'account',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(name: 'body', type: 'text', nullable: false),
      ],
    ),
    _TableTemplate(
      id: 'event_log',
      name: 'event_log',
      color: ops,
      anchor: Offset(760, -120),
      columns: [
        _ColumnTemplate(
          name: 'id',
          type: 'bigserial',
          primaryKey: true,
          nullable: false,
        ),
        _ColumnTemplate(
          name: 'organization_id',
          type: 'uuid',
          referencesTableId: 'organization',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'actor_account_id',
          type: 'uuid',
          referencesTableId: 'account',
          referencesColumnName: 'id',
        ),
        _ColumnTemplate(
          name: 'entity_type',
          type: 'varchar(80)',
          nullable: false,
        ),
        _ColumnTemplate(name: 'entity_id', type: 'uuid', nullable: false),
        _ColumnTemplate(
          name: 'created_at',
          type: 'timestamptz',
          nullable: false,
        ),
      ],
    ),
  ];
}
