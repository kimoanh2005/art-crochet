import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// API layer cho Art Crochet.
/// Bao gồm Supabase Auth, hồ sơ, chart, thiết kế, tiến độ, màu len và export.
///
/// Cách dùng:
/// final api = CrochetApi.instance;
/// final charts = await api.getCharts();
class CrochetApi {
  CrochetApi._();

  static final CrochetApi instance = CrochetApi._();

  final SupabaseClient _db = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  User? get currentUser => _db.auth.currentUser;
  String get _userId {
    final user = currentUser;
    if (user == null)
      throw StateError('Bạn cần đăng nhập để thực hiện thao tác này.');
    return user.id;
  }

  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  String _now() => DateTime.now().toUtc().toIso8601String();

  List<Map<String, dynamic>> _rows(dynamic value) =>
      List<Map<String, dynamic>>.from(value as List);

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  void _checkChartType(String chartType) {
    if (!const ['pixel', 'stitch_symbols', 'circular'].contains(chartType)) {
      throw ArgumentError(
        'chartType phải là pixel, stitch_symbols hoặc circular.',
      );
    }
  }

  void _checkDimensions(int rows, int cols) {
    if (rows < 2 || rows > 50 || cols < 2 || cols > 50) {
      throw ArgumentError('Số hàng và số cột phải nằm trong khoảng 2–50.');
    }
  }

  // ---------------------------------------------------------------------------
  // 1. AUTH
  // ---------------------------------------------------------------------------

