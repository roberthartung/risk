library risk.input;

import 'dart:html';
import 'dart:svg' show PathElement, GElement;
import 'dart:async';
//import 'dart:math' show Point;
import 'package:risk/world/world.dart';
import 'package:risk/game.dart';

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

  //Country hoveredCountry = null;
  Country selectedCountry = null;

  MouseInputDevice(Element container) {
    container.onClick.listen((MouseEvent ev) {
      if(ev.target is PathElement) {
        PathElement path = ev.target;
        if(path.classes.contains('countrypart')) {
          GElement countryElement = path.parent;
          Country country = Country.countries[countryElement.id];
          if(country == null) {
            throw "Click on unknown country";
          }

          if(selectedCountry != null) {
            _countryDeselectedController.add(selectedCountry);
          }

          selectedCountry = country;
          _countrySelectedController.add(selectedCountry);
        }
      } else if(selectedCountry != null) {
        //print('Click to unknown target: ${ev.target}');
        _countryDeselectedController.add(selectedCountry);
        selectedCountry = null;
      }
    });
    /*
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
    */
    /*
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
    */
    /// TODO(rh)
  }
/*
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
  */
}
