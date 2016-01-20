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
World world;
ServerConnection server;
DivElement game_container;
num scaleX = 1;
num scaleY = 1;
Map<Country,List<Country>> connectedCountries = new Map();
Country hoveredCountry = null;
Country highlightedCountry = null;

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

CanvasElement canvas_background;
CanvasRenderingContext2D ctx_background;
CanvasElement canvas_highlight;
CanvasRenderingContext2D ctx_highlight;
CanvasGradient bg_gradient;
Point mouse_position = null;

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
      world.countries[country.id] = country;
      continent.countries.add(country);
    });

    world.continents.add(continent);
  });
}

void loadConnectors(GElement connectorsElement) {
  connectorsElement.children.where((Element e) => e is GElement).forEach((Element connectorLayerElement) {
    Element connectorElement = connectorLayerElement.children.where((Element e) => e is PathElement).first;
    String start = connectorElement.getAttribute('inkscape:connection-start').split('-').first.substring(1);
    String end = connectorElement.getAttribute('inkscape:connection-end').split('-').first.substring(1);
    world.connectors.add(new Connector(world.countries[start], world.countries[end], new Path2D(connectorElement.getAttribute('d'))));
  });
}

void calculateConnectedCountries() {
  connectedCountries.clear();
  world.connectors.forEach((Connector connector) {
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
    world = new World(dimension);
    loadCountries(root.querySelector('#countries'));
    loadConnectors(root.querySelector('#connectors'));
    /// Pre-calculate the connected countries (Map country -> list of countries)
    calculateConnectedCountries();
    root.remove();
    return true;
  });
}

void renderBase() {
  // Background
  ctx_background.fillStyle=bg_gradient;
  ctx_background.fillRect(0,0,canvas_background.width,canvas_background.height);

  ctx_background.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
  ctx_background.scale(scaleX, scaleY);

  // Grid
  ctx_background.save();
  ctx_background.beginPath();
  for (var x = 0.5-MAP_PADDING; x <= world.dimension.width+MAP_PADDING; x += 20) {
    ctx_background.moveTo(x, -MAP_PADDING);
    ctx_background.lineTo(x, world.dimension.height+MAP_PADDING);
  }
  for (var y = 0.5-MAP_PADDING; y <= world.dimension.height+MAP_PADDING; y += 20) {
    ctx_background.moveTo(-MAP_PADDING, y);
    ctx_background.lineTo(world.dimension.width+MAP_PADDING, y);
  }
  ctx_background.strokeStyle = "#e9b988";
  ctx_background.stroke();
  ctx_background.restore();

  // Outline
  ctx_background.save();
  ctx_background.lineWidth = 5;
  ctx_background.setLineDash([35]);
  ctx_background.beginPath();
  ctx_background.rect(-MAP_PADDING,-MAP_PADDING,world.dimension.width+2*MAP_PADDING,world.dimension.height+2*MAP_PADDING);
  ctx_background.closePath();
  ctx_background.stroke();
  ctx_background.restore();
}

void renderConnectors() {
  world.connectors.forEach((Connector connector) {
    ctx_background.save();
    ctx_background.lineWidth = 2;
    ctx_background.strokeStyle = 'black';
    ctx_background.setLineDash([4,2]);
    ctx_background.stroke(connector.path);
    ctx_background.restore();
  });
}

void renderCountries() {
  //canvas_highlight.setAttribute('title', '');
  world.continents.forEach((Continent continent) {
    continent.countries.forEach((Country country) {
      // Don't show connected countries -> regular mouseover!
      /*
      if(highlightedCountry == null) {
        if(country.isMouseOver) {
          //canvas_highlight.setAttribute('title', country.name);
          ctx.fillStyle = 'red';
        } else {
          ctx.fillStyle = country.color;
        }
      } else {
        if(highlightedCountry == country) {
          ctx.fillStyle = 'red';
        } else if(connectedCountries[highlightedCountry] != null && connectedCountries[highlightedCountry].contains(country)) {
          ctx.fillStyle = country.color;
        } else {
          ctx.fillStyle = 'gray';
        }
      }
      */
      ctx_background.fillStyle = country.color;

      country.parts.forEach((CountryPart part) {
        ctx_background.save();
        ctx_background.stroke(part.path);
        ctx_background.fill(part.path);
        ctx_background.clip(part.path);
        ctx_background.strokeStyle = 'black';
        ctx_background.shadowBlur = 20;
        ctx_background.shadowColor = 'black';
        ctx_background.shadowOffsetX = 0;
        ctx_background.shadowOffsetY = 0;
        ctx_background.stroke(part.path);
        ctx_background.restore();
      });
    });
  });
}

