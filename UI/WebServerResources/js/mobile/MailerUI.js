/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.Mailer (mobile) */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.MailerUI', ['ionic', 'SOGo.Common', 'SOGo.UICommon', 'SOGo.UIMobile'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL
    })

    .run(function($ionicPlatform) {
      $ionicPlatform.ready(function() {
        // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
        // for form inputs)
        if (window.cordova && window.cordova.plugins.Keyboard) {
          cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
        }
        if (window.StatusBar) {
          // org.apache.cordova.statusbar required
          StatusBar.styleDefault();
        }
      });
    })

    .config(function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('app', {
          url: '/app',
          abstract: true,
          templateUrl: 'menu.html',
          controller: 'AppCtrl'
        })
        .state('app.mail', {
          url: '/mail',
          views: {
            menuContent: {
              templateUrl: 'mailboxes.html',
              controller: 'MailboxesCtrl',
              }
          },
          resolve: {
            stateAccounts: ['$q', 'sgAccount', function($q, Account) {
              var accounts = Account.$findAll(mailAccounts);
              var promises = [];
              // Resolve mailboxes of each account
              angular.forEach(accounts, function(account, i) {
                var mailboxes = account.$getMailboxes();
                promises.push(mailboxes.then(function(objects) {
                  accounts[i].mailboxes = objects;
                  return account;
                }));
              });
              return $q.all(promises);
            }]
          }
        })
        .state('app.mail.account', {
          url: '/:accountId',
          abstract: true,
          resolve: {
            stateAccount: ['$stateParams', 'stateAccounts', function($stateParams, stateAccounts) {
              return _.find(stateAccounts, function(account) {
                return account.id == $stateParams.accountId;
              });
            }]
          }
        })
        .state('app.mail.account.mailbox', {
          url: '/:mailboxId',
          views: {
            'menuContent@app': {
              templateUrl: 'mailbox.html',
              controller: 'MailboxCtrl'
              }
          },
          resolve: {
            stateMailbox: ['$stateParams', 'stateAccount', 'decodeUriFilter', function($stateParams, stateAccount, decodeUriFilter) {
              var mailboxId = decodeUriFilter($stateParams.mailboxId);
              // Recursive find function
              var _find = function(mailboxes) {
                var mailbox = _.find(mailboxes, function(o) {
                  return o.path == mailboxId;
                });
                if (!mailbox) {
                  angular.forEach(mailboxes, function(o) {
                    if (!mailbox && o.children && o.children.length > 0) {
                      mailbox = _find(o.children);
                    }
                  });
                }
                return mailbox;
              };
              return _find(stateAccount.mailboxes);
            }],
            stateMessages: ['stateMailbox', function(stateMailbox) {
              return stateMailbox.$update();
            }]
          }
        })
        .state('app.mail.account.mailbox.message', {
          url: "/:messageId",
          views: {
            'menuContent@app': {
              templateUrl: "message.html",
              controller: 'MessageCtrl'
            }
          },
          resolve: {
            stateMessage: ['$stateParams', 'stateMailbox', 'stateMessages', function($stateParams, stateMailbox, stateMessages) {
              var message = _.find(stateMessages, function(messageObject) {
                return messageObject.uid == $stateParams.messageId;
              });
              return message;
            }]
          }
        });


      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/app/mail');
    })

    .controller('AppCtrl', ['$scope', '$http', function($scope, $http) {
      $scope.UserLogin = UserLogin;
      $scope.UserFolderURL = UserFolderURL;
      $scope.ApplicationBaseURL = ApplicationBaseURL;
    }])

    .controller('MailboxesCtrl', ['$scope', '$http', '$state', 'sgAccount', 'sgMailbox', 'encodeUriFilter', 'stateAccounts', function($scope, $http, $state, Account, Mailbox, encodeUriFilter, stateAccounts) {
      $scope.accounts = stateAccounts

      angular.forEach($scope.accounts, function(account, i) {
        var mailboxes = account.$getMailboxes();
        mailboxes.then(function(objects) {
          $scope.accounts[i].mailboxes = objects;
        });
      });

      $scope.setCurrentFolder = function(account, folder) {
        $state.go('app.mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
      };
    }])

    .controller('MailboxCtrl', ['$scope', 'stateAccount', 'stateMailbox', function($scope, stateAccount, stateMailbox) {
      $scope.account = stateAccount;
      $scope.mailbox = stateMailbox;
    }])

    .controller('MessageCtrl', ['$scope', '$stateParams', 'stateMessage', function($scope, $stateParams, stateMessage) {
      $scope.message = stateMessage;
    }]);

})();
