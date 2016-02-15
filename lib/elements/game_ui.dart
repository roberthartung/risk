library game.ui;

import 'dart:html' hide Point;
import 'dart:async' hide Point;
import 'dart:svg' show PathElement, GraphicsElement, CircleElement, Rect, Matrix, GeometryElement, Point;
import 'dart:math' hide Point;

import 'package:vector_math/vector_math.dart';
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
    _inputDevice.onCountrySelected.listen((Country country) {
      AudioElement click = $['sound-click'];
      //click.pause();
      click.currentTime = 0;
      click.play();
    });
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

  void clearHighlightedCountries() {
    game.world.connectedCountries.keys.forEach((Country country) {
      country.element.classes.remove('highlight');
    });
  }

  void highlightCountryAndConnected(Country country) {
    /// Iterate through connected countries and highlight all countries that
    /// are from a different user!
    game.world.connectedCountries[country].forEach((Country connectedCountry) {
      if(connectedCountry.user != country.user) {
        connectedCountry.element.classes.add('highlight');
      }
    });
  }

  void highlightReinforceableCountries() {
    clearHighlightedCountries();
    game.world.connectedCountries.forEach((Country country, List<Country> countries) {
      if(country.user == game.localUser) {
        country.element.classes.add('highlight');
      }
    });
  }

  void highlightPossibleCountries() {
    clearHighlightedCountries();
    game.world.connectedCountries.forEach((Country country, List<Country> countries) {
      if(country.user == game.localUser && country.armySize > 1) {
        country.element.classes.add('highlight');
      }
    });
  }

  Future<Element> waitForClick(List<Element> elements) {
    Completer<Element> completer = new Completer();
    List<StreamSubscription> subscriptions = [];

    void handleClick(Element e) {
      subscriptions.forEach((StreamSubscription subscription) {
        subscription.cancel();
      });
      completer.complete(e);
    }

    elements.forEach((Element element) {
      subscriptions.add(element.onClick.listen((MouseEvent ev) => handleClick(element)));
    });

    return completer.future;
  }

  void setMoveDescription(String text) {
    SpanElement moveDescription = $['move-description'];
    moveDescription.text = text;
  }

  void finishMove() {
    setMoveDescription('');
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

    /*
    Country start = null;
    //Point startPos = null;
    _inputDevice.onCountrySelected.listen((Country country) {
      if(start == null) {
        start = country;
      } else if(start != country) {

        Vector2 getPos(GraphicsElement e) {
          e.attributes['fill'] = 'red';
          Point p = game.world.root.createSvgPoint();
          Rect bbox = e.getBBox();
          p.x = bbox.x + bbox.width/2;
          p.y = bbox.y + bbox.height/2;
          Matrix m = e.getTransformToElement(game.world.root);
          var sp = p.matrixTransform(m);
          Vector2 pos = new Vector2(sp.x, sp.y);

          return pos;
        }

        Vector2 begin = getPos(start.element.querySelector('circle'));
        Vector2 end = getPos(country.element.querySelector('circle')); // #${country.element.id}-0

        PathElement path = game.world.root.querySelector('#attackindicator');
        Vector2 dir = end - begin;
        Vector2 middle = begin + dir.scaled(0.5);
        num t = radians(-90.0);
        Vector2 norm = new Vector2(dir.x * cos(t) - dir.y * sin(t), dir.x * sin(t) + dir.y * cos(t));
        norm.normalize();
        Vector2 through = middle + norm * 50.0; // dir.length
        path.attributes['d'] = 'M${begin.x},${begin.y} Q${through.x},${through.y} ${end.x},${end.y}';

        start = null;
      }
    });
    */

    ButtonElement nextPhaseButton = $['btn-next-phase'];
    nextPhaseButton.onClick.listen((MouseEvent ev) {
      ev.preventDefault();
      game.server.send(new NextPhaseMessage());
      finishMove();
      // nextPhaseButton.disabled = true;
    });
    // map.classes.add('highlighed');
    //ButtonElement finishMoveButton = $['game-move-finish'];
    game.onNextMove.listen((MoveType move) {
      /// Initialle: Button is disabled
      //finishMoveButton.attributes['disabled'] = 'disabled';
      print('Next move: $move');
      switch(move) {
        case MoveType.CONQUER :
          setMoveDescription('Select a country to conquer!');
          StreamSubscription _waitForSelection;
          clearHighlightedCountries();
          _waitForSelection = inputDevice.onCountrySelected.listen((Country country) {
            if(country.user == null) {
              _waitForSelection.cancel();
              game.server.send(new ConquerMoveFinishedMessage(country));
              clearHighlightedCountries();
              finishMove();
            }
          });
          break;
        case MoveType.REINFORCE :
          setMoveDescription('Select a country to refinforce!');
          StreamSubscription _waitForSelection;
          highlightReinforceableCountries();
          _waitForSelection = inputDevice.onCountrySelected.listen((Country country) {
            if(country.user == game.localUser) {
              _waitForSelection.cancel();
              game.server.send(new ReinforceMoveFinishedMessage(country));
              clearHighlightedCountries();
              finishMove();
            }
          });
          break;
        case MoveType.ATTACK :
          setMoveDescription('Select a country to attack from!');
          /// Highlight countries for this user and all countries he can attack
          highlightPossibleCountries();

          Country country = null;
          StreamSubscription _waitForDeselect = _inputDevice.onCountryDeselected.listen((Country deselectedCountry) {
            /// The [selectedCountry] property will hold the new country
            /// If null, it is an actual deselect and not a different country
            /// the user clicked on.
            if(_inputDevice.selectedCountry == null) {
              country = null;
              highlightPossibleCountries();
              setMoveDescription('Select a country to attack from!');
            }
          });

          /// Wait for the user to select a highlighted country
          /// This is either his own or another user's country
          StreamSubscription _waitForSelect;
          _waitForSelect = _inputDevice.onCountrySelected.listen((Country selectedCountry) {
            /// First country selected
            if(country == null) {
              if(selectedCountry.element.classes.contains('highlight')) {
                /// Make sure to remove highlight from all countries
                clearHighlightedCountries();
                highlightCountryAndConnected(selectedCountry);
                country = selectedCountry;
                setMoveDescription('Select a country to attack to!');
              }
            } else {
              if(selectedCountry.element.classes.contains('highlight')) {
                _waitForDeselect.cancel();
                _waitForSelect.cancel();
                /// This is a valid attack move
                /// Ask user with how many ppl he wants to attack
                if (selectedCountry.user == game.localUser) {
                  game.server.send(new AttackMessage(selectedCountry, country));
                  finishMove();
                } else {
                  game.server.send(new AttackMessage(country, selectedCountry));
                  finishMove();
                }
              }
            }
          });
          break;
      }
    });

    game.onChooseTroopSize.listen((ChooseTroopSizeMessage m) {
      List<Element> elements = [];
      ImageElement dice3 = $['control-dice-3'];
      ImageElement dice2 = $['control-dice-2'];
      ImageElement dice1 = $['control-dice-1'];
      dice1.attributes['hidden'] = 'true';
      dice2.attributes['hidden'] = 'true';
      dice3.attributes['hidden'] = 'true';
      if(m.attacker) {
        setMoveDescription('Choose troop size to attack with!');
        /// TODO(rh): Dice color red
        if(m.country.armySize > 3) {
          elements.add(dice3);
          dice3.attributes.remove('hidden');
        }
        if(m.country.armySize > 2) {
          elements.add(dice2);
          dice2.attributes.remove('hidden');
        }
        if(m.country.armySize > 1) {
          elements.add(dice1);
          dice1.attributes.remove('hidden');
        }
      } else if(m.defender) {
        setMoveDescription('Choose troop size to defend with!');
        /// TODO(rh): Dice color blue
        if(m.country.armySize >= 2) {
          elements.add($['control-dice-2']);
          dice2.attributes.remove('hidden');
        }
        if(m.country.armySize >= 1) {
          elements.add($['control-dice-1']);
          dice1.attributes.remove('hidden');
        }
      } else {
        throw "Invalid ChooseTroopSizeMessage";
      }

      print("Waiting for dice click");
      waitForClick(elements).then((Element e) {
        print('Clicked: ${e.id}');
        int size = int.parse(e.id.substring("control-dice-".length));
        /// TODO(rh): Check if size is possible?!
        game.server.send(new TroopSizeMessage(size));
        finishMove();
      });
    });

    RangeInputElement range = $['control-range'];
    SpanElement range_text = $['control-range-text'];

    range.onChange.listen((_) {
      range_text.text = range.value;
    });

    game.onFortify.listen((FortifyMoveMessage m) {
      if(m.from != null && m.to != null) {
        setMoveDescription('Choose troops to move to conquered country!');
        range.min = '${m.min}';
        range.max = '${m.max}';
        range.value = range.min;
        range_text.text = range.value;
        range.attributes.remove('hidden');
        range_text.attributes.remove('hidden');
        nextPhaseButton.onClick.first.then((MouseEvent ev) {
          ev.stopPropagation();
          game.server.send(new FortifyMessage(m.from, m.to, int.parse(range.value)));
          finishMove();
          range.attributes['hidden'] = 'true';
          range_text.attributes['hidden'] = 'true';
        });
      } else {
        setMoveDescription('NOT IMPLEMENTED! Move on to next phase!');
        print('Free Fortify');
        /// TODO(rh): Make user select countries to move army from
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
    map.classes.add('highlighed');
    $['map-container'].append(map);
  }
}