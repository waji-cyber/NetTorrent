import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import 'download_manager.dart';

/// Localhost HTTP bridge that the NetTorrent browser extension talks to.
///
/// Endpoints (all JSON):
/// - `GET /status` -> `{name, version, tasks}` (no auth; localhost only)
/// - `POST /add` with body `{"url": "..."}` and header
///   `Authorization: Bearer <token>` -> `202 {"id": "<taskId>"}`
///
/// Security model: the server binds to 127.0.0.1 only and requires a
/// per-install bearer token. The token is shown in Settings so the user can
/// paste it into the extension once (pairing). Nothing leaves the machine.
class BridgeServer {
  final Ref _ref;
  HttpServer? _server;
  String? _token;

  BridgeServer(this._ref);

  int get port => _server?.port ?? kBridgePort;
  bool get running => _server != null;

  /// The pairing token shown in Settings.
  Future<String> getToken() async {
    if (_token != null) return _token!;
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(kBridgeTokenPrefsKey);
    token ??= const Uuid().v4();
    await prefs.setString(kBridgeTokenPrefsKey, token);
    return _token = token;
  }

  Future<void> start() async {
    if (_server != null) return;
    await getToken();
    final router = Router()
      ..get('/status', _status)
      ..post('/add', _add);
    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    try {
      // shelf_io.serve binds the loopback server AND adapts dart:io
      // HttpRequests into shelf Requests.
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        kBridgePort,
      );
    } on SocketException {
      // Port busy or loopback unavailable: the app works fine without the
      // bridge; the extension simply cannot connect.
      _server = null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<Response> _status(Request request) async {
    final tasks = _ref.read(downloadManagerProvider);
    return Response.ok(
      jsonEncode({
        'name': kAppName,
        'version': kAppVersion,
        'tasks': tasks.length,
        'active': tasks.where((t) => t.isActive).length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _add(Request request) async {
    final auth = request.headers['authorization'] ?? '';
    if (auth != 'Bearer $_token') {
      return Response.forbidden(
        jsonEncode({'error': 'invalid or missing token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    late final Map<String, dynamic> body;
    try {
      body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return Response.badRequest(
        body: jsonEncode({'error': 'body must be JSON'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final url = (body['url'] as String?)?.trim() ?? '';
    if (!isValidDownloadUrl(url)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'not a valid http/https URL'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      final manager = _ref.read(downloadManagerProvider.notifier);
      final task = await manager.addHttpDownload(url);
      return Response(
        202,
        body: jsonEncode({'id': task.id, 'name': task.name}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}

final bridgeServerProvider = Provider<BridgeServer>(
  (ref) => BridgeServer(ref),
);
