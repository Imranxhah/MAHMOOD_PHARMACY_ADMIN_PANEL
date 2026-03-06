import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahmoodpharmacy_admin_panel/common_widgets/pharmacy_loader.dart';
import 'package:mahmoodpharmacy_admin_panel/common_widgets/report_generation_loader.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminWebViewScreen extends StatefulWidget {
  const AdminWebViewScreen({super.key});

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();

  // URL provided in requirements.
  final String _initialUrl = "https://mpharmacy.pythonanywhere.com/admin/";

  late String _currentUrl;

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    allowFileAccess: true,
    allowContentAccess: true,
    useOnDownloadStart: true,
  );

  PullToRefreshController? pullToRefreshController;
  double progress = 0;
  bool _isFirstLoad = true;
  bool _isOffline = false;
  bool _isWebViewError = false;

  // Download state
  bool _isDownloading = false;
  String _downloadStatus = "Starting download...";

  // Report generation state
  bool _isGeneratingReport = false;
  final StringBuffer _downloadBuffer = StringBuffer();
  String? _pendingFilename;
  String? _pendingMimeType;

  // State restoration variables
  XFile? _pendingRestoreFile;
  String? _pendingRestoreInputId;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = _initialUrl;
    _checkConnection();
    _recoverLostData();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(color: Colors.teal),
            onRefresh: () async {
              if (Platform.isAndroid) {
                webViewController?.reload();
              } else if (Platform.isIOS) {
                webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: await webViewController?.getUrl(),
                  ),
                );
              }
            },
          );
  }

  /// Checks if the app was killed by the OS while the image picker was active.
  /// If so, it retrieves the lost file and sets up the state to restore it
  /// once the WebView loads.
  Future<void> _recoverLostData() async {
    if (!Platform.isAndroid) return;

    try {
      final ImagePicker picker = ImagePicker();
      final LostDataResponse response = await picker.retrieveLostData();

      if (response.isEmpty) {
        return;
      }

      final file = response.file;
      if (file != null) {
        // App was killed, but we recovered the file!
        final prefs = await SharedPreferences.getInstance();
        final String? lastUrl = prefs.getString('last_url');
        final String? lastInputId = prefs.getString('last_input_id');

        if (lastUrl != null && lastInputId != null) {
          setState(() {
            _isRestoring = true;
            _pendingRestoreFile = file;
            _pendingRestoreInputId = lastInputId;
            _currentUrl = lastUrl;
          });

          // If the webViewController is already available (unlikely in initState, but safe to check),
          // load the URL immediately. Otherwise, initialUrlRequest will handle it.
          if (webViewController != null) {
            webViewController!.loadUrl(
              urlRequest: URLRequest(url: WebUri(lastUrl)),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error recovering lost data: $e");
      }
    }
  }

  Future<void> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });
  }

  Future<bool> _goBack() async {
    // If we are on an error page or offline screen, pressing back should prompt to exit app,
    // rather than trying to navigate back within the (potentially failed) webview history.
    if (_isWebViewError || _isOffline) {
      // Return false to indicate we are not handling the pop internally in the webview,
      // but we want the PopScope to trigger its logic which calls this function...
      // Actually, PopScope calls this function. If we return false, it does nothing?
      // Wait, the logic in build() is:
      // onPopInvokedWithResult: (didPop, result) async {
      //   if (didPop) return;
      //   final shouldPop = await _goBack();
      //   if (shouldPop) { SystemNavigator.pop(); }
      // }
      // So _goBack needs to return true if we want to exit?
      // No, _goBack returns whether we should close the app.

      return await _showExitDialog();
    }

    if (webViewController != null && await webViewController!.canGoBack()) {
      webViewController!.goBack();
      return false; // Handled navigation, do not close app
    }

    return await _showExitDialog();
  }

  Future<bool> _showExitDialog() async {
    // Show confirmation dialog
    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app_rounded,
                  size: 40,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Exit App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                'Are you sure you want to close the app?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Exit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return shouldClose ?? false;
  }

  /// Inject file into WebView input
  Future<void> injectFile(XFile image, String inputId) async {
    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);
    final fileName = image.name;
    final mimeType = image.mimeType ?? 'image/jpeg';

    final jsCode =
        """
      (function() {
        var input = document.getElementById('$inputId');
        if (!input) return;
        
        // Helper to convert base64 to Blob
        function b64toBlob(b64Data, contentType, sliceSize) {
          contentType = contentType || '';
          sliceSize = sliceSize || 512;
          var byteCharacters = atob(b64Data);
          var byteArrays = [];
          for (var offset = 0; offset < byteCharacters.length; offset += sliceSize) {
            var slice = byteCharacters.slice(offset, offset + sliceSize);
            var byteNumbers = new Array(slice.length);
            for (var i = 0; i < slice.length; i++) {
              byteNumbers[i] = slice.charCodeAt(i);
            }
            var byteArray = new Uint8Array(byteNumbers);
            byteArrays.push(byteArray);
          }
          var blob = new Blob(byteArrays, {type: contentType});
          return blob;
        }

        var blob = b64toBlob('$base64String', '$mimeType');
        var file = new File([blob], '$fileName', { type: '$mimeType' });
        var dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        input.files = dataTransfer.files;

        // Trigger change event so the form knows it changed
        var event = new Event('change', { bubbles: true });
        input.dispatchEvent(event);
      })();
    """;

    await webViewController?.evaluateJavascript(source: jsCode);
  }

  // Helper to handle image picking and passing back to JS
  Future<void> handleImagePicker(String inputId) async {
    // Save state before launching picker, in case app is killed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_input_id', inputId);
    final url = await webViewController?.getUrl();
    if (url != null) {
      await prefs.setString('last_url', url.toString());
    }

    final ImagePicker picker = ImagePicker();
    // Show dialog to choose source
    if (!mounted) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      try {
        final XFile? image = await picker.pickImage(source: source);
        if (image != null) {
          await injectFile(image, inputId);
        }
      } catch (e) {
        // Handle pick error
        if (kDebugMode) print("Pick error: $e");
      }
    }
  }

  Future<void> _downloadFile(DownloadStartRequest request) async {
    final String url = request.url.toString();

    // Check for Data URI
    if (url.startsWith('data:')) {
      String mimeType = 'application/octet-stream';
      String? extension;

      // Try to extract mime type
      final match = RegExp(r'data:([^;]+);').firstMatch(url);
      if (match != null) {
        mimeType = match.group(1) ?? mimeType;
        // Simple extension mapping
        if (mimeType == 'image/png')
          extension = 'png';
        else if (mimeType == 'image/jpeg')
          extension = 'jpg';
        else if (mimeType == 'application/pdf')
          extension = 'pdf';
      }

      String filename = request.suggestedFilename ?? "download";

      // Fix: If suggested filename is too long (likely data) or null, generate one
      if (filename.length > 50 || filename.trim().isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filename = "file_$timestamp";
      }

      // If filename doesn't have an extension, try to add one
      if (extension != null && !filename.endsWith('.$extension')) {
        filename = "$filename.$extension";
      }

      await _saveBase64File(url, filename, mimeType);
      return;
    }

    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // On Android 13+, this might always return denied for storage, but we can access public folders.
        // We proceed if it's denied, assuming scoped storage or public downloads folder might work.
        // But for better UX, we might check manageExternalStorage if absolutely needed.
        // For now, let's try to proceed.
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getDownloadsDirectory();
      }

      if (dir == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not find download directory")),
          );
        }
        return;
      }

      String filename = request.suggestedFilename ?? "download.pdf";
      // Sanitize filename
      filename = filename.replaceAll(RegExp(r'[^\w\s\.-]'), '');
      if (filename.isEmpty) filename = "download.pdf";

      final savePath = "${dir.path}/$filename";

      setState(() {
        _isDownloading = true;
        _downloadStatus = "Downloading $filename...";
      });

      final Dio dio = Dio();

      // Get cookies from the WebView to maintain session
      String cookies = "";
      final cookieManager = CookieManager.instance();
      final List<Cookie> cookieList = await cookieManager.getCookies(
        url: request.url,
      );
      cookies = cookieList.map((c) => "${c.name}=${c.value}").join("; ");

      // Get current URL for Referer header
      final currentUrl = await webViewController?.getUrl();

      await dio.download(
        request.url.toString(),
        savePath,
        options: Options(
          headers: {
            HttpHeaders.cookieHeader: cookies,
            HttpHeaders.userAgentHeader: settings.userAgent,
            if (currentUrl != null)
              HttpHeaders.refererHeader: currentUrl.toString(),
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Optional: calculate percentage if needed, but for now just showing spinner
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "File downloaded successfully",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.amberAccent,
              onPressed: () {
                OpenFile.open(savePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      String errorMessage = "Download failed";
      if (e is DioException) {
        if (e.response?.statusCode == 405) {
          errorMessage =
              "Download failed: Server requires a different request method (likely POST).";
        } else {
          errorMessage = "Download failed: ${e.message}";
        }
      } else {
        errorMessage = "Download failed: $e";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
      debugPrint("Download error: $e");
    }
  }

  Future<void> _saveBase64File(
    String base64String,
    String filename,
    String mimeType,
  ) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Proceeding as per _downloadFile logic
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getDownloadsDirectory();
      }

      if (dir == null) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not find download directory")),
           );
        }
        setState(() {
          _isGeneratingReport = false;
        });
        return;
      }

      // Sanitize filename
      filename = filename.replaceAll(RegExp(r'[^\w\s\.-]'), '');
      if (filename.isEmpty) {
        filename = "downloaded_file.pdf";
        if (mimeType == 'image/png') filename = "image.png";
        else if (mimeType == 'image/jpeg') filename = "image.jpg";
      }

      final savePath = "${dir.path}/$filename";

      setState(() {
        _isDownloading = true;
        _downloadStatus = "Saving $filename...";
        _isGeneratingReport = false;
      });

      // Strip Data URI prefix if present
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }

      // Decode and Write
      final bytes = base64Decode(base64String);
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "File downloaded successfully",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.amberAccent,
              onPressed: () {
                OpenFile.open(savePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _isGeneratingReport = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("File save failed: $e")));
      }
      debugPrint("File save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _goBack();
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                // Use _currentUrl which might be updated by _recoverLostData
                initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
                initialSettings: settings,
                pullToRefreshController: pullToRefreshController,
                onDownloadStartRequest: (controller, request) {
                  final String url = request.url.toString();
                  // Fix for 405 Method Not Allowed:
                  // Ignore native download attempts for report endpoints as they are POST requests handled by JS.
                  if (url.contains('/api/reports/sales/') ||
                      url.contains('/api/reports/visual/')) {
                    if (kDebugMode) {
                      print(
                        "Blocked native download for report (handled by JS): $url",
                      );
                    }
                    return;
                  }
                  _downloadFile(request);
                },
                onWebViewCreated: (controller) {
                  webViewController = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'imagePickerHandler',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        handleImagePicker(args[0].toString());
                      }
                    },
                  );

                  // Handler for Report Generation Loading State
                  controller.addJavaScriptHandler(
                    handlerName: 'reportGenerationHandler',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        final bool isLoading = args[0] as bool;
                        setState(() {
                          _isGeneratingReport = isLoading;
                        });
                      }
                    },
                  );

                  // Handler for Blob/Base64 downloads (Chunked)
                  controller.addJavaScriptHandler(
                    handlerName: 'blobDownloadHandler',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        final data = args[0] as Map<String, dynamic>;
                        final status = data['status'];

                        if (status == 'start') {
                          _downloadBuffer.clear();
                          _pendingFilename = data['filename'];
                          _pendingMimeType = data['mimetype'];
                        } else if (status == 'chunk') {
                          final chunk = data['data'];
                          if (chunk != null) {
                            _downloadBuffer.write(chunk);
                          }
                        } else if (status == 'end') {
                          if (_pendingFilename != null &&
                              _downloadBuffer.isNotEmpty) {
                            _saveBase64File(
                              _downloadBuffer.toString(),
                              _pendingFilename!,
                              _pendingMimeType ?? 'application/pdf',
                            );
                            _downloadBuffer.clear();
                            _pendingFilename = null;
                            _pendingMimeType = null;
                          } else {
                            setState(() {
                              _isGeneratingReport = false;
                            });
                          }
                        }
                      }
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'consoleLog',
                    callback: (args) {
                      if (kDebugMode) {
                        print("JS Console: ${args.join(' ')}");
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isWebViewError = false;
                    if (url != null) {
                      _currentUrl = url.toString();
                    }
                  });
                },
                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                  if (url != null) {
                    setState(() {
                      _currentUrl = url.toString();
                    });
                  }
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController?.endRefreshing();

                  // Inject click interceptor (Original)
                  await controller.evaluateJavascript(
                    source: """
                    (function() {
                      var fileInputs = document.querySelectorAll("input[type='file']");
                      fileInputs.forEach(function(input, index) {
                        if (!input.id) {
                          input.id = 'file_input_generated_' + index;
                        }
                        input.removeEventListener('click', window.flutterClickInterceptor);
                        
                        window.flutterClickInterceptor = function(event) {
                          event.preventDefault();
                          window.flutter_inappwebview.callHandler('imagePickerHandler', input.id);
                        };

                        input.addEventListener('click', window.flutterClickInterceptor);
                      });
                    })();
                  """,
                  );

                  // Inject Report Download Interceptor (Chunked) - Strict Implementation based on User Plan
                  await controller.evaluateJavascript(
                    source: """
                    (function() {
                        // Avoid adding multiple listeners if re-injected
                        if (window.isInterceptorActive) return;
                        window.isInterceptorActive = true;

                        function getCookie(name) {
                            let cookieValue = null;
                            if (document.cookie && document.cookie !== '') {
                                const cookies = document.cookie.split(';');
                                for (let i = 0; i < cookies.length; i++) {
                                    const cookie = cookies[i].trim();
                                    if (cookie.substring(0, name.length + 1) === (name + '=')) {
                                        cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                                        break;
                                    }
                                }
                            }
                            return cookieValue;
                        }

                        // Specific endpoints from the Backend Analysis plan
                        const reportEndpoints = [
                            '/api/reports/sales/', 
                            '/api/reports/visual/'
                        ];

                        document.addEventListener('submit', function(e) {
                            const form = e.target;
                            // Check if the form action matches our specific report endpoints
                            // Use form.action property to get full resolved URL, fallback to window.location.href if empty
                            let formAction = form.action;
                            if (!formAction || formAction === "") {
                                formAction = window.location.href;
                            }
                            
                            const isReportForm = formAction && reportEndpoints.some(endpoint => formAction.includes(endpoint));

                            if (isReportForm) {
                                e.preventDefault(); // Stop normal submission
                                
                                // Notify Flutter to show the "Generating Report..." loader
                                window.flutter_inappwebview.callHandler('consoleLog', 'Intercepting report generation for: ' + formAction);
                                window.flutter_inappwebview.callHandler('reportGenerationHandler', true);
                                
                                const formData = new FormData(form);
                                const csrfToken = getCookie('csrftoken');
                                
                                fetch(formAction, {
                                    method: 'POST',
                                    body: formData,
                                    headers: {
                                        'X-CSRFToken': csrfToken || ''
                                    }
                                })
                                .then(response => {
                                    if (!response.ok) throw new Error('Status: ' + response.status);
                                    
                                    // Extract filename
                                    const disposition = response.headers.get('Content-Disposition');
                                    let filename = 'report.pdf';
                                    if (disposition && disposition.indexOf('attachment') !== -1) {
                                        var filenameRegex = /filename[^;=\\n]*=((['"]).*?\\2|[^;\\n]*)/;
                                        var matches = filenameRegex.exec(disposition);
                                        if (matches != null && matches[1]) { 
                                          filename = matches[1].replace(/['"]/g, '');
                                        }
                                    }
                                    return response.blob().then(blob => ({ blob, filename }));
                                })
                                .then(({ blob, filename }) => {
                                    var reader = new FileReader();
                                    reader.readAsDataURL(blob); 
                                    reader.onloadend = async function() {
                                        var base64data = reader.result;
                                        
                                        // Strip header (data:application/pdf;base64,) to get pure Base64
                                        // Robust check for comma
                                        var data = base64data;
                                        if (base64data.includes(',')) {
                                            data = base64data.split(',')[1];
                                        }
                                        
                                        // Send in chunks to prevent bridge crash/corruption on large files
                                        var chunkSize = 1024 * 512; // 512KB chunks
                                        var totalLength = data.length;
                                        
                                        await window.flutter_inappwebview.callHandler('blobDownloadHandler', {
                                            'status': 'start',
                                            'filename': filename,
                                            'mimetype': blob.type
                                        });
                                        
                                        for (var offset = 0; offset < totalLength; offset += chunkSize) {
                                            var chunk = data.slice(offset, offset + chunkSize);
                                            await window.flutter_inappwebview.callHandler('blobDownloadHandler', {
                                                'status': 'chunk',
                                                'data': chunk
                                            });
                                        }
                                        
                                        await window.flutter_inappwebview.callHandler('blobDownloadHandler', {
                                            'status': 'end'
                                        });
                                    };
                                })
                                .catch(error => {
                                    window.flutter_inappwebview.callHandler('consoleLog', 'Report generation error: ' + error.message);
                                    window.flutter_inappwebview.callHandler('reportGenerationHandler', false);
                                });
                            }
                        }, true); // Use capture phase to ensure we catch the submit event
                    })();
                  """,
                  );

                  setState(() {
                    // Page loaded
                  });

                  // Handle Restoration Logic
                  if (_isRestoring &&
                      _pendingRestoreFile != null &&
                      _pendingRestoreInputId != null) {
                    // We wait a brief moment to ensure JS is ready
                    await Future.delayed(const Duration(milliseconds: 500));

                    await injectFile(
                      _pendingRestoreFile!,
                      _pendingRestoreInputId!,
                    );

                    setState(() {
                      _isRestoring = false;
                      _pendingRestoreFile = null;
                      _pendingRestoreInputId = null;
                    });

                    // Optional: Show a snackbar
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Image restored after reload"),
                        ),
                      );
                    }
                  }
                },
                onReceivedError: (controller, request, error) {
                  // Only show error screen if the main frame (the page itself) fails to load.
                  // Ignore errors for sub-resources like images, css, etc.
                  if (request.isForMainFrame ?? true) {
                    pullToRefreshController?.endRefreshing();
                    setState(() {
                      _isWebViewError = true;
                      _isFirstLoad = false;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, error) {
                  // Only show error screen if the main frame (the page itself) fails to load.
                  if (request.isForMainFrame ?? true) {
                    pullToRefreshController?.endRefreshing();
                    setState(() {
                      _isWebViewError = true;
                      _isFirstLoad = false;
                    });
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController?.endRefreshing();
                    setState(() {
                      this.progress = progress / 100;
                      _isFirstLoad = false;
                    });
                  } else {
                    setState(() {
                      this.progress = progress / 100;
                    });
                  }
                },
                onConsoleMessage: (controller, consoleMessage) {
                  if (kDebugMode) {
                    print(consoleMessage);
                  }
                },
              ),
              if (!_isFirstLoad && progress < 1.0)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: PharmacyLoader(
                        size: 50,
                        color: Colors.teal,
                        value: progress,
                      ),
                    ),
                  ),
                ),
              if (_isGeneratingReport)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3), // Dim background
                    child: const Center(
                      child: ReportGenerationLoader(
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
              if (_isFirstLoad)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.local_pharmacy,
                                size: 180,
                                color: Colors.teal,
                              ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          "Admin Panel",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Mahmood Pharmacy",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 48),
                        PharmacyLoader(
                          size: 40,
                          color: Colors.teal,
                          value: progress > 0 ? progress : null,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isWebViewError && !_isOffline)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 100,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Something Went Wrong",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "We couldn't load the admin panel.\nPlease check your connection and try again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isWebViewError = false;
                              _isFirstLoad = true;
                            });
                            webViewController?.reload();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Refresh Page"),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isOffline)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 100,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "No Internet Connection",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Please check your internet settings\nand try again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: () {
                            _checkConnection();
                            if (!_isOffline) {
                              setState(() {
                                _isFirstLoad = true;
                              });
                              webViewController?.reload();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text("Try Again"),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isDownloading)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _downloadStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
