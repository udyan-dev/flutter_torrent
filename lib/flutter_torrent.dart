import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'flutter_torrent_bindings_generated.dart';

const String _libName = 'flutter_torrent';

/// Direct FFI call - use from any isolate including background TaskHandler.
void initSession(String configDir, String appName) => _bindings.init_session(
      configDir.toNativeUtf8().cast<Char>(),
      appName.toNativeUtf8().cast<Char>(),
    );

void closeSession() => _bindings.close_session();

void saveSettings() => _bindings.save_settings();

void resetSettings() => _bindings.reset_settings();

/// Synchronous request - use from background isolates where helper isolate is unavailable.
String request(String json) =>
    _bindings.request(json.toNativeUtf8().cast<Char>()).cast<Utf8>().toDartString();

/// Asynchronous request using helper isolate - use from main isolate for non-blocking calls.
Future<String> requestAsync(String json) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextTransmissionRequestId++;
  final _TransmissionRequest request = _TransmissionRequest(requestId, json);
  final Completer<String> completer = Completer<String>();
  _requestRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final FlutterTorrentBindings _bindings = FlutterTorrentBindings(_dylib);

class _TransmissionRequest {
  final int id;
  final String json;
  const _TransmissionRequest(this.id, this.json);
}

class _TransmissionRequestResponse {
  final int id;
  final String result;
  const _TransmissionRequestResponse(this.id, this.result);
}

int _nextTransmissionRequestId = 0;
final Map<int, Completer<String>> _requestRequests = <int, Completer<String>>{};

Future<SendPort> _helperIsolateSendPort = () async {
  final Completer<SendPort> completer = Completer<SendPort>();
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
        return;
      }
      if (data is _TransmissionRequestResponse) {
        final Completer<String>? requestCompleter = _requestRequests.remove(data.id);
        if (requestCompleter != null && !requestCompleter.isCompleted) {
          requestCompleter.complete(data.result);
        }
        return;
      }
    });

  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is _TransmissionRequest) {
          final result = _bindings.request(data.json.toNativeUtf8().cast<Char>());
          final response = _TransmissionRequestResponse(data.id, result.cast<Utf8>().toDartString());
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  return completer.future;
}();
