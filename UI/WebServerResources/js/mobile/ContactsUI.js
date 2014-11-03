/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.ContactsUI (mobile) module */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ionic', 'SOGo.Common', 'SOGo.UIMobile'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL
    })

    .run(function($ionicPlatform) {
      $ionicPlatform.ready(function() {
        // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
        // for form inputs)
        if (window.cordova && window.cordova.plugins.Keyboard) {
          cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
        }
        if (window.StatusBar) {
          // org.apache.cordova.statusbar required
          StatusBar.styleDefault();
        }
      });
    })

    .config(function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('app', {
          url: '/app',
          abstract: true,
          templateUrl: 'menu.html',
          controller: 'AppCtrl'
        })

        .state('app.addressbooks', {
          url: '/addressbooks',
          views: {
            menuContent: {
              templateUrl: 'addressbooks.html',
              controller: 'AddressBooksCtrl'
            }
          }
        })

        .state('app.addressbook', {
          url: '/addressbook/:addressbookId',
          views: {
            menuContent: {
              templateUrl: 'addressbook.html',
              controller: 'AddressBookCtrl',
              resolve: {
                stateAddressbook: function($stateParams, sgAddressBook) {
                  return sgAddressBook.$find($stateParams.addressbookId);
                }
              }
            }
          }
        })

        .state('app.newCard', {
          url: '/addressbook/:addressbookId/:contactType/new',
          views: {
            menuContent: {
              templateUrl: 'card.html',
              controller: 'CardCtrl',
              resolve: {
                stateCard: ['$rootScope', '$stateParams', 'sgAddressBook', 'sgCard', function($rootScope, $stateParams, sgAddressBook, Card) {
                  var tag = 'v' + $stateParams.contactType;
                  if (!$rootScope.addressbook) {
                    $rootScope.addressbook = sgAddressBook.$find($stateParams.addressbookId);
                  }
                  return new Card(
                    {
                      pid: $stateParams.addressbookId,
                      tag: tag,
                      isNew: true
                    }
                  );
                }]
              }
            }
          }
        })

        .state('app.card', {
          url: '/addressbook/:addressbookId/:cardId',
          views: {
            menuContent: {
              templateUrl: 'card.html',
              controller: 'CardCtrl',
              resolve: {
                stateCard: ['$rootScope', '$stateParams', 'sgAddressBook', function($rootScope, $stateParams, AddressBook) {
                  if (!$rootScope.addressbook) {
                    $rootScope.addressbook = AddressBook.$find($stateParams.addressbookId);
                  }
                  return $rootScope.addressbook.$getCard($stateParams.cardId);
                }]
              }
            }
          }
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/app/addressbooks');
    })

  // Inspired from http://codepen.io/gastonbesada/pen/eqvJK
    .directive('ionSearch', function() {
      return {
        restrict: 'E',
        replace: true,
        scope: {
          getData: '=source',
          clearData: '&clear',
          model: '=?',
          search: '=?filter'
        },
        link: function(scope, element, attrs) {
          attrs.minLength = attrs.minLength || 0;
          scope.placeholder = attrs.placeholder || '';
          scope.search = {value: ''};

          if (attrs.class)
            element.addClass(attrs.class);

          if (attrs.source) {
            scope.$watch('search.value', function(newValue, oldValue) {
              if (newValue.length > attrs.minLength) {
                scope.getData(newValue).then(function(results) {
                  scope.model = results;
                });
              }
            });
          }
          scope.clearSearch = function() {
            scope.search.value = '';
            scope.clearData();
          };
        },
        template: '<div class="item-input-wrapper">' +
          '<i class="icon ion-android-search"></i>' +
          '<input type="search" placeholder="{{placeholder}}" ng-model="search.value" id="searchInput">' +
          '<i ng-if="search.value.length > 0" ng-click="clearSearch()" class="icon ion-close"></i>' +
          '</div>'
      };
    })

    .controller('AppCtrl', ['$scope', '$http', function($scope, $http) {
      $scope.UserLogin = UserLogin;
      $scope.UserFolderURL = UserFolderURL;
      $scope.ApplicationBaseURL = ApplicationBaseURL;
      // $scope.logout = function(url) {
      //     $http.get(url)
      //     .success(function(data, status, headers) {
      //         console.debug(headers);
      //     });
      // };
    }])

    .controller('AddressBooksCtrl', ['$scope', '$state', '$rootScope', '$ionicModal', '$ionicListDelegate', '$ionicActionSheet', 'sgDialog', 'sgAddressBook', 'sgUser', function($scope, $state, $rootScope, $ionicModal, $ionicListDelegate, $ionicActionSheet, Dialog, AddressBook, User) {
      // Initialize with data from template
      $scope.addressbooks = AddressBook.$findAll(contactFolders);
      $scope.newAddressbook = function() {
        Dialog.prompt(l('Create addressbook'),
                      l('Name of new addressbook'))
          .then(function(res) {
            if (res && res.length > 0) {
              var addressbook = new AddressBook(
                {
                  name: res,
                  isEditable: true,
                  isRemote: false
                }
              );
              AddressBook.$add(addressbook);
            }
          });
      };
      $scope.edit = function(addressbook) {
        $ionicActionSheet.show({
          buttons: [
            { text: l('Rename') },
            { text: l('Set Access Rights') }
          ],
          destructiveText: l('Delete'),
          cancelText: l('Cancel'),
          buttonClicked: function(index) {
            if (index == 0) {
              // Rename
              Dialog.prompt(l('Rename addressbook'), addressbook.name)
                .then(function(name) {
                  if (name && name.length > 0) {
                    addressbook.$rename(name); // TODO check error
                  }
                });
            }
            else if (index == 1) {
              // Set Access Rights
              $ionicModal.fromTemplateUrl('acl-modal.html', { scope: $scope }).then(function(modal) {
                var aclUsers = {};

                function refreshUsers(users) {
                  $scope.users = [];
                  $scope.search.active = false;
                  angular.forEach(users, function(user) {
                    user.inAclList = true;
                    $scope.users.push(user);
                    aclUsers[user.uid] = user;
                  })
                };

                if ($scope.aclEditorModal) {
                  $scope.aclEditorModal.remove();
                }

                $scope.title = addressbook.name;
                $scope.aclEditorModal = modal;
                $scope.showDelete = false;
                $scope.search = {active: false};

                // Load ACL users
                addressbook.$acl.$users().then(function(users) {
                  refreshUsers(users);
                }, function(data, status) {
                  Dialog.alert(l('Warning'), l('An error occurs while trying to fetch users from the server.'));
                });

                $scope.closeModal = function() {
                  $scope.aclEditorModal.remove();
                };
                $scope.displayIcon = function(user) {
                  if (user.inAclList)
                    return ($scope.userIsSelected(user) ? 'ion-ios7-arrow-down' : 'ion-ios7-arrow-right');
                  else
                    return 'ion-plus';
                }
                $scope.toggleUser = function(user) {
                  if (user.inAclList) {
                    if ($scope.userIsSelected(user)) {
                      // Close rights editor
                      delete $scope.selectedUser;
                    }
                    else {
                      // Edit user rights
                      $scope.editUser(user);
                    }
                  }
                  else {
                    // Add user
                    $scope.addUser(user);
                  }
                };
                $scope.userIsSelected = function(user) {
                  return $scope.selectedUser && $scope.selectedUser.uid == user.uid;
                };
                $scope.searchUsers = function(search) {
                  $scope.users = [];
                  $scope.search.active = true;
                  return User.$filter(search).then(function(results) {
                    angular.forEach(results, function(userFound) {
                      userFound.inAclList = (aclUsers[userFound.uid]) ? true : false;
                      $scope.users.push(userFound);
                    })
                  });
                };
                $scope.cancelSearch = function() {
                  addressbook.$acl.$users().then(function(users) {
                    refreshUsers(users);
                  }, function(data, status) {
                    Dialog.alert(l('Warning'), l('An error occured please try again.'));
                  });
                };
                $scope.toggleDelete = function(boolean) {
                  $scope.showDelete = boolean;
                };
                $scope.editUser = function(user) {
                  if ($scope.selectedUser != user) {
                    $scope.selectedUser = user;
                    $scope.selectedUser.$rights();
                  }
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
                $scope.saveModal = function() {
                  addressbook.$acl.$saveUsersRights().then(function() {
                    $scope.aclEditorModal.remove();
                  }, function(data, status) {
                    Dialog.alert(l('Warning'), l('An error occured please try again.'));
                  });
                };
                $scope.removeUser = function(user) {
                  if (user) {
                    addressbook.$acl.$removeUser(user.uid).then(function() {
                      delete aclUsers[user.uid];
                      delete $scope.selectedUser;
                      $scope.users = _.reject($scope.users, function(o) {
                        return o.uid == user.uid;
                      });
                    }, function(data, status) {
                      Dialog.alert(l('Warning'), l('An error occured please try again.'))
                    });
                  }
                };
                $scope.addUser = function(user) {
                  if (user.uid) {
                    addressbook.$acl.$addUser(user).then(function() {
                      user.inAclList = true;
                      aclUsers[user.uid] = user;
                    }, function(data, status) {
                      Dialog.alert(l('Warning'), l('An error occured please try again.'))
                    });
                  }
                  else {
                    Dialog.alert(l('Warning'), l('Please select a user inside your domain'));
                  }
                };

                // Show modal
                $scope.aclEditorModal.show();
              });
            }
            return true;
          },
          destructiveButtonClicked: function() {
            // Delete addressbook
            addressbook.$delete()
              .then(function() {
                addressbook = null;
              }, function(data) {
                Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                               addressbook.name),
                             l(data.error));
              });
            return true;
          }
          // cancel: function() {
          // },
        });
        $ionicListDelegate.closeOptionButtons();
      };
    }])

    .controller('AddressBookCtrl', ['$scope', '$rootScope', '$stateParams', '$state', '$ionicActionSheet', 'sgAddressBook', 'sgCard', 'stateAddressbook', function($scope, $rootScope, $stateParams, $state, $ionicActionSheet, AddressBook, Card, stateAddressbook) {
      $rootScope.addressbook = stateAddressbook;

      $scope.search = { status: null, filter: null, lastFilter: null };

      $scope.addCard = function() {
        $ionicActionSheet.show({
          //titleText: l('Create a new card or a new list'),
          buttons: [
            { text: l('New Card') },
            { text: l('New List') }
          ],
          canceltext: l('Cancel'),
          buttonClicked: function(index) {
            if (index == 0) {
              $state.go('app.newCard', { addressbookId: stateAddressbook.id, contactType: 'card' });
            }
            else if (index == 1) {
              $state.go('app.newCard', { addressbookId: stateAddressbook.id, contactType: 'list' });
            }
            return true;
          }
        });
      };

      $scope.doSearch = function(keyEvent) {
        if ($scope.search.lastFilter != $scope.search.filter) {
          if ($scope.search.filter.length > 2) {
            $rootScope.addressbook.$filter($scope.search.filter).then(function(data) {
              if (data.length == 0)
                $scope.search.status = 'no-result';
              else
                $scope.search.status = '';
            });
          }
          else if ($scope.search.filter.length == 0) {
            $scope.searchStatus = '';
            $rootScope.addressbook = AddressBook.$find($rootScope.addressbook.id);
          }
          else {
            $scope.search.status = 'min-char';
            $rootScope.addressbook.cards = [];
          }
        }
        $scope.search.lastFilter = $scope.search.filter;
      };
    }])

    .controller('CardCtrl', ['$scope', '$rootScope', '$state', '$stateParams', '$ionicModal', '$ionicPopover', 'sgDialog', 'sgAddressBook', 'sgCard', 'stateCard', function($scope, $rootScope, $state, $stateParams, $ionicModal, $ionicPopover, Dialog, AddressBook, Card, stateCard) {
      $scope.card = stateCard;

      $scope.UserFolderURL = UserFolderURL;
      $scope.allEmailTypes = Card.$EMAIL_TYPES;
      $scope.allTelTypes = Card.$TEL_TYPES;
      $scope.allUrlTypes = Card.$URL_TYPES;
      $scope.allAddressTypes = Card.$ADDRESS_TYPES;

      $scope.search = {query: ''};
      $scope.cardsFilter = function(item) {
        var query, id = false;
        if (item.tag == 'vcard' && $scope.search.query) {
          query = $scope.search.query.toLowerCase();
          if (item.emails && item.emails.length > 0) {
            // Is one of the email addresses match the query string?
            if (_.find(item.emails, function(email) {
              return (email.value.toLowerCase().indexOf(query) >= 0);
            })) {
              id = item.id;
            }
          }
          if (!id && item.fn) {
            // Is the fn attribute matches the query string?
            if (item.fn.toLowerCase().indexOf(query) >= 0) {
              id = item.id;
            }
          }
          if (id) {
            // Is the card already part of the members? If so, ignore it.
            if (_.find($scope.card.refs, function(ref) {
              return ref.reference == id;
            })) {
              id = false;
            }
          }
        }
        return id;
      };
      $scope.resetSearch = function() {
        $scope.search.query = null;
      };
      $scope.addMember = function(member) {
        var i = $scope.card.$addMember(''),
            email = member.$preferredEmail($scope.search.query);
        $scope.card.$updateMember(i, email, member);
        $scope.popover.hide();
      };
      $ionicPopover.fromTemplateUrl('searchFolderContacts.html', {
        scope: $scope
      }).then(function(popover) {
        $scope.popover = popover;
      });

      $scope.edit = function() {
        // Build modal editor
        $ionicModal.fromTemplateUrl('cardEditor.html', {
          scope: $scope,
          focusFirstInput: false
        }).then(function(modal) {
          if ($scope.$cardEditorModal) {
            // Delete previous modal
            $scope.$cardEditorModal.remove();
          }
          $scope.$cardEditorModal = modal;
          // Show modal
          $scope.$cardEditorModal.show();
        });
      };
      $scope.cancel = function() {
        if ($scope.card.isNew) {
          $scope.$cardEditorModal.hide().then(function() {
            // Go back to addressbook
            $state.go('app.addressbook', { addressbookId: $rootScope.addressbook.id });
          });
        }
        else {
          $scope.card.$reset();
          $scope.$cardEditorModal.hide()
        }
      };
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
      $scope.showPopOver = function(keyEvent) {
        $scope.popover.show(keyEvent);
      }
      $scope.save = function(form) {
        if (form.$valid) {
          $scope.card.$save()
            .then(function(data) {
              var i;
              delete $scope.card.isNew;
              i = _.indexOf(_.pluck($rootScope.addressbook.cards, 'id'), $scope.card.id);
              if (i < 0) {
                // New card
                // Reload contacts list and show addressbook in which the card has been created
                $rootScope.addressbook = AddressBook.$find(data.pid);
                $state.go('app.addressbook', { addressbookId: data.pid });
              }
              else {
                // Update contacts list with new version of the Card object
                $rootScope.addressbook.cards[i] = angular.copy($scope.card);
              }
              // Close editor
              $scope.$cardEditorModal.hide();
            });
        }
      };
      $scope.confirmDelete = function(card) {
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the card of <b>%{0}</b>?', card.$fullname()))
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
                  // Delete modal editor
                  $scope.$cardEditorModal.remove();
                  // Go back to addressbook
                  $state.go('app.addressbook', { addressbookId: $rootScope.addressbook.id });
                }, function(data, status) {
                  Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                               card.$fullname()));
                });
            }
          });
      };

      if ($scope.card && $scope.card.isNew) {
        // New contact
        $scope.edit();
      }
    }]);
})();
