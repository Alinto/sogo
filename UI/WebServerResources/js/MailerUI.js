/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.MailerUI module */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);
  angular.module('SOGo.ContactsUI', []);

  angular.module('SOGo.MailerUI', ['ngSanitize', 'ui.router', 'vs-repeat', 'ck', 'ngTagsInput', 'angularFileUpload', 'SOGo.Common', 'SOGo.UI', 'SOGo.UIDesktop', 'SOGo.ContactsUI'])

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

    .config(['$stateProvider', '$urlRouterProvider', 'tagsInputConfigProvider', function($stateProvider, $urlRouterProvider, tagsInputConfigProvider) {
      $stateProvider
        .state('mail', {
          url: '/Mail',
          views: {
            mailboxes: {
              templateUrl: 'UIxMailMainFrame', // UI/Templates/MailerUI/UIxMailMainFrame.wox
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
          views: {
            'mailbox@mail': {
              templateUrl: 'UIxMailFolderTemplate', // UI/Templates/MailerUI/UIxMailFolderTemplate.wox
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
              return stateMailbox.$filter();
            }]
          }
        })
        .state('mail.account.mailbox.message', {
          url: '/:messageId',
          views: {
            message: {
              templateUrl: 'UIxMailViewTemplate', // UI/Templates/MailerUI/UIxMailViewTemplate.wox
              controller: 'MessageCtrl'
            }
          },
          resolve: {
            stateMessage: ['encodeUriFilter', '$stateParams', '$state', 'stateMailbox', 'stateMessages', function(encodeUriFilter, $stateParams, $state, stateMailbox, stateMessages) {
              var message = _.find(stateMessages, function(messageObject) {
                return messageObject.uid == $stateParams.messageId;
              });

              if (message)
                return message.$reload();
              else
                // Message not found
                $state.go('mail.account.mailbox', { accountId: stateMailbox.$account.id, mailboxId: encodeUriFilter(stateMailbox.path) });
            }]
          }
        })
        .state('mail.account.mailbox.message.edit', {
          url: '/edit',
          views: {
            'mailbox@mail': {
              templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
              controller: 'MessageEditorCtrl'
            }
          },
          resolve: {
            stateContent: ['stateMessage', function(stateMessage) {
              return stateMessage.$editableContent();
            }]
          }
        })
        .state('mail.account.mailbox.message.action', {
          url: '/{actionName:(?:reply|replyall|forward)}',
          views: {
            'mailbox@mail': {
              templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
              controller: 'MessageEditorCtrl'
            }
          }
        })
        .state('mail.newMessage', {
          url: '/new',
          views: {
            mailbox: {
              templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
              controller: 'MessageEditorCtrl'
            }
          },
          resolve: {
            stateMessage: ['stateAccounts', function(stateAccounts) {
              if (stateAccounts.length > 0) {
                return stateAccounts[0].$newMessage();
              }
            }]
          }
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/Mail');

      // Set default configuration for tags input
      tagsInputConfigProvider.setDefaults('tagsInput', {
        addOnComma: false,
        replaceSpacesWithDashes: false,
        allowedTagsPattern: /([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)/i
      });
    }])

    .run(function($rootScope) {
      $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
        console.error(event, current, previous, rejection)
      })
    })

    .controller('MailboxesCtrl', ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgSettings', 'sgAccount', 'sgMailbox', 'stateAccounts', function($scope, $rootScope, $stateParams, $state, $timeout, focus, encodeUriFilter, Dialog, Settings, Account, Mailbox, stateAccounts) {
      $scope.activeUser = Settings.activeUser;
      $scope.accounts = stateAccounts;

      $scope.newFolder = function(parentFolder) {
        Dialog.prompt(l('New folder'),
                      l('Enter the new name of your folder :'))
          .then(function(name) {
            if (name && name.length > 0) {
              parentFolder.$newMailbox(parentFolder.id, name);
            }
          });
      };
      $scope.editFolder = function(folder) {
        $rootScope.$broadcast('sgEditFolder', folder.id);
      };
      $scope.setCurrentFolder = function(account, folder) {
        $rootScope.currentFolder = folder;
        $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
      };
      $scope.exportMails = function() {
        window.location.href = ApplicationBaseURL + '/' + $rootScope.currentFolder.id + '/exportFolder';
      };
      $scope.confirmDelete = function() {
        Dialog.confirm(l('Confirmation'), l('Do you really want to move this folder into the trash ?'))
            .then(function(res) {
              if (res) {
                $rootScope.currentFolder.$delete()
                  .then(function() {
                    $rootScope.currentFolder = null;
                  }, function(data, status) {
                    Dialog.alert(l('An error occured while deleting the mailbox "%{0}".',
                                   $rootScope.currentFolder.name),
                                 l(data.error));
                  });
              }
            });
      };

      // Register listeners
      $scope.$on('sgRevertFolder', function(event, folderId) {
        if (folderId == $scope.currentFolder.id) {
          $scope.currentFolder.$reset();
          event.stopPropagation();
        }
      });
      $scope.$on('sgSaveFolder', function(event, folderId) {
        if (folderId == $scope.currentFolder.id) {
          $scope.currentFolder.$rename();
          event.stopPropagation();
        }
      });

      if ($state.current.name == 'mail' && $scope.accounts.length > 0 && $scope.accounts[0].$mailboxes.length > 0) {
        // Redirect to first mailbox of first account if no mailbox is selected
        var account = $scope.accounts[0];
        var mailbox = account.$mailboxes[0];
        $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
      }
    }])

    .controller('MailboxCtrl', ['$scope', '$rootScope', '$stateParams', 'stateAccount', 'stateMailbox', '$timeout', 'sgFocus', 'sgDialog', 'sgAccount', 'sgMailbox', function($scope, $rootScope, $stateParams, stateAccount, stateMailbox, $timeout, focus, Dialog, Account, Mailbox) {
      $scope.account = stateAccount;
      $rootScope.mailbox = stateMailbox;
      $rootScope.currentFolder = stateMailbox;
      $timeout(function() {
        $rootScope.$broadcast('sgSelectFolder', stateMailbox.id);
      });
    }])

    .controller('MessageCtrl', ['$scope', '$rootScope', '$stateParams', '$state', 'stateAccount', 'stateMailbox', 'stateMessage', '$timeout', 'encodeUriFilter', 'sgFocus', 'sgDialog', 'sgAccount', 'sgMailbox', function($scope, $rootScope, $stateParams, $state, stateAccount, stateMailbox, stateMessage, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox) {
      $rootScope.message = stateMessage;
      $scope.doDelete = function() {
        stateMailbox.$deleteMessages([stateMessage.uid]).then(function() {
          // Remove card from list of addressbook
          stateMailbox.$messages = _.reject(stateMailbox.$messages, function(o) {
            return o.uid == stateMessage.uid;
          });
          // Remove card object from scope
          $rootScope.message = null;
          $state.go('mail.account.mailbox', { accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path) });
        });
      };
    }])

    .controller('MessageEditorCtrl', ['$scope', '$rootScope', '$stateParams', '$state', '$q', 'FileUploader', 'stateAccounts', 'stateMessage', '$timeout', 'encodeUriFilter', 'sgFocus', 'sgDialog', 'sgAccount', 'sgMailbox', 'sgAddressBook', function($scope, $rootScope, $stateParams, $state, $q, FileUploader, stateAccounts, stateMessage, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox, AddressBook) {
      if ($stateParams.actionName == 'reply') {
        stateMessage.$reply().then(function(msgObject) {
          $scope.message = msgObject;
        });
      }
      else if ($stateParams.actionName == 'replyall') {
        stateMessage.$replyAll().then(function(msgObject) {
          $scope.message = msgObject;
        });
      }
      else if ($stateParams.actionName == 'forward') {
        stateMessage.$forward().then(function(msgObject) {
          $scope.message = msgObject;
        });
      }
      else if (angular.isDefined(stateMessage)) {
        $scope.message = stateMessage;
      }
      $scope.identities = _.pluck(_.flatten(_.pluck(stateAccounts, 'identities')), 'full');
      $scope.cancel = function() {
        if ($scope.mailbox)
          $state.go('mail.account.mailbox', { accountId: $scope.mailbox.$account.id, mailboxId: encodeUriFilter($scope.mailbox.path) });
        else
          $state.go('mail');
      };
      $scope.send = function(message) {
        message.$send().then(function(data) {
          $rootScope.message = null;
          $state.go('mail');
        }, function(data) {
          console.debug('failure ' + JSON.stringify(data, undefined, 2));
        });
      };
      $scope.userFilter = function($query) {
        var deferred = $q.defer();
        AddressBook.$filterAll($query).then(function(results) {
          deferred.resolve(_.invoke(results, '$shortFormat'));
        });
        return deferred.promise;
      };
      $scope.uploader = new FileUploader({
        url: stateMessage.$absolutePath({asDraft: true}) + '/save',
        autoUpload: true,
        alias: 'attachments',
        onProgressItem: function(item, progress) {
          console.debug(item); console.debug(progress);
        },
        onSuccessItem: function(item, response, status, headers) {
          stateMessage.$setUID(response.uid);
          stateMessage.$reload();
          console.debug(item); console.debug('success = ' + JSON.stringify(response, undefined, 2));
        },
        onErrorItem: function(item, response, status, headers) {
          console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
        }
      });
    }]);

})();
