/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ngSanitize', 'ui.router', 'vs-repeat', 'SOGo.Common'])

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

    .config(configure);

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
            controller: 'AddressBooksController'
          }
        },
        resolve: {
          stateAddressbooks: ['AddressBook', function(AddressBook) {
            return AddressBook.$findAll(window.contactFolders);
          }]
        }
      })
      .state('app.addressbook', {
        url: '/:addressbookId',
        views: {
          addressbook: {
            templateUrl: 'addressbook',
            controller: 'AddressBookController'
          }
        },
        resolve: {
          stateAddressbook: ['$stateParams', 'AddressBook', function($stateParams, AddressBook) {
            return AddressBook.$find($stateParams.addressbookId);
          }]
        }
      })
      .state('app.addressbook.new', {
        url: '/{contactType:(?:card|list)}/new',
        views: {
          card: {
            templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
            controller: 'CardController'
          }
        },
        resolve: {
          stateCard: ['$stateParams', 'stateAddressbook', 'Card', function($stateParams, stateAddressbook, Card) {
            var tag = 'v' + $stateParams.contactType,
                card = new Card({ pid: $stateParams.addressbookId, tag: tag });
            return card;
          }]
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
          stateCard: ['$stateParams', 'stateAddressbook', function($stateParams, stateAddressbook) {
            return stateAddressbook.$getCard($stateParams.cardId);
          }]
        }
      })
      .state('app.addressbook.card.view', {
        url: '/view',
        views: {
          'card@app.addressbook': {
            templateUrl: 'UIxContactViewTemplate', // UI/Templates/Contacts/UIxContactViewTemplate.wox
            controller: 'CardController'
          }
        }
      })
      .state('app.addressbook.card.editor', {
        url: '/edit',
        views: {
          'card@app.addressbook': {
            templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
            controller: 'CardController'
          }
        }
      });

    // if none of the above states are matched, use this as the fallback
    $urlRouterProvider.otherwise('/addressbooks/personal');
  }

})();
