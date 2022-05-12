/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';

  angular.module('SOGo.AdministrationUI', ['ui.router', 'SOGo.Common', 'SOGo.Authentication', 'SOGo.PreferencesUI', 'SOGo.ContactsUI', 'SOGo.SchedulerUI'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlServiceProvider'];
  function configure($stateProvider, $urlServiceProvider) {
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
          stateUser: stateUser,
          stateFolder: stateFolder
        }
      })
      .state('administration.theme', {
        url: '/theme',
        views: {
          module: {
            templateUrl: 'UIxThemePreview', // UI/Templates/Administration/UIxThemePreview.wox
            controller: 'ThemePreviewController',
            controllerAs: 'ctrl'
          }
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlServiceProvider.rules.otherwise('/rights');
  }

  /**
   * @ngInject
   */
  stateUser.$inject = ['$q', '$stateParams', 'User'];
  function stateUser($q, $stateParams, User) {
    var user;

    user = _.find(User.$users, function(user) {
      return user.uid == $stateParams.userId;
    });

    if (angular.isUndefined(user)) {
      return User.$filter($stateParams.userId).then(function(users) {
        user = _.find(User.$users, function(user) {
          return user.uid == $stateParams.userId;
        });
        if (angular.isUndefined(user)) {
          return $q.reject('User with ID ' + $stateParams.userId + ' not found');
        }
        else {
          // Resolve folders
          return user.$folders().then(function() {
            return user;
          });
        }
        return user;
      });
    }

    return user;
  }

  /**
   * @ngInject
   */
  stateFolder.$inject = ['$state', '$stateParams', 'decodeUriFilter', 'stateUser', 'AddressBook', 'Calendar'];
  function stateFolder($state, $stateParams, decodeUriFilter, stateUser, AddressBook, Calendar) {
    var folder, o,
        folderId = decodeUriFilter($stateParams.folderId);

    folder = _.find(stateUser.$$folders, function(folder) {
      return folder.name == folderId;
    });
    
    if (folder.type == "Appointment") {
      o = new Calendar({ id: folder.name.split('/').pop(),
                         owner: folder.owner,
                         name: folder.displayName });
    } else {
      o = new AddressBook({ id: folder.name.split('/').pop(),
                            owner: folder.owner,
                            name: folder.displayName });
    }

    stateUser.selectedFolder = o.id;

    return o;
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$window', '$log', '$transitions', '$state'];
  function runBlock($window, $log, $transitions, $state) {
    if (!$window.DebugEnabled)
      $state.defaultErrorHandler(function() {
        // Don't report any state error
      });
    $transitions.onError({ to: 'administration.**' }, function(transition) {
      if (transition.to().name != 'administration' &&
          !transition.ignored()) {
        $log.error('transition error to ' + transition.to().name + ': ' + transition.error().detail);
        $state.go({ state: 'administration.rights' });
      }
    });
  }

})();
