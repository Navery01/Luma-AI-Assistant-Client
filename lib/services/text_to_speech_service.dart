import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';


class TextToSpeechService {
  TextToSpeechService({required this.ws});
  final WebSocketChannel ws;

  Future<void> speak(String text) async {
    
  }
}
