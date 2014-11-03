(function() {
  'use strict';

  /**
   * @name Acl
   * @constructor
   * @param {String} folderId - the folder ID associated to the ACLs
   */
  function Acl(folderId) {
    this.folderId = folderId;
  }

  /**
   * @memberof Acl
   * @desc The factory we'll use to register with Angular.
   * @return the Acl constructor
   */
  Acl.factory = ['$q', '$timeout', 'sgSettings', 'sgResource', 'sgUser', function($q, $timeout, Settings, Resource, User) {
    angular.extend(Acl, {
      $q: $q,
      $timeout: $timeout,
      $$resource: new Resource(Settings.baseURL),
      $User: User
    });

    return Acl;
  }];

  /**
   * @module SOGo.Common
   * @desc Factory registration of User in Angular module.
   */
  angular.module('SOGo.Common').factory('sgAcl', Acl.factory);

  /**
   * @function $users
   * @memberof Acl.prototype
   * @desc Fetch the list of users that have specific rights for the current folder.
   * @return a promise of an array of User objects
   */
  Acl.prototype.$users = function() {
    var _this = this,
        deferred = Acl.$q.defer(),
        user;
    if (this.users) {
      deferred.resolve(this.users);
    }
    else {
      return Acl.$$resource.fetch(this.folderId, 'acls').then(function(users) {
        _this.users = [];
        // console.debug(JSON.stringify(users, undefined, 2));
        angular.forEach(users, function(data) {
          user = new Acl.$User(data);
          user.canSubscribeUser = user.isSubscribed;
          user.wasSubscribed = user.isSubscribed;
          user.$rights = angular.bind(user, user.$acl, _this.folderId);
          _this.users.push(user);
        });
        deferred.resolve(_this.users);
        return _this.users;
      });
    }
    return deferred.promise;
  };

  /**
   * @function $addUser
   * @memberof Acl.prototype
   * @param {Object} user - a User object with minimal set of attributes (uid, isGroup, cn, c_email)
   * @see {@link User.$filter}
   */
  Acl.prototype.$addUser = function(user) {
    var _this = this,
        deferred = Acl.$q.defer(),
        param = {uid: user.uid};
    if (!user.uid || _.indexOf(_.pluck(this.users, 'uid'), user.uid) > -1) {
      // No UID specified or user already in ACLs
      deferred.resolve();
    }
    else {
      Acl.$$resource.fetch(this.folderId, 'addUserInAcls', param).then(function() {
        user.wasSubscribed = false;
        user.userClass = user.isGroup ? 'group-user' : 'normal-user';
        user.$rights = angular.bind(user, user.$acl, _this.folderId);
        _this.users.push(user);
        deferred.resolve(_this.users);
      }, function(data, status) {
        deferred.reject(l('An error occured please try again.'));
      });
    }
    return deferred.promise;
  };

  /**
   * @function $removeUser
   * @memberof Acl.prototype
   * @desc Remove a user from the folder's ACL
   * @return a promise of the server call to remove the user from the folder's ACL
   */
  Acl.prototype.$removeUser = function(uid) {
    var _this = this,
        param = {uid: uid};
    return Acl.$$resource.fetch(this.folderId, 'removeUserFromAcls', param).then(function() {
      var i = _.indexOf(_.pluck(_this.users, 'uid'), uid);
      if (i >= 0) {
        _this.users.splice(i, 1);
      }
    });
  };

  /**
   * @function $resetUsersRights
   * @memberof Acl.prototype
   * @desc Restore initial rights of all users.
   */
  Acl.prototype.$resetUsersRights = function() {
    angular.forEach(this.users, function(user) {
      user.$resetRights();
    });
  };

  /**
   * @function $saveUsersRights
   * @memberof Acl.prototype
   * @desc Save user rights that have changed and subscribe users that have been selected.
   * @return a promise that resolved only if the modifications and subscriptions were successful
   */
  Acl.prototype.$saveUsersRights = function() {
    var _this = this,
        deferredSave = Acl.$q.defer(),
        deferredSubscribe = Acl.$q.defer(),
        param = {action: 'saveUserRights'},
        users = [];

    // Save user rights
    angular.forEach(this.users, function(user) {
      if (user.$rightsAreDirty()) {
        users.push(user.$omit());
        // console.debug('save ' + JSON.stringify(user.$omit(), undefined, 2));
      }
    });
    if (users.length) {
      Acl.$$resource.save(this.folderId, users, param)
        .then(function() {
          // Save was successful; copy rights to shadow rights
          angular.forEach(_this.users, function(user) {
            if (user.$rightsAreDirty()) {
              user.$shadowRights = angular.copy(user.rights);
            }
          });
          deferredSave.resolve();
        }, deferredSave.reject);
    }
    else {
      deferredSave.resolve();
    }

    // Subscribe users
    users = [];
    angular.forEach(this.users, function(user) {
      if (!user.wasSubscribed && user.isSubscribed) {
        users.push(user.uid);
        // console.debug('subscribe ' + user.uid);
      };
    });
    if (users.length) {
      param = {uids: users.join(',')};
      Acl.$$resource.fetch(this.folderId, 'subscribeUsers', param)
        .then(function() {
          // Subscribe was successful; reset "wasSubscribed" attribute
          angular.forEach(_this.users, function(user) {
            user.wasSubscribed = user.isSubscribed;
          });
          deferredSubscribe.resolve();
        }, deferredSubscribe.reject);
    }
    else {
      deferredSubscribe.resolve();
    }
    return Acl.$q.all([deferredSave.promise, deferredSubscribe.promise]);
  };

})();
