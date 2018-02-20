/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  angular.module('SOGo.Common')
    .config(configure)

  /**
   * @ngInject
   */
  configure.$inject = ['$mdThemingProvider'];
  function configure($mdThemingProvider) {

    /**
     * Define a new palette or choose any of the default palettes:
     *
     * https://material.io/guidelines/style/color.html#color-color-palette
     */
    // $mdThemingProvider.definePalette('sogo-paper', {
    //   '50': 'fcf7f8',
    //   '100': 'f7f1dc',
    //   '200': 'ede5ca',
    //   '300': 'e6d8ba',
    //   '400': 'e2d2a3',
    //   '500': 'd6c48d',
    //   '600': 'baa870',
    //   '700': '857545',
    //   '800': '524517',
    //   '900': '433809',
    //   '1000': '000000',
    //   'A100': 'ffffff',
    //   'A200': 'eeeeee',
    //   'A400': 'bdbdbd',
    //   'A700': '616161',
    //   'contrastDefaultColor': 'dark',
    //   'contrastLightColors': ['800', '900']
    // });

    /**
     * Overwrite the default theme
     */
    $mdThemingProvider.theme('default')
      .primaryPalette('blue-grey', {
        'default': '400',  // top toolbar
        'hue-1': '400',
        'hue-2': '600',    // sidebar toolbar
        'hue-3': 'A700'
      })
      .accentPalette('teal', {
        'default': '600',  // fab buttons
        'hue-1': '50',     // center list toolbar
        'hue-2': '300',
        'hue-3': 'A700'
      })
      .backgroundPalette('grey', {
        'default': '50',   // center list background
        'hue-1': '200',
        'hue-2': '300',
        'hue-3': '500'
      });

    $mdThemingProvider.setDefaultTheme('default');
    $mdThemingProvider.generateThemesOnDemand(false);
  }
})();
