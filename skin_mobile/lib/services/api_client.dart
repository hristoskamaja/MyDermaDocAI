import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import 'api_config.dart';
import 'locale_storage.dart';

/// Thrown whenever the API returns a non-2xx status code, or when the
/// request fails at the network layer.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic body;

  /// True when the request ran into its client-side timeout.
  final bool isTimeout;

  ApiException(this.message, {this.statusCode, this.body, this.isTimeout = false});

  @override
  String toString() => message;
}

/// Persists and retrieves the JWT access/refresh tokens.
class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<void> saveAccessToken(String access) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

/// Thin HTTP wrapper around the DermaScanAI Django REST API.
///
/// Handles: base URL prefixing, JSON encode/decode, attaching the
/// `Authorization: Bearer <access>` header for authenticated requests,
/// and throwing [ApiException] on non-2xx responses or network errors.
class ApiClient {
  // Attaches the current UI language (see LocaleStorage/LocaleProvider) to
  // every request as ?lang=en|mk, mirroring skin_web/src/services/api.js's
  // axios interceptor - so condition/recommendation text comes back in
  // whichever language the user has selected in Profile.
  static Uri _uri(String path) {
    final uri = Uri.parse('$kApiBaseUrl$path');
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'lang': LocaleStorage.current},
    );
  }

  static Future<Map<String, String>> _headers({
    required bool auth,
    bool json = true,
  }) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';
    if (auth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  static dynamic _handle(http.Response response) {
    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    String message = 'Request failed (${response.statusCode}).';
    if (decoded is Map<String, dynamic>) {
      message = (decoded['detail'] ??
              decoded['error'] ??
              decoded['message'] ??
              _firstFieldError(decoded) ??
              message)
          .toString();
    }
    throw ApiException(message, statusCode: response.statusCode, body: decoded);
  }

  static String? _firstFieldError(Map<String, dynamic> decoded) {
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${entry.key}: ${value.first}';
      }
      if (value is String) {
        return '${entry.key}: $value';
      }
    }
    return null;
  }

  /// Called when the session cannot be recovered (refresh token missing,
  /// expired or rejected). AuthProvider hooks into this to log the user out.
  static void Function()? onSessionExpired;

  // One shared in-flight refresh, so several requests that get a 401 at the
  // same time trigger a single /jwt-auth/refresh/ call.
  static Future<bool>? _refreshing;

  /// Exchanges the stored refresh token for a new access token.
  /// Returns false if that is not possible.
  static Future<bool> _refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) return false;
    try {
      final response = await http
          .post(
            _uri('/jwt-auth/refresh/'),
            headers: await _headers(auth: false),
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = _decode(response);
      if (decoded is! Map || decoded['access'] is! String) return false;
      await TokenStorage.saveAccessToken(decoded['access'] as String);
      // Only present if the backend ever turns on refresh rotation.
      if (decoded['refresh'] is String) {
        await TokenStorage.saveTokens(
          access: decoded['access'] as String,
          refresh: decoded['refresh'] as String,
        );
      }
      return true;
    } catch (_) {
      // Network problem: keep the session, the caller sees the original 401.
      return false;
    }
  }

  /// Sends a request built by [build] (called again after a refresh, so the
  /// new access token is picked up). On a 401 for an authenticated request:
  /// refresh once, retry once, and only end the session if refresh fails.
  /// Returns the raw response (no status check) so callers can read bytes.
  static Future<http.Response> _sendRaw(
    Future<http.Response> Function() build, {
    required bool auth,
  }) async {
    try {
      var response = await build();
      if (response.statusCode == 401 && auth) {
        final hadRefreshToken = await TokenStorage.getRefreshToken() != null;
        if (await _refreshAccessToken()) {
          response = await build();
        } else if (hadRefreshToken || await TokenStorage.getAccessToken() != null) {
          await TokenStorage.clear();
          onSessionExpired?.call();
        }
      }
      return response;
    } on TimeoutException {
      throw ApiException(
        AppStrings.t(LocaleStorage.current, 'common.serverUnreachable'),
        isTimeout: true,
      );
    } on SocketException {
      throw ApiException(
        AppStrings.t(LocaleStorage.current, 'common.serverUnreachable'),
      );
    } catch (e) {
      throw ApiException('Something went wrong: $e');
    }
  }

  static Future<dynamic> _send(
    Future<http.Response> Function() build, {
    required bool auth,
  }) async {
    return _handle(await _sendRaw(build, auth: auth));
  }

  static Future<dynamic> get(String path, {bool auth = true}) {
    return _send(
      () async => http
          .get(_uri(path), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 30)),
      auth: auth,
    );
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      () async => http
          .post(
            _uri(path),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(timeout),
      auth: auth,
    );
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) {
    return _send(
      () async => http
          .put(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30)),
      auth: auth,
    );
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body, {bool auth = true}) {
    return _send(
      () async => http
          .patch(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30)),
      auth: auth,
    );
  }

  static Future<dynamic> delete(String path, {bool auth = true}) {
    return _send(
      () async => http
          .delete(_uri(path), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 30)),
      auth: auth,
    );
  }

  /// Downloads a protected binary (e.g. a private check-in photo) with the
  /// Bearer token. Throws [ApiException] on a non-2xx status.
  static Future<Uint8List> getBytes(String path, {bool auth = true}) async {
    final response = await _sendRaw(
      () async => http
          .get(_uri(path), headers: await _headers(auth: auth, json: false))
          .timeout(const Duration(seconds: 30)),
      auth: auth,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed (${response.statusCode}).', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  /// Multipart request with plain text [fields] and an optional [file]
  /// (used to save a check-in together with its photo).
  static Future<dynamic> sendMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'photo',
    bool auth = true,
  }) {
    return _send(
      () async {
        final request = http.MultipartRequest(method, _uri(path));
        request.headers.addAll(await _headers(auth: auth, json: false));
        request.fields.addAll(fields);
        if (file != null) {
          request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
        }
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      },
      auth: auth,
    );
  }

  /// Multipart upload, used for `POST /analyses/scan-skin/`.
  static Future<dynamic> postMultipart(
    String path, {
    required String fieldName,
    required File file,
    bool auth = true,
  }) {
    return _send(
      () async {
        // A MultipartRequest can only be sent once, so build a new one on
        // every attempt.
        final request = http.MultipartRequest('POST', _uri(path));
        request.headers.addAll(await _headers(auth: auth, json: false));
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, file.path),
        );
        final streamed = await request.send().timeout(
              const Duration(seconds: 60),
            );
        return http.Response.fromStream(streamed);
      },
      auth: auth,
    );
  }
}
