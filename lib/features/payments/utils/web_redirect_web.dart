// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation - redirects using window.location.href
void redirectToUrl(String url) {
  html.window.location.href = url;
}
