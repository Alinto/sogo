/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.MailerUI module */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.MailerUI', ['ngSanitize', 'ui.router', 'mm.foundation', 'vs-repeat', 'SOGo.Common', 'SOGo.UICommon', 'SOGo.UIDesktop'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL,
      activeUser: {
        login: UserLogin,
        language: UserLanguage,
        folderURL: UserFolderURL,
        isSuperUser: IsSuperUser
      }
   })

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('mail', {
          url: '/Mail',
          views: {
            mailboxes: {
              templateUrl: 'mailboxes.html',
              controller: 'MailboxesCtrl'
            }
          },
          resolve: {
            stateAccounts: ['$q', 'sgAccount', function($q, Account) {
              var accounts = Account.$findAll(mailAccounts);
              var promises = [];
              // Fetch list of mailboxes for each account
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
        .state('mail.account', {
          url: '/:accountId',
          abstract: true,
          views: {
            mailbox: {
              template: '<ui-view/>',
            }
          },
          resolve: {
            stateAccount: ['$stateParams', 'stateAccounts', function($stateParams, stateAccounts) {
              return _.find(stateAccounts, function(account) {
                return account.id == $stateParams.accountId;
              });
            }]
          }
        })
        .state('mail.account.mailbox', {
          url: '/:mailboxId',
          templateUrl: 'mailbox.html',
          controller: 'MailboxCtrl',
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
        .state('mail.account.mailbox.message', {
          url: "/:messageId",
          views: {
            message: {
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
        // .state('mailbox.newMessage', {
        //   url: "/new",
        //   templateUrl: "messageEditor.html",
        //   controller: 'MessageCtrl'
        // })
        // .state('mailbox.editMessage', {
        //   url: "/:messageId/edit",
        //   templateUrl: "messageEditor.html",
        //   controller: 'MessageCtrl'
        // });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/Mail');
    }])

    .controller('MailboxesCtrl', ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$modal', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgAccount', 'sgMailbox', 'stateAccounts', function($scope, $rootScope, $stateParams, $state, $timeout, $modal, focus, encodeUriFilter, Dialog, Account, Mailbox, stateAccounts) {
      $scope.accounts = stateAccounts;

      $scope.setCurrentFolder = function(account, folder) {
        $rootScope.currentFolder = folder;
        console.debug('setCurrentFolder ' + folder.type + ' ' + account.id + ' ' + encodeUriFilter(folder.path))
        $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
      };

      if (_.isEmpty($state.params) && $scope.accounts.length > 0 && $scope.accounts[0].mailboxes.length > 0) {
        var account = $scope.accounts[0];
        var mailbox = account.mailboxes[0];
        $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
      }
    }])

    .controller('MailboxCtrl', ['$scope', '$rootScope', '$stateParams', 'stateAccount', 'stateMailbox', '$timeout', '$modal', 'sgFocus', 'sgDialog', 'sgAccount', 'sgMailbox', function($scope, $rootScope, $stateParams, stateAccount, stateMailbox, $timeout, $modal, focus, Dialog, Account, Mailbox) {
      console.debug('MailboxCtrl ' + stateMailbox.path);
      $scope.account = stateAccount;
      $scope.mailbox = stateMailbox;
      $rootScope.currentFolder = stateMailbox;
      $timeout(function() {
        $rootScope.$broadcast('sgSelectFolder', stateMailbox.id);
      });
    }])

    .controller('MessageCtrl', ['$scope', '$rootScope', '$stateParams', 'stateMessage', '$timeout', '$modal', 'sgFocus', 'sgDialog', 'sgAccount', 'sgMailbox', function($scope, $rootScope, $stateParams, stateMessage, $timeout, $modal, focus, Dialog, Account, Mailbox) {
      $rootScope.message = stateMessage;
    }]);

})();
