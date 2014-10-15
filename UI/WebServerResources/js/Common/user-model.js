(function() {
  'use strict';

  function User(folder) {
  	this.folder_id = folder.id;
  }

  /* The factory we'll use to register with Angular */
  User.factory = ['$q', '$timeout', 'sgSettings', 'sgResource', function($q, $timeout, Settings, Resource) {
    angular.extend(User, {
      $q: $q,
      $timeout: $timeout,
      $$resource: new Resource(Settings.baseURL)
    });

    return User; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.Common').factory('sgUser', User.factory);

  /* Instance methods
   * Public method, assigned to prototype      
   */
  User.prototype.$filter = function(search) {
  	// return a collections of users for a filter
  	var param = {"search": search};
  	return User.$$resource.fetch(null, "usersSearch", param).then(function(results) {
      return results;
    })
  };
  User.prototype.$acls = function(){
  	// return a collections of aclUsers for a folder(addressbook/mailboxe/calendar)
  	return User.$$resource.fetch(this.folder_id, "acls");
  };
})();