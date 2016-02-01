//import 'dart:mirrors';
import 'package:risk/world/world.dart';
import 'package:risk/user.dart';
import 'package:risk/game.dart' show GameState;

class Message {
  String get type;
  Message() {

  }

  Message.fromObject(Object json) {

  }

  Map toObject() {
    return {'type':type};
  }
}

class StartGameMessage extends Message {
  bool random;

  String get type => 'StartGameMessage';

  StartGameMessage(this.random) : super();

  Map toObject() {
    Map obj = super.toObject();
    obj['random'] = random;
    return obj;
  }
}

class NextMoveMessage extends Message {
  String get type => 'NextMoveMessage';
  NextMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class ConquerMoveMessage extends NextMoveMessage {
  String get type => 'ConquerMoveMessage';
  ConquerMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class ReinforceMoveMessage extends NextMoveMessage {
  String get type => 'ReinforceMoveMessage';
  ReinforceMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class MoveFinishedMessage extends Message {
  String get type => 'MoveFinishedMessage';
  MoveFinishedMessage() : super();
}

class GameStateChangedMessage extends Message {
  String get type => 'GameStateChangedMessage';
  final GameState state;
  GameStateChangedMessage.fromObject(obj) : this.state = GameState.values[obj['state']];
}

class LoginMessage extends Message {
  String get type => 'LoginMessage';
  final String name;
  final String pass;
  final String game;

  LoginMessage(this.name, this.pass, this.game);

  LoginMessage.fromObject(obj) : super.fromObject(obj), this.name = obj['name'], this.game = obj['game'], this.pass = obj['pass'];
  Map toObject() {
    Map obj = super.toObject();
    obj['name'] = name;
    obj['game'] = game;
    obj['pass'] = pass;
    return obj;
  }
}
class GameInformationMessage extends Message {
  String get type => 'GameInformationMessage';
  final GameState state;
  final String leader;
  final User me;
  GameInformationMessage.fromObject(obj) : super.fromObject(obj), this.state = GameState.values[obj['state']], this.me = new User(obj['user']['name']), this.leader = obj['leader'] {
    this.me.color = obj['user']['color'];
  }
}

class ListOfUsersMessage extends Message {
  String get type => 'ListOfUsersMessage';
  final List<User> users;
  ListOfUsersMessage.fromObject(obj) : super.fromObject(obj), users = _unpackUsers(obj);

  static List<User> _unpackUsers(obj) {
    List<User> users = new List();
    obj['users'].forEach((Map userObj) {
      User user = new User(userObj['name']);
      user.color = userObj['color'];
      users.add(user);
    });
    return users;
  }
}

class UserMessage extends Message {
  String get type => 'UserMessage';
  final User user;
  UserMessage(this.user);

  UserMessage.fromObject(Map obj) : super.fromObject(obj), this.user = new User(obj['user']['name']) {
    if(obj['user'].containsKey('color')) {
      user.color = obj['user']['color'];
    }
  }

  Map toObject() {
    Map obj = super.toObject();
    obj['user'] = {'name': user.name, 'color': user.color};
    return obj;
  }
}

class UserJoinedMessage extends UserMessage {
  String get type => 'UserJoinedMessage';
  UserJoinedMessage.fromObject(obj) : super.fromObject(obj);
}

class UserQuitMessage extends UserMessage {
  String get type => 'UserQuitMessage';
  UserQuitMessage.fromObject(obj) : super.fromObject(obj);
}

class UserOfflineMessage extends UserMessage {
  String get type => 'UserOfflineMessage';
  UserOfflineMessage.fromObject(obj) : super.fromObject(obj);
}

class UserOnlineMessage extends UserMessage {
  String get type => 'UserOnlineMessage';
  UserOnlineMessage.fromObject(obj) : super.fromObject(obj);
}

class LeaderChangedMessage extends Message {
  String get type => 'LeaderChangedMessage';
  final String leader;
  LeaderChangedMessage.fromObject(obj) : super.fromObject(obj), this.leader = obj['leader'];
}

class CountryMessage extends Message {
  String get type => 'CountryMessage';
  final Country country;
  CountryMessage(this.country) : super();

  CountryMessage.fromObject(obj) : super.fromObject(obj), country = new Country(obj['country']);

  Map toObject() {
    Map obj = super.toObject();
    obj['country'] = country.id;
    return obj;
  }
}

class ConquerMoveFinishedMessage extends CountryMessage {
  String get type => 'ConquerMoveFinishedMessage';
  ConquerMoveFinishedMessage(country) : super(country);
}

class ReinforceMoveFinishedMessage extends CountryMessage {
  String get type => 'ReinforceMoveFinishedMessage';
  ReinforceMoveFinishedMessage(country) : super(country);
}

class CountryConqueredMessage extends CountryMessage {
  String get type => 'CountryConqueredMessage';
  final User user;
  CountryConqueredMessage.fromObject(obj) : super.fromObject(obj), this.user = new User(obj['user']['name']);
}

class CountryReinforcedMessage extends CountryMessage {
  String get type => 'CountryReinforcedMessage';
  CountryReinforcedMessage.fromObject(obj) : super.fromObject(obj);
}

class CountriesListMessage extends Message {
  String get type => 'CountriesListMessage';
  final Map countries;
  CountriesListMessage.fromObject(obj) : super.fromObject(obj), this.countries = obj['countries'] {
    countries.forEach((String id, Map data) {
      Country country = new Country(id);
      if(data['user'] != null) {
        country.user = new User(data['user']['name']);
      }
      country.armySize = data['army'];
    });
  }
}