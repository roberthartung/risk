// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html' ;
import 'dart:async';
import 'dart:math' show Rectangle, Point;

import 'package:risk/communication/server.dart';
import 'package:risk/communication/messages.dart';
import 'package:risk/world/world.dart';
import 'package:risk/user.dart';

const num MAP_MARGIN = 30;
const num MAP_PADDING = 20;

enum MoveType {
  CONQUER
}

class GameRenderer {
  num _scaleX = 1;
  num _scaleY = 1;
  num get scaleX => _scaleX;
  num get scaleY => _scaleY;
  CanvasGradient bg_gradient;
  final Game game;
  final CanvasElement canvas_bg;
  final CanvasElement canvas_hl;
  final CanvasRenderingContext2D ctx_bg;
  final CanvasRenderingContext2D ctx_hl;

  final Element container;

  Country selectedCountry = null;

  GameRenderer(CanvasElement canvas_bg, CanvasElement canvas_hl, this.container, this.game) :
    this.canvas_bg = canvas_bg,
    this.canvas_hl = canvas_hl,
    this.ctx_bg = canvas_bg.getContext('2d'),
    this.ctx_hl = canvas_hl.getContext('2d') {
    window.onResize.listen((_) {
      updateSize();
    });
  }

  /// Sets the selected country and forces a re-render to highlight the country
  void setSelectedCountry(Country country) {
    selectedCountry = country;
    requestRender();
  }

  void requestRender() {
    window.animationFrame.then(render);
  }

  void updateSize() {
    canvas_bg.width = container.clientWidth;
    canvas_bg.height = container.clientHeight;
    canvas_hl.width = container.clientWidth;
    canvas_hl.height = container.clientHeight;

    double canvasRatio  = canvas_bg.width / canvas_bg.height;
    double mapRatio = game.world.dimension.width / game.world.dimension.height;

    if(canvasRatio > mapRatio) {
      _scaleX = (canvas_bg.height - 2*MAP_MARGIN - 2*MAP_PADDING) / game.world.dimension.height;
      _scaleY = _scaleX;
    } else {
      _scaleX = (canvas_bg.width - 2*MAP_MARGIN - 2*MAP_PADDING) / game.world.dimension.width;
      _scaleY = _scaleX;
    }

    window.animationFrame.then(renderBackground);
    requestRender();
  }

  void renderBase() {
    // Background
    ctx_bg.fillStyle=bg_gradient;
    ctx_bg.fillRect(0,0,canvas_bg.width,canvas_bg.height);

    ctx_bg.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
    ctx_bg.scale(scaleX, scaleY);

    // Grid
    ctx_bg.save();
    ctx_bg.beginPath();
    for (var x = 0.5-MAP_PADDING; x <= game.world.dimension.width+MAP_PADDING; x += 20) {
      ctx_bg.moveTo(x, -MAP_PADDING);
      ctx_bg.lineTo(x, game.world.dimension.height+MAP_PADDING);
    }

    for (var y = 0.5-MAP_PADDING; y <= game.world.dimension.height+MAP_PADDING; y += 20) {
      ctx_bg.moveTo(-MAP_PADDING, y);
      ctx_bg.lineTo(game.world.dimension.width+MAP_PADDING, y);
    }
    ctx_bg.strokeStyle = "#e9b988";
    ctx_bg.stroke();
    ctx_bg.restore();

    // Outline
    ctx_bg.save();
    ctx_bg.lineWidth = 5;
    ctx_bg.setLineDash([35]);
    ctx_bg.beginPath();
    ctx_bg.rect(-MAP_PADDING,-MAP_PADDING,game.world.dimension.width+2*MAP_PADDING, game.world.dimension.height+2*MAP_PADDING);
    ctx_bg.closePath();
    ctx_bg.stroke();
    ctx_bg.restore();
  }

  void renderConnectors() {
    game.world.connectors.forEach((Connector connector) {
      ctx_bg.save();
      ctx_bg.lineWidth = 2;
      ctx_bg.strokeStyle = 'black';
      ctx_bg.setLineDash([4,2]);
      ctx_bg.stroke(connector.path);
      ctx_bg.restore();
    });
  }

