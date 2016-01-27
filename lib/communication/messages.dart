import 'package:risk/world/world.dart';
import 'package:risk/user.dart';
import 'package:risk/game.dart' show GameState;

class Message {
  Message() {

  }

  Message.fromObject(Object json) {

  }

  Map toObject() {
    return {'type':this.runtimeType.toString()};
  }
}

class StartGameMessage extends Message {
  StartGameMessage() : super();
}

class NextMoveMessage extends Message {
  NextMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class ConquerMoveMessage extends NextMoveMessage {
  ConquerMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class ReinforceMoveMessage extends NextMoveMessage {
  ReinforceMoveMessage.fromObject(obj) : super.fromObject(obj);
}

class MoveFinishedMessage extends Message {
  MoveFinishedMessage() : super();
}

class GameStateChangedMessage extends Message {
  final GameState state;
  GameStateChangedMessage.fromObject(obj) : this.state = GameState.values[obj['state']];
}

class LoginMessage extends Message {
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
  final GameState state;
  final String leader;
  final String me;
  GameInformationMessage.fromObject(obj) : super.fromObject(obj), this.state = GameState.values[obj['state']], this.me = obj['you'], this.leader = obj['leader'];
}

class ListOfUsersMessage extends Message {
  final List<String> users;
  ListOfUsersMessage.fromObject(obj) : super.fromObject(obj), this.users = obj['users'];
}

class UserMessage extends Message {
  final String user;
  UserMessage(this.user);

  UserMessage.fromObject(obj) : super.fromObject(obj), this.user = obj['user'];
  Map toObject() {
    Map obj = super.toObject();
    obj['user'] = user;
    return obj;
  }
}

class UserJoinedMessage extends UserMessage {
  UserJoinedMessage.fromObject(obj) : super.fromObject(obj);
}

class UserQuitMessage extends UserMessage {
  UserQuitMessage.fromObject(obj) : super.fromObject(obj);
}

class UserOfflineMessage extends UserMessage {
  UserOfflineMessage.fromObject(obj) : super.fromObject(obj);
}

class UserOnlineMessage extends UserMessage {
  UserOnlineMessage.fromObject(obj) : super.fromObject(obj);
}

class LeaderChangedMessage extends Message {
  final String leader;
  LeaderChangedMessage.fromObject(obj) : super.fromObject(obj), this.leader = obj['leader'];
}

class CountryMessage extends Message {
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
  ConquerMoveFinishedMessage(country) : super(country);
}

class ReinforceMoveFinishedMessage extends CountryMessage {
  ReinforceMoveFinishedMessage(country) : super(country);
}


class CountryConqueredMessage extends CountryMessage {
  final User user;
  CountryConqueredMessage.fromObject(obj) : super.fromObject(obj), this.user = new User(obj['user']);
}

class CountryReinforcedMessage extends CountryMessage {
  final User user;
  CountryReinforcedMessage.fromObject(obj) : super.fromObject(obj), this.user = new User(obj['user']);
}