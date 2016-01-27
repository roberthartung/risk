// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html' ;
import 'dart:async';
import 'dart:math' show Rectangle, Point;
import 'dart:svg' show PathElement, GElement;

import 'package:risk/communication/server.dart';
import 'package:risk/communication/messages.dart';
import 'package:risk/world/world.dart';
import 'package:risk/user.dart';
import 'package:polymer/polymer.dart';

const num MAP_MARGIN = 30;
const num MAP_PADDING = 20;

/*
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

  final int TEXT_PADDING = 10;

  void renderLabels() {
    game.world.continents.forEach((Continent continent) {
      continent.countries.forEach((Country country) {
        if(selectedCountry == null || selectedCountry == country || (game.world.connectedCountries[selectedCountry] != null && game.world.connectedCountries[selectedCountry].contains(country))) {
          var dim = ctx_hl.measureText(country.name);
          ctx_hl.textBaseline = "middle";
          ctx_hl.fillStyle = 'rgba(255,255,255,0.85)';
          ctx_hl.fillRect(country.middle.x - dim.width/2 - TEXT_PADDING/2, country.middle.y-16/2, dim.width+TEXT_PADDING, 16);
          ctx_hl.fillStyle = 'black';
          ctx_hl.fillText(country.name, country.middle.x - dim.width/2, country.middle.y);
        }

        //if(country.armySize > 0) {
          var text = country.armySize.toString();
          var dim = ctx_hl.measureText(text);
          ctx_hl.textBaseline = "middle";
          ctx_hl.fillStyle = 'rgba(255,255,255,0.85)';
          ctx_hl.fillRect(country.middle.x - dim.width/2 - TEXT_PADDING/2, country.middle.y + 20 - 16/2, dim.width+TEXT_PADDING, 16);
          ctx_hl.fillStyle = 'black';
          ctx_hl.fillText(text, country.middle.x - dim.width/2, country.middle.y + 20);
        //}
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
*/

void main() {
  initPolymer();
  // querySelector('#canvas-background'), querySelector('#canvas-highlight')

  /*
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
    switch(move) {
      case MoveType.CONQUER :
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
        break;
      case MoveType.REINFORCE :
        Country countryToReinforce;
        StreamSubscription waitForSelection;
        StreamSubscription waitForDeselection;
        waitForSelection = game.inputDevice.onCountrySelected.listen((Country country) {
          if(country.user == game.localUser) {
            countryToReinforce = country;
            finishMoveButton.attributes.remove('disabled');
          }
        });

        waitForDeselection = game.inputDevice.onCountryDeselected.listen((Country country) {
          finishMoveButton.attributes['disabled'] = 'disabled';
        });

        finishMoveButton.onClick.first.then((_) {
          waitForSelection.cancel();
          waitForDeselection.cancel();
          game.server.send(new ReinforceMoveFinishedMessage(countryToReinforce));
        });
        break;
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
  */
}