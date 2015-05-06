/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', []);
  angular.module('SOGo.MailerUI', []);

  angular.module('SOGo.PreferencesUI', ['ngSanitize', 'ui.router', 'SOGo.Common', 'SOGo.MailerUI', 'SOGo.ContactsUI', 'SOGo.Authentication'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL,
      activeUser: {
        login: UserLogin,
        identification: UserIdentification,
        language: UserLanguage,
        folderURL: UserFolderURL,
        isSuperUser: IsSuperUser
      }
    })
    .config(configure);

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
        },
        resolve: {
          statePreferences: statePreferences
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
  statePreferences.$inject = ['Preferences'];
  function statePreferences(Preferences) {
    return new Preferences();
  }
  
})();
