library game.map;

import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:risk/world/world.dart';
import 'package:risk/input.dart';

@CustomTag('game-map')
class GameMap extends PolymerElement {
  World world;
  @published String map;
  @published bool lobby = false;
  StreamController<World> _onWorldLoadedController = new StreamController<World>.broadcast();
  Stream<World> get onWorldLoaded => _onWorldLoadedController.stream;

  GameMap.created() : super.created();

  void attached() {
    print('Loading world');
    // $['container']
    loadWorld($['container'], map).then((World world) => _worldLoaded(world));
  }

  void _worldLoaded(World world) {
    print('World loaded');
    this.world = world;
    _onWorldLoadedController.add(world);
  }

  void attach(InputDevice inputDevice) {
    inputDevice.attach($['container']);
    inputDevice.onCountrySelected.listen((Country country) {
      country.element.classes.add('selected');
    });

    inputDevice.onCountryDeselected.listen((Country country) {
      country.element.classes.remove('selected');
    });
    /*
    inputDevice.onCountryMouseOver.listen((Country country) {
      //print('Country over: $country');
      //renderer.requestRender();
    });

    inputDevice.onCountryMouseOut.listen((Country country) {
      //print('Country out: $country');
      //renderer.requestRender();
    });
    */
  }
}