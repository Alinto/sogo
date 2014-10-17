(function() {
  'use strict';

  function Acl(folder_id) {
    this.folder_id = folder_id;
  }

  /* The factory we'll use to register with Angular */
  Acl.factory = ['sgSettings', 'sgResource', function(Settings, Resource) {
    angular.extend(Acl, {
      $$resource: new Resource(Settings.baseURL)
    });

    return Acl; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.Common').factory('sgAcl', Acl.factory);

  /* Instance methods
   * Public method, assigned to prototype      
   */
  Acl.prototype.$userRights = function(uid) {
    var param = {"uid": uid};
    return Acl.$$resource.fetch(this.folder_id, "userRights", param);
  };

  Acl.prototype.$addUser = function(uid) {
    var param = {"uid": uid};
    Acl.$$resource.fetch(this.folder_id, "addUserInAcls", param);
  };

  Acl.prototype.$removeUser = function(uid) {
    var param = {"uid": uid};
    Acl.$$resource.fetch(this.folder_id, "removeUserFromAcls", param);
  };

  Acl.prototype.$saveUsersRights = function(dirtyObjects) {
    var param = {"action": "saveUserRights"};
    Acl.$$resource.save(this.folder_id, dirtyObjects, param);
  };

  Acl.prototype.$subscribeUsers = function(uids) {
    var param = {"uids": uids};
    Acl.$$resource.fetch(this.folder_id, "subscribeUsers", param);
  };

  Acl.prototype.$users = function() {
    return Acl.$$resource.fetch(this.folder_id, "acls");
  };
})();