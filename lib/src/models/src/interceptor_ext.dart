import 'dart:async';

import 'package:http/http.dart';

/// {@template interceptor_ext}
/// An extension of the [InterceptorExt] class that allows for more
/// customization.
/// {@endtemplate}
class InterceptorExt {
  /// {@macro interceptor_ext}
  const InterceptorExt();

  /// Called before a request is sent.
  FutureOr<Response> onResponse(Response response) => response;

  /// Called before a request is sent.
  FutureOr<BaseRequest> onRequest(BaseRequest request) => request;
}

/// {@template HeadersInterceptorExt}
/// An interceptor that adds headers to a request.
/// {@endtemplate}
class HeadersInterceptorExt extends InterceptorExt {
  /// {@macro HeadersInterceptorExt}
  const HeadersInterceptorExt(this.headers);

  /// The headers to add to the request.
  final Map<String, String> headers;

  @override
  BaseRequest onRequest(BaseRequest request) {
    request.headers.addAll(headers);
    return request;
  }
}
