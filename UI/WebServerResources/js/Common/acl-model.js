(function() {
  'use strict';

  function AclUsers(addressbook) {  
    this.addressbook_id = addressbook.id;  
    this.addressbook_name = addressbook.name;
    this.addressbook_owner = addressbook.owner;
  }

  /* The factory we'll use to register with Angular */
  AclUsers.factory = ['$q', '$timeout', 'sgSettings', 'sgResource', function($q, $timeout, Settings, Resource) {
    angular.extend(AclUsers, {
      $q: $q,
      $timeout: $timeout,
      $$resource: new Resource(Settings.baseURL)
    });

    return AclUsers; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.Common').factory('sgAclUsers', AclUsers.factory);

  /* Instance methods
   * Public method, assigned to prototype      
   */
  AclUsers.prototype.getUsers = function() {
    return AclUsers.$$resource.fetch(this.addressbook_id, "getUsersForObject");
  };

  AclUsers.prototype.searchUsers = function(inputText) {
    var param = "search=" + inputText;
    return AclUsers.$$resource.fetch(null, "usersSearch", param);
  };
   
  AclUsers.prototype.openRightsForUserId = function(user) {
    var param = "uid=" + user;
    return AclUsers.$$resource.fetch(this.addressbook_id, "userRights", param);
  };

  AclUsers.prototype.addUser = function(user) {
    var param = "uid=" + user;
    AclUsers.$$resource.fetch(this.addressbook_id, "addUserInAcls", param);
  };

  AclUsers.prototype.subscribeUsers = function(users) {
    var param = "uids=" + users;
    AclUsers.$$resource.fetch(this.addressbook_id, "subscribeUsers", param);
  };

  AclUsers.prototype.removeUser = function(user) {
    var userId = "uid=" + user.uid;
    AclUsers.$$resource.fetch(this.addressbook_id, "removeUserFromAcls", userId);
  };

  AclUsers.prototype.saveUsersRights = function(dirtyObjects) {
    AclUsers.$$resource.saveAclUsers(this.addressbook_id, "saveUserRights", dirtyObjects);
  };
})();