import 'dart:async';
import 'dart:io';
import 'package:app_realtime_ext/app_realtime_ext.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:http/http.dart' as http;

/// {@template cookie_manager_ext}
/// An interceptor that manages cookies.
/// {@endtemplate}
class CookieManagerExt extends InterceptorExt {
  /// {@macro cookie_manager_ext}
  const CookieManagerExt(this.cookieJar);

  /// The cookie jar to manage cookies.
  final CookieJar cookieJar;

  @override
  FutureOr<http.BaseRequest> onRequest(
    http.BaseRequest request,
  ) async {
    await cookieJar
        .loadForRequest(Uri(scheme: request.url.scheme, host: request.url.host))
        .then((cookies) {
      final cookie = getCookies(cookies);
      if (cookie.isNotEmpty) {
        request.headers.addAll({HttpHeaders.cookieHeader: cookie});
      }
      return request;
    }).catchError((e, stackTrace) {
      return request;
    });
    return request;
  }

  @override
  FutureOr<http.Response> onResponse(http.Response response) {
    _saveCookies(response).then((_) => response).catchError((e, stackTrace) {
      return response;
    });
    return response;
  }

  Future<void> _saveCookies(http.Response response) async {
    final cookie = response.headers[HttpHeaders.setCookieHeader];
    if (cookie == null) return;
    final exp = RegExp(',(?=[^ ])');
    final cookies = cookie.split(exp);
    await cookieJar.saveFromResponse(
      Uri(
        scheme: response.request!.url.scheme,
        host: response.request!.url.host,
      ),
      cookies.map(Cookie.fromSetCookieValue).toList(),
    );
  }

  /// Get cookies from a list of cookies.
  static String getCookies(List<Cookie> cookies) {
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }
}
