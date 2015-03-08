/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* Angular JavaScript for common UI services */
// TODO: Normalize the namespace and prefixes


/**
 * The common SOGo UI, app module
 *
 * @type {angular.Module}
 */
(function () {
  'use strict';
  angular.module('SOGo.UI', ['ngMaterial'])

      .config(function ($mdThemingProvider) {

        $mdThemingProvider.definePalette('sogo-green', {
          '50': 'eaf5e9',
          '100': 'cbe5c8',
          '200': 'aad6a5',
          '300': '88c781',
          '400': '66b86a',
          '500': '56b04c',
          '600': '4da143',
          '700': '388e3c',
          '800': '367d2e',
          '900': '225e1b',
          'A100': 'b9f6ca',
          'A200': '69f0ae',
          'A400': '00e676',
          'A700': '00c853',
          'contrastDefaultColor': 'dark',
          'contrastLightColors': '500 600 700 800 900'
        });
        $mdThemingProvider.definePalette('vintage-blue', {
          '50': 'f0faf9',
          '100': 'e1f5f3',
          '200': 'ceebe8',
          '300': 'bfe0dd',
          '400': 'b2d6d3',
          '500': 'a1ccc8',
          '600': '8ebfbb',
          '700': '7db3b0',
          '800': '639997',
          '900': '4d8080',
          'A100': 'd4f7fa',
          'A200': 'c3f5fa',
          'A400': '53e3f0',
          'A700': '00b0c0',
          'contrastDefaultColor': 'light',
          'contrastDarkColors': ['50', '100', '200'],
          'contrastLightColors': ['300', '400', '500', '600', '700', '800', '900', 'A100', 'A200', 'A400', 'A700']
        });
        $mdThemingProvider.definePalette('paper', {
          '50': 'fcfbf8',
          '100': 'f7f1dc',
          '200': 'ede5ca',
          '300': 'e6d8ba',
          '400': 'e2d2a3',
          '500': 'd6c48d',
          '600': 'baa870',
          '700': '857545',
          '800': '524517',
          '900': '433809',
          '1000': '000000',
          'A100': 'ffffff',
          'A200': 'eeeeee',
          'A400': 'bdbdbd',
          'A700': '616161',
          'contrastDefaultColor': 'dark',
          'contrastLightColors': '800 900'
        });
        // Default theme definition
        // .primaryColor will soon be deprecated in favor of primaryPalette (already on dev builds https://groups.google.com/forum/m/#!topic/ngmaterial/-sXR8CYBMPg)
        $mdThemingProvider.theme('default')
          .primaryPalette('vintage-blue', {
              'default': '300',
              'hue-1': '100',
              'hue-2': '400',
              'hue-3': 'A700'
            })
          .accentPalette('sogo-green')
          .backgroundPalette('paper', {
              'default': '500',
              'hue-1': '200',
              'hue-2': '50',
              'hue-3': '100'
            });
      })

      .controller('toggleCtrl', ['$scope', '$timeout', '$mdSidenav', '$log', function ($scope, $timeout, $mdSidenav, $log) {
        $scope.toggleLeft = function () {
          $mdSidenav('left').toggle()
              .then(function () {
                $log.debug("toggle left is done");
              });
        };
        $scope.toggleRight = function () {
          $mdSidenav('right').toggle()
              .then(function () {
                $log.debug("toggle RIGHT is done");
              });
        };
      }])

      .controller('LeftCtrl', function ($scope, $timeout, $mdSidenav, $log) {
        $scope.close = function () {
          $mdSidenav('left').close()
              .then(function () {
                $log.debug("close LEFT is done");
              });
        };
      })

      .controller('RightCtrl', function ($scope, $timeout, $mdSidenav, $log) {
        $scope.close = function () {
          $mdSidenav('right').close()
              .then(function () {
                $log.debug("close RIGHT is done");
              });
        };
      });

})();
