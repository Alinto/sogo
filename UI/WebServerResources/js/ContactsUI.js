/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts */

(function() {
    'use strict';

angular.module('SOGo').config(['$routeProvider', function($routeProvider) {
    $routeProvider
        .when('/:addressbook_id', {
            controller: 'contactDisplayController',
            templateUrl: 'rightPanel.html'
        })
        .when('/:addressbook_id/:contact_id', {
            controller: 'contactDisplayController',
            templateUrl: 'rightPanel.html'
        })
        .otherwise({
            redirectTo: '/personal'
        });
}]);

angular.module('SOGo').directive('sgFocusOn', function() {
   return function(scope, elem, attr) {
      scope.$on('sgFocusOn', function(e, name) {
        if (name === attr.sgFocusOn) {
          elem[0].focus();
        }
      });
   };
});

angular.module('SOGo').factory('sgFocus', ['$rootScope', '$timeout', function ($rootScope, $timeout) {
  return function(name) {
    $timeout(function (){
      $rootScope.$broadcast('sgFocusOn', name);
    });
  }
}]);

// angular.module('SOGo').provider('Contact', function() {
//     var folders = contactFolders;
//     var selectedIndex;
//     this.$get = [function() {
//         var self = this;
//         var service = {
//             getFoldersList: function() {
//                 return folders
//             },
//             selectFolder: function(index) {
//                 selectedIndex = index;
//             },
//             currentFolder: function() {
//                 return selectedIndex;
//             }
//         };
//         return service;
//     }];
// });

// angular.module('SOGo').controller('addressbookSharingModal', ['$scope', '$rootScope', '$modal', function($scope, $rootScope, $modal) {

// }]);

angular.module('SOGo').controller('addressbooksList', ['$scope', '$rootScope', '$timeout', '$modal', 'sgFocus', 'sgContact', 'sgAddressBook', function($scope, $rootScope, $timeout, $modal, focus, Contact, AddressBook) {
    // Initialize with data from template
    // $rootScope.addressbooks = new Array();
    // angular.forEach(contactFolders, function(folder, index) {
    //     $rootScope.addressbooks.push(new AddressBook(folder));
    // //     contactFolders[index].$omit();
    // });
    //$scope.contactFolders = contactFolders;
    $rootScope.addressbooks = contactFolders;
    $scope.select = function(rowIndex) {
        //$rootScope.selectedAddressBook = $scope.contactFolders[rowIndex];
        $scope.editMode = false;
    };
    // $rootScope.$on('AddressBook:selected', function(event, id) {
    //     $rootScope.selectedAddressBook = id;
    // });
    $scope.rename = function() {
        console.debug("rename folder");
        $scope.editMode = $rootScope.addressbook.id;
        focus('folderName');
    };
    $scope.save = function() {
        console.debug("save addressbook");
        $rootScope.addressbook.$save()
            .then(function(data) {
                console.debug("saved!");
                $scope.editMode = false;
            }, function(data, status) {
                console.debug("failed");
            });
    };
    $scope.sharing = function() {
        var modal = $modal.open({
            templateUrl: 'addressbookSharing.html',
            //controller: 'addressbookSharingCtrl'
            controller: function($scope, $modalInstance) {
                $scope.closeModal = function() {
                    console.debug('please close it');
                    $modalInstance.close();
                };
            }
        });
        // modal.result.then(function() {
        //     console.debug('close');
        // }, function() {
        //     console.debug('dismiss');
        // });    
    };
    // $scope.rename = function(rowIndex) {
    //     var folder = $scope.contactFolders[rowIndex];
    //     if (folder.owner != "nobody") {
    //         showPromptDialog(l("Properties"),
    //                          l("Address Book Name"),
    //                          onAddressBookModifyConfirm,
    //                          folder.name);
    //     }
    // };
}]);

// angular.module('SOGo').controller('addressbookSharingCtrl', ['$scope', '$modalInstance', function($scope, modal) {
//     $scope.closeModal = function() {
//         console.debug('please close it');
//         modal.close();
//     };
// }]);


angular.module('SOGo').controller('contactDisplayController', ['$scope', '$rootScope', 'sgAddressBook', 'sgContact', 'sgFocus', '$routeParams', function($scope, $rootScope, AddressBook, Contact, focus, $routeParams) {
    if ($routeParams.addressbook_id &&
        ($rootScope.addressbook == undefined || $routeParams.addressbook_id != $rootScope.addressbook.id)) {
        // Selected addressbook has changed
        console.debug("show addressbook " + $routeParams.addressbook_id);
        $rootScope.addressbook = AddressBook.$find($routeParams.addressbook_id);
        // Extend resulting model instance with parameters from addressbooks listing
        angular.forEach($rootScope.addressbooks, function(o, i) {
            if (o.id ==  $routeParams.addressbook_id) {
                angular.extend($rootScope.addressbook, o);
                $rootScope.addressbooks[i] = $rootScope.addressbook;
            }
        });
        angular.extend($rootScope.addressbook, $rootScope.selectedAddressBook);
    }

    if ($routeParams.contact_id) {
        console.debug("show contact " + $routeParams.contact_id);
        $rootScope.addressbook.$getContact($routeParams.contact_id);
        $scope.editMode = false;
    }
    $scope.allEmailTypes = Contact.$email_types;
    $scope.allTelTypes = Contact.$tel_types;
    $scope.allUrlTypes = Contact.$url_types;
    $scope.allAddressTypes = Contact.$address_types;
    // $scope.select = function(cname) {
    //     console.debug('show contact ' + cname);
    // };
    $scope.edit = function() {
        $rootScope.master_contact = angular.copy($rootScope.addressbook.contact);
        $scope.editMode = true;
        console.debug('edit');
    };
    $scope.addOrgUnit = function() {
        var i = $rootScope.addressbook.contact.$addOrgUnit('');
        focus('orgUnit_' + i);
    };
    $scope.addCategory = function() {
        var i = $rootScope.addressbook.contact.$addCategory($scope.new_category);
        focus('category_' + i);
    };
    $scope.addEmail = function() {
        var i = $rootScope.addressbook.contact.$addEmail($scope.new_email_type);
        focus('email_' + i);
    };
    $scope.addPhone = function() {
        var i = $rootScope.addressbook.contact.$addPhone($scope.new_phone_type);
        focus('phone_' + i);
    };
    $scope.addUrl = function() {
        var i = $rootScope.addressbook.contact.$addUrl('', '');
        focus('url_' + i);
    };
    $scope.addAddress = function() {
        var i = $rootScope.addressbook.contact.$addAddress('', '', '', '', '', '', '', '');
        focus('address_' + i);
    };
    $scope.save = function(contactForm) {
        console.debug("save");
        if (contactForm.$valid) {
            $rootScope.addressbook.contact.$save()
                .then(function(data) {
                    console.debug("saved!");
                    $scope.editMode = false;
                }, function(data, status) {
                    console.debug("failed");
                });
        }
    };
    $scope.cancel = function() {
        $scope.reset();
        $scope.editMode = false;
    };
    $scope.reset = function() {
        $rootScope.addressbook.contact = angular.copy($rootScope.master_contact);
    };
}]);

})();
