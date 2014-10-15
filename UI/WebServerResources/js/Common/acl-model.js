(function() {
  'use strict';

  function AclUsers(folder) {  
    this.folder_id = folder.id;  
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
  AclUsers.prototype.userRights = function(uid) {
    var param = {"uid": uid};
    return AclUsers.$$resource.fetch(this.folder_id, "userRights", param);
  };

  AclUsers.prototype.addUser = function(uid) {
    var param = {"uid": uid};
    AclUsers.$$resource.fetch(this.folder_id, "addUserInAcls", param);
  };

  AclUsers.prototype.removeUser = function(uid) {
    var param = {"uid": uid};
    AclUsers.$$resource.fetch(this.folder_id, "removeUserFromAcls", param);
  };

  AclUsers.prototype.saveUsersRights = function(dirtyObjects) {
    var param = {"action": "saveUserRights"};
    AclUsers.$$resource.save(this.folder_id, dirtyObjects, param);
  };

  AclUsers.prototype.subscribeUsers = function(uids) {
    var param = {"uids": uids};
    AclUsers.$$resource.fetch(this.folder_id, "subscribeUsers", param);
  };

})();