/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ngSanitize', 'ui.router', 'vs-repeat', 'SOGo.Common', 'SOGo.UI', 'SOGo.UIDesktop'])

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

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('app', {
          url: '/addressbooks',
          abstract: true,
          views: {
            addressbooks: {
              templateUrl: 'UIxContactFoldersView', // UI/Templates/Contacts/UIxContactFoldersView.wox
              controller: 'AddressBooksCtrl'
            }
          },
          resolve: {
            stateAddressbooks: ['sgAddressBook', function(AddressBook) {
              return AddressBook.$findAll(contactFolders);
            }]
          }
        })
        .state('app.addressbook', {
          url: '/:addressbookId',
          views: {
            addressbook: {
              templateUrl: 'addressbook',
              controller: 'AddressBookCtrl'
            }
          },
          resolve: {
            stateAddressbook: ['$stateParams', 'sgAddressBook', function($stateParams, AddressBook) {
              return AddressBook.$find($stateParams.addressbookId);
            }]
          }
        })
        .state('app.addressbook.new', {
          url: '/:contactType/new',
          views: {
            card: {
              templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
              controller: 'CardCtrl'
            }
          },
          resolve: {
            stateCard: ['$stateParams', 'stateAddressbook', 'sgCard', function($stateParams, stateAddressbook, Card) {
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
              controller: 'CardCtrl'
            }
          }
        })
        .state('app.addressbook.card.editor', {
          url: '/edit',
          views: {
            'card@app.addressbook': {
              templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
              controller: 'CardCtrl'
            }
          }
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/addressbooks/personal');
    }])

    .controller('AddressBooksCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$q', '$mdDialog', 'sgFocus', 'sgCard', 'sgAddressBook', 'sgDialog', 'sgSettings', 'sgUser', 'stateAddressbooks', function($state, $scope, $rootScope, $stateParams, $timeout, $q, $mdDialog, focus, Card, AddressBook, Dialog, Settings, User, stateAddressbooks) {
      var currentAddressbook;

      $scope.activeUser = Settings.activeUser;
      $scope.service = AddressBook;

      // $scope functions
      $scope.select = function(folder) {
        $scope.editMode = false;
        //$rootScope.currentFolder = folder;
      };
      $scope.newAddressbook = function(ev) {
        $scope.editMode = false;
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: ev,
          clickOutsideToClose: true,
          escapeToClose: true,
          template:
          '<md-dialog aria-label="' + l('New addressbook') + '">' +
            '  <md-content layout="column">' +
            '    <md-input-container>' +
            '      <label>' + l('Name of new addressbook') + '</label>' +
            '      <input type="text" ng-model="name" required="required"/>' +
            '    </md-input-container>' +
            '    <div layout="row">' +
            '      <md-button ng-click="cancelClicked()">' +
            '        Cancel' +
            '      </md-button>' +
            '      <md-button ng-click="okClicked()" ng-disabled="!name.length">' +
            '        OK' +
            '      </md-button>' +
            '    </div>'+
            '  </md-content>' +
            '</md-dialog>',
          controller: NewAddressBookDialogController
        });
        function NewAddressBookDialogController(scope, $mdDialog) {
          scope.name = "";
          scope.cancelClicked = function() {
            $mdDialog.hide();
          }
          scope.okClicked = function() {
            var addressbook = new AddressBook(
              {
                name: scope.name,
                isEditable: true,
                isRemote: false,
                owner: UserLogin
              }
            );
            AddressBook.$add(addressbook);
            $mdDialog.hide();
          }
        }
      };
      $scope.edit = function(index, folder) {
        if (!folder.isRemote) {
          $scope.editMode = folder.id;
          $scope.originalAddressbook = angular.extend({}, folder.$omit());
          focus('addressBookName_' + folder.id);
        }
      };
      $scope.revertEditing = function(folder) {
        folder.name = $scope.originalAddressbook.name;
        $scope.editMode = false;
      };
      $scope.save = function(folder) {
        var name = folder.name;
        if (name && name.length > 0 && name != $scope.originalAddressbook.name) {
          folder.$rename(name)
            .then(function(data) {
              $scope.editMode = false;
            }, function(data, status) {
              Dialog.alert(l('Warning'), data);
            });
        }
      };
      $scope.confirmDelete = function() {
        if ($scope.currentFolder.isSubscription) {
          // Unsubscribe without confirmation
          $rootScope.currentFolder.$delete()
            .then(function() {
              $rootScope.currentFolder = null;
              $state.go('app.addressbook', { addressbookId: 'personal' });
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                             $rootScope.currentFolder.name),
                           l(data.error));
            });
        }
        else {
          Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                         $scope.currentFolder.name))
            .then(function() {
              $rootScope.currentFolder.$delete()
                .then(function() {
                  $rootScope.currentFolder = null;
                }, function(data, status) {
                  Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                                 $rootScope.currentFolder.name),
                               l(data.error));
                });
            });
        }
      };
      $scope.importCards = function() {

      };
      $scope.exportCards = function() {
        window.location.href = ApplicationBaseURL + '/' + $scope.currentFolder.id + '/exportFolder';
      };
      $scope.share = function() {
        $mdDialog.show({
          templateUrl: $scope.currentFolder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: AddressBookACLController,
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: $scope.currentFolder.$acl.$users(),
            User: User,
            stateAddressbook: $scope.currentFolder,
            q: $q
          }
        });
        function AddressBookACLController($scope, $mdDialog, usersWithACL, User, stateAddressbook, q) {
          $scope.users = usersWithACL; // ACL users
          $scope.stateAddressbook = stateAddressbook;
          $scope.userToAdd = '';
          $scope.searchText = '';
          $scope.userFilter = function($query) {
            var deferred = q.defer();
            User.$filter($query).then(function(results) {
              deferred.resolve(results)
            });
            return deferred.promise;
          };
          $scope.closeModal = function() {
              stateAddressbook.$acl.$resetUsersRights(); // cancel changes
              $mdDialog.hide();
            };
            $scope.saveModal = function() {
              stateAddressbook.$acl.$saveUsersRights().then(function() {
                $mdDialog.hide();
              }, function(data, status) {
                Dialog.alert(l('Warning'), l('An error occured please try again.'));
              });
            };
            $scope.confirmChange = function(user) {
              var confirmation = user.$confirmRights();
              if (confirmation) {
                Dialog.confirm(l('Warning'), confirmation).then(function(res) {
                  if (!res)
                    user.$resetRights(true);
                });
              }
            };
            $scope.removeUser = function(user) {
              stateAddressbook.$acl.$removeUser(user.uid).then(function() {
                if (user.uid == $scope.selectedUser.uid) {
                  $scope.selectedUser = null;
                }
              }, function(data, status) {
                Dialog.alert(l('Warning'), l('An error occured please try again.'))
              });
            };
          $scope.addUser = function(data) {            
              stateAddressbook.$acl.$addUser(data).then(function() {
                $scope.userToAdd = '';
                $scope.searchText = '';
              }, function(error) {
                Dialog.alert(l('Warning'), error);
              });
            };
            $scope.selectUser = function(user) {
              // Check if it is a different user
              if ($scope.selectedUser != user) {
                $scope.selectedUser = user;
                $scope.selectedUser.$rights();
              }
            };
        };
      };

      /**
       * subscribeToFolder - Callback of sgSubscribe directive
       */
      $scope.subscribeToFolder = function(addressbookData) {
        console.debug('subscribeToFolder ' + addressbookData.owner + addressbookData.name);
        AddressBook.$subscribe(addressbookData.owner, addressbookData.name).catch(function(data) {
          Dialog.alert(l('Warning'), l('An error occured please try again.'));
        });
      };
    }])

    .controller('AddressBookCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$mdDialog', 'sgFocus', 'sgCard', 'sgAddressBook', 'sgDialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook', function($state, $scope, $rootScope, $stateParams, $timeout, $mdDialog, focus, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
      var currentAddressbook;

      $rootScope.currentFolder = stateAddressbook;

      $scope.newComponent = function(ev) {
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: ev,
          clickOutsideToClose: true,
          escapeToClose: true,
          template:
          '<md-dialog aria-label="Create component">' +
            '  <md-content>' +
            '  <div layout="column">' +
            '    <md-button ng-click="createContact()">' +
            '      Contact' +
            '    </md-button>' +
            '    <md-button ng-click="createList()">' +
            '      List' +
            '    </md-button>' +
            '  </div>' +
            '  </md-content>' +
            '</md-dialog>',
          locals: {
            state: $state
          },
          controller: ComponentDialogController
        });
        function ComponentDialogController(scope, $mdDialog, state) {
          scope.createContact = function() {
            state.go('app.addressbook.new', { addressbookId: $scope.currentFolder.id, contactType: 'card' });
            $mdDialog.hide();
          }
          scope.createList = function() {
            state.go('app.addressbook.new', { addressbookId: $scope.currentFolder.id, contactType: 'list' });
            $mdDialog.hide();
          }
        }
      };
    }])

  /**
   * Controller to view and edit a card
   */
    .controller('CardCtrl', ['$scope', '$rootScope', '$timeout', 'sgAddressBook', 'sgCard', 'sgDialog', 'sgFocus', '$state', '$stateParams', 'stateCard', function($scope, $rootScope, $timeout, AddressBook, Card, Dialog, focus, $state, $stateParams, stateCard) {
      $rootScope.card = stateCard;

      $scope.allEmailTypes = Card.$EMAIL_TYPES;
      $scope.allTelTypes = Card.$TEL_TYPES;
      $scope.allUrlTypes = Card.$URL_TYPES;
      $scope.allAddressTypes = Card.$ADDRESS_TYPES;
      $scope.categories = {};

      $scope.addOrgUnit = function() {
        var i = $scope.card.$addOrgUnit('');
        focus('orgUnit_' + i);
      };
      $scope.addEmail = function() {
        var i = $scope.card.$addEmail('');
        focus('email_' + i);
      };
      $scope.addPhone = function() {
        var i = $scope.card.$addPhone('');
        focus('phone_' + i);
      };
      $scope.addUrl = function() {
        var i = $scope.card.$addUrl('', '');
        focus('url_' + i);
      };
      $scope.addAddress = function() {
        var i = $scope.card.$addAddress('', '', '', '', '', '', '', '');
        focus('address_' + i);
      };
      $scope.addMember = function() {
        var i = $scope.card.$addMember('');
        focus('ref_' + i);
      };
      $scope.save = function(form) {
        if (form.$valid) {
          $scope.card.$save()
            .then(function(data) {
              var i = _.indexOf(_.pluck($scope.currentFolder.cards, 'id'), $scope.card.id);
              if (i < 0) {
                // New card; reload contacts list and show addressbook in which the card has been created
                $rootScope.currentFolder = AddressBook.$find(data.pid);
              }
              else {
                // Update contacts list with new version of the Card object
                $rootScope.currentFolder.cards[i] = angular.copy($scope.card);
              }
              $state.go('app.addressbook.card.view', { cardId: $scope.card.id });
            }, function(data, status) {
              console.debug('failed');
            });
        }
      };
      $scope.reset = function() {
        $scope.card.$reset();
      };
      $scope.cancel = function() {
        $scope.card.$reset();
        if ($scope.card.isNew) {
          // Cancelling the creation of a card
          $scope.card = null;
          $state.go('app.addressbook', { addressbookId: $scope.currentFolder.id });
        }
        else {
          // Cancelling the edition of an existing card
          $state.go('app.addressbook.card.view', { cardId: $scope.card.id });
        }
      };
      $scope.confirmDelete = function(card) {
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the card of %{0}?', card.$fullname()))
          .then(function() {
            // User confirmed the deletion
            card.$delete()
              .then(function() {
                // Remove card from list of addressbook
                $rootScope.currentFolder.cards = _.reject($rootScope.currentFolder.cards, function(o) {
                  return o.id == card.id;
                });
                // Remove card object from scope
                $scope.card = null;
                $state.go('app.addressbook', { addressbookId: $scope.currentFolder.id });
              }, function(data, status) {
                Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                             card.$fullname()));
              });
          });
      };
    }]);
})();
