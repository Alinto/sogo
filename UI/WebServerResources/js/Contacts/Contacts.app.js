/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', ['ngCookies', 'ui.router', 'angularFileUpload', 'ck', 'SOGo.Common', 'SOGo.PreferencesUI', 'SOGo.MailerUI'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlServiceProvider'];
  function configure($stateProvider, $urlServiceProvider) {
    $stateProvider
      .state('app', {
        url: '/addressbooks',
        abstract: true,
        views: {
          addressbooks: {
            templateUrl: 'UIxContactFoldersView', // UI/Templates/Contacts/UIxContactFoldersView.wox
            controller: 'AddressBooksController',
            controllerAs: 'app'
          }
        },
        resolve: {
          stateAddressbooks: stateAddressbooks
        }
      })
      .state('app.addressbook', {
        url: '/:addressbookId',
        views: {
          addressbook: {
            templateUrl: 'addressbook',
            controller: 'AddressBookController',
            controllerAs: 'addressbook'
          }
        },
        resolve: {
          stateAddressbook: stateAddressbook
        }
      })
      .state('app.addressbook.new', {
        url: '/{contactType:(?:card|list)}/new',
        params: {
          refs: { array: true }
        },
        views: {
          card: {
            templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
            controller: 'CardController',
            controllerAs: 'editor'
          }
        },
        resolve: {
          stateCard: stateNewCard
        }
      })
      .state('app.addressbook.card', {
        url: '/:cardId',
        abstract: true,
        views: {
          card: {
            template: '<ui-view/>'
          }
        },
        resolve: {
          stateCard: stateCard
        },
        onEnter: onEnterCard,
        onExit: onExitCard
      })
      .state('app.addressbook.card.view', {
        url: '/view',
        views: {
          'card@app.addressbook': {
            templateUrl: 'UIxContactViewTemplate', // UI/Templates/Contacts/UIxContactViewTemplate.wox
            controller: 'CardController',
            controllerAs: 'editor'
          }
        }
      })
      .state('app.addressbook.card.editor', {
        url: '/edit',
        views: {
          'card@app.addressbook': {
            templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
            controller: 'CardController',
            controllerAs: 'editor'
          }
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlServiceProvider.rules.otherwise({ state: 'app.addressbook', params: { addressbookId: 'personal' } });
  }

  /**
   * @ngInject
   */
  stateAddressbooks.$inject = ['AddressBook'];
  function stateAddressbooks(AddressBook) {
    return AddressBook.$findAll(window.contactFolders);
  }

  /**
   * @ngInject
   */
  stateAddressbook.$inject = ['$q', '$state', '$stateParams', 'AddressBook'];
  function stateAddressbook($q, $state, $stateParams, AddressBook) {
    var addressbook = _.find(AddressBook.$findAll(), function(addressbook) {
      return addressbook.id == $stateParams.addressbookId;
    });
    if (addressbook) {
      delete addressbook.selectedCard;
      addressbook.$reload();
      return addressbook;
    }
    return $q.reject('Addressbook ' + $stateParams.addressbookId + ' not found');
  }

  /**
   * @ngInject
   */
  stateNewCard.$inject = ['$stateParams', 'stateAddressbook', 'Card'];
  function stateNewCard($stateParams, stateAddressbook, Card) {
    var tag = 'v' + $stateParams.contactType,
        card = new Card({ pid: $stateParams.addressbookId, c_component: tag, refs: $stateParams.refs });
    stateAddressbook.selectedCard = true;
    return card;
  }

  /**
   * @ngInject
   */
  stateCard.$inject = ['$state', '$stateParams', 'stateAddressbook'];
  function stateCard($state, $stateParams, stateAddressbook) {
    return stateAddressbook.$futureAddressBookData.then(function() {
      var card = _.find(stateAddressbook.$cards, function(cardObject) {
        return (cardObject.id == $stateParams.cardId);
      });

      if (card) {
        return card.$reload();
      }
      else {
        // Card not found
        $state.go('app.addressbook');
      }
    });
  }

  /**
   * @ngInject
   */
  onEnterCard.$inject = ['$stateParams', 'stateAddressbook'];
  function onEnterCard($stateParams, stateAddressbook) {
    stateAddressbook.selectedCard = $stateParams.cardId;
  }

  /**
   * @ngInject
   */
  onExitCard.$inject = ['stateAddressbook'];
  function onExitCard(stateMailbox) {
    delete stateAddressbook.selectedCard;
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
    $transitions.onError({ to: 'app.**' }, function(transition) {
      if (transition.to().name != 'app' &&
          !transition.ignored()) {
        $log.error('transition error to ' + transition.to().name + ': ' + transition.error().detail);
        $state.go('app.addressbook', { addressbookId: 'personal' });
      }
    });
  }

})();
