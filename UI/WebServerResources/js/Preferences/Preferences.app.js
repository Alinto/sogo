/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  angular.module('SOGo.PreferencesUI', ['ui.router', 'ck', 'angularFileUpload', 'SOGo.Common', 'SOGo.MailerUI', 'SOGo.ContactsUI', 'SOGo.Authentication', 'as.sortable'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlRouterProvider'];
  function configure($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('preferences', {
        abstract: true,
        views: {
          preferences: {
            templateUrl: 'preferences.html',
            controller: 'PreferencesController',
            controllerAs: 'app'
          }
        }
      })
      .state('preferences.general', {
        url: '/general',
        views: {
          module: {
            templateUrl: 'generalPreferences.html'
          }
        }
      })
      .state('preferences.calendars', {
        url: '/calendars',
        views: {
          module: {
            templateUrl: 'calendarsPreferences.html'
          }
        }
      })
      .state('preferences.addressbooks', {
        url: '/addressbooks',
        views: {
          module: {
            templateUrl: 'addressbooksPreferences.html'
          }
        }
      })
      .state('preferences.mailer', {
        url: '/mailer',
        views: {
          module: {
            templateUrl: 'mailerPreferences.html'
          }
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlRouterProvider.otherwise('/general');
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