  void renderCountries() {
    //canvas_highlight.setAttribute('title', '');
    game.world.continents.forEach((Continent continent) {
      continent.countries.forEach((Country country) {
        // Don't show connected countries -> regular mouseover!
        ctx_bg.fillStyle = country.color;

        country.parts.forEach((CountryPart part) {
          ctx_bg.save();
          ctx_bg.stroke(part.path);
          ctx_bg.fill(part.path);
          ctx_bg.clip(part.path);
          ctx_bg.strokeStyle = 'black';
          ctx_bg.shadowBlur = 20;
          ctx_bg.shadowColor = 'black';
          ctx_bg.shadowOffsetX = 0;
          ctx_bg.shadowOffsetY = 0;
          ctx_bg.stroke(part.path);
          ctx_bg.restore();
        });
      });
    });
  }

  void renderLabels() {
    game.world.continents.forEach((Continent continent) {
      continent.countries.forEach((Country country) {
        if(selectedCountry == null || selectedCountry == country || (game.world.connectedCountries[selectedCountry] != null && game.world.connectedCountries[selectedCountry].contains(country))) {
          var dim = ctx_hl.measureText(country.name);
          ctx_hl.textBaseline="middle";
          ctx_hl.fillStyle = 'rgba(255,255,255,0.85)';
          ctx_hl.fillRect(country.middle.x - dim.width/2 - 10/2, country.middle.y-16/2, dim.width+10, 16);
          ctx_hl.fillStyle = 'black';
          ctx_hl.fillText(country.name, country.middle.x - dim.width/2, country.middle.y);
        }
      });
    });
  }

  void renderHighlightedCountries() {
    game.world.continents.forEach((Continent continent) {
      continent.countries.forEach((Country country) {
        // Don't show connected countries -> regular mouseover!
        bool needsRender = false;

        if(selectedCountry == null) {
          if(country.isMouseOver) {
            ctx_hl.fillStyle = 'red';
            needsRender = true;
          }
        } else {
          if(selectedCountry == country) {
            ctx_hl.fillStyle = 'red';
            needsRender = true;
          } else if(game.world.connectedCountries[selectedCountry] != null && game.world.connectedCountries[selectedCountry].contains(country)) {
            ctx_hl.fillStyle = country.color;
            needsRender = true;
          } else {
            ctx_hl.fillStyle = 'gray';
            needsRender = true;
          }
        }

        //ctx_background.fillStyle = country.color;
        if(needsRender) {
          country.parts.forEach((CountryPart part) {
            ctx_hl.save();
            ctx_hl.stroke(part.path);
            ctx_hl.fill(part.path);
            ctx_hl.clip(part.path);
            ctx_hl.strokeStyle = 'black';
            ctx_hl.shadowBlur = 20;
            ctx_hl.shadowColor = 'black';
            ctx_hl.shadowOffsetX = 0;
            ctx_hl.shadowOffsetY = 0;
            ctx_hl.stroke(part.path);
            ctx_hl.restore();
          });
        }
      });
    });
  }

  void renderConqueredCountries() {
    game.world.continents.forEach((Continent continent) {
      continent.countries.forEach((Country country) {
        // Don't show connected countries -> regular mouseover!
        bool needsRender = false;

        if(selectedCountry == country) {
          ctx_hl.fillStyle = 'red';
          needsRender = true;
        } else if(country.user == game.localUser) {
          ctx_hl.fillStyle = 'green';
          needsRender = true;
        } else if(country.user != null) {
          ctx_hl.fillStyle = country.color;
          needsRender = true;
        } else {
          ctx_hl.fillStyle = 'gray';
          needsRender = true;
        }

        if(needsRender) {
          country.parts.forEach((CountryPart part) {
            ctx_hl.save();
            ctx_hl.stroke(part.path);
            ctx_hl.fill(part.path);
            ctx_hl.clip(part.path);
            ctx_hl.strokeStyle = 'black';
            ctx_hl.shadowBlur = 20;
            ctx_hl.shadowColor = 'black';
            ctx_hl.shadowOffsetX = 0;
            ctx_hl.shadowOffsetY = 0;
            ctx_hl.stroke(part.path);
            ctx_hl.restore();
          });
        }
      });
    });
  }

