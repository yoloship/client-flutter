import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/request.dart';
import '../../providers/user_provider.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isAdmin = false;
  List<dynamic> _manufacturers = [];
  Map<String, dynamic>? _selectedManufacturer;
  
  List<dynamic> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 10;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onRefresh();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      _isAdmin = user != null && (user['role'] == 'admin' || user['user_type'] == 'platform');
      if (_isAdmin) {
        _fetchManufacturers();
      }
      _fetchOrders();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _page++;
          _fetchOrders();
        }
      }
    });
  }

  Future<void> _fetchManufacturers() async {
    try {
      final status = _tabController.index == 0 ? '加工中' : 'processed';
      final res = await RequestUtil.get('/mina/manufacturers/active?status=$status');
      if (res['data'] != null && mounted) {
        setState(() {
          _manufacturers = res['data'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch manufacturers: $e');
    }
  }

  Future<void> _fetchOrders() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final status = _tabController.index == 0 ? '加工中' : 'processed';
      String url = '/mina/orders?page=$_page&page_size=$_pageSize&status=$status';
      if (_selectedManufacturer != null) {
        url += '&manufacturer_id=${_selectedManufacturer!['ID']}';
      }

      final res = await RequestUtil.get(url);
      if (res['data'] != null) {
        final List newData = res['data'];
        setState(() {
          if (_page == 1) {
            _orders = newData;
          } else {
            _orders.addAll(newData);
          }
          _hasMore = newData.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch orders: $e');
      if (_page == 1 && mounted) {
        setState(() => _orders.clear());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    _page = 1;
    _hasMore = true;
    _orders.clear();
    if (_isAdmin) _fetchManufacturers();
    await _fetchOrders();
  }

  List<MapEntry<String, List<dynamic>>> get _groupedOrders {
    final Map<String, List<dynamic>> groups = {};
    for (var o in _orders) {
      final date = o['warehousing_date']?.toString().split('T')[0] ?? '未知日期';
      if (!groups.containsKey(date)) {
        groups[date] = [];
      }
      groups[date]!.add(o);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys.map((k) => MapEntry(k, groups[k]!)).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '加工中': return Colors.blue;
      case '已完成': return Colors.green;
      case '已发货': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _showOrderDetails(dynamic order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final items = (order['items'] as List?) ?? [];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['order_code'] ?? '--',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '创建于 ${order['CreatedAt']?.toString().split('T')[0]}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(order['status'] ?? '未知', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: _getStatusColor(order['status']),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('生产工厂', style: TextStyle(fontSize: 10, color: Colors.blue)),
                              Text(
                                order['manufacturer']?['name'] ?? '--',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('明细照片', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final assetName = item['trademark']?['name'] ?? item['product_asset']?['code'] ?? '--';
                        return Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 96,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  image: item['photo_data'] != null && item['photo_data'].isNotEmpty
                                      ? DecorationImage(image: NetworkImage(item['photo_data']), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: item['photo_data'] == null || item['photo_data'].isEmpty
                                    ? const Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 32))
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(assetName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('x${item['quantity']}', style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  if (_isAdmin && order['status'] == '加工中')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          // TODO: 状态扭转
                          Navigator.pop(context);
                        },
                        child: const Text('标记为加工完成'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('订单追踪'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: '正在加工'),
            Tab(text: '加工完成'),
          ],
        ),
      ),
      body: Row(
        children: [
          // 左侧：厂商侧边栏 (仅Admin可见)
          if (_isAdmin)
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: ListView(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => _selectedManufacturer = null);
                      _onRefresh();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: _selectedManufacturer == null ? Colors.blueAccent : Colors.transparent,
                            width: 4,
                          ),
                        ),
                        color: _selectedManufacturer == null ? Colors.white : Colors.transparent,
                      ),
                      child: const Center(
                        child: Text('全部', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  ..._manufacturers.map((m) {
                    final isSelected = _selectedManufacturer?['ID'] == m['ID'];
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedManufacturer = m);
                        _onRefresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? Colors.blueAccent : Colors.transparent,
                              width: 4,
                            ),
                          ),
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            m['name'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.blueAccent : Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  })
                ],
              ),
            ),
          
          // 右侧：订单流
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (_orders.isEmpty && !_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: Text('暂无订单数据', style: TextStyle(color: Colors.grey))),
                    ),
                  
                  ..._groupedOrders.map((group) {
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyHeaderDelegate(group.key, group.value.length),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = group.value[index];
                              return Card(
                                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showOrderDetails(order),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(left: BorderSide(color: _getStatusColor(order['status']), width: 4)),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                order['manufacturer']?['name'] ?? '--',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(order['status']).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                order['status'] ?? '',
                                                style: TextStyle(fontSize: 10, color: _getStatusColor(order['status']), fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ...((order['items'] as List?) ?? []).map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${item['trademark']?['name'] ?? item['product_asset']?['code'] ?? ''} ${item['product_code'] ?? ''}',
                                                    style: const TextStyle(fontSize: 12),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text('x${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)),
                                              ],
                                            ),
                                          );
                                        })
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: group.value.length,
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;

  _StickyHeaderDelegate(this.title, this.count);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50]?.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          '$title  ·  $count单',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 44.0;

  @override
  double get minExtent => 44.0;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || count != oldDelegate.count;
  }
}
