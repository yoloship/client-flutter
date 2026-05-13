import 'package:flutter/material.dart';
import '../order/create_page.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工厂概览看板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建出货单',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateOrderPage()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('工作台数据开发中...'),
      ),
    );
  }
}
