/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';

  angular.module('SOGo.AdministrationUI', ['ngSanitize', 'ui.router', 'SOGo.Common', 'SOGo.ContactsUI', 'SOGo.Authentication'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlRouterProvider'];
  function configure($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('administration', {
        abstract: true,
        views: {
          administration: {
            templateUrl: 'administration.html',
            controller: 'AdministrationController',
            controllerAs: 'app'
          }
        },
        resolve: {
          stateAdministration: stateAdministration
        }
      })
      .state('administration.rights', {
        url: '/rights',
        views: {
          module: {
            templateUrl: 'rights.html'
          }
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlRouterProvider.otherwise('/rights');
  }

  /**
   * @ngInject
   */
  stateAdministration.$inject = ['Administration'];
  function stateAdministration(Administration) {
    return Administration;
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope'];
  function runBlock($rootScope) {
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      console.error(event, current, previous, rejection);
    });
  }

})();
