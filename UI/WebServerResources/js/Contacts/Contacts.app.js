/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', ['ngSanitize', 'ui.router', 'angularFileUpload', 'ck', 'SOGo.Common', 'SOGo.PreferencesUI', 'SOGo.MailerUI'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlRouterProvider'];
  function configure($stateProvider, $urlRouterProvider) {
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
        }
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
    $urlRouterProvider.otherwise('/addressbooks/personal');
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
  stateAddressbook.$inject = ['$stateParams', 'stateAddressbooks', 'AddressBook'];
  function stateAddressbook($stateParams, stateAddressbooks, AddressBook) {
    var addressbook = _.find(stateAddressbooks, function(addressbook) {
      return addressbook.id == $stateParams.addressbookId;
    });
    addressbook.$reload();
    return addressbook;
  }

  /**
   * @ngInject
   */
  stateNewCard.$inject = ['$stateParams', 'stateAddressbook', 'Card'];
  function stateNewCard($stateParams, stateAddressbook, Card) {
    var tag = 'v' + $stateParams.contactType,
        card = new Card({ pid: $stateParams.addressbookId, c_component: tag });
    stateAddressbook.selectedCard = true;
    return card;
  }

  /**
   * @ngInject
   */
  stateCard.$inject = ['$stateParams', 'stateAddressbook'];
  function stateCard($stateParams, stateAddressbook) {
    stateAddressbook.selectedCard = $stateParams.cardId;
    return stateAddressbook.$getCard($stateParams.cardId);
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope', '$log', '$state'];
  function runBlock($rootScope, $log, $state) {
    $rootScope.$on('$stateChangeError', function(event, toState, toParams, fromState, fromParams, error) {
      $log.error(error);
      $state.go('app');
    });
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      $log.error(event, current, previous, rejection);
    });
  }

})();
