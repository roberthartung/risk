import 'dart:svg' show SvgSvgElement, GElement, PathElement, Rect, TextElement, CircleElement;
import 'dart:html';
import 'dart:async';
import 'package:risk/user.dart';
import 'dart:math';

final RegExp regexp_stroke = new RegExp('stroke:(#[a-f0-9]{6})');

class World {
  final List<Continent> continents = new List();
  final List<Connector> connectors = new List();
  final Rectangle dimension;
  final Map<Country,List<Country>> connectedCountries = new Map();
  final SvgSvgElement root;

  World(this.dimension, this.root);

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
  final Element element;
  Continent(this.name, this.element);
}

class Country {
  final List<CountryPart> parts = new List();

  String _id;
  String get id => _id;

  String _name;
  String get name => _name;

  String _color;
  String get color => _color;

  Point _middle;
  Point get middle => _middle;

  Element _element;
  Element get element => _element;

  Element _text;

  /// Map of id to [Country] instances
  static final Map<String, Country> countries = new Map();

  /// User who conquered this country!
  User user = null;

  int armySize = 0;

  /// Indicator if this country is hovered!
  bool isMouseOver = false;

  /// Constructor
  Country._(this._id/*, this.name, this.color, this.middle, this.element*/);
  //{
    //countries[id] = this;
    //CircleElement circle = this.element.querySelector('circle');
    //if(circle != null) {
      //circle.attributes['fill'] = 'green';
      //circle.style['fill'] = 'green';
      //Random r = new Random();
      //circle.style.setProperty('fill', 'rgb(${r.nextInt(255)},${r.nextInt(255)},${r.nextInt(255)})');
    //}
  //}

  factory Country(id) {
    if(countries.containsKey(id)) {
      return countries[id];
    }

    Country c = new Country._(id);
    countries[id] = c;
    return c;
  }

  void conquer(User user) {
    this.user = user;
    this.armySize = 1;
    this.element
      ..classes.add('conquered')
      ..querySelector('circle').style.setProperty('fill', user.color);
    updateArmySize();
  }

  void reinforce([int amount = 1]) {
    this.armySize += amount;
    updateArmySize();
  }

  void setElement(Element e) {
    _element = e;
    _text = e.querySelector('text');
    updateArmySize();
  }

  void updateArmySize() {
    _text.text = '$armySize';
  }

  /// String representation: name of the country
  toString() => name;
}

class CountryPart {
  final Path2D path;
  final Element element;
  CountryPart(this.path, this.element);
}

void loadCountries(World world, GElement countriesElement) {
  countriesElement.children.where((Element e) => e is GElement).forEach((GElement continentElement) {
    continentElement.classes.add('continent');
    String continentName = continentElement.getAttribute('inkscape:label');
    Continent continent = new Continent(continentName, continentElement);
    continentElement.children.where((Element e) => e is GElement).forEach((GElement countryElement) {
      countryElement.classes.add('country');
      String countryName = countryElement.getAttribute('inkscape:label');
      String countryId = countryElement.getAttribute('id');
      List<CountryPart> parts = new List();
      String color;
      Point middle;
      PathElement primaryElement;
      countryElement.children.where((Element e) => e is PathElement).forEach((PathElement pathElement) {
        pathElement.classes.add('countrypart');
        if(pathElement.id == countryElement.id + "-0") {
          Rect bbox = pathElement.getBBox();
          middle = new Point(bbox.x + bbox.width/2, bbox.y + bbox.height/2);
          primaryElement = pathElement;
        }
        Match match = regexp_stroke.firstMatch(pathElement.getAttribute('style'));
        if(match != null) {
          color = match.group(1);
          Path2D path = new Path2D(pathElement.getAttribute('d'));
          parts.add(new CountryPart(path, pathElement));
        }
      });
      Country country = new Country(countryId);
      // countryName, color, middle, countryElement
      country._name = countryName;
      country._color = color;
      country._middle = middle;
      country.setElement(countryElement);
      /// Query for circle to append sibling <text> element
      //CircleElement circle = country._element.querySelector('circle');
      //TextElement text = new TextElement();
      //text.appendText('0');
      //if(primaryElement != null) {
      //var pos = primaryElement.getBBox();
      //text.style.setProperty('fill', '#fff');
      //text.attributes['x'] = circle.attributes['cx'];
      //text.attributes['y'] = circle.attributes['cy'];
      // text.attributes['x'] = '${pos.x + pos.width/2}';
      //text.attributes['y'] = '${pos.y + pos.height/2}';
      //}
      //circle.parent.append(text);
      //circle.insertAdjacentElement('afterend', text);
      country.parts.addAll(parts);
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
    world.connectors.add(new Connector(new Country(start), new Country(end), new Path2D(connectorElement.getAttribute('d'))));
  });
}

Future loadWorld(Element container, String fileName) {
  return HttpRequest.request(fileName).then((HttpRequest request) {
    print('Map file received');
    /// Create SVG object from responseText
    DocumentFragment svg = new DocumentFragment.svg(request.responseText);
    SvgSvgElement root = svg.querySelector('svg');
    // Append to DOM so we can query position and dimension of countries
    container.append(root);
    /// Get viewbox (dimension) from document
    var viewBox = root.getAttribute('viewBox').split(' ');
    Rectangle dimension = new Rectangle<double>(double.parse(viewBox[0]), double.parse(viewBox[1]), double.parse(viewBox[2]), double.parse(viewBox[3]));
    /// Create world, countries, ...
    World world = new World(dimension, root);
    loadCountries(world, root.querySelector('#countries'));
    loadConnectors(world, root.querySelector('#connectors'));
    /// Pre-calculate the connected countries (Map country -> list of countries)
    world.calculateConnectedCountries();
    PathElement attackPath = new PathElement();
    attackPath.attributes['style'] = 'stroke:black; stroke-width: 4px; stroke-dasharray: 5 5; marker-end: url(#markerArrow); fill: none;';
    attackPath.id = 'attackindicator';
    attackPath.hidden = true;
    // <path d="M10,10 Q90,30 110,110"/>
    world.root.append(attackPath);
    return world;
  });
}