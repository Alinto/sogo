/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.MailerUI module */

(function() {
  'use strict';

  angular.module('SOGo.MailerUI', ['ngCookies', 'ui.router', 'ck', 'angularFileUpload', 'SOGo.Common', 'SOGo.ContactsUI', 'SOGo.SchedulerUI', 'ngAnimate', 'SOGo.PreferencesUI'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlServiceProvider'];
  function configure($stateProvider, $urlServiceProvider) {
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
        },
        onEnter: onEnterMessage,
        onExit: onExitMessage
      })
      .state('mail.account.inbox', {
        url: '/inbox',
        onEnter: onEnterInbox
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
        onEnter: onEnterMessage,
        onExit: onExitMessage,
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
    $urlServiceProvider.rules.otherwise('/Mail/0/inbox');

    // Try to register SOGo has an handler for mailto: links
    if (navigator && navigator.registerProtocolHandler) {
      var mailtoURL = window.location.origin + window.ApplicationBaseURL + 'UIxMailPopupView#!/Mail/0/INBOX/new?%s';
      try {
        navigator.registerProtocolHandler('mailto', mailtoURL, 'SOGo');
      }
      catch (e) {}
    }
  }

  /**
   * @ngInject
   */
  stateAccounts.$inject = ['$window', '$q', 'Account'];
  function stateAccounts($window, $q, Account) {
    var accounts = Account.$findAll($window.mailAccounts),
        promises = [];
    // Fetch list of mailboxes for each account
    angular.forEach(accounts, function(account, i) {
      var mailboxes = account.$getMailboxes();
      if (i === 0)
        // Make sure we have the list of mailboxes of the first account
        promises.push(mailboxes.then(function(objects) {
          return account;
        }));
      else
        // Don't wait for external accounts
        promises.push(account);
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
  stateMailbox.$inject = ['$q', '$stateParams', 'stateAccount', 'decodeUriFilter', 'Mailbox'];
  function stateMailbox($q, $stateParams, stateAccount, decodeUriFilter, Mailbox) {
    var mailbox,
        mailboxId = decodeUriFilter($stateParams.mailboxId),
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

    if (Mailbox.selectedFolder && !Mailbox.$virtualMode)
      Mailbox.selectedFolder.$isLoading = true;

    mailbox = _find(stateAccount.$mailboxes);

    if (mailbox) {
      mailbox.$topIndex = 0;
      mailbox.selectFolder();
      return mailbox;
    }
    else
      // Mailbox not found
      return $q.reject("Mailbox doesn't exist");
  }

  /**
   * @ngInject
   */
  onEnterInbox.$inject = ['$transition$', 'encodeUriFilter', 'Mailbox'];
  function onEnterInbox($transition, encodeUriFilter, Mailbox) {
    var stateAccountPromise = $transition.injector().getAsync('stateAccount');
    return stateAccountPromise.then(function(stateAccount) {
      if (stateAccount.$mailboxes.length > 0) {
        return $transition.router.stateService.target('mail.account.mailbox', {
          accountId: stateAccount.id,
          mailboxId: encodeUriFilter(stateAccount.$mailboxes[0].path)
        });
      }
      else {
        Mailbox.selectedFolder = false;
        return $transition.router.stateService.target('mail');
      }
    });
  }

  /**
   * @ngInject
   */
  stateMessages.$inject = ['$q', '$state', 'Mailbox', 'stateMailbox'];
  function stateMessages($q, $state, Mailbox, stateMailbox) {
    var promise;

    if (Mailbox.$virtualMode)
      return [];

    if (stateMailbox)
      promise = stateMailbox.$filter().catch(function() {
        // Mailbox not found
        return $q.reject('Mailbox not found');
      });
    else
      promise = $q.reject("Mailbox doesn't exist");

    return promise;
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
      return messageObject.uid == parseInt($stateParams.messageId);
    });

    if (message) {
      return message.$reload({useCache: true});
    }
    else {
      // Message not found
      $state.go('mail.account.mailbox', { accountId: stateMailbox.$account.id, mailboxId: encodeUriFilter(stateMailbox.path) });
    }
  }

  /**
   * @ngInject
   */
  onEnterMessage.$inject = ['$stateParams', 'stateMailbox'];
  function onEnterMessage($stateParams, stateMailbox) {
    stateMailbox.selectedMessage = parseInt($stateParams.messageId);
  }

  /**
   * @ngInject
   */
  onExitMessage.$inject = ['stateMailbox'];
  function onExitMessage(stateMailbox) {
    delete stateMailbox.selectedMessage;
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$window', '$transitions', '$log', '$state', 'Mailbox'];
  function runBlock($window, $transitions, $log, $state, Mailbox) {
    if (!$window.DebugEnabled)
      $state.defaultErrorHandler(function() {
        // Don't report any state error
      });
    $transitions.onError({ to: 'mail.**' }, function(transition) {
      if (transition.to().name != 'mail' &&
          !transition.ignored() &&
          transition.error().message.indexOf('superseded') < 0) {
        $log.error('transition error to ' + transition.to().name + ': ' + transition.error().detail);
        // Unselect everything
        Mailbox.selectedFolder = false;
        $state.go('mail');
      }
    });
  }

})();
