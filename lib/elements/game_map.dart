library game.map;

import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:risk/world/world.dart';
import 'package:risk/input.dart';

@CustomTag('game-map')
class GameMap extends PolymerElement {
  World world;
  @published String map;
  InputDevice _inputDevice;
  InputDevice get inputDevice => _inputDevice;
  StreamController<World> _onWorldLoadedController = new StreamController<World>.broadcast();
  Stream<World> get onWorldLoaded => _onWorldLoadedController.stream;

  GameMap.created() : super.created();

  void ready() {
    super.ready();
    loadWorld($['container'], map).then((World world) => _worldLoaded(world));
  }

  void _worldLoaded(World world) {
    this.world = world;
    _inputDevice = new MouseInputDevice($['container']);
    _onWorldLoadedController.add(world);
  }
}