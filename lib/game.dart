library risk.game;


import 'dart:async';
import 'dart:collection';
import 'user.dart';
import 'package:observe/observe.dart';

import 'world/world.dart';
import 'communication/server.dart';
import 'communication/messages.dart';

enum MoveType {
  CONQUER,
  REINFORCE,
  ATTACK
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

  final StreamController<ChooseTroopSizeMessage> _chooseTroopSizeController = new StreamController.broadcast();
  Stream<ChooseTroopSizeMessage> get onChooseTroopSize => _chooseTroopSizeController.stream;

  final StreamController<FortifyMoveMessage> _fortifyController = new StreamController.broadcast();
  Stream<FortifyMoveMessage> get onFortify => _fortifyController.stream;

  Queue<Message> _messageQueue = new Queue();

  //GameRenderer _renderer;
  //GameRenderer get renderer => _renderer;
  World _world;
  World get world => _world;
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

  void setWorld(World world) {
    _world = world;
    print('Game: World loaded, ${_messageQueue.length}');
    _messageQueue.forEach(handleMessage);
    _messageQueue.clear();
  }

  void handleMessage(Message m) {
    if(m is CountriesListMessage) {
      Country.countries.forEach((String id, Country country) {
        if(country.user != null) {
          country.conquer(country.user);
        }
      });
    } else if(m is CountryConqueredMessage) {
      m.country.conquer(m.user);
    } else if(m is NextMoveMessage) {
      if(m is ConquerMoveMessage) {
        _nextMoveController.add(MoveType.CONQUER);
      } else if(m is ReinforceMoveMessage) {
        _nextMoveController.add(MoveType.REINFORCE);
      } else if(m is AttackMoveMessage) {
        _nextMoveController.add(MoveType.ATTACK);
      }
    } else if(m is CountryReinforcedMessage) {
      m.country.reinforce();
    } else if(m is LeaderChangedMessage) {
      _leaderChangedController.add(new User(m.leader));
    } else if(m is ChooseTroopSizeMessage) {
      _chooseTroopSizeController.add(m);
    } else if(m is CountryArmySizeMessage) {
      m.country.armySize = m.army;
      m.country.updateArmySize();
    } else if(m is FortifyMoveMessage) {
      _fortifyController.add(m);
    }
  }

  void _setupServer() {
    _server.onMessage.listen((Message m) {
      if(m is UserJoinedMessage) {
        _userJoinedController.add(m.user);
      } else if(m is UserQuitMessage) {
        _userLeftController.add(m.user);
      } else if(m is ListOfUsersMessage) {
        m.users.forEach((User user) {
          _userJoinedController.add(user);
        });
        //print('List of users: ${m.users}');
      } else if(m is GameInformationMessage) {
        localUser = m.me;
        _leaderChangedController.add(new User(m.leader));
        state = m.state;
        _gameStateChangedController.add(m.state);
      } else if(m is GameStateChangedMessage) {
        state = m.state;
        _gameStateChangedController.add(m.state);
      } else {
        if(_world == null) {
          _messageQueue.add(m);
        } else {
          handleMessage(m);
        }
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