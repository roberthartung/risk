library game.ui;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:risk/game.dart';
import 'game_map.dart';
import 'package:risk/world/world.dart';
import 'package:risk/communication/server.dart';
import 'package:risk/communication/messages.dart';

@CustomTag('game-ui')
class GameUi extends PolymerElement {
  @observable Game game;
  GameMap map;
  ServerConnection _server;
  GameUi.created() : super.created();

  void ready() {
    super.ready();
    login_show();
    print('$this ready');
    /*
    map = $['map'];
    map.onWorldLoaded.listen(_onWorldLoaded);
    */
  }

  void login_show() {
    FormElement login_form = $['login-form'];
    login_form.onSubmit.listen((Event ev) {
      ev.preventDefault();
      login_do();

      return true;
    });
  }

  void login_do() {
    InputElement login_input_user = $['login-user'];
    InputElement login_input_pass = $['login-pass'];
    InputElement login_input_game = $['login-game'];

    server_setup().then((ServerConnection conn) {
      ($['login'] as Element).hidden = true;
      game = new Game(conn);
      game.onStateChange.listen((GameState newState) {
        print('Game state changed: $newState');
        switch(newState) {
          case GameState.lobby :
              lobby_show();
            break;
          case GameState.preparation :
          case GameState.started :
              game_show();
            break;
          case GameState.finished :
              /// Display finished
            break;
        }
      });
      /*
      StreamSubscription _scr;
      _scr = conn.onMessage.listen((Message m) {
        if(m is GameInformationMessage) {
          /// Depending on the game state, we have to display different
          /// information to the user
          _scr.cancel();
        } else {
          print('Unknown message');
        }
      });
      */

      conn.send(new LoginMessage(login_input_user.value, login_input_pass.value, login_input_game.value));
    });
  }

  Future<ServerConnection> server_setup() {
    Completer<ServerConnection> completer = new Completer();
    if(_server != null && _server.isConnected) {
      completer.complete(_server);
    } else {
      _server = new ServerConnection("ws://${window.location.hostname}:5678");
      _server.onMessage.listen((Message m) {
        print('Message: $m');
      });
      _server.onConnected.listen((_) {
        completer.complete(_server);
      });
    }

    return completer.future;
  }

  void lobby_show() {
    $['lobby'].hidden = false;
  }

  void game_show() {
    $['game'].hidden = false;
  }

  void _onWorldLoaded(World world) {
    /// game = new Game(world, map.inputDevice);
    /*map.inputDevice.onCountrySelected.listen((Country country) {
      if(state == GameState.preparation) {
        /// ....
      }
      country.element.classes.add('selected');
      // renderer.setSelectedCountry(country);
    });

    map.inputDevice.onCountryDeselected.listen((Country country) {
      // renderer.setSelectedCountry(null);
      country.element.classes.remove('selected');
    });

    map.inputDevice.onCountryMouseOver.listen((Country country) {
      //print('Country over: $country');
      //renderer.requestRender();
    });

    map.inputDevice.onCountryMouseOut.listen((Country country) {
      //print('Country out: $country');
      //renderer.requestRender();
    });
    */
  }
}