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
              return _find(stateAccount.$mailboxes);
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

    .controller('MailboxesCtrl', ['$scope', '$http', '$state', '$ionicActionSheet', 'sgAccount', 'sgMailbox', 'encodeUriFilter', 'stateAccounts', function($scope, $http, $state, $ionicActionSheet, Account, Mailbox, encodeUriFilter, stateAccounts) {
      $scope.accounts = stateAccounts

      $scope.setCurrentFolder = function(account, folder) {
        $state.go('app.mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
      };
      $scope.edit = function(folder) {
        $ionicActionSheet.show({
          buttons: [
            { text: l('Rename') },
            { text: l('Set Access Rights') }
          ],
          destructiveText: l('Delete'),
          cancelText: l('Cancel'),
          buttonClicked: function(index) {
            // TODO
            return true;
          },
          destructiveButtonClicked: function() {
            // Delete mailbox 
            folder.$delete()
              .then(function() {
                folder = null;
              }, function(data) {
                Dialog.alert(l('An error occured while deleting the mailbox "%{0}".',
                               folder.name),
                             l(data.error));
              });
            return true;
          }
          // cancel: function() {
          // },
        });
        $ionicListDelegate.closeOptionButtons();
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
