import 'package:flutter/material.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String callbackUrl;

  const PaystackWebViewScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.callbackUrl,
  });

  @override
  State<PaystackWebViewScreen> createState() => _PaystackWebViewScreenState();
}

class _PaystackWebViewScreenState extends State<PaystackWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasHandledCompletion = false;

  bool _isPaymentCompleteUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('paystack.co/close') ||
        lowerUrl.contains('trxref=') ||
        lowerUrl.contains('reference=') ||
        lowerUrl.contains('/success') ||
        lowerUrl.contains('status=success') ||
        lowerUrl.contains('status=abandoned');
  }

  void _checkPaymentCompletion(String url) {
    if (_hasHandledCompletion) return;
    if (_isPaymentCompleteUrl(url)) {
      _handlePaymentSuccess(url);
    }
  }

  void _handlePaymentSuccess(String url) {
    if (_hasHandledCompletion) return;
    _hasHandledCompletion = true;

    final uri = Uri.tryParse(url);
    String? ref = uri?.queryParameters['trxref'] ?? uri?.queryParameters['reference'] ?? widget.reference;

    debugPrint('Payment completed, closing WebView. Reference: $ref');

    Navigator.of(context).pop(PaystackPaymentResult(success: true, reference: ref, message: 'Payment completed'));
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PaystackComplete',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('PaystackComplete message: ${message.message}');
          if (!_hasHandledCompletion) {
            _handlePaymentSuccess(widget.authorizationUrl);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('WebView onPageStarted: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            debugPrint('WebView onPageFinished: $url');
            setState(() {
              _isLoading = false;
            });
            _checkPaymentCompletion(url);
            _injectSuccessDetector();
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('WebView onNavigationRequest: ${request.url}');
            final url = request.url.toLowerCase();

            if (_isPaymentCompleteUrl(url)) {
              _handlePaymentSuccess(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _injectSuccessDetector() {
    _controller.runJavaScript('''
      (function() {
        var checkSuccess = function() {
          var body = document.body ? document.body.innerText.toLowerCase() : '';
          if (body.includes('payment successful') || 
              body.includes('transaction successful') ||
              body.includes('payment complete') ||
              body.includes('approved')) {
            if (window.PaystackComplete) {
              window.PaystackComplete.postMessage('success');
            }
          }
          if (body.includes('payment failed') || 
              body.includes('transaction failed') ||
              body.includes('declined')) {
            if (window.PaystackComplete) {
              window.PaystackComplete.postMessage('failed');
            }
          }
        };
        
        // Check immediately and after a short delay
        checkSuccess();
        setTimeout(checkSuccess, 1000);
        setTimeout(checkSuccess, 2000);
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.accentOrange,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(PaystackPaymentResult(success: false, message: 'Payment was cancelled'));
          },
        ),
        title: Text(
          'Complete Payment',
          style: TextStyle(
            fontFamily: 'Lato',
            package: 'grab_go_shared',
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pop(PaystackPaymentResult(success: true, reference: widget.reference, message: 'Payment completed'));
            },
            child: Text(
              'Done',
              style: TextStyle(
                fontFamily: 'Lato',
                package: 'grab_go_shared',
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(context.appColors.accentOrange),
              ),
            ),
        ],
      ),
    );
  }
}
