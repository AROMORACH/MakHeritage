import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _secretController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  Future<void> _requestOtp() async {
    setState(() => _isLoading = true);
    final baseUrl = dotenv.env['API_URL'] ?? 'https://makheritage-dev.onrender.com';
    
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );
      
      if (res.statusCode == 200) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(res.body)['error'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAdmin() async {
    setState(() => _isLoading = true);
    final baseUrl = dotenv.env['API_URL'] ?? 'https://makheritage-dev.onrender.com';
    
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/admin/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'code': _otpController.text,
          'secretCode': _secretController.text,
        }),
      );
      
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin verified.')));
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(res.body)['error'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Verification', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF006633),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Makerere Email',
                border: OutlineInputBorder(),
              ),
              enabled: !_otpSent,
            ),
            if (_otpSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'OTP Code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret Code',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _otpSent ? _verifyAdmin : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _otpSent ? 'Verify & Login' : 'Request OTP',
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}