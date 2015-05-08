/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name AddressBook
   * @constructor
   * @param {object} futureAddressBookData - either an object literal or a promise
   */
  function AddressBook(futureAddressBookData) {
    // Data is immediately available
    if (typeof futureAddressBookData.then !== 'function') {
      this.init(futureAddressBookData);
      if (this.name && !this.id) {
        // Create a new addressbook on the server
        var newAddressBookData = AddressBook.$$resource.create('createFolder', this.name);
        this.$unwrap(newAddressBookData);
      }
      else if (this.id) {
        this.$acl = new AddressBook.$$Acl('Contacts/' + this.id);
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
  AddressBook.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Card', 'Acl', function($q, $timeout, $log, Settings, Resource, Card, Acl) {
    angular.extend(AddressBook, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL + 'Contacts', Settings.activeUser),
      $Card: Card,
      $$Acl: Acl,
      activeUser: Settings.activeUser
    });

    return AddressBook; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.ContactsUI')
    .factory('AddressBook', AddressBook.$factory);

  /**
   * @memberof AddressBook
   * @desc Search for cards among all addressbooks matching some criterias.
   * @param {string} search - the search string to match
   * @param {object} [options] - additional options to the query (excludeGroups and excludeLists)
   * @returns a collection of Cards instances
   */
  AddressBook.$filterAll = function(search, options) {
    var params = {search: search};

    angular.extend(params, options);
    return AddressBook.$$resource.fetch(null, 'allContactSearch', params).then(function(response) {
      var results = [];
      angular.forEach(response.contacts, function(data) {
        var card = new AddressBook.$Card(data);
        results.push(card);
      });
      return results;
    });
  };

  /**
   * @memberof AddressBook
   * @desc Add a new addressbook to the static list of addressbooks
   * @param {AddressBook} addressbook - an Addressbook object instance
   */
  AddressBook.$add = function(addressbook) {
    // Insert new addressbook at proper index
    var list, sibling, i;

    list = addressbook.isSubscription? this.$subscriptions : this.$addressbooks;
    sibling = _.find(list, function(o) {
      return (addressbook.id == 'personal'
              || (o.id != 'personal'
                  && o.name.localeCompare(addressbook.name) === 1));
    });
    i = sibling ? _.indexOf(_.pluck(list, 'id'), sibling.id) : 1;
    list.splice(i, 0, addressbook);
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
      this.$addressbooks = [];
      this.$subscriptions = [];
      this.$remotes = [];
      // Instanciate AddressBook objects
      angular.forEach(data, function(o, i) {
        var addressbook = new AddressBook(o);
        if (addressbook.isRemote)
          _this.$remotes.push(addressbook);
        else if (addressbook.isSubscription)
          _this.$subscriptions.push(addressbook);
        else
          _this.$addressbooks.push(addressbook);
      });
    }
    return this.$addressbooks;
  };

  /**
   * @memberOf AddressBook
   * @desc Fetch list of cards and return an AddressBook instance.
   * @param {string} addressbookId - the addressbook identifier
   * @returns an AddressBook object instance
   */
  AddressBook.$find = function(addressbookId) {
    var futureAddressBookData = AddressBook.$$resource.fetch(addressbookId, 'view');

    return new AddressBook(futureAddressBookData);
  };

  /**
   * @memberOf AddressBook
   * @desc Subscribe to another user's addressbook and add it to the list of addressbooks.
   * @param {string} uid - user id
   * @param {string} path - path of folder for specified user
   * @returns a promise of the HTTP query result
   */
  AddressBook.$subscribe = function(uid, path) {
    var _this = this;
    return AddressBook.$$resource.userResource(uid).fetch(path, 'subscribe').then(function(addressbookData) {
      var addressbook = new AddressBook(addressbookData);
      if (!_.find(_this.$subscriptions, function(o) {
        return o.id == addressbookData.id;
      })) {
        // Not already subscribed
        AddressBook.$add(addressbook);
      }
      return addressbook;
    });
  };

  /**
   * @function init
   * @memberof AddressBook.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of addressbook
   */
  AddressBook.prototype.init = function(data) {
    angular.extend(this, data);
    // Add 'isOwned' and 'isSubscription' attributes based on active user (TODO: add it server-side?)
    this.isOwned = AddressBook.activeUser.isSuperUser || this.owner == AddressBook.activeUser.login;
    this.isSubscription = !this.isRemote && this.owner != AddressBook.activeUser.login;
    this.$query = undefined;
  };

  /**
   * @function $id
   * @memberof AddressBook.prototype
   * @desc Resolve the addressbook id.
   * @returns a promise of the addressbook id
   */
  AddressBook.prototype.$id = function() {
    return this.$futureAddressBookData.then(function(data) {
      return data.id;
    });
  };

  /**
   * @function $selectedCount
   * @memberof AddressBook.prototype
   * @desc Return the number of cards selected by the user.
   * @returns the number of selected cards
   */
  AddressBook.prototype.$selectedCount = function() {
    var count;

    count = 0;
    if (this.cards) {
      count = (_.filter(this.cards, function(card) { return card.selected })).length;
    }
    return count;
  };

  /**
   * @function $filter
   * @memberof AddressBook.prototype
   * @desc Search for cards matching some criterias
   * @param {string} search - the search string to match
   * @param {object} [options] - additional options to the query
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
    if (options)
      angular.extend(params, options);

    return this.$id().then(function(addressbookId) {
      var futureAddressBookData = AddressBook.$$resource.fetch(addressbookId, 'view', params);
      return futureAddressBookData.then(function(data) {
        var cards;
        _this.$query = search;
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
          cards[i] = new AddressBook.$Card(o, search);
        });

        return cards;
      });
    });
  };

  /**
   * @function $rename
   * @memberof AddressBook.prototype
   * @desc Rename the addressbook and keep the list sorted
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

  /**
   * @function $delete
   * @memberof AddressBook.prototype
   * @desc Delete the addressbook from the server and the static list of addressbooks.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$delete = function() {
    var _this = this,
        d = AddressBook.$q.defer(),
        list,
        promise;

    if (this.isSubscription) {
      promise = AddressBook.$$resource.fetch(this.id, 'unsubscribe');
      list = AddressBook.$subscriptions;
    }
    else {
      promise = AddressBook.$$resource.remove(this.id);
      list = AddressBook.$addressbooks;
    }

    promise.then(function() {
      var i = _.indexOf(_.pluck(list, 'id'), _this.id);
      list.splice(i, 1);
      d.resolve();
    }, function(data, status) {
      d.reject(data);
    });
    return d.promise;
  };

  /**
   * @function $deleteCards
   * @memberof AddressBook.prototype
   * @desc Delete multiple cards from addressbook.
   * @return a promise of the HTTP operation
   */
  AddressBook.prototype.$deleteCards = function(cards) {

    var uids = _.map(cards, function(card) { return card.id });
    var _this = this;
    
    return AddressBook.$$resource.post(this.id, 'batchDelete', {uids: uids}).then(function() {
      _this.cards = _.difference(_this.cards, cards);
    });
  };

  /**
   * @function $save
   * @memberof AddressBook.prototype
   * @desc Save the addressbook to the server. This currently can only affect the name of the addressbook.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$save = function() {
    return AddressBook.$$resource.save(this.id, this.$omit()).then(function(data) {
      return data;
    });
  };

  /**
   * @function $getCard
   * @memberof AddressBook.prototype
   * @desc Fetch the card attributes from the server.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$getCard = function(cardId) {
    return this.$id().then(function(addressbookId) {
      return AddressBook.$Card.$find(addressbookId, cardId);
    });
  };

  /**
   * @function $unwrap
   * @memberof AddressBook.prototype
   * @desc Unwrap a promise and instanciate new Card objects using received data.
   * @param {promise} futureAddressBookData - a promise of the AddressBook's data
   */
  AddressBook.prototype.$unwrap = function(futureAddressBookData) {
    var _this = this;

    // Expose the promise
    this.$futureAddressBookData = futureAddressBookData;
    // Resolve the promise
    this.$futureAddressBookData.then(function(data) {
      AddressBook.$timeout(function() {
        _this.init(data);
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
        _this.$acl = new AddressBook.$$Acl('Contacts/' + _this.id);
      });
    }, function(data) {
      _this.isError = true;
      if (angular.isObject(data)) {
        AddressBook.$timeout(function() {
          angular.extend(_this, data);
        });
      }
    });
  };

  /**
   * @function $omit
   * @memberof AddressBook.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Addressbook instance
   */
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
