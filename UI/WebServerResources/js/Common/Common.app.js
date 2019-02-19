/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  angular.module('SOGo.Common', ['ngAnimate', 'ngMessages', 'ngSanitize', 'ngMaterial', 'mdColors'])
    .value('sgSettings', {
      isPopup: document.body.classList.contains('popup'),
      baseURL: function() {
        return ApplicationBaseURL || null;
      },
      resourcesURL: function() {
        return ResourcesURL || null;
      },
      activeUser: function(param) {
        var settings = {
          login: UserLogin || null,
          identification: UserIdentification || null,
          email: UserEmail || null,
          language: UserLanguage || null,
          folderURL: UserFolderURL || null,
          isSuperUser: IsSuperUser || null,
          path: {
            calendar: UserCalendarPath || null,
            contacts: UserContactsPath || null,
            mail: UserMailPath || null,
            preferences: UserPreferencesPath || null,
            administration: (IsSuperUser ? UserAdministrationPath : null),
            help: HelpURL || null,
            logoff: UserLogoffPath || null
          }
        };
        if (param)
          return settings[param];
        else
          return settings;
      },
      minimumSearchLength: function() {
        return angular.isNumber(minimumSearchLength)? minimumSearchLength : 2;
      }
    })

    .constant('sgColors', {
      selection: [
        '#FFFFFF',
        '#330033',
        '#C0C0C0',
        '#999999',
        '#666666',
        '#333333',
        '#000000',
        '#FFCCCC',
        '#FF6666',
        '#FF0000',
        '#CC0000',
        '#990000',
        '#660000',
        '#330000',
        '#FFCC99',
        '#FF9966',
        '#FF9900',
        '#FF6600',
        '#CC6600',
        '#993300',
        '#663300',
        '#FFFF99',
        '#FFFF66',
        '#FFCC66',
        '#FFCC33',
        '#CC9933',
        '#996633',
        '#663333',
        '#FFFFCC',
        '#FFFF33',
        '#FFFF00',
        '#FFCC00',
        '#999900',
        '#666600',
        '#333300',
        '#CCCCCC',
        '#66FF99',
        '#33FF33',
        '#33CC00',
        '#009900',
        '#006600',
        '#003300',
        '#99FFFF',
        '#33FFFF',
        '#66CCCC',
        '#00CCCC',
        '#339999',
        '#336666',
        '#003333',
        '#CCFFFF',
        '#66FFFF',
        '#33CCFF',
        '#3366FF',
        '#3333FF',
        '#000099',
        '#000066',
        '#CCCCFF',
        '#9999FF',
        '#6666CC',
        '#6633FF',
        '#6600CC',
        '#333399',
        '#330099',
        '#FFCCFF',
        '#FF99FF',
        '#CC66CC',
        '#CC33CC',
        '#993399',
        '#663366',
        '#99FF99'
      ]
    })

  // md break-points values are hard-coded in angular-material/src/core/util/constant.js
  // $mdMedia has a built-in support for those values but can also evaluate others.
  // The following breakpoints match our CSS breakpoints in scss/core/variables.scss
    .constant('sgConstant', {
      'xs'    : '(max-width: 599px)'                         ,
      'gt-xs' : '(min-width: 600px)'                         ,
      'sm'    : '(min-width: 600px) and (max-width: 959px)'  ,
      'gt-sm' : '(min-width: 960px)'                         ,
      'md'    : '(min-width: 960px) and (max-width: 1023px)' ,
      'gt-md' : '(min-width: 1024px)'                        ,
      'lg'    : '(min-width: 1024px) and (max-width: 1279px)',
      'gt-lg' : '(min-width: 1280px)'                        ,
      'xl'    : '(min-width: 1920px)'                        ,
      'print' : 'print'
    })

    .config(configure)

    .factory('AuthInterceptor', AuthInterceptor)
    .factory('ErrorInterceptor', ErrorInterceptor);

  /**
   * @ngInject
   */
  configure.$inject = ['$animateProvider', '$logProvider', '$compileProvider', '$httpProvider', '$mdThemingProvider', '$mdAriaProvider', '$qProvider'];
  function configure($animateProvider, $logProvider, $compileProvider, $httpProvider, $mdThemingProvider, $mdAriaProvider, $qProvider) {
    // Disabled animation for elements with class ng-animate-disabled
    $animateProvider.classNameFilter(/^(?:(?!ng-animate-disabled).)*$/);

    // Accent palette
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
      // 'A100': 'b9f6ca',
      'A100': 'fafafa', // assigned to md-hue-1, equivalent to grey-50 (default background palette)
      'A200': '69f0ae',
      'A400': '00e676',
      'A700': '00c853',
      'contrastDefaultColor': 'dark',
      // 'contrastDarkColors': ['50', '100', '200', 'A100'],
      'contrastLightColors': ['300', '400', '500', '600', '700', '800', '900']
    });
    // Primary palette
    $mdThemingProvider.definePalette('sogo-blue', {
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
      // 'contrastLightColors': ['300', '400', '500', '600', '700', '800', '900', 'A100', 'A200', 'A400', 'A700']
    });
    // Background palette
    $mdThemingProvider.definePalette('sogo-paper', {
      '50': 'fcf7f8',
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
      'contrastLightColors': ['800', '900']
    });
    var greyMap = $mdThemingProvider.extendPalette('grey', {
      '1000': 'baa870' // used as the background color of the busy periods of the attendees editor
    });
    $mdThemingProvider.definePalette('sogo-grey', greyMap);
    // Default theme definition
    $mdThemingProvider.theme('default')
      .primaryPalette('sogo-blue', {
        'default': '900',
        'hue-1': '400',
        'hue-2': '800',
        'hue-3': 'A700'
      })
      .accentPalette('sogo-green', {
        'default': '500',
        // 'hue-1': '200',
        'hue-1': 'A100', // grey-50
        'hue-2': '300',
        'hue-3': 'A700'
      })
      .backgroundPalette('sogo-grey');


    // Register custom stylesheet for md-autocomplete
    $mdThemingProvider.registerStyles([
      '.md-autocomplete-suggestions.md-3-line li p {',
      '  color: \'{{foreground-2}}\';',
      '}',
    ].join(''));

    // Register custom stylesheet for sgTimepicker
    $mdThemingProvider.registerStyles([
      '.sg-time-selection-indicator.sg-time-selected,',
      '.sg-time-selection-indicator:hover.sg-time-selected,',
      '.sg-time-selection-indicator.md-focus.sg-time-selected {',
      '  background: \'{{primary-500}}\';',
      '}',
      '.sg-timepicker-open .sg-timepicker-icon {',
      '  color: \'{{primary-900}}\';',
      '}',
      '.sg-timepicker-time,',
      '.sg-timepicker-open .sg-timepicker-input-container {',
      '  background: \'{{background-hue-1}}\';',
      '}',
      '.sg-timepicker-input-mask-opaque {',
      '  box-shadow: 0 0 0 9999px \'{{background-hue-1}}\';',
      '}',
    ].join(''));

    // Register custom stylesheet for Calendar module
    $mdThemingProvider.registerStyles([
      '[ui-view=calendars] .hours {',
      '  color: \'{{primary-700}}\';',
      '}',
      '.attendees .busy {',
      '  background-color: \'{{background-1000}}\';',
      '}',
      '.attendees .event {',
      '  background-color: \'{{primary-300}}\';',
      '}'
    ].join(''));

    if (!window.DebugEnabled) {
      // Disable debugging information
      $logProvider.debugEnabled(false);
      $compileProvider.debugInfoEnabled(false);
      // Disable warnings
      $mdAriaProvider.disableWarnings();
      $qProvider.errorOnUnhandledRejections(false);
      // Disable theme generation but keep definition in config (required by mdColors)
      $mdThemingProvider.generateThemesOnDemand(true);
      // Disable theming completely
      //$mdThemingProvider.disableTheming();
    }

    $httpProvider.interceptors.push('AuthInterceptor');
    $httpProvider.interceptors.push('ErrorInterceptor');
  }

  /**
   * @ngInject
   */
  AuthInterceptor.$inject = ['$window', '$q'];
  function AuthInterceptor($window, $q) {
    return {
      response: function(response) {
        // When expecting JSON but receiving HTML, assume session has expired and reload page
        if (response && /^application\/json/.test(response.config.headers.Accept) &&
            /^[\n\r ]*<!DOCTYPE html>/.test(response.data)) {
          $window.location.href = $window.ApplicationBaseURL;
          return $q.reject();
        }
        return response;
      }
    };
  }

  /**
   * @ngInject
   */
  ErrorInterceptor.$inject = ['$rootScope', '$window', '$q', '$timeout', '$injector'];
  function ErrorInterceptor($rootScope, $window, $q, $timeout, $injector) {
    return {
      responseError: function(rejection) {
        var deferred, iframe;
        if (/^application\/json/.test(rejection.config.headers.Accept)) {
          // Handle CAS ticket renewal
          if ($window.usesCASAuthentication && rejection.status == -1) {
            deferred = $q.defer();
            iframe = angular.element('<iframe class="ng-hide" src="' + $window.UserFolderURL + 'recover"></iframe>');
            iframe.on('load', function() {
              if (rejection.config.attempt) {
                // Already attempted once -- reload page
                angular.element($window).off('beforeunload');
                $window.location.href = $window.ApplicationBaseURL;
                deferred.reject();
              }
              else {
                // Once the browser has followed the redirection, send the initial request
                $timeout(function() {
                  var $http = $injector.get('$http');
                  rejection.config.attempt = 1;
                  $http(rejection.config).then(function(response) {
                    deferred.resolve(response);
                  });
                  $timeout(iframe.remove, 500);
                }, 100); // Wait before replaying the request
              }
            });
            document.body.appendChild(iframe[0]);
            return deferred.promise;
          }
          else if ($window.usesSAML2Authentication && rejection.status == 401 && !$window.recovered) {
            angular.element($window).off('beforeunload');
            $window.recovered = true;
            $window.location.href = $window.ApplicationBaseURL;
          }
          else {
            // Broadcast the response error
            $rootScope.$broadcast('http:Error', rejection);
          }
        }
        return $q.reject(rejection);
      }
    };
  }

})();
