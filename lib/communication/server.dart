import 'dart:convert' show JSON;
import 'dart:html' show WebSocket, MessageEvent;
import 'dart:async';
import 'messages.dart';

class ServerConnection {
  final StreamController<Message> _messageController = new StreamController.broadcast();
  Stream<Message> get onMessage => _messageController.stream;

  final WebSocket ws;
  ServerConnection(url) : ws = new WebSocket(url) {
    ws.onOpen.listen((_) {
      print('WS opened');
    });

    ws.onClose.listen((_) {
      print('WS closed');
    });

    ws.onError.listen((_) {
      print('WS error');
    });

    ws.onMessage.listen((MessageEvent ev) {
      //print('WS Message');
      //print(ev.data);
      var obj = JSON.decode(ev.data);
      switch(obj['type']) {
        case 'UserJoinedMessage' :
          _messageController.add(new UserJoinedMessage.fromObject(obj));
          break;
        case 'UserQuitMessage' :
          _messageController.add(new UserQuitMessage.fromObject(obj));
          break;
        case 'ListOfUsersMessage' :
          _messageController.add(new ListOfUsersMessage.fromObject(obj));
          break;
        case 'GameInformationMessage' :
          _messageController.add(new GameInformationMessage.fromObject(obj));
          break;
        case 'GameStateChangedMessage' :
          _messageController.add(new GameStateChangedMessage.fromObject(obj));
          break;
        case 'NextMoveMessage':
          _messageController.add(new NextMoveMessage.fromObject(obj));
          break;
        default :
          _messageController.addError(obj);
          //print('Unknown message: $obj');
          break;
      }
    });
  }

  void send(Message m) {
    ws.send(JSON.encode(m.toObject()));
  }
}