  void render(num) {
    ctx_hl.save();

    ctx_hl.clearRect(0,0,canvas_hl.width, canvas_hl.height);
    ctx_hl.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
    ctx_hl.scale(scaleX, scaleY);
    if(game.state == GameState.preparation) {
      renderConqueredCountries();
    } else {
      renderHighlightedCountries();
    }
    renderLabels();

    ctx_hl.restore();
  }

  void renderBackground(num) {
    ctx_bg.save();

    ctx_bg.clearRect(0,0,canvas_bg.width, canvas_bg.height);

    bg_gradient = ctx_bg.createLinearGradient(0,0,canvas_bg.width,canvas_bg.height);
    bg_gradient.addColorStop(0,"#e78778");
    bg_gradient.addColorStop(0.1,"#f8d8c8");
    bg_gradient.addColorStop(0.25,"#ffffff");
    bg_gradient.addColorStop(0.9,"#f8d8a8");
    bg_gradient.addColorStop(1,"#e8b878");

    renderBase();
    renderConnectors();
    renderCountries();

    ctx_bg.restore();
  }
}

// Handle input e.g. hover or click countries!
abstract class InputDevice {
  Stream<Country> get onCountrySelected;
  Stream<Country> get onCountryDeselected;
  Stream<Country> get onCountryMouseOver;
  Stream<Country> get onCountryMouseOut;
}

class MouseInputDevice extends InputDevice {
  Point mouse_position = null;

  StreamController<Country> _countrySelectedController = new StreamController.broadcast();
  Stream<Country> get onCountrySelected => _countrySelectedController.stream;

  StreamController<Country> _countryDeselectedController = new StreamController.broadcast();
  Stream<Country> get onCountryDeselected => _countryDeselectedController.stream;

  StreamController<Country> _countryMouseOverController = new StreamController.broadcast();
  Stream<Country> get onCountryMouseOver => _countryMouseOverController.stream;

  StreamController<Country> _countryMouseOutController = new StreamController.broadcast();
  Stream<Country> get onCountryMouseOut => _countryMouseOutController.stream;

  Country hoveredCountry = null;
  Country selectedCountry = null;

  final Game game;

  MouseInputDevice(this.game) {
    game.renderer.canvas_hl.onMouseMove.listen((MouseEvent ev) {
      game.renderer.ctx_hl.save();
      game.renderer.ctx_hl.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
      game.renderer.ctx_hl.scale(game.renderer.scaleX, game.renderer.scaleY);
      mouse_position = ev.offset;

      if(hoveredCountry != null) {
        checkCountry(hoveredCountry);
      }

      Country.countries.forEach((String id, Country country) {
        checkCountry(country);
      });
      game.renderer.ctx_hl.restore();
    });

    game.renderer.canvas_hl.onClick.listen((MouseEvent ev) {
      if(hoveredCountry != null) {
        /// Do nothing if same country has been clicked again
        if(selectedCountry == hoveredCountry) {
          return;
        }
        /// In case it is a different country fire deselected event!
        if(selectedCountry != null) {
          _countryDeselectedController.add(selectedCountry);
        }
        selectedCountry = hoveredCountry;
        _countrySelectedController.add(hoveredCountry);
      } else if(selectedCountry != null) {
        _countryDeselectedController.add(selectedCountry);
        selectedCountry = null;
      }
    });
  }

  void checkCountry(Country country) {
    bool isMouseOver = false;
    country.parts.forEach((CountryPart part) {
      if(game.renderer.ctx_hl.isPointInPath(part.path, mouse_position.x, mouse_position.y)) {
        isMouseOver = true;
      }
    });

    if(country.isMouseOver) {
      if(!isMouseOver) {
        country.isMouseOver = false;
        hoveredCountry = null;
        _countryMouseOutController.add(country);
      }
    } else {
      if(isMouseOver) {
        country.isMouseOver = true;
        hoveredCountry = country;
        _countryMouseOverController.add(country);
      }
    }
  }
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

  GameRenderer _renderer;
  GameRenderer get renderer => _renderer;
  World world;
  InputDevice _inputDevice;
  InputDevice get inputDevice => _inputDevice;
  ServerConnection _server;
  ServerConnection get server => _server;
  User localUser;
  GameState state;

