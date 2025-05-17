// lib/core/services/api_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

typedef ApiCall<T> = Future<Response<T>> Function();

class ApiService {
  final Dio _dio;
  final Connectivity _connectivity = Connectivity();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // Queue for requests when offline
  final List<_QueuedRequest> _requestQueue = [];

  bool _isOnline = true;

  ApiService({Dio? dio}) : _dio = dio ?? Dio() {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline) {
        _processQueue();
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription.cancel();
  }

  // Enqueue or execute immediately based on connectivity
  Future<Response<T>> _queueOrExecute<T>(ApiCall<T> apiCall) async {
    if (_isOnline) {
      try {
        return await apiCall();
      } catch (e) {
        // Optionally queue failed requests too (implement if needed)
        rethrow;
      }
    } else {
      final completer = Completer<Response<T>>();
      _requestQueue.add(_QueuedRequest(apiCall, completer));
      return completer.future;
    }
  }

  Future<void> _processQueue() async {
    if (_requestQueue.isEmpty) return;

    final queueCopy = List<_QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();

    for (final queuedRequest in queueCopy) {
      try {
        final response = await queuedRequest.apiCall();
        queuedRequest.completer.complete(response);
      } catch (e, st) {
        queuedRequest.completer.completeError(e, st);
      }
    }
  }

  // =================== HTTP Methods ===================

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _queueOrExecute(() => _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _queueOrExecute(() => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _queueOrExecute(() => _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _queueOrExecute(() => _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  // =================== File Upload ===================

  /// Upload file with multipart/form-data
  Future<Response<T>> uploadFile<T>(
    String path, {
    required File file,
    Map<String, dynamic>? data,
    String fileFieldName = 'file',
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      fileFieldName:
          await MultipartFile.fromFile(file.path, filename: fileName),
      if (data != null) ...data,
    });

    return _queueOrExecute(() => _dio.post<T>(
          path,
          data: formData,
          options: options ?? Options(contentType: 'multipart/form-data'),
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        ));
  }

  // =================== File Download ===================

  /// Downloads a file to local storage, returns saved File
  Future<File> downloadFile(
    String url, {
    String? saveAs,
    ProgressCallback? onReceiveProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = saveAs != null
        ? '${tempDir.path}${Platform.pathSeparator}$saveAs'
        : '${tempDir.path}${Platform.pathSeparator}${url.split('/').last}';

    // Use isolate to handle heavy file download
    return await _downloadFileIsolate(url, savePath, onReceiveProgress);
  }

  // Isolate runner for downloadFile
  Future<File> _downloadFileIsolate(
    String url,
    String savePath,
    ProgressCallback? onReceiveProgress,
  ) async {
    final p = ReceivePort();
    await Isolate.spawn<_DownloadParams>(
      _downloadEntryPoint,
      _DownloadParams(url, savePath, p.sendPort),
    );
    return await p.first as File;
  }

  // Entry point for isolate download
  static Future<void> _downloadEntryPoint(_DownloadParams params) async {
    final dio = Dio();
    String yash;

    final response = await dio.download(
      params.url,
      params.savePath,
      onReceiveProgress: params.onReceiveProgress,
      deleteOnError: true,
    );

    params.sendPort.send(File(params.savePath));
  }
}

class _DownloadParams {
  final String url;
  final String savePath;
  final SendPort sendPort;
  final ProgressCallback? onReceiveProgress;

  _DownloadParams(this.url, this.savePath, this.sendPort,
      [this.onReceiveProgress]);
}

class _QueuedRequest {
  final ApiCall apiCall;
  final Completer completer;

  _QueuedRequest(this.apiCall, this.completer);
}

// final apiService = ApiService();
//
// // Simple GET
// final response = await apiService.get<Map<String, dynamic>>('/tasks');
//
// // POST with data
// final postResponse = await apiService.post('/tasks', data: {'title': 'New Task'});
//
// // PUT example
// final putResponse = await apiService.put('/tasks/1', data: {'title': 'Updated Task'});
//
// // DELETE example
// final deleteResponse = await apiService.delete('/tasks/1');
//
// // Upload file
// final file = File('/path/to/file.jpg');
// final uploadResponse = await apiService.uploadFile('/upload', file: file);
//
// // Download file
// final downloadedFile = await apiService.downloadFile('https://example.com/video.mp4');
// print('File saved at: ${downloadedFile.path}');
