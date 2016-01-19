// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html' ;
import 'dart:svg' show SvgSvgElement, GElement, PathElement;
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

CanvasElement canvas;
CanvasRenderingContext2D ctx;
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
    return true;
  });
}

void render(num) {
  ctx.save();

  ctx.clearRect(0,0,canvas.width, canvas.height);
  // Background
  ctx.fillStyle=bg_gradient;
  ctx.fillRect(0,0,canvas.width,canvas.height);

  ctx.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
  ctx.scale(scaleX, scaleY);

  // Grid
  ctx.save();
  ctx.beginPath();
  for (var x = 0.5-MAP_PADDING; x <= world.dimension.width+MAP_PADDING; x += 20) {
    ctx.moveTo(x, -MAP_PADDING);
    ctx.lineTo(x, world.dimension.height+MAP_PADDING);
  }

  for (var y = 0.5-MAP_PADDING; y <= world.dimension.height+MAP_PADDING; y += 20) {
    ctx.moveTo(-MAP_PADDING, y);
    ctx.lineTo(world.dimension.width+MAP_PADDING, y);
  }
  ctx.strokeStyle = "#e9b988";
  ctx.stroke();
  ctx.restore();

  // Outline
  ctx.save();
  ctx.lineWidth = 5;
  ctx.setLineDash([35]);
  ctx.beginPath();
  ctx.rect(-MAP_PADDING,-MAP_PADDING,world.dimension.width+2*MAP_PADDING,world.dimension.height+2*MAP_PADDING);
  ctx.closePath();
  ctx.stroke();

  ctx.restore();

  world.connectors.forEach((Connector connector) {
    ctx.save();
    ctx.lineWidth = 2;
    ctx.strokeStyle = 'black';
    ctx.setLineDash([4,2]);
    ctx.stroke(connector.path);
    ctx.restore();
  });

  canvas.setAttribute('title', '');
  world.continents.forEach((Continent continent) {
    continent.countries.forEach((Country country) {
      // Don't show connected countries -> regular mouseover!
      if(highlightedCountry == null) {
        if(country.isMouseOver) {
          canvas.setAttribute('title', country.name);
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

      country.parts.forEach((CountryPart part) {
        ctx.save();
        ctx.stroke(part.path);
        ctx.fill(part.path);
        ctx.clip(part.path);
        ctx.strokeStyle = 'black';
        ctx.shadowBlur = 20;
        ctx.shadowColor = 'black';
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;
        ctx.stroke(part.path);
        ctx.restore();
      });


    });
  });

  world.continents.forEach((Continent continent) {
    continent.countries.forEach((Country country) {
      if(highlightedCountry == null || highlightedCountry == country || (connectedCountries[highlightedCountry] != null && connectedCountries[highlightedCountry].contains(country))) {
        var dim = ctx.measureText(country.name);
        ctx.textBaseline="middle";
        ctx.fillStyle = 'rgba(255,255,255,0.85)';
        ctx.fillRect(country.middle.x - dim.width/2 - 10/2, country.middle.y-16/2, dim.width+10, 16);
        ctx.fillStyle = 'black';
        ctx.fillText(country.name, country.middle.x - dim.width/2, country.middle.y);
      }
    });
  });

  ctx.restore();
}

void setMapSize() {
  canvas.width = game_container.clientWidth;
  canvas.height = game_container.clientHeight;

  double canvasRatio  = canvas.width / canvas.height;
  double mapRatio = world.dimension.width / world.dimension.height;

  if(canvasRatio > mapRatio) {
    scaleX = (canvas.height - 2*MAP_MARGIN - 2*MAP_PADDING) / world.dimension.height;
    scaleY = scaleX;
  } else {
    scaleX = (canvas.width - 2*MAP_MARGIN - 2*MAP_PADDING) / world.dimension.width;
    scaleY = scaleX;
  }

  window.animationFrame.then(render);
}

void main() {
  canvas = querySelector('#map');
  ctx = canvas.getContext('2d');
  game_container = querySelector('#game');

  bg_gradient = ctx.createLinearGradient(0,0,1920,1080);
  bg_gradient.addColorStop(0,"#e78778");
  bg_gradient.addColorStop(0.1,"#f8d8c8");
  bg_gradient.addColorStop(0.25,"#ffffff");
  bg_gradient.addColorStop(0.9,"#f8d8a8");
  bg_gradient.addColorStop(1,"#e8b878");

  loadWorld('map.svg').then((_) {
    setMapSize();
  });

  window.onResize.listen((_) {
    setMapSize();
  });

  canvas.onMouseMove.listen((MouseEvent ev) {
    ctx.save();
    ctx.translate(MAP_MARGIN+MAP_PADDING,MAP_MARGIN+MAP_PADDING);
    ctx.scale(scaleX, scaleY);
    mouse_position = ev.offset;
    world.countries.forEach((String id, Country country) {
      bool isMouseOver = false;
      country.parts.forEach((CountryPart part) {
        if(ctx.isPointInPath(part.path, ev.offset.x, ev.offset.y)) {
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
    ctx.restore();
  });

  canvas.onClick.listen((MouseEvent ev) {
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
    ..allowElement('td')
    ..allowTextElements();

  ButtonElement startButton = querySelector('#btn-start');
  ButtonElement finishMoveButton = querySelector('#btn-finish-move');

  String me = null;
  server = new ServerConnection("ws://${window.location.hostname}:5678");
  server.onMessage.listen((Message m) {
    if(m is UserJoinedMessage) {
      print('User joined ${m.user}');
      users_list_element.appendHtml("""<tr data-user-name="${m.user}">
          <td>${m.user}</td>
          <td>&nbsp;</td>
          <td>&nbsp;</td>
      </tr>""", validator: userListNodeValidator);
    } else if(m is UserQuitMessage) {
      print('User quit ${m.user}');
      Element e = querySelector('#users-list tr[data-user-name="${m.user}"]');
      if(e != null)
        e.remove();
    } else if(m is ListOfUsersMessage) {
      m.users.forEach((String name) {
        users_list_element.appendHtml("""<tr data-user-name="${name}">
          <td>${name}</td>
          <td>&nbsp;</td>
          <td>&nbsp;</td>
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
      print('Your move!');
      finishMoveButton.attributes.remove('disabled');
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