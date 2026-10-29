import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";
import "../../theme/app_theme.dart";

/// Otvara PayPal checkout (approveUrl) u WebView-u. Kada PayPal preusmjeri na
/// return_url (payment/success) ili cancel_url (payment/cancel), vraca rezultat
/// pozivaocu: true = odobreno (treba capture), false = otkazano.
class PaymentScreen extends StatefulWidget {
  final String approveUrl;
  const PaymentScreen({super.key, required this.approveUrl});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => _checkRedirect(url),
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (req) {
          if (_checkRedirect(req.url)) return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.approveUrl));
  }

  bool _checkRedirect(String url) {
    if (_handled) return false;
    // Backend je postavio return_url = .../payment/success, cancel_url = .../payment/cancel
    if (url.contains("/payment/success")) {
      _handled = true;
      Navigator.pop(context, true); // odobreno -> capture
      return true;
    }
    if (url.contains("/payment/cancel")) {
      _handled = true;
      Navigator.pop(context, false); // otkazano
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Placanje (PayPal)"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ),
    );
  }
}
