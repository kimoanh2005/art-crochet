import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/crochet_chart.dart';
import '../models/stitch_type.dart';
import '../models/user_profile.dart';
import '../models/yarn_color.dart';
import '../services/crochet_api.dart';

class AppState extends ChangeNotifier {
  AppState({CrochetApi? api}) : _api = api ?? CrochetApi.instance;

  final CrochetApi _api;
  final List<CrochetChart> _charts = [];
  final List<YarnColor> _yarnColors = [];
  final List<StitchType> _stitchTypes = [];
  StreamSubscription<AuthState>? _authSubscription;
  UserProfile _profile = const UserProfile(displayName: '', email: '');
  bool _isAuthenticated = false;
  bool _isInitializing = true;
  String? _initializationError;
  String? _loadedUserId;
  String? _loadingUserId;
  Future<void>? _activeLoad;
  int _loadGeneration = 0;

  List<CrochetChart> get charts => List.unmodifiable(_charts);
  List<YarnColor> get yarnColors => List.unmodifiable(_yarnColors);
  UserProfile get profile => _profile;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  String? get initializationError => _initializationError;
  List<StitchType> get stitchTypes => List.unmodifiable(_stitchTypes);

  Future<void> initialize() async {
    _isInitializing = true;
    _initializationError = null;
    notifyListeners();
    await _authSubscription?.cancel();
    _authSubscription = _api.authChanges.listen(_handleAuthState);

    try {
      final user = _api.currentUser;
      if (user == null) {
        _clearUserData();
      } else {
        _isAuthenticated = true;
        await _loadUserData(user.id);
      }
    } catch (error) {
      _initializationError = error.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> retryInitialization() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await initialize();
  }

  void _handleAuthState(AuthState state) {
    final user = state.session?.user;
    if (user == null) {
      _clearUserData();
      notifyListeners();
      return;
    }
    if (_loadedUserId != null && _loadedUserId != user.id) {
      _clearUserData();
    }
    _isAuthenticated = true;
    if (_loadedUserId == user.id || _loadingUserId == user.id) {
      notifyListeners();
      return;
    }
    _loadUserData(user.id).catchError((Object error) {
      _initializationError = error.toString();
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String userId) {
    if (_loadedUserId == userId && _initializationError == null) {
      return Future<void>.value();
    }
    if (_loadingUserId == userId && _activeLoad != null) {
      return _activeLoad!;
    }

    _loadingUserId = userId;
    final generation = ++_loadGeneration;
    final load = _performLoad(userId, generation);
    _activeLoad = load;
    return load.whenComplete(() {
      if (_loadingUserId == userId) {
        _loadingUserId = null;
        _activeLoad = null;
      }
    });
  }

  Future<void> _performLoad(String userId, int generation) async {
    final results = await Future.wait<Object?>([
      _api.getProfile(),
      _api.getCharts(),
      _api.getYarnColors(),
      _api.getStitchTypes(),
    ]);

    final user = _api.currentUser;
    if (generation != _loadGeneration || user?.id != userId) return;

    var profileRow = results[0] as Map<String, dynamic>?;
    if (profileRow == null) {
      final metadata = user?.userMetadata ?? const <String, dynamic>{};
      final displayName =
          metadata['display_name']?.toString() ??
          user?.email?.split('@').first ??
          '';
      profileRow = await _api.upsertProfile(displayName: displayName);
    }

    final chartRows = results[1] as List<Map<String, dynamic>>;
    final loadedCharts = await Future.wait(chartRows.map(_loadChart));
    if (generation != _loadGeneration || _api.currentUser?.id != userId) return;

    _profile = UserProfile(
      displayName: _stringValue(profileRow['display_name']),
      email: _api.currentUser?.email ?? '',
      bio: _stringValue(profileRow['bio']),
    );
    _charts
      ..clear()
      ..addAll(loadedCharts);
    _yarnColors
      ..clear()
      ..addAll(
        (results[2] as List<Map<String, dynamic>>).map(_yarnColorFromRow),
      );
    _stitchTypes
      ..clear()
      ..addAll(
        (results[3] as List<Map<String, dynamic>>).map(_stitchTypeFromRow),
      );
    _loadedUserId = userId;
    _isAuthenticated = true;
    _initializationError = null;
    notifyListeners();
  }

  Future<CrochetChart> _loadChart(Map<String, dynamic> row) async {
    final id = _stringValue(row['id']);
    final chartType = _chartTypeFromValue(row['chart_type']);
    final results = await Future.wait<Object?>([
      _api.getProgress(id),
      if (chartType == ChartType.pixel) _api.getPixelCells(id),
      if (chartType != ChartType.pixel) _api.getChartStitches(id),
      if (chartType != ChartType.pixel) _api.getChartSections(id),
    ]);

    final progress = results[0] as Map<String, dynamic>?;
    final cells = <String, ChartCellData>{};
    final instructions = <int, String>{};

    if (chartType == ChartType.pixel) {
      for (final cellRow in results[1] as List<Map<String, dynamic>>) {
        final stitch = _nestedRow(cellRow['stitch_types']);
        final color = _nestedRow(cellRow['chart_colors']);
        final cell = ChartCellData(
          row: _intValue(cellRow['row_index']),
          column: _intValue(cellRow['col_index']),
          stitchCode: stitch == null ? '' : _stringValue(stitch['code']),
          colorHex: _stringValue(color?['hex_code'], fallback: '#FFFFFF'),
        );
        cells[cell.key] = cell;
      }
    } else {
      for (final stitchRow in results[1] as List<Map<String, dynamic>>) {
        final stitchType = _nestedRow(stitchRow['stitch_types']);
        if (stitchType == null) {
          throw const FormatException(
            'Một ký hiệu trong chart không có loại mũi hợp lệ.',
          );
        }
        final section = _intValue(stitchRow['section_index']);
        final sequence = _intValue(stitchRow['sequence_index']);
        final cell = ChartCellData(
          row: section,
          column: sequence,
          stitchCode: _stringValue(stitchType['code']),
          colorHex: _stringValue(stitchRow['color_hex']),
          positionX: _doubleValue(stitchRow['position_x']),
          positionY: _doubleValue(stitchRow['position_y']),
        );
        cells['stitch-${_stringValue(stitchRow['id'])}'] = cell;
      }
      for (final sectionRow in results[2] as List<Map<String, dynamic>>) {
        final instruction = _stringValue(sectionRow['instruction_text']);
        if (instruction.isNotEmpty) {
          instructions[_intValue(sectionRow['section_index'])] = instruction;
        }
      }
    }

    final rowsCount = _intValue(row['rows_count']);
    final completedRows = _intValue(
      progress?['completed_rows'] ?? 0,
    ).clamp(0, rowsCount);
    return CrochetChart(
      id: id,
      name: _stringValue(row['name']),
      category: _stringValue(row['category']),
      description: _stringValue(row['description']),
      chartType: chartType,
      rowsCount: rowsCount,
      columnsCount: _intValue(row['cols_count']),
      status: _chartStatusFromValue(progress?['status']),
      completedRows: completedRows,
      isFavorite: row['is_favorite'] == true,
      updatedAt: DateTime.parse(_stringValue(row['updated_at'])),
      notes: _stringValue(progress?['notes']),
      cells: cells,
      instructions: instructions,
    );
  }

  void _clearUserData() {
    _loadGeneration++;
    _loadedUserId = null;
    _loadingUserId = null;
    _activeLoad = null;
    _isAuthenticated = false;
    _initializationError = null;
    _profile = const UserProfile(displayName: '', email: '');
    _charts.clear();
    _yarnColors.clear();
    _stitchTypes.clear();
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await _api.signIn(email: email, password: password);
    final userId = response.user?.id;
    if (userId == null) {
      throw StateError(
        'Supabase không trả về thông tin tài khoản sau đăng nhập.',
      );
    }
    _isAuthenticated = true;
    await _loadUserData(userId);
  }

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _api.signUp(
      displayName: displayName,
      email: email,
      password: password,
    );
    final userId = response.session?.user.id;
    if (userId == null) return false;
    _isAuthenticated = true;
    await _loadUserData(userId);
    return true;
  }

  Future<void> signOut() async {
    await _api.signOut();
    _clearUserData();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String displayName,
    required String email,
    required String bio,
  }) async {
    if (email.trim() != (_api.currentUser?.email ?? '')) {
      await _api.updateAuthEmail(email);
    }
    final row = await _api.upsertProfile(displayName: displayName, bio: bio);
    _profile = UserProfile(
      displayName: _stringValue(row['display_name']),
      email: _api.currentUser?.email ?? '',
      bio: _stringValue(row['bio']),
    );
    notifyListeners();
  }

  CrochetChart? chartById(String id) {
    for (final chart in _charts) {
      if (chart.id == id) return chart;
    }
    return null;
  }

  Future<CrochetChart> createChart({
    required String name,
    required String category,
    required String description,
    required ChartType chartType,
    required int rows,
    required int columns,
  }) async {
    final row = await _api.createChart(
      name: name,
      category: category,
      description: description,
      chartType: _chartTypeToValue(chartType),
      rowsCount: rows,
      colsCount: columns,
    );
    final chart = CrochetChart(
      id: _stringValue(row['id']),
      name: _stringValue(row['name']),
      category: _stringValue(row['category']),
      description: _stringValue(row['description']),
      chartType: _chartTypeFromValue(row['chart_type']),
      rowsCount: _intValue(row['rows_count']),
      columnsCount: _intValue(row['cols_count']),
      status: ChartStatus.notStarted,
      completedRows: 0,
      isFavorite: row['is_favorite'] == true,
      updatedAt: DateTime.parse(_stringValue(row['updated_at'])),
    );
    _charts.insert(0, chart);
    notifyListeners();
    return chart;
  }

  Future<void> updateChart(CrochetChart chart) async {
    final cells = chart.chartType == ChartType.pixel
        ? chart.cells
        : _normalizeFreeformCells(chart.cells);
    final updatedRow = await _api.updateChart(
      chartId: chart.id,
      name: chart.name,
      category: chart.category,
      description: chart.description,
      rowsCount: chart.rowsCount,
      colsCount: chart.columnsCount,
    );

    if (chart.chartType == ChartType.pixel) {
      final colorsByHex = <String, Map<String, dynamic>>{};
      final pixelCells = <Map<String, dynamic>>[];
      for (final cell in cells.values) {
        colorsByHex.putIfAbsent(cell.colorHex, () {
          return {
            'id': _newUuid(),
            'color_name': cell.colorHex,
            'hex_code': cell.colorHex,
          };
        });
        pixelCells.add({
          'row_index': cell.row,
          'col_index': cell.column,
          'stitch_code': cell.stitchCode,
          'hex_code': cell.colorHex,
        });
      }
      await _api.savePixelDesign(
        chartId: chart.id,
        colors: colorsByHex.values.toList(),
        cells: pixelCells,
      );
    } else {
      final stitches = cells.values.toList()
        ..sort((a, b) {
          final rowOrder = a.row.compareTo(b.row);
          return rowOrder != 0 ? rowOrder : a.column.compareTo(b.column);
        });
      await _api.saveStitchDesign(
        chartId: chart.id,
        stitches: [
          for (final cell in stitches)
            {
              'section_index': cell.row,
              'sequence_index': cell.column,
              'position_x': cell.positionX,
              'position_y': cell.positionY,
              'stitch_code': cell.stitchCode,
              'color_hex': cell.colorHex,
            },
        ],
        sections: [
          for (final entry in chart.instructions.entries)
            {'section_index': entry.key, 'instruction_text': entry.value},
        ],
      );
    }

    await _api.saveProgress(
      chartId: chart.id,
      completedRows: chart.completedRows,
      currentRow: chart.currentRow,
      status: _chartStatusToValue(chart.status),
      notes: chart.notes,
    );

    final index = _charts.indexWhere((item) => item.id == chart.id);
    if (index < 0) return;
    _charts[index] = chart.copyWith(
      cells: cells,
      updatedAt: DateTime.parse(_stringValue(updatedRow['updated_at'])),
    );
    notifyListeners();
  }

  Future<CrochetChart?> duplicateChart(String id) async {
    final chart = chartById(id);
    if (chart == null) return null;
    final copy = await createChart(
      name: '${chart.name} (bản sao)',
      category: chart.category,
      description: chart.description,
      chartType: chart.chartType,
      rows: chart.rowsCount,
      columns: chart.columnsCount,
    );
    try {
      final duplicate = copy.copyWith(
        cells: Map.of(chart.cells),
        instructions: Map.of(chart.instructions),
      );
      await updateChart(duplicate);
      return chartById(copy.id);
    } catch (error) {
      try {
        await _api.deleteChart(copy.id);
        _charts.removeWhere((item) => item.id == copy.id);
        notifyListeners();
      } catch (cleanupError) {
        throw StateError(
          'Không thể sao chép chart ($error); đồng thời không thể xóa chart '
          'tạo dở ($cleanupError).',
        );
      }
      rethrow;
    }
  }

  Future<void> toggleFavorite(String id) async {
    final chart = chartById(id);
    if (chart == null) return;
    final row = await _api.setFavorite(
      chartId: id,
      isFavorite: !chart.isFavorite,
    );
    final index = _charts.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _charts[index] = chart.copyWith(
      isFavorite: row['is_favorite'] == true,
      updatedAt: DateTime.parse(_stringValue(row['updated_at'])),
    );
    notifyListeners();
  }

  Future<void> deleteChart(String id) async {
    await _api.deleteChart(id);
    _charts.removeWhere((chart) => chart.id == id);
    notifyListeners();
  }

  Future<void> markCurrentRowComplete(String id) async {
    final chart = chartById(id);
    if (chart == null || chart.completedRows >= chart.rowsCount) return;
    final row = await _api.completeNextRow(chartId: id, notes: chart.notes);
    final index = _charts.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _charts[index] = chart.copyWith(
      completedRows: _intValue(row['completed_rows']),
      status: _chartStatusFromValue(row['status']),
      updatedAt: DateTime.parse(_stringValue(row['updated_at'])),
    );
    notifyListeners();
  }

  Future<void> addYarnColor(YarnColor color) async {
    final row = await _api.addYarnColor(
      name: color.name,
      hexCode: color.hexCode,
      brand: color.brand,
      yarnCode: color.yarnCode,
    );
    _yarnColors.insert(0, _yarnColorFromRow(row));
    notifyListeners();
  }

  Future<void> updateYarnColor(YarnColor color) async {
    final row = await _api.updateYarnColor(
      id: color.id,
      name: color.name,
      hexCode: color.hexCode,
      brand: color.brand,
      yarnCode: color.yarnCode,
    );
    final index = _yarnColors.indexWhere((item) => item.id == color.id);
    if (index < 0) return;
    _yarnColors[index] = _yarnColorFromRow(row);
    notifyListeners();
  }

  Future<void> deleteYarnColor(String id) async {
    await _api.deleteYarnColor(id);
    _yarnColors.removeWhere((color) => color.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this context.');
    return scope!.notifier!;
  }
}

StitchType _stitchTypeFromRow(Map<String, dynamic> row) => StitchType(
  code: _stringValue(row['code']),
  name: _stringValue(row['name']),
  symbol: _stringValue(row['symbol']),
  description: _stringValue(row['description']),
);

YarnColor _yarnColorFromRow(Map<String, dynamic> row) => YarnColor(
  id: _stringValue(row['id']),
  name: _stringValue(row['name']),
  hexCode: _stringValue(row['hex_code']),
  brand: _stringValue(row['brand']),
  yarnCode: _stringValue(row['yarn_code']),
);

ChartType _chartTypeFromValue(Object? value) => switch (value) {
  'pixel' => ChartType.pixel,
  'stitch_symbols' => ChartType.stitchSymbols,
  'circular' => ChartType.circular,
  _ => throw FormatException('Kiểu chart Supabase không hợp lệ: $value'),
};

String _chartTypeToValue(ChartType value) => switch (value) {
  ChartType.pixel => 'pixel',
  ChartType.stitchSymbols => 'stitch_symbols',
  ChartType.circular => 'circular',
};

ChartStatus _chartStatusFromValue(Object? value) => switch (value) {
  null || 'not_started' => ChartStatus.notStarted,
  'in_progress' => ChartStatus.inProgress,
  'completed' => ChartStatus.completed,
  _ => throw FormatException('Trạng thái chart Supabase không hợp lệ: $value'),
};

String _chartStatusToValue(ChartStatus value) => switch (value) {
  ChartStatus.notStarted => 'not_started',
  ChartStatus.inProgress => 'in_progress',
  ChartStatus.completed => 'completed',
};

Map<String, dynamic>? _nestedRow(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is List &&
      value.isNotEmpty &&
      value.first is Map<String, dynamic>) {
    return value.first as Map<String, dynamic>;
  }
  throw const FormatException('Dữ liệu quan hệ Supabase không hợp lệ.');
}

String _stringValue(Object? value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

int _intValue(Object? value) => switch (value) {
  num number => number.toInt(),
  null => throw const FormatException('Thiếu giá trị số bắt buộc từ Supabase.'),
  _ => throw FormatException('Giá trị số Supabase không hợp lệ: $value'),
};

double _doubleValue(Object? value) => switch (value) {
  num number => number.toDouble(),
  _ => throw FormatException('Tọa độ Supabase không hợp lệ: $value'),
};

Map<String, ChartCellData> _normalizeFreeformCells(
  Map<String, ChartCellData> cells,
) {
  final rows = <int, List<MapEntry<String, ChartCellData>>>{};
  for (final entry in cells.entries) {
    rows.putIfAbsent(entry.value.row, () => []).add(entry);
  }

  final normalized = <String, ChartCellData>{};
  for (final row in rows.values) {
    row.sort((a, b) => a.value.column.compareTo(b.value.column));
    for (var index = 0; index < row.length; index++) {
      final entry = row[index];
      final cell = entry.value;
      normalized[entry.key] = ChartCellData(
        row: cell.row,
        column: index,
        stitchCode: cell.stitchCode,
        colorHex: cell.colorHex,
        positionX: cell.positionX,
        positionY: cell.positionY,
      );
    }
  }
  return normalized;
}

String _newUuid() {
  final generator = Random.secure();
  final random = List<int>.generate(16, (_) => generator.nextInt(256));
  random[6] = (random[6] & 0x0f) | 0x40;
  random[8] = (random[8] & 0x3f) | 0x80;
  final hex = random
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
