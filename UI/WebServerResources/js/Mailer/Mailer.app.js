/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.MailerUI module */

(function() {
  'use strict';

  angular.module('SOGo.MailerUI', ['ngSanitize', 'ui.router', 'ck', 'angularFileUpload', 'SOGo.Common', 'SOGo.ContactsUI', 'ngAnimate', 'SOGo.PreferencesUI'])
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
            controller: 'MailboxesController',
            controllerAs: 'app'
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
            template: '<ui-view/>'
          }
        },
        resolve: {
          stateAccount: stateAccount
        }
      })
      .state('mail.account.virtualMailbox', {
        url: '/virtual',
        views: {
          'mailbox@mail': {
            templateUrl: 'UIxMailFolderTemplate', // UI/Templates/MailerUI/UIxMailFolderTemplate.wox
            controller: 'MailboxController',
            controllerAs: 'mailbox'
          }
        },
        resolve: {
          stateMailbox: stateVirtualMailbox
        }
      })
      .state('mail.account.virtualMailbox.message', {
        url: '/:mailboxId/:messageId',
        views: {
           message: {
            templateUrl: 'UIxMailViewTemplate', // UI/Templates/MailerUI/UIxMailViewTemplate.wox
            controller: 'MessageController',
            controllerAs: 'viewer'
          }
        },
        resolve: {
          stateMailbox: stateVirtualMailboxOfMessage,
          stateMessages: stateMessages,
          stateMessage: stateMessage
        }
      })
      .state('mail.account.mailbox', {
        url: '/:mailboxId',
        views: {
          'mailbox@mail': {
            templateUrl: 'UIxMailFolderTemplate', // UI/Templates/MailerUI/UIxMailFolderTemplate.wox
            controller: 'MailboxController',
            controllerAs: 'mailbox'
          }
        },
        resolve: {
          stateMailbox: stateMailbox,
          stateMessages: stateMessages
        }
      })
      // .state('mail.account.mailbox.newMessage', {
      //   url: '/new',
      //   views: {
      //     'mailbox@mail': {
      //       templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
      //       controller: 'MessageEditorController',
      //       controllerAs: 'editor'
      //     }
      //   },
      //   resolve: {
      //     stateMessage: stateNewMessage
      //   }
      // })
      .state('mail.account.mailbox.message', {
        url: '/:messageId',
        views: {
          message: {
            templateUrl: 'UIxMailViewTemplate', // UI/Templates/MailerUI/UIxMailViewTemplate.wox
            controller: 'MessageController',
            controllerAs: 'viewer'
          }
        },
        resolve: {
          stateMessage: stateMessage
        }
      });
      // .state('mail.account.mailbox.message.edit', {
      //   url: '/edit',
      //   views: {
      //     'mailbox@mail': {
      //       templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
      //       controller: 'MessageEditorController',
      //       controllerAs: 'editor'
      //     }
      //   },
      //   resolve: {
      //     stateContent: stateContent
      //   }
      // })
      // .state('mail.account.mailbox.message.action', {
      //   url: '/{actionName:(?:reply|replyall|forward)}',
      //   views: {
      //     'mailbox@mail': {
      //       templateUrl: 'UIxMailEditor', // UI/Templates/MailerUI/UIxMailEditor.wox
      //       controller: 'MessageEditorController',
      //       controllerAs: 'editor'
      //     }
      //   }
      // });

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
    var accounts = Account.$findAll(mailAccounts),
        promises = [];
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
  stateMailbox.$inject = ['Mailbox', '$stateParams', 'stateAccount', 'decodeUriFilter'];
  function stateMailbox(Mailbox, $stateParams, stateAccount, decodeUriFilter) {
    var mailboxId = decodeUriFilter($stateParams.mailboxId),
        _find;

    // Recursive find function
    _find = function(mailboxes) {
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
  stateMessages.$inject = ['Mailbox', 'stateMailbox'];
  function stateMessages(Mailbox, stateMailbox) {
    if (Mailbox.$virtualMode)
      return [];

    return stateMailbox.$filter();
  }

  /**
   * @ngInject
   */
  // stateNewMessage.$inject = ['stateAccount'];
  // function stateNewMessage(stateAccount) {
  //   return stateAccount.$newMessage();
  // }

  /**
   * Return a VirtualMailbox instance
   * @ngInject
   */
  stateVirtualMailbox.$inject = ['$q', 'Mailbox'];
  function stateVirtualMailbox($q, Mailbox) {
    if (Mailbox.$virtualMode)
      return Mailbox.selectedFolder;
    else
      return $q.reject("No virtual mailbox defined");
  }

  /**
   * Return a Mailbox instance from a VirtualMailbox instance
   * @ngInject
   */
  stateVirtualMailboxOfMessage.$inject = ['$q', 'Mailbox', 'decodeUriFilter', '$stateParams'];
  function stateVirtualMailboxOfMessage($q, Mailbox, decodeUriFilter, $stateParams) {
    var mailboxId = decodeUriFilter($stateParams.mailboxId);

    if (Mailbox.$virtualMode) {
      Mailbox.selectedFolder.resetSelectedMessage();
      return _.find(Mailbox.selectedFolder.$mailboxes, function(mailboxObject) {
        return mailboxObject.path == mailboxId;
      });
    }
    else
      return $q.reject("No virtual mailbox defined for message");
  }

  /**
   * @ngInject
   */
  stateMessage.$inject = ['Mailbox', 'encodeUriFilter', '$stateParams', '$state', 'stateMailbox', 'stateMessages'];
  function stateMessage(Mailbox, encodeUriFilter, $stateParams, $state, stateMailbox, stateMessages) {
    var message;

    message = _.find(stateMailbox.$messages, function(messageObject) {
      return messageObject.uid == $stateParams.messageId;
    });

    if (message) {
      stateMailbox.selectedMessage = $stateParams.messageId;
      return message.$reload();
    }
    else {
      // Message not found
      $state.go('mail.account.mailbox', { accountId: stateMailbox.$account.id, mailboxId: encodeUriFilter(stateMailbox.path) });
    }
  }

  /**
   * @ngInject
   */
  // stateContent.$inject = ['stateMessage'];
  // function stateContent(stateMessage) {
  //   return stateMessage.$editableContent();
  // }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope', '$log', '$state'];
  function runBlock($rootScope, $log, $state) {
    $rootScope.$on('$stateChangeError', function(event, toState, toParams, fromState, fromParams, error) {
      $log.error(error);
      $state.go('mail');
    });
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      $log.error(event, current, previous, rejection);
    });
  }

})();
