import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:daum_postcode_search/daum_postcode_search.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  DaumPostcodeLocalServer? _server;
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await _server?.stop();
      _server = null;

      final server = DaumPostcodeLocalServer();
      await server.start();
      _server = server;

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'DaumPostcodeResult',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final decoded = jsonDecode(message.message);
            final address = decoded['roadAddress'] ?? decoded['jibunAddress'] ?? '';
            if (address.isNotEmpty && mounted) {
              Navigator.pop(context, address);
            }
          } catch (e) {
            if (message.message.isNotEmpty && mounted) {
              Navigator.pop(context, message.message);
            }
          }
        },
      );
      await controller.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          controller.runJavaScript('''
            window.addEventListener("message", function(event) {
              try {
                flutter.postMessage(JSON.stringify(event.data));
              } catch(e) {}
            });
          ''');
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (WebResourceError error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = '[${error.errorCode}] ${error.description}';
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          if (request.url == 'about:blank' || request.url.isEmpty) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

      final url = '${server.url}/${DaumPostcodeAssets.postMessage}';
      await controller.loadRequest(Uri.parse(url));

      if (mounted) {
        setState(() => _webViewController = controller);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '서버 시작 실패: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 검색'), backgroundColor: const Color(0xFF005A9C)),
      body: Stack(
        children: [
          if (_webViewController != null)
            WebViewWidget(controller: _webViewController!)
          else if (_errorMessage == null)
            const SizedBox.shrink(),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _errorMessage = null; _isLoading = true; });
                        _startServer();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}