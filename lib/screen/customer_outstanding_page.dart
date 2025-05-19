// lib/screens/customer_outstanding_page.dart

import 'package:flutter/material.dart';
import '../models/customer_outstanding.dart';
import '../services/customer_outstanding_service.dart';
import 'payment_entry_page.dart'; // ← import the new page

class CustomerOutstandingPage extends StatefulWidget {
  const CustomerOutstandingPage({super.key});

  @override
  _CustomerOutstandingPageState createState() =>
      _CustomerOutstandingPageState();
}

class _CustomerOutstandingPageState extends State<CustomerOutstandingPage> {
  late Future<List<CustomerOutstanding>> _futureList;
  List<CustomerOutstanding> _all = [];
  List<CustomerOutstanding> _filtered = [];

  @override
  void initState() {
    super.initState();
    _futureList = CustomerOutstandingService.fetchAll();
    _futureList
        .then((list) {
          setState(() {
            _all = list;
            _filtered = list;
          });
        })
        .catchError((err) {
          print('Error loading customers: $err');
        });
  }

  void _filter(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered =
          _all.where((c) => c.name.toLowerCase().contains(lower)).toList();
    });
    print('Filter "$q" → ${_filtered.length} matches');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رصيد العملاء')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filter,
            ),
          ),

          // Customer cards
          Expanded(
            child: FutureBuilder<List<CustomerOutstanding>>(
              future: _futureList,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (_filtered.isEmpty) {
                  return const Center(child: Text('لا يوجد عملاء'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = _filtered[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'المبلغ المستحق: ${c.outstanding.toStringAsFixed(2)}',
                        ),
                        onTap: () {
                          // Navigate to payment entry page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => PaymentEntryPage(customerName: c.name),
                            ),
                          );
                          print('→ [ListPage] Navigator.push called');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
