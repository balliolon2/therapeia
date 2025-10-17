import 'package:flutter/material.dart';
import 'package:flutter_frontend/api_service.dart';
import '../widgets/custom_app_bar.dart';

class InformationPagePatient extends StatefulWidget {
  final String email;

  const InformationPagePatient({super.key, required this.email});

  @override
  State<InformationPagePatient> createState() => _InformationPagePatientState();
}

class _InformationPagePatientState extends State<InformationPagePatient> {
  late Future<Map<String, dynamic>> _profileFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _profileFuture = _apiService.getPatientProfile(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'ข้อมูลส่วนตัว'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'ไม่สามารถโหลดข้อมูลผู้ป่วยได้',
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            final fullName = _composeFullName(
              data['first_name'] as String?,
              data['last_name'] as String?,
            );
            final hnValue = data['hn']?.toString() ?? '-';

            final infoItems = <Map<String, String>>[
              {'title': 'ชื่อ-นามสกุล', 'value': fullName},
              {'title': 'อีเมล', 'value': data['email'] as String? ?? '-'},
              {
                'title': 'เบอร์โทรศัพท์',
                'value': data['phone'] as String? ?? '-',
              },
              {
                'title': 'เลขบัตรประชาชน',
                'value': data['citizen_id'] as String? ?? '-',
              },
              {'title': 'Hospital Number (HN)', 'value': hnValue},
            ];

            return ListView(
              children: <Widget>[
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.lightGreen[200],
                    backgroundImage: const NetworkImage(
                      'https://via.placeholder.com/150',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...infoItems.map(
                  (item) => _buildInfoTile(
                    title: item['title']!,
                    value: item['value']!,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoTile({required String title, required String value}) {
    return Card(
      color: Colors.lightGreen[50],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  String _composeFullName(String? firstName, String? lastName) {
    final parts = <String>[];
    if (firstName != null && firstName.isNotEmpty) {
      parts.add(firstName);
    }
    if (lastName != null && lastName.isNotEmpty) {
      parts.add(lastName);
    }
    return parts.isNotEmpty ? parts.join(' ') : '-';
  }
}
