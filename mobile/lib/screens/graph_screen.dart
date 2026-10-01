import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphNode {
  String label;
  double riskScore;
  int id;
  Offset position;
  Offset velocity;
  bool compromised;

  _GraphNode({
    required this.label,
    required this.riskScore,
    required this.id,
    required this.position,
  }) : velocity = Offset.zero,
       compromised = false;
}

class _GraphEdge {
  int from;
  int to;
  String type;

  _GraphEdge({required this.from, required this.to, required this.type});
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<_GraphNode> _nodes = [];
  List<_GraphEdge> _edges = [];
  bool _loading = true;
  int? _selectedNode;
  late AnimationController _animController;
  String _selectedFilter = 'All';
  final _filterTypes = [
    'All',
    'SSO',
    'Recovery',
    'Password Reuse',
    'Data Sharing',
  ];
  final _filterTypeKeys = {
    'All': null,
    'SSO': 'sso',
    'Recovery': 'recovery_email',
    'Password Reuse': 'password_reuse',
    'Data Sharing': 'data_sharing',
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_simulate);
    _loadGraph();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadGraph() async {
    try {
      final data = await _api.get('/graph/');
      final nodes = (data['nodes'] as List?) ?? [];
      final edges = (data['edges'] as List?) ?? [];
      final rng = Random(42);
      setState(() {
        _nodes = nodes.asMap().entries.map((entry) {
          final n = entry.value;
          return _GraphNode(
            id: int.tryParse(n['id'].toString()) ?? entry.key,
            label: n['label'] ?? n['service_name'] ?? 'Unknown',
            riskScore: ((n['riskScore'] ?? n['risk_score'] ?? 0) as num)
                .toDouble(),
            position: Offset(
              100 + rng.nextDouble() * 200,
              100 + rng.nextDouble() * 300,
            ),
          );
        }).toList();
        _edges = edges.map((e) {
          return _GraphEdge(
            from:
                int.tryParse(
                  (e['from'] ?? e['source'] ?? e['from_account_id'] ?? '0')
                      .toString(),
                ) ??
                0,
            to:
                int.tryParse(
                  (e['to'] ?? e['target'] ?? e['to_account_id'] ?? '0')
                      .toString(),
                ) ??
                0,
            type: e['type'] ?? e['connection_type'] ?? 'unknown',
          );
        }).toList();
        _loading = false;
      });
      _animController.repeat();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _animController.stop();
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _simulate() {
    if (_nodes.length < 2) return;
    const k = 80.0;
    const gravity = 0.01;
    final center = const Offset(200, 250);

    for (final node in _nodes) {
      var force = Offset.zero;
      for (final other in _nodes) {
        if (other.id == node.id) continue;
        var d = node.position - other.position;
        final dist = max(d.distance, 1.0);
        force += d / dist * (k * k / dist);
      }
      for (final edge in _edges) {
        _GraphNode? other;
        if (edge.from == node.id) {
          other = _nodes.where((n) => n.id == edge.to).firstOrNull;
        }
        if (edge.to == node.id) {
          other = _nodes.where((n) => n.id == edge.from).firstOrNull;
        }
        if (other == null) continue;
        final d = other.position - node.position;
        final dist = max(d.distance, 1.0);
        force += d / dist * (dist - k) * 0.1;
      }
      force += (center - node.position) * gravity;
      node.velocity = (node.velocity + force) * 0.85;
      node.position += node.velocity;
    }
    setState(() {});
  }

  Future<void> _addDataSharingConnection() async {
    if (_nodes.length < 2) return;
    int fromId = _nodes.first.id;
    int toId = _nodes[1].id;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Map a data-sharing link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: fromId,
                decoration: const InputDecoration(labelText: 'Source account'),
                items: _nodes
                    .map(
                      (node) => DropdownMenuItem(
                        value: node.id,
                        child: Text(node.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => fromId = value ?? fromId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: toId,
                decoration: const InputDecoration(
                  labelText: 'Connected account',
                ),
                items: _nodes
                    .where((node) => node.id != fromId)
                    .map(
                      (node) => DropdownMenuItem(
                        value: node.id,
                        child: Text(node.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => toId = value ?? toId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: fromId == toId
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Add link'),
            ),
          ],
        ),
      ),
    );
    if (created != true) return;
    try {
      await _api.post(
        '/accounts/connections',
        body: {
          'from_account_id': fromId,
          'to_account_id': toId,
          'connection_type': 'data_sharing',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection added to your risk graph.')),
        );
        await _loadGraph();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add connection: $e')));
      }
    }
  }

  Color _nodeColor(_GraphNode node) {
    if (node.compromised) return AppColors.red;
    if (node.id == _selectedNode) return AppColors.cyan;
    if (node.riskScore >= 75) return AppColors.red;
    if (node.riskScore >= 50) return AppColors.orange;
    if (node.riskScore >= 25) return AppColors.blue;
    return AppColors.green;
  }

  Color _edgeColor(String type) {
    switch (type) {
      case 'sso':
        return AppColors.purple;
      case 'recovery':
        return AppColors.orange;
      case 'password_reuse':
        return AppColors.red;
      case 'data_sharing':
        return AppColors.cyan;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (_nodes.isEmpty) {
      return const Center(
        child: Text(
          'Add accounts and connections to see the graph',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    // Filter edges based on selected filter
    final filteredEdges = _selectedFilter == 'All'
        ? _edges
        : _edges
              .where((e) => e.type == _filterTypeKeys[_selectedFilter])
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_selectedNode != null) ...[
                Expanded(
                  child: Text(
                    'Selected: ${_nodes.firstWhere((n) => n.id == _selectedNode, orElse: () => _nodes.first).label}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/hack-me', arguments: _selectedNode),
                  icon: const Icon(Icons.bug_report, size: 18),
                  label: const Text('Hack Me'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Text(
                    'Tap a node to select it',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                IconButton(
                  tooltip: 'Map data-sharing connection',
                  onPressed: _nodes.length < 2
                      ? null
                      : _addDataSharingConnection,
                  icon: const Icon(Icons.add_link, color: AppColors.blue),
                ),
              ],
            ],
          ),
        ),
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _filterTypes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final isSelected = _filterTypes[i] == _selectedFilter;
              return ChoiceChip(
                label: Text(_filterTypes[i]),
                selected: isSelected,
                selectedColor: AppColors.blue,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                ),
                onSelected: (_) =>
                    setState(() => _selectedFilter = _filterTypes[i]),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTapDown: (details) {
                  for (final node in _nodes) {
                    if ((node.position - details.localPosition).distance < 24) {
                      setState(() => _selectedNode = node.id);
                      return;
                    }
                  }
                  setState(() => _selectedNode = null);
                },
                child: CustomPaint(
                  painter: _GraphPainter(
                    nodes: _nodes,
                    edges: filteredEdges,
                    nodeColor: _nodeColor,
                    edgeColor: _edgeColor,
                  ),
                  size: Size.infinite,
                ),
              ),
              // Mini-map
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CustomPaint(
                    painter: _MiniMapPainter(
                      nodes: _nodes,
                      nodeColor: _nodeColor,
                    ),
                    size: const Size(100, 100),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _legendItem(AppColors.purple, 'SSO'),
          _legendItem(AppColors.orange, 'Recovery'),
          _legendItem(AppColors.red, 'Password Reuse'),
          _legendItem(AppColors.cyan, 'Data Sharing'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final List<_GraphEdge> edges;
  final Color Function(_GraphNode) nodeColor;
  final Color Function(String) edgeColor;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.nodeColor,
    required this.edgeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = nodes.where((n) => n.id == edge.from).firstOrNull;
      final to = nodes.where((n) => n.id == edge.to).firstOrNull;
      if (from == null || to == null) continue;
      canvas.drawLine(
        from.position,
        to.position,
        Paint()
          ..color = edgeColor(edge.type).withAlpha(120)
          ..strokeWidth = 1.5,
      );
    }
    for (final node in nodes) {
      final color = nodeColor(node);
      canvas.drawCircle(
        node.position,
        20,
        Paint()..color = color.withAlpha(50),
      );
      canvas.drawCircle(node.position, 14, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: node.label.length > 8
              ? '${node.label.substring(0, 8)}..'
              : node.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, node.position - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MiniMapPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final Color Function(_GraphNode) nodeColor;

  _MiniMapPainter({required this.nodes, required this.nodeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final node in nodes) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dx > maxX) maxX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
      if (node.position.dy > maxY) maxY = node.position.dy;
    }

    final rangeX = max(maxX - minX, 1.0);
    final rangeY = max(maxY - minY, 1.0);
    final padding = 8.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    for (final node in nodes) {
      final x = padding + ((node.position.dx - minX) / rangeX) * drawW;
      final y = padding + ((node.position.dy - minY) / rangeY) * drawH;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = nodeColor(node));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