  Future<AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
  }) {
    if (password.length < 6) {
      throw ArgumentError('Mật khẩu cần có ít nhất 6 ký tự.');
    }
    return _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) {
    return _db.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);
  }

  Future<UserResponse> updatePassword(String newPassword) {
    if (newPassword.length < 6) {
      throw ArgumentError('Mật khẩu mới cần có ít nhất 6 ký tự.');
    }
    return _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> updateAuthEmail(String newEmail) async {
    await _db.auth.updateUser(UserAttributes(email: newEmail.trim()));
    // Supabase có thể yêu cầu xác nhận email mới.
  }

  // ---------------------------------------------------------------------------
  // 2. PROFILE
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getProfile() async {
    final result = await _db
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    return result == null ? null : _map(result);
  }

  Future<Map<String, dynamic>> upsertProfile({
    required String displayName,
    String bio = '',
    String? avatarUrl,
  }) async {
    final result = await _db
        .from('profiles')
        .upsert({
          'id': _userId,
          'display_name': displayName.trim(),
          'bio': bio.trim(),
          'avatar_url': avatarUrl,
          'updated_at': _now(),
        })
        .select()
        .single();
    return _map(result);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{'updated_at': _now()};
    if (displayName != null) data['display_name'] = displayName.trim();
    if (bio != null) data['bio'] = bio.trim();
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    final result = await _db
        .from('profiles')
        .update(data)
        .eq('id', _userId)
        .select()
        .single();
    return _map(result);
  }

  // ---------------------------------------------------------------------------
  // 3. STITCH TYPES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getStitchTypes() async {
    final result = await _db.from('stitch_types').select().order('sort_order');
    return _rows(result);
  }

  Future<Map<String, dynamic>?> getStitchTypeByCode(String code) async {
    final result = await _db
        .from('stitch_types')
        .select()
        .eq('code', code)
        .maybeSingle();
    return result == null ? null : _map(result);
  }

  // ---------------------------------------------------------------------------
  // 4. CHARTS CRUD + SEARCH/FILTER
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCharts({
    String? category,
    String? chartType,
    bool? favoriteOnly,
    String? search,
  }) async {
    var query = _db.from('charts').select().eq('user_id', _userId);
    if (category != null && category.isNotEmpty)
      query = query.eq('category', category);
    if (chartType != null && chartType.isNotEmpty) {
      _checkChartType(chartType);
      query = query.eq('chart_type', chartType);
    }
    if (favoriteOnly == true) query = query.eq('is_favorite', true);
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }
    final result = await query.order('updated_at', ascending: false);
    return _rows(result);
  }

  Future<Map<String, dynamic>> getChart(String chartId) async {
    final result = await _db.from('charts').select().eq('id', chartId).single();
    return _map(result);
  }

  Future<Map<String, dynamic>> createChart({
    required String name,
    required String category,
    String description = '',
    required String chartType,
    required int rowsCount,
    required int colsCount,
  }) async {
    _checkChartType(chartType);
    _checkDimensions(rowsCount, colsCount);

    final chart = _map(
      await _db
          .from('charts')
          .insert({
            'user_id': _userId,
            'name': name.trim(),
            'category': category.trim(),
            'description': description.trim(),
            'chart_type': chartType,
            'rows_count': rowsCount,
            'cols_count': colsCount,
          })
          .select()
          .single(),
    );

    await _db.from('chart_progress').upsert({
      'chart_id': chart['id'],
      'user_id': _userId,
      'completed_rows': 0,
      'current_row': 1,
      'status': 'not_started',
      'updated_at': _now(),
    }, onConflict: 'chart_id,user_id');

    return chart;
  }

  Future<Map<String, dynamic>> updateChart({
    required String chartId,
    String? name,
    String? category,
    String? description,
    String? chartType,
    int? rowsCount,
    int? colsCount,
  }) async {
    final data = <String, dynamic>{'updated_at': _now()};
    if (name != null) data['name'] = name.trim();
    if (category != null) data['category'] = category.trim();
    if (description != null) data['description'] = description.trim();
    if (chartType != null) {
      _checkChartType(chartType);
      data['chart_type'] = chartType;
    }
    if (rowsCount != null || colsCount != null) {
      final existing = await getChart(chartId);
      _checkDimensions(
        rowsCount ?? (existing['rows_count'] as num).toInt(),
        colsCount ?? (existing['cols_count'] as num).toInt(),
      );
    }
    if (rowsCount != null) data['rows_count'] = rowsCount;
    if (colsCount != null) data['cols_count'] = colsCount;

    return _map(
      await _db.from('charts').update(data).eq('id', chartId).select().single(),
    );
  }

  Future<void> deleteChart(String chartId) async {
    await _db.from('charts').delete().eq('id', chartId);
  }

  Future<Map<String, dynamic>> setFavorite({
    required String chartId,
    required bool isFavorite,
  }) async {
    return _map(
      await _db
          .from('charts')
          .update({'is_favorite': isFavorite, 'updated_at': _now()})
          .eq('id', chartId)
          .select()
          .single(),
    );
  }

  Future<Map<String, dynamic>> toggleFavorite(String chartId) async {
    final chart = await getChart(chartId);
    return setFavorite(
      chartId: chartId,
      isFavorite: !(chart['is_favorite'] as bool? ?? false),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. PIXEL CHART DESIGN
  // RPC save_chart_design(p_chart_id, p_colors, p_cells)
  // colors: color_name, hex_code, yarn_brand, yarn_code
  // cells: row_index, col_index, stitch_code, hex_code
  // ---------------------------------------------------------------------------

  Future<void> savePixelDesign({
    required String chartId,
    required List<Map<String, dynamic>> colors,
    required List<Map<String, dynamic>> cells,
  }) async {
    await _db.rpc(
      'save_chart_design',
      params: {'p_chart_id': chartId, 'p_colors': colors, 'p_cells': cells},
    );
  }

  Future<List<Map<String, dynamic>>> getPixelColors(String chartId) async {
    return _rows(
      await _db.from('chart_colors').select().eq('chart_id', chartId),
    );
  }

  Future<List<Map<String, dynamic>>> getPixelCells(String chartId) async {
    return _rows(
      await _db
          .from('chart_cells')
          .select('*, stitch_types(*), chart_colors(*)')
          .eq('chart_id', chartId)
          .order('row_index')
          .order('col_index'),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. SYMBOL / CIRCULAR CHART DESIGN
  // RPC save_chart_stitches(p_chart_id, p_stitches, p_sections)
  // ---------------------------------------------------------------------------

  Future<void> saveStitchDesign({
    required String chartId,
    required List<Map<String, dynamic>> stitches,
    required List<Map<String, dynamic>> sections,
  }) async {
    await _db.rpc(
      'save_chart_stitches',
      params: {
        'p_chart_id': chartId,
        'p_stitches': stitches,
        'p_sections': sections,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getChartSections(String chartId) async {
    return _rows(
      await _db
          .from('chart_sections')
          .select()
          .eq('chart_id', chartId)
          .order('section_index'),
    );
  }

  Future<List<Map<String, dynamic>>> getChartStitches(String chartId) async {
    return _rows(
      await _db
          .from('chart_stitches')
          .select('*, stitch_types(*)')
          .eq('chart_id', chartId)
          .order('section_index')
          .order('sequence_index'),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. PROGRESS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getProgress(String chartId) async {
    final result = await _db
        .from('chart_progress')
        .select()
        .eq('chart_id', chartId)
        .eq('user_id', _userId)
        .maybeSingle();
    return result == null ? null : _map(result);
  }

  Future<Map<String, dynamic>> saveProgress({
    required String chartId,
    required int completedRows,
    required int currentRow,
    required String status,
    String? notes,
  }) async {
    if (!const ['not_started', 'in_progress', 'completed'].contains(status)) {
      throw ArgumentError('status không hợp lệ.');
    }
    if (completedRows < 0 || currentRow < 1) {
      throw ArgumentError('Số hàng hoàn thành không hợp lệ.');
    }
    return _map(
      await _db
          .from('chart_progress')
          .upsert({
            'chart_id': chartId,
            'user_id': _userId,
            'completed_rows': completedRows,
            'current_row': currentRow,
            'status': status,
            'notes': notes ?? '',
            'updated_at': _now(),
          }, onConflict: 'chart_id,user_id')
          .select()
          .single(),
    );
  }

  Future<Map<String, dynamic>> completeNextRow({
    required String chartId,
    String? notes,
  }) async {
    final chart = await getChart(chartId);
    final totalRows = (chart['rows_count'] as num).toInt();
    final progress = await getProgress(chartId);
    final completed = ((progress?['completed_rows'] as num?)?.toInt() ?? 0);
    final nextCompleted = (completed + 1).clamp(0, totalRows).toInt();
    final status = nextCompleted >= totalRows
        ? 'completed'
        : (nextCompleted == 0 ? 'not_started' : 'in_progress');

    return saveProgress(
      chartId: chartId,
      completedRows: nextCompleted,
      currentRow: nextCompleted >= totalRows ? totalRows : nextCompleted + 1,
      status: status,
      notes: notes ?? progress?['notes'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // 8. PERSONAL YARN COLORS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getYarnColors() async {
    return _rows(
      await _db
          .from('yarn_colors')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> addYarnColor({
    required String name,
    required String hexCode,
    String? brand,
    String? yarnCode,
  }) async {
    return _map(
      await _db
          .from('yarn_colors')
          .insert({
            'user_id': _userId,
            'name': name.trim(),
            'hex_code': hexCode.trim(),
            'brand': brand?.trim(),
            'yarn_code': yarnCode?.trim(),
          })
          .select()
          .single(),
    );
  }

  Future<Map<String, dynamic>> updateYarnColor({
    required String id,
    required String name,
    required String hexCode,
    String? brand,
    String? yarnCode,
  }) async {
    return _map(
      await _db
          .from('yarn_colors')
          .update({
            'name': name.trim(),
            'hex_code': hexCode.trim(),
            'brand': brand?.trim(),
            'yarn_code': yarnCode?.trim(),
            'updated_at': _now(),
          })
          .eq('id', id)
          .select()
          .single(),
    );
  }

  Future<void> deleteYarnColor(String id) async {
    await _db.from('yarn_colors').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 9. EXPORT RECORDS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> addExportRecord({
    required String chartId,
    required String fileType,
    required String fileUrl,
  }) async {
    if (!const ['png', 'pdf'].contains(fileType.toLowerCase())) {
      throw ArgumentError('fileType chỉ nhận png hoặc pdf.');
    }
    return _map(
      await _db
          .from('chart_exports')
          .insert({
            'chart_id': chartId,
            'user_id': _userId,
            'file_type': fileType.toLowerCase(),
            'file_url': fileUrl,
          })
          .select()
          .single(),
    );
  }

  Future<List<Map<String, dynamic>>> getExportRecords(String chartId) async {
    return _rows(
      await _db
          .from('chart_exports')
          .select()
          .eq('chart_id', chartId)
          .order('created_at', ascending: false),
    );
  }

  // ---------------------------------------------------------------------------
  // 10. SUPABASE STORAGE
  // Upload / delete / signed URL. Tạo bucket riêng trong Supabase Storage trước.
  // ---------------------------------------------------------------------------

  Future<String> uploadChartFile({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _db.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _db.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> createSignedFileUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) {
    return _db.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  Future<void> deleteStorageFile({
    required String bucket,
    required String path,
  }) {
    return _db.storage.from(bucket).remove([path]);
  }

  // ---------------------------------------------------------------------------
  // 11. DASHBOARD / STATISTICS
  // ---------------------------------------------------------------------------

  Future<Map<String, int>> getChartStatistics() async {
    final charts = await getCharts();
    var pixel = 0;
    var symbols = 0;
    var circular = 0;
    var favorites = 0;

    for (final chart in charts) {
      switch (chart['chart_type']) {
        case 'pixel':
          pixel++;
          break;
        case 'stitch_symbols':
          symbols++;
          break;
        case 'circular':
          circular++;
          break;
      }
      if (chart['is_favorite'] == true) favorites++;
    }

    return {
      'total': charts.length,
      'pixel': pixel,
      'stitch_symbols': symbols,
      'circular': circular,
      'favorites': favorites,
    };
  }
}
