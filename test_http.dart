import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  try {
    await http.get(Uri.parse('http://0.0.0.0:12345/test'));
  } catch (e) {
    print(e is SocketException);
    print(e is http.ClientException);
  }
}
