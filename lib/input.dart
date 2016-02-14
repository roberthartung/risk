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
  Country get selectedCountry;
  //Stream<Country> get onCountryDoubleClicked;

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
    container.onClick.listen((MouseEvent ev) {
      ev.preventDefault();
      Country country = getCountryFromEvent(ev);
      if(country != null) {
        if(selectedCountry != null) {
          _countryDeselectedController.add(selectedCountry);
        }

        selectedCountry = country;
        _countrySelectedController.add(selectedCountry);
      } else if(selectedCountry != null) {
        Country _selectedCountry = selectedCountry;
        selectedCountry = null;
        _countryDeselectedController.add(_selectedCountry);
      }
    });
  }
}
