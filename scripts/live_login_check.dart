import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final apiBaseUrl = Platform.environment['API_BASE_URL'];
  final email = Platform.environment['LOGIN_EMAIL'];
  final password = Platform.environment['LOGIN_PASSWORD'];

  if (apiBaseUrl == null || email == null || password == null) {
    stderr.writeln(
      'Set API_BASE_URL, LOGIN_EMAIL, and LOGIN_PASSWORD before running.',
    );
    exitCode = 2;
    return;
  }

  try {
    final uri = Uri.parse(
      '${apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/auth/login/',
    );
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    request.headers.set('ngrok-skip-browser-warning', 'true');

    final body = utf8.encode(jsonEncode({
      'email': email,
      'password': password,
      'remember_me': false,
    }));
    request.contentLength = body.length;
    request.add(body);

    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    client.close(force: true);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        decoded['message']?.toString() ?? decoded['detail']?.toString() ?? raw,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final user = data['user'] as Map<String, dynamic>? ?? {};
    stdout.writeln('Login successful for ${user['email']}.');
    stdout.writeln(
      'Access and refresh tokens received: '
      '${data['access'] != null && data['refresh'] != null}.',
    );
  } catch (error) {
    stderr.writeln('Login failed: $error');
    exitCode = 1;
  }
}
