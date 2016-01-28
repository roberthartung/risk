library risk.game;


import 'dart:async';
import 'user.dart';
import 'package:observe/observe.dart';

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

class Game extends Observable {
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
  @observable User leader;
  @observable User localUser;
  @observable GameState state;
  @observable ObservableList users = new ObservableList();

  Game(uri) {
    _server = new ServerConnection(uri);
    _setupServer();
  }

  void login(String user, String pass, String game) {
    _server.send(new LoginMessage(user, pass, game));
  }

  void _setupServer() {
    _server.onMessage.listen((Message m) {
      print('$m');
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
        state = m.state;
        _gameStateChangedController.add(m.state);
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
      } else if(m is LeaderChangedMessage) {
        _leaderChangedController.add(new User(m.leader));
      } else if(m is CountriesListMessage) {
        /// TODO(rh): Update countries?
        print('List: $m');
        print(m.countries);
      }
    });

    onUserJoin.listen((User u) {
      users.add(u);
    });

    onUserLeave.listen((User u) {
      users.remove(u);
    });

    onLeaderChange.listen((User u) {
      leader = u;
    });
  }
}