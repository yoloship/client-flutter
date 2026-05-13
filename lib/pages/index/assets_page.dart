import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/request.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _assets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAssets();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _page++;
          _fetchAssets();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _page = 1;
        _assets.clear();
        _hasMore = true;
      });
      _fetchAssets();
    });
  }

  Future<void> _fetchAssets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final keyword = Uri.encodeComponent(_searchController.text.trim());
      final res = await RequestUtil.get('/mina/assets/search?keyword=$keyword&page=$_page&page_size=$_pageSize');
      
      if (res['data'] != null && res['data'] is List) {
        final List newData = res['data'];
        setState(() {
          if (_page == 1) {
            _assets = newData;
          } else {
            _assets.addAll(newData);
          }
          if (newData.length < _pageSize) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted && _page == 1) {
        setState(() => _assets.clear());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索商标名称、编号或货号',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _assets.isEmpty && !_isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无资产数据', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _assets.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _assets.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = _assets[index];
                      final isTrademark = item['type'] == 'trademark';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTrademark ? Colors.blue.shade50 : Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTrademark ? '商标' : '货号',
                              style: TextStyle(
                                fontSize: 12,
                                color: isTrademark ? Colors.blue : Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['name']?.replaceAll('货号资产品: ', '') ?? '未知资产',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: item['screen'] != null
                              ? Text('物理网板: ${item['screen']['code']}')
                              : null,
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            // TODO: Navigator to detail
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
