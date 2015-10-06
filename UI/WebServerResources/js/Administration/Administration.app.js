/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';

  angular.module('SOGo.AdministrationUI', ['ngSanitize', 'ui.router', 'SOGo.Common', 'SOGo.Authentication', 'SOGo.PreferencesUI', 'SOGo.ContactsUI', 'SOGo.SchedulerUI'])
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
        }
      })
      .state('administration.rights', {
        url: '/rights',
        views: {
          module: {
            templateUrl: 'rights.html'
          }
        }
      })
      .state('administration.rights.edit', {
        url: '/:userId/:folderId/edit',
        views: {
          acl: {
            templateUrl: 'UIxAdministrationAclEditor', // UI/Templates/Administration/UIxAdministrationAclEditor.wox
            controller: 'AdministrationAclController',
            controllerAs: 'acl'
          }
        },
        resolve: {
          stateFolder: stateFolder
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlRouterProvider.otherwise('/rights');
  }
  
  stateFolder.$inject = ['$stateParams', 'User', 'AddressBook', 'Calendar'];
  function stateFolder($stateParams, User, AddressBook, Calendar) {
    var user = _.find(User.$users, function(user) {
      return user.uid == $stateParams.userId;
    });

    var folder = _.find(user.$$folders, function(folder) {
      return folder.name == $stateParams.folderId;
    });

    var o;
    
    if (folder.type == "Appointment") {
      o = new Calendar({id: folder.name.split('/').pop(),
                        owner: folder.owner,
                        name: folder.displayName});
    } else {
      o = new AddressBook({id: folder.name.split('/').pop(),
                           owner: folder.owner,
                           name: folder.displayName});
    }
    
    return o;
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
