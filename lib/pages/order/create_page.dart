import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../utils/request.dart';
import '../../providers/user_provider.dart';

class OrderItem {
  String id = UniqueKey().toString();
  String prefix = '';
  String productCode = '';
  String remark = '';
  String color = '';
  String size = '';
  int count = 0;
  bool isAiLoading = false;
}

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final List<OrderItem> _items = [OrderItem()];
  final ImagePicker _picker = ImagePicker();
  
  String _globalPrefix = '';
  bool _isSubmitting = false;

  void _syncGlobalPrefix(String val) {
    setState(() {
      _globalPrefix = val;
      for (var item in _items) {
        if (item.prefix.isEmpty) {
          item.prefix = val;
        }
      }
    });
  }

  Future<void> _takePhotoAndAnalyze(int index) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // 原生压缩
        maxWidth: 1600,
      );
      if (photo == null) return;

      setState(() {
        _items[index].isAiLoading = true;
      });

      // 1. 上传图片
      final String photoUrl = await RequestUtil.uploadPhoto(photo.path);

      // 2. 调用 AI 分析接口
      final userProvider = context.read<UserProvider>();
      final manufacturerId = userProvider.user?['manufacturer_id'] ?? 0;
      
      final aiRes = await RequestUtil.post('/orders/ai-analyze', data: {
        'photo_url': photoUrl,
        'manufacturer_id': manufacturerId,
      });

      if (aiRes['data'] != null) {
        final data = aiRes['data'];
        final aiProductCode = data['product_code'] ?? '';
        final aiQuantity = data['total_quantity'] ?? 0;
        final aiRemark = data['trademark_name'] ?? '';

        setState(() {
          // 核心前缀裁切逻辑：如果 AI 返回了带有当前前缀的完整货号，则智能剥离前缀
          String activePrefix = _items[index].prefix.isNotEmpty ? _items[index].prefix : _globalPrefix;
          String pureCode = aiProductCode;
          
          if (activePrefix.isNotEmpty && pureCode.startsWith(activePrefix)) {
             pureCode = pureCode.substring(activePrefix.length);
          }

          _items[index].productCode = pureCode;
          _items[index].count = aiQuantity is int ? aiQuantity : int.tryParse(aiQuantity.toString()) ?? 0;
          _items[index].remark = aiRemark;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 识别填入成功', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI 分析失败: ${e.toString()}')),
         );
      }
    } finally {
      setState(() {
        _items[index].isAiLoading = false;
      });
    }
  }

  void _submitOrder() async {
    // 基础校验
    bool hasEmptyCode = _items.any((item) => item.productCode.isEmpty);
    if (hasEmptyCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的货号后缀')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payloadItems = _items.map((i) => {
        'product_code': '${i.prefix}${i.productCode}',
        'count': i.count,
        'color': i.color,
        'size': i.size,
        'remark': i.remark,
      }).toList();

      await RequestUtil.post('/orders', data: {
        'items': payloadItems,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出货单提交成功')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) {
         setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增出货单'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('提交', style: TextStyle(color: Colors.white)),
            onPressed: _isSubmitting ? null : _submitOrder,
          )
        ],
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          // 全局前缀设置区块
          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '全局本批次前缀 (如: 4-)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: _syncGlobalPrefix,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 动态表单列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('明细 #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            if (item.isAiLoading)
                               const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                               IconButton(
                                 icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                                 tooltip: '拍照 AI 智能识别',
                                 onPressed: () => _takePhotoAndAnalyze(index),
                               ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() => _items.removeAt(index)),
                              )
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: item.prefix,
                                decoration: const InputDecoration(labelText: '前缀', border: UnderlineInputBorder()),
                                onChanged: (val) => item.prefix = val,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                key: ValueKey('${item.id}_code'),
                                initialValue: item.productCode,
                                decoration: const InputDecoration(labelText: '货号后缀 *', border: UnderlineInputBorder()),
                                onChanged: (val) => item.productCode = val,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: ValueKey('${item.id}_count'),
                                initialValue: item.count == 0 ? '' : item.count.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: '数量 *', border: UnderlineInputBorder()),
                                onChanged: (val) => item.count = int.tryParse(val) ?? 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('${item.id}_remark'),
                                initialValue: item.remark,
                                decoration: const InputDecoration(labelText: '商标/备注', border: UnderlineInputBorder()),
                                onChanged: (val) => item.remark = val,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
              childCount: _items.length,
            ),
          ),
          
          // 新增按钮
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('添加下一行明细'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _items.add(OrderItem()..prefix = _globalPrefix);
                  });
                },
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)) // 安全底部边距
        ],
      ),
    );
  }
}
