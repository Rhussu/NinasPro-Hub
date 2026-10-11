import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/health_service.dart';

class DbHealthChecker extends StatefulWidget {
  final HealthService? healthService;
  final String? initialSupabaseUrl;
  final String? initialAnonKey;

  const DbHealthChecker({
    super.key,
    this.healthService,
    this.initialSupabaseUrl,
    this.initialAnonKey,
  });

  @override
  State<DbHealthChecker> createState() => _DbHealthCheckerState();
}

class _DbHealthCheckerState extends State<DbHealthChecker> {
  late final HealthService _healthService;
  late String _supabaseUrl;
  late String _anonKey;

  DbHealthResult? _result;
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _healthService = widget.healthService ?? HealthService();
    _supabaseUrl = widget.initialSupabaseUrl ?? AppConfig.supabaseUrl;
    _anonKey = widget.initialAnonKey ?? AppConfig.supabaseAnonKey;

    _runHealthCheck();
  }

  @override
  void dispose() {
    if (widget.healthService == null) {
      _healthService.dispose();
    }
    super.dispose();
  }

  Future<void> _runHealthCheck() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _result = DbHealthResult.checking('$_supabaseUrl${AppConfig.defaultHealthPath}');
    });

    final res = await _healthService.checkDatabaseHealth(
      supabaseUrl: _supabaseUrl,
      anonKey: _anonKey,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _result = res;
      });
    }
  }

  void _showConfigDialog() {
    final urlController = TextEditingController(text: _supabaseUrl);
    final keyController = TextEditingController(text: _anonKey);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.settings_suggest_rounded, color: Color(0xFF7B2CBF)),
            SizedBox(width: 8),
            Text('Configurar Conexión DB', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona un entorno predefinido o edita manualmente:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.computer_rounded, size: 14),
                    label: const Text('Local (CLI)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      urlController.text = AppConfig.localSupabaseUrl;
                      keyController.text = AppConfig.localAnonKey;
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.cloud_outlined, size: 14),
                    label: const Text('Nube / Personalizado', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      urlController.text = 'https://tu-proyecto.supabase.co';
                      keyController.text = '';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'SUPABASE_ANON_KEY',
                  hintText: 'eyJhbGciOiJIUzI1NiIsIn...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF6C5CE7)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En producción puedes pasarla al compilar con:\n--dart-define=SUPABASE_ANON_KEY=tu_clave',
                        style: TextStyle(fontSize: 11, color: Color(0xFF480CA8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
            ),
            onPressed: () {
              setState(() {
                _supabaseUrl = urlController.text.trim();
                _anonKey = keyController.text.trim();
              });
              Navigator.pop(ctx);
              _runHealthCheck();
            },
            child: const Text('Guardar y Probar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_isLoading) return const Color(0xFFF59E0B); // Amber
    if (_result == null) return const Color(0xFF9CA3AF);

    switch (_result!.state) {
      case DbHealthState.connected:
        return const Color(0xFF10B981); // Emerald Green
      case DbHealthState.unauthenticated:
        return const Color(0xFFF59E0B); // Amber / Warning
      case DbHealthState.error:
        return const Color(0xFFEF4444); // Red
      case DbHealthState.checking:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getStatusIcon() {
    if (_isLoading) return Icons.sync_rounded;
    if (_result == null) return Icons.help_outline_rounded;

    switch (_result!.state) {
      case DbHealthState.connected:
        return Icons.check_circle_rounded;
      case DbHealthState.unauthenticated:
        return Icons.warning_amber_rounded;
      case DbHealthState.error:
        return Icons.cancel_rounded;
      case DbHealthState.checking:
        return Icons.sync_rounded;
    }
  }

  String _getStatusText() {
    if (_isLoading) return 'Verificando DB...';
    if (_result == null) return 'DB Desconocida';

    switch (_result!.state) {
      case DbHealthState.connected:
        return 'DB: Conectada (${_result!.latencyMs ?? 0}ms)';
      case DbHealthState.unauthenticated:
        return 'DB: En línea (falta clave)';
      case DbHealthState.error:
        return 'DB: Error (${_result!.latencyMs ?? 0}ms)';
      case DbHealthState.checking:
        return 'Verificando DB...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText();

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          maxWidth: _isExpanded ? 340 : 280,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header / Compact bar
              Row(
                children: [
                  // Dot indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icon
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  // Text
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    onPressed: _isLoading ? null : _runHealthCheck,
                    tooltip: 'Reintentar chequeo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  // Expand/collapse toggle
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    tooltip: _isExpanded ? 'Contraer' : 'Ver detalles',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                ],
              ),

              // Expanded details
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildDetailRow('Servicio', 'Supabase PostgreSQL / PostgREST'),
                const SizedBox(height: 4),
                _buildDetailRow(
                  'Entorno',
                  _supabaseUrl.contains('127.0.0.1') || _supabaseUrl.contains('localhost')
                      ? 'Local (CLI :54321)'
                      : 'Nube (Cloud)',
                ),
                const SizedBox(height: 4),
                _buildDetailRow(
                  'Latencia',
                  _result?.latencyMs != null ? '${_result!.latencyMs} ms' : 'N/A',
                ),
                const SizedBox(height: 4),
                _buildDetailRow(
                  'Estado HTTP',
                  _result?.statusCode != null ? '${_result!.statusCode}' : 'N/A',
                ),
                const SizedBox(height: 4),
                _buildDetailRow(
                  'Último check',
                  _result != null
                      ? '${_result!.timestamp.hour.toString().padLeft(2, '0')}:${_result!.timestamp.minute.toString().padLeft(2, '0')}:${_result!.timestamp.second.toString().padLeft(2, '0')}'
                      : 'N/A',
                ),
                if (_result?.details != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _result!.details!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text('Configurar', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF7B2CBF),
                      ),
                      onPressed: _showConfigDialog,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
