import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/service_item.dart';
import '../services/service_item_repository.dart';
import '../widgets/custom_page_title.dart';

class FazaaScreen extends StatefulWidget {
  const FazaaScreen({super.key});

  @override
  State<FazaaScreen> createState() => _FazaaScreenState();
}

class _FazaaScreenState extends State<FazaaScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _place;
  int? _guests;
  double? _budget; // يمكن استخدامه لاحقًا إذا احتجت للميزانية في الفلترة أو العرض
  bool _showResults = false;
  List<ServiceItem> _filteredItems = [];

  void _filterItems() async {
    List<ServiceItem> allItems = [];
    final repo = ServiceItemRepository();
    // جلب كل العناصر من جميع الخدمات
    for (var serviceId in ['car', 'hotel', 'hall', 'bouquet']) {
      final items = await repo.getItems(serviceId).first;
      allItems.addAll(items.map((e) => e.copyWith(serviceId: serviceId)));
    }
    setState(() {
      _filteredItems = allItems.where((item) {
        final matchesPlace = _place == null || item.location == _place;
        final matchesGuests = item.serviceId != 'hall' || (_guests == null || (item.capacity != null && item.capacity! >= _guests!));
        return matchesPlace && matchesGuests;
      }).toList();
      _showResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 216, 208, 208),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                CustomPageTitle('فزعة'),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: !_showResults
                        ? Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      decoration: InputDecoration(labelText: 'الميزانية الكاملة (اختياري)'),
                                      keyboardType: TextInputType.number,
                                      onSaved: (v) => _budget = double.tryParse(v ?? ''),
                                    ),
                                    TextFormField(
                                      decoration: InputDecoration(labelText: 'مكان العرس'),
                                      onSaved: (v) => _place = v,
                                      validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال مكان العرس' : null,
                                    ),
                                    TextFormField(
                                      decoration: InputDecoration(labelText: 'عدد الضيوف'),
                                      keyboardType: TextInputType.number,
                                      onSaved: (v) => _guests = int.tryParse(v ?? ''),
                                      validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال عدد الضيوف' : null,
                                    ),
                                    SizedBox(height: 32),
                                    ElevatedButton(
                                      child: Text('بحث'),
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                          _formKey.currentState!.save();
                                          _filterItems();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: _filteredItems.isEmpty
                                    ? Center(child: Text('لا توجد عناصر مطابقة'))
                                    : ListView.builder(
                                        itemCount: _filteredItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _filteredItems[index];
                                          return Card(
                                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: ListTile(
                                              leading: item.imageUrl.isNotEmpty
                                                  ? Image.network(item.imageUrl, width: 60, height: 40, fit: BoxFit.cover)
                                                  : null,
                                              title: Text(item.name),
                                              subtitle: Text('المكان: ${item.location}\nالسعر: ${item.price}'),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_showResults)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                tooltip: 'بحث جديد',
                onPressed: () {
                  setState(() {
                    _showResults = false;
                    _filteredItems = [];
                  });
                },
                child: Icon(Icons.refresh),
              ),
            ),
        ],
      ),
    );
  }
}