void renderLabels() {
  world.continents.forEach((Continent continent) {
    continent.countries.forEach((Country country) {
      if(highlightedCountry == null || highlightedCountry == country || (connectedCountries[highlightedCountry] != null && connectedCountries[highlightedCountry].contains(country))) {
        var dim = ctx_highlight.measureText(country.name);
        ctx_highlight.textBaseline="middle";
        ctx_highlight.fillStyle = 'rgba(255,255,255,0.85)';
        ctx_highlight.fillRect(country.middle.x - dim.width/2 - 10/2, country.middle.y-16/2, dim.width+10, 16);
        ctx_highlight.fillStyle = 'black';
        ctx_highlight.fillText(country.name, country.middle.x - dim.width/2, country.middle.y);
      }
    });
  });
}

void renderHighlightedCountries() {
  world.continents.forEach((Continent continent) {
    continent.countries.forEach((Country country) {
      // Don't show connected countries -> regular mouseover!
      bool needsRender = false;

      if(highlightedCountry == null) {
        if(country.isMouseOver) {
          ctx_highlight.fillStyle = 'red';
          needsRender = true;
        } /*else {
          ctx_highlight.fillStyle = country.color;
        }*/
      } else {
        if(highlightedCountry == country) {
          ctx_highlight.fillStyle = 'red';
          needsRender = true;
        } else if(connectedCountries[highlightedCountry] != null && connectedCountries[highlightedCountry].contains(country)) {
          ctx_highlight.fillStyle = country.color;
          needsRender = true;
        } else {
          ctx_highlight.fillStyle = 'gray';
          needsRender = true;
        }
      }

      //ctx_background.fillStyle = country.color;
      if(needsRender) {
        country.parts.forEach((CountryPart part) {
          ctx_highlight.save();
          ctx_highlight.stroke(part.path);
          ctx_highlight.fill(part.path);
          ctx_highlight.clip(part.path);
          ctx_highlight.strokeStyle = 'black';
          ctx_highlight.shadowBlur = 20;
          ctx_highlight.shadowColor = 'black';
          ctx_highlight.shadowOffsetX = 0;
          ctx_highlight.shadowOffsetY = 0;
          ctx_highlight.stroke(part.path);
          ctx_highlight.restore();
        });
      }
    });
  });
}

void render(num) {
  ctx_highlight.save();

  ctx_highlight.clearRect(0,0,canvas_highlight.width, canvas_highlight.height);
  ctx_highlight.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
  ctx_highlight.scale(scaleX, scaleY);
  renderHighlightedCountries();
  renderLabels();

  ctx_highlight.restore();
}

void renderBackground(num) {
  ctx_background.save();

  ctx_background.clearRect(0,0,canvas_background.width, canvas_background.height);

  bg_gradient = ctx_background.createLinearGradient(0,0,canvas_background.width,canvas_background.height);
  bg_gradient.addColorStop(0,"#e78778");
  bg_gradient.addColorStop(0.1,"#f8d8c8");
  bg_gradient.addColorStop(0.25,"#ffffff");
  bg_gradient.addColorStop(0.9,"#f8d8a8");
  bg_gradient.addColorStop(1,"#e8b878");

  renderBase();
  renderConnectors();
  renderCountries();

  ctx_background.restore();
}

void setMapSize() {
  canvas_background.width = game_container.clientWidth;
  canvas_background.height = game_container.clientHeight;
  canvas_highlight.width = game_container.clientWidth;
  canvas_highlight.height = game_container.clientHeight;

  double canvasRatio  = canvas_background.width / canvas_background.height;
  double mapRatio = world.dimension.width / world.dimension.height;

  if(canvasRatio > mapRatio) {
    scaleX = (canvas_background.height - 2*MAP_MARGIN - 2*MAP_PADDING) / world.dimension.height;
    scaleY = scaleX;
  } else {
    scaleX = (canvas_background.width - 2*MAP_MARGIN - 2*MAP_PADDING) / world.dimension.width;
    scaleY = scaleX;
  }

  window.animationFrame.then(renderBackground);
  window.animationFrame.then(render);
}

