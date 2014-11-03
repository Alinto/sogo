/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ngSanitize', 'ui.router', 'mm.foundation', 'SOGo.Common', 'SOGo.UIDesktop'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL
    })

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('addressbook', {
          url: '/:addressbookId',
          views: {
            addressbooks: {
              templateUrl: 'addressbooks.html',
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
              templateUrl: 'cardEditor.html',
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
              template: '<ui-view/>'
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
          templateUrl: 'card.html',
          controller: 'CardCtrl'
        })
        .state('addressbook.card.editor', {
          url: '/edit',
          templateUrl: 'cardEditor.html',
          controller: 'CardCtrl'
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/personal');
    }])

    .directive('sgFocusOn', function() {
      return function(scope, elem, attr) {
        scope.$on('sgFocusOn', function(e, name) {
          if (name === attr.sgFocusOn) {
            elem[0].focus();
            elem[0].select();
          }
        });
      };
    })

    .factory('sgFocus', ['$rootScope', '$timeout', function($rootScope, $timeout) {
      return function(name) {
        $timeout(function() {
          $rootScope.$broadcast('sgFocusOn', name);
        });
      }
    }])

    .controller('AddressBookCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$modal', 'sgFocus', 'sgCard', 'sgAddressBook', 'sgDialog', 'stateAddressbooks', 'stateAddressbook', function($state, $scope, $rootScope, $stateParams, $timeout, $modal, focus, Card, AddressBook, Dialog, stateAddressbooks, stateAddressbook) {
      var currentAddressbook;

      // Resolved objects
      $scope.addressbooks = stateAddressbooks;
      $rootScope.addressbook = stateAddressbook;

      // $scope objects
      $scope.search = { status: null, filter: null, lastFilter: null };

      // Adjust search status depending on addressbook type
      currentAddressbook = _.find($scope.addressbooks, function(o) {
        return o.id ==  $stateParams.addressbookId;
      });
      $scope.search.status = (currentAddressbook && currentAddressbook.isRemote)? 'remote-addressbook' : '';

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
                  isRemote: false
                }
              );
              AddressBook.$add(addressbook);
            }
          });
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
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                       $rootScope.addressbook.name))
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
      };
      $scope.importCards = function() {

      };
      $scope.exportCards = function() {
        window.location.href = ApplicationBaseURL + '/' + $rootScope.addressbook.id + '/exportFolder';
      };
      $scope.share = function() {
        var modal = $modal.open({
          templateUrl: 'addressbookSharing.html',
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
                  delete $scope.selectedUser;
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
      $scope.doSearch = function(keyEvent) {
        if ($scope.search.filter != $scope.search.lastFilter) {
          if ($scope.search.filter.length > 2) {
            $rootScope.addressbook.$filter($scope.search.filter).then(function(data) {
              if (data.length == 0)
                $scope.search.status = 'no-result';
              else
                $scope.search.status = '';
            });
          }
          else if ($scope.search.filter.length == 0) {
            $rootScope.addressbook = AddressBook.$find($stateParams.addressbookId);
            // Extend resulting model instance with parameters from addressbooks listing
            var o = _.find($scope.addressbooks, function(o) {
              return o.id ==  $stateParams.addressbookId;
            });
            $scope.search.status = (o.isRemote)? 'remote-addressbook' : '';
          }
          else {
            $scope.search.status = 'min-char';
            $rootScope.addressbook.cards = [];
          }
        }
        $scope.search.lastFilter = $scope.search.filter;
      };
    }])

  /**
   * Controller to view and edit a card
   */
    .controller('CardCtrl', ['$scope', '$rootScope', '$timeout', 'sgAddressBook', 'sgCard', 'sgDialog', 'sgFocus', '$state', '$stateParams', 'stateCard', function($scope, $rootScope, $timeout, AddressBook, Card, Dialog, focus, $state, $stateParams, stateCard) {
      $scope.card = stateCard;

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
                // Reload contacts list and show addressbook in which the card has been created
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
          delete $scope.card;
          $state.go('addressbook', { addressbookId: $scope.addressbook.id });
        }
        else {
          // Cancelling the edition of an existing card
          $state.go('addressbook.card.view', { cardId: $scope.card.id });
        }
      };
      $scope.confirmDelete = function(card) {
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the card of <em>%{0}</em>?', card.$fullname()))
          .then(function(res) {
            if (res) {
              // User confirmed the deletion
              card.$delete()
                .then(function() {
                  // Remove card from list of addressbook
                  $rootScope.addressbook.cards = _.reject($rootScope.addressbook.cards, function(o) {
                    return o.id == card.id;
                  });
                  // Remove card object from scope
                  delete $scope.card;
                }, function(data, status) {
                  Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                               card.$fullname()));
                });
            }
          });
      };
    }]);

})();
