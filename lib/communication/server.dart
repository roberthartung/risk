import 'dart:convert' show JSON;
import 'dart:html' show WebSocket, MessageEvent;
import 'dart:async';
import 'messages.dart';

class ServerConnection {
  final StreamController<Message> _messageController = new StreamController.broadcast();
  Stream<Message> get onMessage => _messageController.stream;

  WebSocket _ws;
  Timer _reconnectTimer = null;
  bool get isConnected => _ws.readyState == WebSocket.OPEN;
  ServerConnection(url) {
    _open(url);
  }

  void _open(String url) {
    _ws = new WebSocket(url);

    _ws.onOpen.listen((_) {
      print('WS opened');
      if(_reconnectTimer != null) {
        _reconnectTimer.cancel();
        _reconnectTimer = null;
      }
    });

    _ws.onClose.listen((_) {
      print('WS closed');
    });

    _ws.onError.listen((_) {
      print('WS error');
      if(_reconnectTimer == null) {
        _reconnectTimer = new Timer.periodic(new Duration(seconds: 5), (Timer t) {
          print('Trying to reconnect');
          _open(url);
        });
      }
    });

    _ws.onMessage.listen((MessageEvent ev) {
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
        case 'ConquerMoveMessage':
          _messageController.add(new ConquerMoveMessage.fromObject(obj));
          break;
        case 'ReinforceMoveMessage':
          _messageController.add(new ReinforceMoveMessage.fromObject(obj));
          break;
        default :
          _messageController.addError(obj);
          //print('Unknown message: $obj');
          break;
      }
    });
  }

  void send(Message m) {
    _ws.send(JSON.encode(m.toObject()));
  }
}