void main() {
  canvas_background = querySelector('#canvas-background');
  ctx_background = canvas_background.getContext('2d');
  canvas_highlight = querySelector('#canvas-highlight');
  ctx_highlight = canvas_highlight.getContext('2d');
  game_container = querySelector('#game');

  loadWorld('map.svg').then((_) {
    setMapSize();
  });

  window.onResize.listen((_) {
    setMapSize();
  });

  canvas_highlight.onMouseMove.listen((MouseEvent ev) {
    ctx_highlight.save();
    ctx_highlight.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
    ctx_highlight.scale(scaleX, scaleY);
    mouse_position = ev.offset;
    world.countries.forEach((String id, Country country) {
      bool isMouseOver = false;
      country.parts.forEach((CountryPart part) {
        if(ctx_highlight.isPointInPath(part.path, ev.offset.x, ev.offset.y)) {
          isMouseOver = true;
        }
      });

      if(country.isMouseOver) {
        if(!isMouseOver) {
          country.isMouseOver = false;
          /// It might happen that the new hovered country will be set, before this one is cleared
          /// thus make sure to set the country only to null if no other country
          /// has already been set hovered.
          if(hoveredCountry == country) {
            hoveredCountry = null;
          }
          
          window.animationFrame.then(render);
        }
      } else {
        if(isMouseOver) {
          country.isMouseOver = true;
          hoveredCountry = country;
          window.animationFrame.then(render);
        }
      }
    });
    ctx_highlight.restore();
  });

  canvas_highlight.onClick.listen((MouseEvent ev) {
    if(hoveredCountry != null) {
      highlightedCountry = hoveredCountry;
    } else {
      highlightedCountry = null;
    }
    window.animationFrame.then(render);
  });

  TableSectionElement users_list_element = querySelector('#users-list');

  final NodeValidator userListNodeValidator = new NodeValidatorBuilder()
    ..allowElement('tr', attributes: ['data-user-name'])
    ..allowElement('td', attributes: ['class'])
    ..allowElement('span')
    ..allowTextElements();

  ButtonElement startButton = querySelector('#btn-start');
  ButtonElement finishMoveButton = querySelector('#btn-finish-move');

  String me = null;
  server = new ServerConnection("ws://${window.location.hostname}:5678");
  server.onMessage.listen((Message m) {
    if(m is UserJoinedMessage) {
      print('User joined ${m.user}');
      users_list_element.appendHtml("""<tr data-user-name="${m.user}">
          <td class="user-color"><span></span></td>
          <td>${m.user}</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
      </tr>""", validator: userListNodeValidator);
    } else if(m is UserQuitMessage) {
      print('User quit ${m.user}');
      Element e = querySelector('#users-list tr[data-user-name="${m.user}"]');
      if(e != null)
        e.remove();
    } else if(m is ListOfUsersMessage) {
      m.users.forEach((String name) {
        users_list_element.appendHtml("""<tr data-user-name="${name}">
          <td class="user-color"><span></span></td>
          <td>${name}</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
      </tr>""", validator: userListNodeValidator);
      });
      //print('List of users: ${m.users}');
    } else if(m is GameInformationMessage) {
      me = m.me;
      print("GameInfo - Leader: ${m.leader} - State: ${m.state} Me: ${m.me}");
      if (m.leader == m.me) {
        print('Local player is leader!');
        startButton.attributes.remove('hidden');
      }
    } else if(m is GameStateChangedMessage) {
      print('Game state changed: ${m.state}');
    } else if(m is NextMoveMessage) {
      finishMoveButton.attributes.remove('disabled');
      if(m is ConquerMoveMessage) {
        print('Conquer move -> Let user select a free country!');
      }
    }
  });

  startButton.onClick.first.then((MouseEvent ev) {
    print('Starting game...');
    server.send(new StartGameMessage());
  });

  finishMoveButton.onClick.listen((MouseEvent ev) {
    print('Move finished');
    server.send(new MoveFinishedMessage());
    finishMoveButton.attributes['disabled'] = 'disabled';
  });

  // print(GameState.values[0]);

  ButtonElement button_login = querySelector('#login button');
  InputElement input_login_name = querySelector('#login-name');
  InputElement input_login_pass = querySelector('#login-pass');
  InputElement input_login_game = querySelector('#login-game');
  button_login.onClick.listen((MouseEvent ev) {
    ev.preventDefault();
    server.send(new LoginMessage(input_login_name.value, input_login_game.value, input_login_pass.value));
    //server.send(JSON.encode({'type':'login','name':input_login_name.value,'game':input_login_game.value}));
  });
}