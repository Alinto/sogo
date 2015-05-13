/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.MailerUI module */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', []);

  angular.module('SOGo.MailerUI', ['ngSanitize', 'ui.router', 'vs-repeat', 'ck', 'angularFileUpload', 'SOGo.Common', 'SOGo.ContactsUI', 'ngAnimate'])

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

    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlRouterProvider'];
  function configure($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('mail', {
        url: '/Mail',
        views: {
          mailboxes: {
            templateUrl: 'UIxMailMainFrame', // UI/Templates/MailerUI/UIxMailMainFrame.wox
            controller: 'MailboxesController'
          }
        },
        resolve: {
          stateAccounts: stateAccounts
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
          stateAccount: stateAccount
        }
      })
      .state('mail.account.mailbox', {
        url: '/:mailboxId',
        views: {
          'mailbox@mail': {
            templateUrl: 'UIxMailFolderTemplate', // UI/Templates/MailerUI/UIxMailFolderTemplate.wox
            controller: 'MailboxController'
          }
        },
        resolve: {
          stateMailbox: stateMailbox,
          stateMessages: stateMessages
        }
      })
      .state('mail.account.mailbox.message', {
        url: '/:messageId',
        views: {
          message: {
            templateUrl: 'UIxMailViewTemplate', // UI/Templates/MailerUI/UIxMailViewTemplate.wox
            controller: 'MessageController'
          }
        },
        resolve: {
          stateMessage: stateMessage
        }
      })
      .state('mail.account.mailbox.message.edit', {
        url: '/edit',
        views: {
          'mailbox@mail': {
            templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
            controller: 'MessageEditorController'
          }
        },
        resolve: {
          stateContent: stateContent
        }
      })
      .state('mail.account.mailbox.message.action', {
        url: '/{actionName:(?:reply|replyall|forward)}',
        views: {
          'mailbox@mail': {
            templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
            controller: 'MessageEditorController'
          }
        }
      })
      .state('mail.newMessage', {
        url: '/new',
        views: {
          mailbox: {
            templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
            controller: 'MessageEditorController'
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
    // tagsInputConfigProvider.setDefaults('tagsInput', {
    //   addOnComma: false,
    //   replaceSpacesWithDashes: false,
    //   allowedTagsPattern: /([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)/i
    // });
  }

  /**
   * @ngInject
   */
  stateAccounts.$inject = ['$q', 'Account'];
  function stateAccounts($q, Account) {
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
  }

  /**
   * @ngInject
   */
  stateAccount.$inject = ['$stateParams', 'stateAccounts'];
  function stateAccount($stateParams, stateAccounts) {
    return _.find(stateAccounts, function(account) {
      return account.id == $stateParams.accountId;
    });
  }

  /**
   * @ngInject
   */
  stateMailbox.$inject = ['$stateParams', 'stateAccount', 'decodeUriFilter'];
  function stateMailbox($stateParams, stateAccount, decodeUriFilter) {
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
  }

  /**
   * @ngInject
   */
  stateMessages.$inject = ['stateMailbox'];
  function stateMessages(stateMailbox) {
    return stateMailbox.$filter();
  }

  /**
   * @ngInject
   */
  stateMessage.$inject = ['encodeUriFilter', '$stateParams', '$state', 'stateMailbox', 'stateMessages'];
  function stateMessage(encodeUriFilter, $stateParams, $state, stateMailbox, stateMessages) {
    var message = _.find(stateMailbox.$messages, function(messageObject) {
      return messageObject.uid == $stateParams.messageId;
    });

    if (message)
      return message.$reload();
    else
      // Message not found
      $state.go('mail.account.mailbox', { accountId: stateMailbox.$account.id, mailboxId: encodeUriFilter(stateMailbox.path) }  );
  }

  /**
   * @ngInject
   */
  stateContent.$inject = ['stateMessage'];
  function stateContent(stateMessage) {
    return stateMessage.$editableContent();
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope'];
  function runBlock($rootScope) {
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      console.error(event, current, previous, rejection)
    })
  }

})();
