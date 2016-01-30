library risk.input;

import 'dart:html';
import 'dart:svg' show PathElement, GElement;
import 'dart:async';
//import 'dart:math' show Point;
import 'package:risk/world/world.dart';

// Handle input e.g. hover or click countries!
abstract class InputDevice {
  Stream<Country> get onCountrySelected;
  Stream<Country> get onCountryDeselected;
  Stream<Country> get onCountryMouseOver;
  Stream<Country> get onCountryMouseOut;
  Stream<Country> get onCountryDoubleClicked;

  void attach(Element container);
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

  StreamController<Country> _countryDoubleClickedController = new StreamController.broadcast();
  Stream<Country> get onCountryDoubleClicked => _countryDoubleClickedController.stream;

  Country selectedCountry = null;

  MouseInputDevice() {

  }

  Country getCountryFromEvent(MouseEvent ev) {
    if(ev.target is PathElement) {
      PathElement path = ev.target;
      if (path.classes.contains('countrypart')) {
        GElement countryElement = path.parent;
        Country country = Country.countries[countryElement.id];
        if (country == null) {
          throw "Click on unknown country";
        }
        return country;
      }
    }
    return null;
  }

  void attach(Element container) {
    container.onDoubleClick.listen((MouseEvent ev) {
      if(selectedCountry != null) {
        _countryDoubleClickedController.add(selectedCountry);
      }
    });

    container.onClick.listen((MouseEvent ev) {
      Country country = getCountryFromEvent(ev);
      if(country != null) {
        if(selectedCountry != null) {
          _countryDeselectedController.add(selectedCountry);
        }

        selectedCountry = country;
        _countrySelectedController.add(selectedCountry);
      } else if(selectedCountry != null) {
        _countryDeselectedController.add(selectedCountry);
        selectedCountry = null;
      }
    });
  }
}