  Game(canvas_bg, canvas_hl, container) {
    loadWorld('map.svg').then((World world) => _worldLoaded(world, canvas_bg, canvas_hl, container));
  }

  void _worldLoaded(World world, canvas_bg, canvas_hl, container) {
    this.world = world;

    _renderer = new GameRenderer(canvas_bg, canvas_hl, container, this);
    _inputDevice = new MouseInputDevice(this);
    setupServer();

    _inputDevice.onCountrySelected.listen((Country country) {
      if(state == GameState.preparation) {
        /// ....
      }
      renderer.setSelectedCountry(country);
    });

    _inputDevice.onCountryDeselected.listen((Country country) {
      renderer.setSelectedCountry(null);
    });

    _inputDevice.onCountryMouseOver.listen((Country country) {
      //print('Country over: $country');
      renderer.requestRender();
    });

    _inputDevice.onCountryMouseOut.listen((Country country) {
      //print('Country out: $country');
      renderer.requestRender();
    });

    renderer.updateSize();
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
        }
      } else if(m is CountryConqueredMessage) {
        m.country.user = m.user;
        game.renderer.requestRender();
      }
    });
  }
}

Game game;

void main() {
  game = new Game(querySelector('#canvas-background'), querySelector('#canvas-highlight'), querySelector('#game'));

  TableSectionElement users_list_element = querySelector('#users-list');

  final NodeValidator userListNodeValidator = new NodeValidatorBuilder()
    ..allowElement('tr', attributes: ['data-user-name'])
    ..allowElement('td', attributes: ['class'])
    ..allowElement('span')
    ..allowTextElements();

  ButtonElement startButton = querySelector('#btn-start');
  ButtonElement finishMoveButton = querySelector('#btn-finish-move');

  game.onUserJoin.listen((User user) {
    users_list_element.appendHtml("""<tr data-user-name="${user.name}">
          <td class="user-color"><span></span></td>
          <td>${user.name}</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
      </tr>""", validator: userListNodeValidator);
  });

  game.onUserLeave.listen((User user) {
    Element e = querySelector('#users-list tr[data-user-name="${user.name}"]');
    if(e != null) {
      e.remove();
    }
  });

  game.onLeaderChange.listen((User user) {
    print('Leader changed: ${user.name}');
    if (user == game.localUser) {
      startButton.attributes.remove('hidden');
    }
  });

  game.onNextMove.listen((MoveType move) {
    if(move == MoveType.CONQUER) {
      Country countryToConquer;
      StreamSubscription waitForSelection;
      StreamSubscription waitForDeselection;
      waitForSelection = game.inputDevice.onCountrySelected.listen((Country country) {
        if(country.user == null) {
          countryToConquer = country;
          finishMoveButton.attributes.remove('disabled');
        }
      });

      waitForDeselection = game.inputDevice.onCountryDeselected.listen((Country country) {
        finishMoveButton.attributes['disabled'] = 'disabled';
      });

      finishMoveButton.onClick.first.then((_) {
        waitForSelection.cancel();
        waitForDeselection.cancel();
        game.server.send(new ConquerMoveFinishedMessage(countryToConquer));
      });
    }
    print('Next Move: $move');
  });

  startButton.onClick.first.then((MouseEvent ev) {
    print('Starting game...');
    game.server.send(new StartGameMessage());
  });

  finishMoveButton.onClick.listen((MouseEvent ev) {
    print('Move finished');
    finishMoveButton.attributes['disabled'] = 'disabled';
  });

  // print(GameState.values[0]);

  ButtonElement button_login = querySelector('#login button');
  InputElement input_login_name = querySelector('#login-name');
  InputElement input_login_pass = querySelector('#login-pass');
  InputElement input_login_game = querySelector('#login-game');
  button_login.onClick.listen((MouseEvent ev) {
    ev.preventDefault();
    game.server.send(new LoginMessage(input_login_name.value, input_login_game.value, input_login_pass.value));
    //server.send(JSON.encode({'type':'login','name':input_login_name.value,'game':input_login_game.value}));
  });
}