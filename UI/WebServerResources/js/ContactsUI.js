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
        .state('addressbook', {
          url: '/:addressbookId',
          views: {
            addressbooks: {
              templateUrl: 'UIxContactFoldersView', // UI/Templates/Contacts/UIxContactFoldersView.wox
              controller: 'AddressBookCtrl'
            }
          },
          resolve: {
            stateAddressbooks: ['sgAddressBook', function(AddressBook) {
              return AddressBook.$findAll(contactFolders);
            }],
            stateAddressbook: ['$stateParams', 'sgAddressBook', function($stateParams, AddressBook) {
              return AddressBook.$find($stateParams.addressbookId);
            }]
          }
        })
        .state('addressbook.new', {
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
        .state('addressbook.card', {
          url: '/:cardId',
          abstract: true,
          views: {
            card: {
              template: '<ui-view/>',
              controller: 'CardCtrl'
            }
          },
          resolve: {
            stateCard: ['$stateParams', 'stateAddressbook', function($stateParams, stateAddressbook) {
              return stateAddressbook.$getCard($stateParams.cardId);
            }]
          }
        })
        .state('addressbook.card.view', {
          url: '/view',
          templateUrl: 'UIxContactViewTemplate', // UI/Templates/Contacts/UIxContactViewTemplate.wox
          controller: 'CardCtrl'
        })
        .state('addressbook.card.editor', {
          url: '/edit',
          templateUrl: 'UIxContactEditorTemplate', // UI/Templates/Contacts/UIxContactEditorTemplate.wox
          controller: 'CardCtrl'
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/personal');
    }])

    .controller('AddressBookCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$mdDialog', 'sgFocus', 'sgCard', 'sgAddressBook', 'sgDialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook', function($state, $scope, $rootScope, $stateParams, $timeout, $modal, focus, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
      var currentAddressbook;

      $scope.activeUser = Settings.activeUser;

      // Resolved objects
      $scope.addressbooks = stateAddressbooks;
      $rootScope.addressbook = stateAddressbook;

      // Adjust search status depending on addressbook type
      currentAddressbook = _.find($scope.addressbooks, function(o) {
        return o.id ==  $stateParams.addressbookId;
      });

      // $scope functions
      $scope.select = function(rowIndex) {
        $scope.editMode = false;
      };
      $scope.newAddressbook = function() {
        $scope.editMode = false;
        Dialog.prompt(l('New addressbook'),
                      l('Name of new addressbook'))
          .then(function(name) {
            if (name && name.length > 0) {
              var addressbook = new AddressBook(
                {
                  name: name,
                  isEditable: true,
                  isRemote: false,
                  owner: UserLogin
                }
              );
              AddressBook.$add(addressbook);
            }
          });
      };
      $scope.currentFolderIsConfigurable = function(folder) {
        return ($scope.addressbook && $scope.addressbook.id == folder.id && !folder.isRemote);
      };
      $scope.edit = function(i) {
        if (!$rootScope.addressbook.isRemote) {
          if (angular.isUndefined(i)) {
            i = _.indexOf(_.pluck($scope.addressbooks, 'id'), $rootScope.addressbook.id);
          }
          $scope.editMode = $rootScope.addressbook.id;
          $scope.originalAddressbook = angular.extend({}, $scope.addressbook.$omit());
          focus('addressBookName_' + i);
        }
      };
      $scope.revertEditing = function(i) {
        $scope.addressbooks[i].name = $scope.originalAddressbook.name;
        $scope.editMode = false;
      };
      $scope.save = function(i) {
        var name = $scope.addressbooks[i].name;
        if (name && name.length > 0) {
          $scope.addressbook.$rename(name)
            .then(function(data) {
              $scope.editMode = false;
            }, function(data, status) {
              Dialog.alert(l('Warning'), data);
            });
        }
      };
      $scope.confirmDelete = function() {
        if ($scope.addressbook.isSubscription) {
          // Unsubscribe without confirmation
          $rootScope.addressbook.$delete()
            .then(function() {
              $rootScope.addressbook = null;
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                             $rootScope.addressbook.name),
                           l(data.error));
            });
        }
        else {
          Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                         $scope.addressbook.name))
            .then(function(res) {
              if (res) {
                $rootScope.addressbook.$delete()
                  .then(function() {
                    $rootScope.addressbook = null;
                  }, function(data, status) {
                    Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                                   $rootScope.addressbook.name),
                                 l(data.error));
                  });
              }
            });
        }
      };
      $scope.importCards = function() {

      };
      $scope.exportCards = function() {
        window.location.href = ApplicationBaseURL + '/' + $rootScope.addressbook.id + '/exportFolder';
      };
      $scope.share = function() {
        var modal = $modal.open({
          templateUrl: stateAddressbook.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          resolve: {
            modalUsers: function() {
              return stateAddressbook.$acl.$users();
            }
          },
          controller: ['$scope', '$modalInstance', 'sgUser', 'modalUsers', function($scope, $modalInstance, User, modalUsers) {
            $scope.users = modalUsers; // ACL users
            $scope.userFilter = User.$filter; // Filter for typeahead
            $scope.closeModal = function() {
              stateAddressbook.$acl.$resetUsersRights(); // cancel changes
              $modalInstance.close();
            };
            $scope.saveModal = function() {
              stateAddressbook.$acl.$saveUsersRights().then(function() {
                $modalInstance.close();
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
              $scope.userToAdd = '';
              stateAddressbook.$acl.$addUser(data).catch(function(error) {
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
          }]
        });
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

  /**
   * Controller to view and edit a card
   */
    .controller('CardCtrl', ['$scope', '$rootScope', '$timeout', 'sgAddressBook', 'sgCard', 'sgDialog', 'sgFocus', '$state', '$stateParams', 'stateCard', function($scope, $rootScope, $timeout, AddressBook, Card, Dialog, focus, $state, $stateParams, stateCard) {
      $rootScope.card = stateCard;

      $scope.allEmailTypes = Card.$EMAIL_TYPES;
      $scope.allTelTypes = Card.$TEL_TYPES;
      $scope.allUrlTypes = Card.$URL_TYPES;
      $scope.allAddressTypes = Card.$ADDRESS_TYPES;

      $scope.addOrgUnit = function() {
        var i = $scope.card.$addOrgUnit('');
        focus('orgUnit_' + i);
      };
      $scope.addCategory = function() {
        var i = $scope.card.$addCategory('');
        focus('category_' + i);
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
              var i = _.indexOf(_.pluck($rootScope.addressbook.cards, 'id'), $scope.card.id);
              if (i < 0) {
                // New card; reload contacts list and show addressbook in which the card has been created
                $rootScope.addressbook = AddressBook.$find(data.pid);
              }
              else {
                // Update contacts list with new version of the Card object
                $rootScope.addressbook.cards[i] = angular.copy($scope.card);
              }
              $state.go('addressbook.card.view', { cardId: $scope.card.id });
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
          $state.go('addressbook', { addressbookId: $scope.addressbook.id });
        }
        else {
          // Cancelling the edition of an existing card
          $state.go('addressbook.card.view', { cardId: $scope.card.id });
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
                $rootScope.addressbook.cards = _.reject($rootScope.addressbook.cards, function(o) {
                  return o.id == card.id;
                });
                // Remove card object from scope
                $scope.card = null;
                $state.go('addressbook', { addressbookId: $scope.addressbook.id });
              }, function(data, status) {
                Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                             card.$fullname()));
              });
          });
      };
    }]);
})();
