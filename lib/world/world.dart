import 'dart:svg' show SvgSvgElement, GElement, PathElement, Rect;
import 'dart:html';
import 'dart:async';
import 'package:risk/user.dart';

final RegExp regexp_stroke = new RegExp('stroke:(#[a-f0-9]{6})');

class World {
  final List<Continent> continents = new List();
  final List<Connector> connectors = new List();
  //final Map<String, Country> countries = new Map();
  final Rectangle dimension;
  final Map<Country,List<Country>> connectedCountries = new Map();

  World(this.dimension);

  void calculateConnectedCountries() {
    connectedCountries.clear();
    connectors.forEach((Connector connector) {
      connectedCountries.putIfAbsent(connector.start, () => new List()).add(connector.end);
      connectedCountries.putIfAbsent(connector.end, () => new List()).add(connector.start);
    });
  }
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
  static final Map<String, Country> countries = new Map();

  /// User who conquered this country!
  User user = null;

  /// Indicator if this country is hovered!
  bool isMouseOver = false;

  /// Constructor
  Country._(this.id, this.name, this.color, this.middle) {
    countries[id] = this;
  }

  factory Country(id) {
    if(countries.containsKey(id)) {
      return countries[id];
    }

    throw "Country not found: $id";
  }

  /// String representation: name of the country
  toString() => name;
}

class CountryPart {
  final Path2D path;
  CountryPart(this.path);
}

void loadCountries(World world, GElement countriesElement) {
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
      Country country = new Country._(countryId, countryName, color, middle);
      country.parts.addAll(parts);
      //world.countries[country.id] = country;
      continent.countries.add(country);
    });

    world.continents.add(continent);
  });
}

void loadConnectors(World world, GElement connectorsElement) {
  connectorsElement.children.where((Element e) => e is GElement).forEach((Element connectorLayerElement) {
    Element connectorElement = connectorLayerElement.children.where((Element e) => e is PathElement).first;
    String start = connectorElement.getAttribute('inkscape:connection-start').split('-').first.substring(1);
    String end = connectorElement.getAttribute('inkscape:connection-end').split('-').first.substring(1);
    world.connectors.add(new Connector(new Country(start), new Country(end)/*world.countries[start], world.countries[end]*/, new Path2D(connectorElement.getAttribute('d'))));
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
    World world = new World(dimension);
    loadCountries(world, root.querySelector('#countries'));
    loadConnectors(world, root.querySelector('#connectors'));
    /// Pre-calculate the connected countries (Map country -> list of countries)
    world.calculateConnectedCountries();
    root.remove();
    return world;
  });
}