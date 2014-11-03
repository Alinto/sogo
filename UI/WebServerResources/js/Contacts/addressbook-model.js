/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name AddressBook
   * @constructor
   * @param {object} futureAddressBookData
   */
  function AddressBook(futureAddressBookData) {
    // Data is immediately available
    if (typeof futureAddressBookData.then !== 'function') {
      angular.extend(this, futureAddressBookData);
      if (this.name && !this.id) {
        // Create a new addressbook on the server
        var newAddressBookData = AddressBook.$$resource.create('createFolder', this.name);
        this.$unwrap(newAddressBookData);
      }
      else if (this.id) {
        this.$acl = new AddressBook.$$Acl(this.id);
      }
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureAddressBookData);
    }
  }

  /**
   * @memberof AddressBook
   * @desc The factory we'll use to register with Angular
   * @returns the AddressBook constructor
   */
  AddressBook.$factory = ['$q', '$timeout', 'sgSettings', 'sgResource', 'sgCard', 'sgAcl', function($q, $timeout, Settings, Resource, Card, Acl) {
    angular.extend(AddressBook, {
      $q: $q,
      $timeout: $timeout,
      $$resource: new Resource(Settings.baseURL),
      $Card: Card,
      $$Acl: Acl,
      activeUser: Settings.activeUser
    });

    return AddressBook; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.ContactsUI')
    .factory('sgAddressBook', AddressBook.$factory);

  /**
   * @memberof AddressBook
   * @desc Add a new addressbook to the static list of addressbooks
   * @param {AddressBook} addressbook - an Addressbook object instance
   */
  AddressBook.$add = function(addressbook) {
    // Insert new addressbook at proper index
    var sibling, i;

    sibling = _.find(this.$addressbooks, function(o) {
      return (o.isRemote || (o.id != 'personal' && o.name.localeCompare(addressbook.name) === 1));
    });
    i = sibling ? _.indexOf(_.pluck(this.$addressbooks, 'id'), sibling.id) : 1;
    this.$addressbooks.splice(i, 0, addressbook);
  };

  /**
   * @memberof AddressBook
   * @desc Set or get the list of addressbooks. Will instanciate a new AddressBook object for each item.
   * @param {array} [data] - the metadata of the addressbooks
   * @returns the list of addressbooks
   */
  AddressBook.$findAll = function(data) {
    var _this = this;
    if (data) {
      this.$addressbooks = data;
      // Instanciate AddressBook objects
      angular.forEach(this.$addressbooks, function(o, i) {
        _this.$addressbooks[i] = new AddressBook(o);
        // Add 'isOwned' attribute based on active user (TODO: add it server-side?)
        _this.$addressbooks[i].isOwned = _this.activeUser.isSuperUser
          || _this.$addressbooks[i].owner == _this.activeUser.login;
      });
    }
    return this.$addressbooks;
  };

  /**
   * @memberOf AddressBook
   * @desc Fetch list of cards and return an AddressBook instance
   * @param {string} addressbookId - the addressbook identifier
   * @returns an AddressBook object instance
   */
  AddressBook.$find = function(addressbookId) {
    var futureAddressBookData = AddressBook.$$resource.fetch(addressbookId, 'view');

    return new AddressBook(futureAddressBookData);
  };

  /* Instance methods */

  AddressBook.prototype.$id = function() {
    return this.$futureAddressBookData.then(function(data) {
      return data.id;
    });
  };

  /**
   * @function $filter
   * @memberof AddressBook.prototype
   * @desc Search for cards matching some criterias
   * @param {string} search - the search string to match
   * @param {hash} [options] - additional options to the query
   * @returns a collection of Cards instances
   */
  AddressBook.prototype.$filter = function(search, options) {
    var _this = this,
        params = {
          search: 'name_or_address',
          value: search,
          sort: 'c_cn',
          asc: 'true'
        };
    if (options && options.excludeLists) {
      params.excludeLists = true;
    }

    return this.$id().then(function(addressbookId) {
      var futureAddressBookData = AddressBook.$$resource.fetch(addressbookId, 'view', params);
      return futureAddressBookData.then(function(data) {
        var cards;
        if (options && options.dry) {
          // Don't keep a copy of the resulting cards.
          // This is usefull when doing autocompletion.
          cards = data.cards;
        }
        else {
          _this.cards = data.cards;
          cards = _this.cards;
        }
        // Instanciate Card objects
        angular.forEach(cards, function(o, i) {
          cards[i] = new AddressBook.$Card(o);
        });

        return cards;
      });
    });
  };

  /**
   * @function $rename
   * @memberof AddressBook.prototype
   * @desc Rename the addressbook
   * @param {string} name - the new name
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$rename = function(name) {
    var i = _.indexOf(_.pluck(AddressBook.$addressbooks, 'id'), this.id);
    this.name = name;
    AddressBook.$addressbooks.splice(i, 1);
    AddressBook.$add(this);
    return this.$save();
  };

  AddressBook.prototype.$delete = function() {
    var _this = this,
        d = AddressBook.$q.defer();
    AddressBook.$$resource.remove(this.id)
      .then(function() {
        var i = _.indexOf(_.pluck(AddressBook.$addressbooks, 'id'), _this.id);
        AddressBook.$addressbooks.splice(i, 1);
        d.resolve(true);
      }, function(data, status) {
        d.reject(data);
      });
    return d.promise;
  };

  AddressBook.prototype.$save = function() {
    return AddressBook.$$resource.save(this.id, this.$omit()).then(function(data) {
      return data;
    });
  };

  AddressBook.prototype.$getCard = function(cardId) {
    return this.$id().then(function(addressbookId) {
      return AddressBook.$Card.$find(addressbookId, cardId);
    });
  };

  // Unwrap a promise
  AddressBook.prototype.$unwrap = function(futureAddressBookData) {
    var _this = this;

    // Expose the promise
    this.$futureAddressBookData = futureAddressBookData;
    // Resolve the promise
    this.$futureAddressBookData.then(function(data) {
      AddressBook.$timeout(function() {
        angular.extend(_this, data);
        // Also extend AddressBook instance from data of addressbooks list.
        // Will inherit attributes such as isEditable and isRemote.
        angular.forEach(AddressBook.$findAll(), function(o, i) {
          if (o.id == _this.id) {
            angular.extend(_this, o);
          }
        });
        // Instanciate Card objects
        angular.forEach(_this.cards, function(o, i) {
          _this.cards[i] = new AddressBook.$Card(o);
        });
        // Instanciate Acl object
        _this.$acl = new AddressBook.$$Acl(_this.id);
      });
    }, function(data) {
      AddressBook.$timeout(function() {
        angular.extend(_this, data);
        _this.isError = true;
      });
    });
  };

  // $omit returns a sanitized object used to send to the server
  AddressBook.prototype.$omit = function() {
    var addressbook = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          key != 'cards' &&
          key[0] != '$') {
        addressbook[key] = value;
      }
    });
    return addressbook;
  };
})();
