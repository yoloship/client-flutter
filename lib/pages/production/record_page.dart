import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/request.dart';
import '../../providers/user_provider.dart';

class ProductionRecordPage extends StatefulWidget {
  const ProductionRecordPage({super.key});

  @override
  State<ProductionRecordPage> createState() => _ProductionRecordPageState();
}

class _ProductionRecordPageState extends State<ProductionRecordPage> {
  bool _isAdmin = false;
  Map<String, dynamic>? _manufacturer;
  List<dynamic> _allManufacturers = [];
  
  String _today = '';
  List<dynamic> _processes = [];
  String _selectedMaterial = '';
  int? _selectedProcessId;
  String _quantity = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      _isAdmin = user != null && (user['role'] == 'admin' || user['user_type'] == 'platform');
      
      _fetchProcesses();
      if (_isAdmin) {
        _fetchManufacturers();
      }
    });
  }

  Future<void> _fetchProcesses() async {
    try {
      final res = await RequestUtil.get('/mina/processes');
      if (res['data'] != null && mounted) {
        setState(() {
          _processes = res['data'];
          if (_processes.isNotEmpty) {
            _selectedMaterial = _materials.first;
            _autoSelectFirstProcess();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch processes: $e');
    }
  }

  Future<void> _fetchManufacturers() async {
    try {
      final res = await RequestUtil.get('/mina/manufacturers');
      if (res['data'] != null && mounted) {
        setState(() {
          _allManufacturers = res['data'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch manufacturers: $e');
    }
  }

  List<String> get _materials {
    final mats = <String>{};
    for (var p in _processes) {
      mats.add(p['material'] ?? '常规');
    }
    final list = mats.toList();
    list.sort((a, b) {
      if (a == '通用') return -1;
      if (b == '通用') return 1;
      return 0;
    });
    return list;
  }

  List<dynamic> get _currentProcesses {
    return _processes.where((p) => (p['material'] ?? '常规') == _selectedMaterial).toList();
  }

  void _autoSelectFirstProcess() {
    final current = _currentProcesses;
    if (current.isNotEmpty) {
      _selectedProcessId = current.first['ID'];
    } else {
      _selectedProcessId = null;
    }
  }

  void _showManufacturerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _allManufacturers.where((m) {
              final name = (m['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: '搜索工厂名称...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final m = filtered[index];
                            final isSelected = _manufacturer?['ID'] == m['ID'];
                            return ListTile(
                              title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${m['contact'] ?? '无'} | ${m['phone'] ?? '无'}'),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
                              onTap: () {
                                setState(() => _manufacturer = m);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _today = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submitRecord() async {
    if (_isAdmin && _manufacturer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择工厂')));
      return;
    }
    if (_selectedProcessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择工艺类型')));
      return;
    }
    final intQty = int.tryParse(_quantity);
    if (intQty == null || intQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正确的产量数值')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final process = _processes.firstWhere((p) => p['ID'] == _selectedProcessId);
      final payload = {
        'process_id': _selectedProcessId,
        'process_type': process['name'],
        'quantity': intQty,
        'record_date': '${_today}T00:00:00Z',
      };
      if (_isAdmin) {
        payload['manufacturer_id'] = _manufacturer!['ID'];
      }

      await RequestUtil.post('/mina/production-records', data: payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('产量录入成功', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('产量登记'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 厂家选择 (仅管理员)
            if (_isAdmin) ...[
              const Text('登记厂家', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showManufacturerPicker,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_manufacturer?['name'] ?? '点击选择工厂', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _manufacturer == null ? Colors.grey : Colors.black)),
                            if (_manufacturer != null) Text('地址 ${_manufacturer!['address'] ?? '未设置'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 生产日期
            const Text('生产日期', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(_today, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 工艺材质
            const Text('工艺材质', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _materials.map((mat) {
                final isSelected = _selectedMaterial == mat;
                return ChoiceChip(
                  label: Text(mat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedMaterial = mat;
                        _autoSelectFirstProcess();
                      });
                    }
                  },
                  selectedColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('选择工艺', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentProcesses.map((p) {
                final isSelected = _selectedProcessId == p['ID'];
                return InkWell(
                  onTap: () => setState(() => _selectedProcessId = p['ID']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : Colors.white,
                      border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p['display_name'] ?? p['name'],
                      style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 产量录入
            const Text('今日产量', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              decoration: InputDecoration(
                hintText: '请输入数值',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixText: 'PCS',
              ),
              onChanged: (val) => _quantity = val,
            ),
            
            const SizedBox(height: 100), // 留出底栏空间
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(
                    '$_quantity PCS',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              width: 160,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitRecord,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('确认录入系统', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
