import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'tawk_visitor.dart';

/// [Tawk] Widget.
class Tawk extends StatefulWidget {
  /// Tawk direct chat link.
  final String directChatLink;

  /// Object used to set the visitor name and email.
  final TawkVisitor? visitor;

  /// Called right after the widget is rendered.
  final Function? onLoad;

  /// Called when a link pressed.
  final Function(String)? onLinkTap;

  /// Render your own loading widget.
  final Widget? placeholder;

  /// Error callback.
  final ValueChanged<dynamic>? onError;

  /// Circular progress indicator color
  final Color? loadingColor;

  /// Called for cleaning the cache
  final bool clearCache;

  const Tawk({
    Key? key,
    required this.directChatLink,
    this.visitor,
    this.onLoad,
    this.onLinkTap,
    this.placeholder,
    this.onError,
    this.loadingColor,
    this.clearCache = false,
  }) : super(key: key);

  @override
  State<Tawk> createState() => _TawkState();
}

class _TawkState extends State<Tawk> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();

    if (widget.clearCache) {
      WebViewCookieManager().clearCookies();
      _controller.clearCache();
      _controller.clearLocalStorage();
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: widget.onError,
          onNavigationRequest: (NavigationRequest request) {
            if (request.url == 'about:blank' ||
                request.url.contains('tawk.to')) {
              return NavigationDecision.navigate;
            }

            if (widget.onLinkTap != null) {
              widget.onLinkTap!(request.url);
            }

            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (widget.visitor != null) {
              _setUser(widget.visitor!);
            }

            if (widget.onLoad != null) {
              widget.onLoad!();
            }

            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.directChatLink));
  }

  void _setUser(TawkVisitor visitor) {
    final json = jsonEncode(visitor);
    String javascriptString;

    if (Platform.isIOS) {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.setAttributes($json);
      ''';
    } else {
      javascriptString = '''
        Tawk_API = Tawk_API || {};
        Tawk_API.onLoad = function() {
          Tawk_API.setAttributes($json);
        };
      ''';
    }

    try {
      _controller.runJavaScript(javascriptString);
    } catch (e) {
      widget.onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadingColor = widget.loadingColor;

    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
        ),
        _isLoading
            ? widget.placeholder ??
                Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: loadingColor != null
                        ? AlwaysStoppedAnimation<Color>(loadingColor)
                        : null,
                  ),
                )
            : Container(),
      ],
    );
  }
}
