library game.ui;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:risk/game.dart';
import 'game_map.dart';
import 'package:risk/world/world.dart';
import 'package:risk/communication/messages.dart';
import 'package:risk/input.dart';

@CustomTag('game-ui')
class GameUi extends PolymerElement {
  @observable Game game;
  GameMap map;
  InputDevice _inputDevice;
  InputDevice get inputDevice => _inputDevice;

  GameUi.created() : super.created();

  void ready() {
    super.ready();
    login_show();
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

    _inputDevice = new MouseInputDevice();
    /// At this point, we want to login to the server
    game = new Game("ws://${window.location.hostname}:5678");
    game_setup_logic();
    game.server.onConnected.listen((_) {
      game.login(login_input_user.value, login_input_pass.value, login_input_game.value);
    });
    /// Only wait for first state here!
    game.onStateChange.first.then((GameState newState) {
      print('Initial game state: $newState');
      ($['login'] as Element).hidden = true;
      switch(newState) {
        case GameState.lobby :
            lobby_show();
          break;
        case GameState.preparation :
        case GameState.started :
            game_show('map.svg');
          break;
        case GameState.finished :
            /// TODO(rh): Display finished message
          break;
      }
    });
  }

  void lobby_show() {
    $['lobby'].hidden = false;
    StreamSubscription sub;
    sub = ($['lobby-start'] as ButtonElement).onClick.listen((MouseEvent ev) {
      if(game.localUser == game.leader) {
        game.server.send(new StartGameMessage(($['lobby-random-conquering'] as CheckboxInputElement).checked));
      } else {
        throw "Request to start for non-leader.";
      }
    });

    StreamSubscription sub_state;
    sub_state = game.onStateChange.listen((GameState state) {
      if(state == GameState.started || state == GameState.preparation) {
        $['lobby'].hidden = true;
        sub.cancel();
        String map = ($['lobby-map'] as SelectElement).value;
        game_show(map);
      }
      sub_state.cancel();
    });
  }

  void game_setup_logic() {
    print('game_setup_logic');
    game.onStateChange.listen((GameState state) {
      switch(state) {
        case GameState.preparation :

          break;
        case GameState.started :

          break;
        default :
            print('Unexpected gamestate in logic: $state');
          break;
      }
    });

    ButtonElement finishMoveButton = $['game-move-finish'];
    game.onNextMove.listen((MoveType move) {
      /// Initialle: Button is disabled
      finishMoveButton.attributes['disabled'] = 'disabled';
      print('Next move: $move');
      switch(move) {
        case MoveType.CONQUER :

          Country countryToConquer;
          StreamSubscription waitForSelection;
          StreamSubscription waitForDeselection;
          StreamSubscription waitForDblClick;
          StreamSubscription waitForButtonClick;

          waitForSelection = _inputDevice.onCountrySelected.listen((Country country) {
            if(country.user == null) {
              countryToConquer = country;
              finishMoveButton.attributes.remove('disabled');
            }
          });

          waitForDblClick = _inputDevice.onCountryDoubleClicked.listen((Country country) {
            if(country.user == null) {
              waitForSelection.cancel();
              waitForDeselection.cancel();
              waitForDblClick.cancel();
              waitForButtonClick.cancel();
              game.server.send(new ConquerMoveFinishedMessage(country));
            }
          });

          waitForDeselection = _inputDevice.onCountryDeselected.listen((Country country) {
            finishMoveButton.attributes['disabled'] = 'disabled';
          });

          waitForButtonClick = finishMoveButton.onClick.listen((_) {
            waitForSelection.cancel();
            waitForDeselection.cancel();
            waitForDblClick.cancel();
            waitForButtonClick.cancel();
            game.server.send(new ConquerMoveFinishedMessage(countryToConquer));
            finishMoveButton.attributes['disabled'] = 'disabled';
          });
          break;
        case MoveType.REINFORCE :
          Country countryToReinforce;
          StreamSubscription waitForSelection;
          StreamSubscription waitForDeselection;
          StreamSubscription waitForDblClick;
          StreamSubscription waitForButtonClick;

          waitForSelection = _inputDevice.onCountrySelected.listen((Country country) {
            if(country.user == game.localUser) {
              countryToReinforce = country;
              finishMoveButton.attributes.remove('disabled');
            }
          });

          waitForDblClick = _inputDevice.onCountryDoubleClicked.listen((Country country) {
            if(country.user == game.localUser) {
              waitForSelection.cancel();
              waitForDeselection.cancel();
              waitForDblClick.cancel();
              waitForButtonClick.cancel();
              game.server.send(new ReinforceMoveFinishedMessage(country));
            }
          });

          waitForDeselection = _inputDevice.onCountryDeselected.listen((Country country) {
            finishMoveButton.attributes['disabled'] = 'disabled';
          });

          waitForButtonClick = finishMoveButton.onClick.listen((_) {
            waitForSelection.cancel();
            waitForDeselection.cancel();
            waitForDblClick.cancel();
            waitForButtonClick.cancel();
            game.server.send(new ReinforceMoveFinishedMessage(countryToReinforce));
            finishMoveButton.attributes['disabled'] = 'disabled';
          });
          break;
      }
    });
  }

  void game_show(String map_filename) {
    /// Show Map
    $['game'].hidden = false;
    //final NodeValidator gameMapNodeValidator = new NodeValidatorBuilder()..allowElement('game-map', attributes: ['id', 'map']);
    //$['game'].appendHtml('<game-map id="map" map="${map_filename}"></game-map>', validator: gameMapNodeValidator);
    //print('Foo: ${map_filename}');
    map = new Element.tag('game-map');
    map.setAttribute('map', map_filename);
    map.onWorldLoaded.listen((World w) {
      map.attach(_inputDevice);
      game.setWorld(w);
    });
    $['game'].append(map);
  }
}