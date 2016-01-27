library risk.game;

import 'dart:html';
import 'dart:async';
import 'user.dart';
import 'input.dart';
import 'world/world.dart';
import 'communication/server.dart';
import 'communication/messages.dart';

enum MoveType {
  CONQUER,
  REINFORCE
}

enum GameState {
  lobby,
  preparation,
  started,
  finished
}

class Game {
  final StreamController<User> _userJoinedController = new StreamController.broadcast();
  Stream<User> get onUserJoin => _userJoinedController.stream;

  final StreamController<User> _userLeftController = new StreamController.broadcast();
  Stream<User> get onUserLeave => _userLeftController.stream;

  final StreamController<User> _leaderChangedController = new StreamController.broadcast();
  Stream<User> get onLeaderChange => _leaderChangedController.stream;

  final StreamController<GameState> _gameStateChangedController = new StreamController.broadcast();
  Stream<GameState> get onStateChange => _gameStateChangedController.stream;

  final StreamController<MoveType> _nextMoveController = new StreamController.broadcast();
  Stream<MoveType> get onNextMove => _nextMoveController.stream;

  //GameRenderer _renderer;
  //GameRenderer get renderer => _renderer;
  World world;
  ServerConnection _server;
  ServerConnection get server => _server;
  User localUser;
  GameState state;

  Game() {
    // TODO(rh): Wait for map to be loaded and attach event listeners
  }

  void setupServer() {
    //String me = null;
    _server = new ServerConnection("ws://${window.location.hostname}:5678");
    _server.onMessage.listen((Message m) {
      if(m is UserJoinedMessage) {
        _userJoinedController.add(new User(m.user));
      } else if(m is UserQuitMessage) {
        _userLeftController.add(new User(m.user));
      } else if(m is ListOfUsersMessage) {
        m.users.forEach((String name) {
          _userJoinedController.add(new User(name));
        });
        //print('List of users: ${m.users}');
      } else if(m is GameInformationMessage) {
        localUser = new User(m.me);
        _leaderChangedController.add(new User(m.leader));
      } else if(m is GameStateChangedMessage) {
        state = m.state;
        _gameStateChangedController.add(m.state);
      } else if(m is NextMoveMessage) {
        if(m is ConquerMoveMessage) {
          _nextMoveController.add(MoveType.CONQUER);
        } else if(m is ReinforceMoveMessage) {
          _nextMoveController.add(MoveType.REINFORCE);
        }
      } else if(m is CountryConqueredMessage) {
        m.country.user = m.user;
        m.country.armySize = 1;
        //game.renderer.requestRender();
      } else if(m is CountryReinforcedMessage) {
        m.country.armySize++;
        //game.renderer.requestRender();
      }
    });
  }
}