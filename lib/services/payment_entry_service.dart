import 'dart:convert';
import '../models/payment_entry.dart';
import 'api_client.dart';

class PaymentEntryService {
  /// 1. List all Mode of Payment names
  static Future<List<String>> _fetchModeNames() async {
    print('→ [Service] _fetchModeNames start');
    const endpoint =
        '/api/resource/Mode of Payment?fields=["name"]&limit_page_length=100';
    print('→ [Service] GET $endpoint');
    final res = await ApiClient.get(endpoint);
    print('← [Service] status: ${res.statusCode}');
    print('← [Service] body: ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Failed to load mode names: HTTP ${res.statusCode}');
    }
    final List data = jsonDecode(res.body)['data'];
    final names = data.map<String>((e) => e['name'] as String).toList();
    print('→ [Service] _fetchModeNames found ${names.length}');
    return names;
  }

  /// 2. For each mode name, GET its default_account & currency
  static Future<List<Map<String, String>>> fetchModesOfPayment() async {
    print('→ [Service] fetchModesOfPayment start');
    final names = await _fetchModeNames();
    final modes = <Map<String, String>>[];

    for (var name in names) {
      final detailEndpoint =
          '/api/resource/Mode of Payment/$name?fields=["accounts"]';
      print('→ [Service] GET $detailEndpoint');
      final detRes = await ApiClient.get(detailEndpoint);
      print('← [Service] detail status: ${detRes.statusCode}');
      print('← [Service] detail body: ${detRes.body}');
      if (detRes.statusCode != 200) {
        print('!!! [Service] failed to fetch detail for $name');
        continue;
      }
      final detailData = jsonDecode(detRes.body)['data'];
      final accounts = detailData['accounts'] as List<dynamic>?;
      if (accounts == null || accounts.isEmpty) continue;
      final defaultAcc =
          (accounts.first as Map<String, dynamic>)['default_account']
              as String?;
      if (defaultAcc == null) continue;

      // Now fetch account currency
      final accEndpoint =
          '/api/resource/Account/$defaultAcc?fields=["account_currency"]';
      print('→ [Service] GET $accEndpoint');
      final accRes = await ApiClient.get(accEndpoint);
      print('← [Service] account status: ${accRes.statusCode}');
      print('← [Service] account body: ${accRes.body}');
      if (accRes.statusCode != 200) continue;
      final currency =
          jsonDecode(accRes.body)['data']['account_currency'] as String?;
      if (currency == null) continue;

      modes.add({'mode': name, 'account': defaultAcc, 'currency': currency});
      print('→ [Service] added mode: $name → $defaultAcc ($currency)');
    }

    print('→ [Service] fetchModesOfPayment complete: ${modes.length} modes');
    return modes;
  }

  /// 3. Post a new Payment Entry record
  static Future<void> createPayment(PaymentEntry entry) async {
    final data = entry.toJson();
    print('→ [Service] createPayment data: $data');
    final res = await ApiClient.postJson('/api/resource/Payment Entry', data);
    print('← [Service] createPayment status: ${res.statusCode}');
    print('← [Service] createPayment body: ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Failed to create payment: HTTP ${res.statusCode} - ${res.body}',
      );
    }
    print('→ [Service] createPayment succeeded');
  }
}
