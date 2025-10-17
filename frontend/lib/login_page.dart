import 'package:flutter/material.dart';
import 'doctor/landing_page_doctor.dart';
import 'patient/landing_page_patient.dart';
import 'register_page.dart';
import 'widgets/custom_textfield.dart';
import 'widgets/custom_button.dart';

import 'package:flutter_frontend/api_service.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'ผู้ป่วย';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Appointment'),
        backgroundColor: Colors.lightGreen[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ยินดีต้อนรับ',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 32.0),
            CustomTextField(
              controller: _emailController,
              labelText: 'อีเมล (Email)',
              hintText: 'Enter your Email',
            ),
            SizedBox(height: 16.0),
            CustomTextField(
              controller: _passwordController,
              labelText: 'รหัสผ่าน (Password)',
              hintText: 'Enter your Password',
              obscureText: true,
            ),
            SizedBox(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'ผู้ป่วย',
                  groupValue: _selectedRole,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const Text('ผู้ป่วย'),
                const SizedBox(width: 16.0),
                Radio<String>(
                  value: 'แพทย์',
                  groupValue: _selectedRole,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const Text('แพทย์'),
              ],
            ),
            const SizedBox(height: 24.0),
            CustomButton(
              text: 'เข้าสู่ระบบ',
              onPressed: () {
                final apiService = ApiService();
                final role = _selectedRole == 'แพทย์' ? 'DOCTOR' : 'PATIENT';

                apiService
                    .login(
                      _emailController.text,
                      _passwordController.text,
                      role: role,
                    )
                    .then((response) {
                      // TODO: Store the token securely
                      final role =
                          (response['role'] as String?)?.toUpperCase() ??
                          'PATIENT';

                      final email = _emailController.text;

                      if (role == 'DOCTOR') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LandingPageDoctor(email: email),
                          ),
                        );
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LandingPagePatient(email: email),
                          ),
                        );
                      }
                    })
                    .catchError((error) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    });
              },
              color: Colors.lightGreen[100],
              textColor: Colors.black,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text('สมัครสมาชิก', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }
}
