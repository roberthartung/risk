library game.ui;

import 'package:polymer/polymer.dart';
import 'package:risk/game.dart';
import 'game_map.dart';
import 'package:risk/world/world.dart';

@CustomTag('game-ui')
class GameUi extends PolymerElement {
  Game game;
  GameMap map;
  GameUi.created() : super.created() {
    print('$this created');
    game = new Game();
  }

  void ready() {
    super.ready();
    print('$this ready');
    map = $['map'];
    map.onWorldLoaded.listen(_onWorldLoaded);
  }

  void _onWorldLoaded(World world) {
    /// game = new Game(world, map.inputDevice);
    /*map.inputDevice.onCountrySelected.listen((Country country) {
      if(state == GameState.preparation) {
        /// ....
      }
      country.element.classes.add('selected');
      // renderer.setSelectedCountry(country);
    });

    map.inputDevice.onCountryDeselected.listen((Country country) {
      // renderer.setSelectedCountry(null);
      country.element.classes.remove('selected');
    });

    map.inputDevice.onCountryMouseOver.listen((Country country) {
      //print('Country over: $country');
      //renderer.requestRender();
    });

    map.inputDevice.onCountryMouseOut.listen((Country country) {
      //print('Country out: $country');
      //renderer.requestRender();
    });
    */
  }
}