// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html' ;
import 'dart:svg' show SvgSvgElement, GElement, PathElement, Rect;
import 'dart:async';
import 'dart:math' show Rectangle, Point;

import 'package:risk/communication/server.dart';
import 'package:risk/communication/messages.dart';

const num MAP_MARGIN = 30;
const num MAP_PADDING = 20;

final RegExp regexp_stroke = new RegExp('stroke:(#[a-f0-9]{6})');
Map<Country,List<Country>> connectedCountries = new Map();

enum MoveType {
  CONQUER
}

class World {
  final List<Continent> continents = new List();
  final List<Connector> connectors = new List();
  final Map<String, Country> countries = new Map();
  final Rectangle dimension;
  World(this.dimension);
}

class Connector {
  final Country start;
  final Country end;
  final Path2D path;
  Connector(this.start, this.end, this.path);
}

class Continent {
  final List<Country> countries = new List();
  final String name;
  Continent(this.name);
}

class Country {
  final List<CountryPart> parts = new List();
  final String id;
  final String name;
  final String color;
  final Point middle;
  bool isMouseOver = false;
  Country(this.id, this.name, this.color, this.middle);
  toString() => name;
}

class CountryPart {
  final Path2D path;
  CountryPart(this.path);
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
        if(selectedCountry == null || selectedCountry == country || (connectedCountries[selectedCountry] != null && connectedCountries[selectedCountry].contains(country))) {
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
          } else if(connectedCountries[selectedCountry] != null && connectedCountries[selectedCountry].contains(country)) {
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

  void render(num) {
    ctx_hl.save();

    ctx_hl.clearRect(0,0,canvas_hl.width, canvas_hl.height);
    ctx_hl.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
    ctx_hl.scale(scaleX, scaleY);
    renderHighlightedCountries();
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

      game.world.countries.forEach((String id, Country country) {
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

class User {
  final String name;

  static Map<String, User> _users = new Map<String, User>();

  factory User(name) {
    if (_users.containsKey(name)) {
      return _users[name];
    } else {
      final user = new User._(name);
      _users[name] = user;
      return user;
    }
  }

  User._(this.name);

  String toString() => name;
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
  //World get world => _world;
  InputDevice _inputDevice;
  ServerConnection _server;
  ServerConnection get server => _server;
  User localUser;
  GameState state;

  Game(canvas_bg, canvas_hl, container) {
    print('Game()');
    loadWorld('map.svg').then((_) {
      renderer.updateSize();
    });
    _renderer = new GameRenderer(canvas_bg, canvas_hl, container, this);
    _inputDevice = new MouseInputDevice(this);
    setupServer();

    _inputDevice.onCountrySelected.listen((Country country) {
      //print('Country selected: $country');
      renderer.setSelectedCountry(country);
    });

    _inputDevice.onCountryDeselected.listen((Country country) {
      //print('Country deselected: $country');
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
  }

  void setupServer() {
    //String me = null;
    _server = new ServerConnection("ws://${window.location.hostname}:5678");
    _server.onMessage.listen((Message m) {
      if(m is UserJoinedMessage) {
        /// TODO(rh): Use User factory here!!
        _userJoinedController.add(new User(m.user));
        /*
        print('User joined ${m.user}');
        users_list_element.appendHtml("""<tr data-user-name="${m.user}">
          <td class="user-color"><span></span></td>
          <td>${m.user}</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
      </tr>""", validator: userListNodeValidator);
      */
      } else if(m is UserQuitMessage) {
        _userLeftController.add(new User(m.user));
        /*
        print('User quit ${m.user}');
        Element e = querySelector('#users-list tr[data-user-name="${m.user}"]');
        if(e != null)
          e.remove();
        */
      } else if(m is ListOfUsersMessage) {
        m.users.forEach((String name) {
          _userJoinedController.add(new User(name));
          /*
          users_list_element.appendHtml("""<tr data-user-name="${name}">
          <td class="user-color"><span></span></td>
          <td>${name}</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
      </tr>""", validator: userListNodeValidator);
      */
        });
        //print('List of users: ${m.users}');
      } else if(m is GameInformationMessage) {
        localUser = new User(m.me);
        _leaderChangedController.add(new User(m.leader));
        // me = m.me;
        // print("GameInfo - Leader: ${m.leader} - State: ${m.state} Me: ${m.me}");
        /*
        if (m.leader == m.me) {
          print('Local player is leader!');
          startButton.attributes.remove('hidden');
        }
        */
      } else if(m is GameStateChangedMessage) {
        // print('Game state changed: ${m.state}');
        _gameStateChangedController.add(m.state);
      } else if(m is NextMoveMessage) {
        //finishMoveButton.attributes.remove('disabled');
        /*
        if(m is ConquerMoveMessage) {
          print('Conquer move -> Let user select a free country!');
        }
        */
      }
    });
  }
}

/*
CanvasElement canvas_background;
CanvasRenderingContext2D ctx_background;
CanvasElement canvas_highlight;
CanvasRenderingContext2D ctx_highlight;
*/

void loadCountries(GElement countriesElement) {
  countriesElement.children.where((Element e) => e is GElement).forEach((GElement continentElement) {
    String continentName = continentElement.getAttribute('inkscape:label');
    Continent continent = new Continent(continentName);
    continentElement.children.where((Element e) => e is GElement).forEach((GElement countryElement) {
      String countryName = countryElement.getAttribute('inkscape:label');
      String countryId = countryElement.getAttribute('id');
      List<CountryPart> parts = new List();
      String color;
      Point middle;
      countryElement.children.where((Element e) => e is PathElement).forEach((PathElement pathElement) {
        if(pathElement.id == countryElement.id + "-0") {
          Rect bbox = pathElement.getBBox();
          middle = new Point(bbox.x + bbox.width/2, bbox.y + bbox.height/2);
        }
        Match match = regexp_stroke.firstMatch(pathElement.getAttribute('style'));
        if(match != null) {
          color = match.group(1);
          Path2D path = new Path2D(pathElement.getAttribute('d'));
          parts.add(new CountryPart(path));
        }
      });
      Country country = new Country(countryId, countryName, color, middle);
      country.parts.addAll(parts);
      game.world.countries[country.id] = country;
      continent.countries.add(country);
    });

    game.world.continents.add(continent);
  });
}

void loadConnectors(GElement connectorsElement) {
  connectorsElement.children.where((Element e) => e is GElement).forEach((Element connectorLayerElement) {
    Element connectorElement = connectorLayerElement.children.where((Element e) => e is PathElement).first;
    String start = connectorElement.getAttribute('inkscape:connection-start').split('-').first.substring(1);
    String end = connectorElement.getAttribute('inkscape:connection-end').split('-').first.substring(1);
    game.world.connectors.add(new Connector(game.world.countries[start], game.world.countries[end], new Path2D(connectorElement.getAttribute('d'))));
  });
}

void calculateConnectedCountries() {
  connectedCountries.clear();
  game.world.connectors.forEach((Connector connector) {
    connectedCountries.putIfAbsent(connector.start, () => new List()).add(connector.end);
    connectedCountries.putIfAbsent(connector.end, () => new List()).add(connector.start);
  });
}

Future loadWorld(String fileName) {
  return HttpRequest.request(fileName).then((HttpRequest request) {
    /// Create SVG object from responseText
    DocumentFragment svg = new DocumentFragment.svg(request.responseText);
    SvgSvgElement root = svg.querySelector('svg');
    // Append to DOM so we can query position and dimension of countries
    document.body.append(root);
    /// Get viewbox (dimension) from document
    var viewBox = root.getAttribute('viewBox').split(' ');
    Rectangle dimension = new Rectangle<double>(double.parse(viewBox[0]), double.parse(viewBox[1]), double.parse(viewBox[2]), double.parse(viewBox[3]));
    /// Create world, countries, ...
    game.world = new World(dimension);
    loadCountries(root.querySelector('#countries'));
    loadConnectors(root.querySelector('#connectors'));
    /// Pre-calculate the connected countries (Map country -> list of countries)
    calculateConnectedCountries();
    root.remove();
    return true;
  });
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
    print('Next Move: $move');
  });

  startButton.onClick.first.then((MouseEvent ev) {
    print('Starting game...');
    game.server.send(new StartGameMessage());
  });

  finishMoveButton.onClick.listen((MouseEvent ev) {
    print('Move finished');
    game.server.send(new MoveFinishedMessage());
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