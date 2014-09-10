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
        }
        else {
            // The promise will be unwrapped first
            this.$unwrap(futureAddressBookData);
        }
    }

    /* The factory we'll use to register with Angular */
    AddressBook.$factory = ['$q', '$timeout', 'sgSettings', 'sgResource', 'sgCard', function($q, $timeout, Settings, Resource, Card) {
        angular.extend(AddressBook, {
            $q: $q,
            $timeout: $timeout,
            $$resource: new Resource(Settings.baseURL),
            $Card: Card
        });

        return AddressBook; // return constructor
    }];

    /* Factory registration in Angular module */
    angular.module('SOGo.ContactsUI').factory('sgAddressBook', AddressBook.$factory);

    /**
     * @memberof AddressBook
     * @desc Set or get the list of addressbooks. Will instanciate a new AddressBook object for each item.
     * @param {array} [data] - the metadata of the addressbooks
     * @returns the list of addressbooks
     */
    AddressBook.$all = function(data) {
        var self = this;
        if (data) {
            this.$addressbooks = data;
            // Instanciate AddressBook objects
            angular.forEach(this.$addressbooks, function(o, i) {
                self.$addressbooks[i] = new AddressBook(o);
            });
        }
        return this.$addressbooks;
    };

    /**
     * @memberof AddressBook
     * @desc Add a new addressbook to the static list of addressbooks
     * @param {AddressBook} addressbook - an Addressbook object instance
     */
    AddressBook.$add = function(addressbook) {
        // Insert new addressbook at proper index
        var sibling = _.find(this.$addressbooks, function(o) {
            return (o.isRemote || (o.id != 'personal' && o.name.localeCompare(addressbook.name) === 1));
        });
        var i = sibling? _.indexOf(_.pluck(this.$addressbooks, 'id'), sibling.id) : 1;
        this.$addressbooks.splice(i, 0, addressbook);
    };

    /* Fetch list of cards and return an AddressBook instance */
    AddressBook.$find = function(addressbook_id) {
        var futureAddressBookData = AddressBook.$$resource.find(addressbook_id);

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
        var self = this;
        var params = { 'search': 'name_or_address',
                       'value': search,
                       'sort': 'c_cn',
                       'asc': 'true' };
        if (options && options.excludeLists) {
            params.excludeLists = true;
        }

        return this.$id().then(function(addressbook_id) {
            var futureAddressBookData = AddressBook.$$resource.filter(addressbook_id, params);
            return futureAddressBookData.then(function(data) {
                var cards;
                if (options && options.dry) {
                    // Don't keep a copy of the resulting cards.
                    // This is usefull when doing autocompletion.
                    cards = data.cards;
                }
                else {
                    self.cards = data.cards;
                    cards = self.cards;
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
        var self = this;
        var d = AddressBook.$q.defer();
        AddressBook.$$resource.remove(this.id)
            .then(function() {
                var i = _.indexOf(_.pluck(AddressBook.$addressbooks, 'id'), self.id);
                AddressBook.$addressbooks.splice(i, 1);
                d.resolve(true);
            }, function(data, status) {
                d.reject(data);
            });
        return d.promise;
    };

    AddressBook.prototype.$save = function() {
        return AddressBook.$$resource.save(this.id, this.$omit()).then(function (data) {
            return data;
        });
    };

    AddressBook.prototype.$getCard = function(card_id) {
        var self = this;
        return this.$id().then(function(addressbook_id) {
            self.card = AddressBook.$Card.$find(addressbook_id, card_id);
            return self.card;
        });
    };

    AddressBook.prototype.$resetCard = function() {
        this.$getCard(this.card.id);
    };

    AddressBook.prototype.$viewerIsActive = function(editMode) {
        return (this.card != null && !editMode);
    };

    // Unwrap a promise
    AddressBook.prototype.$unwrap = function(futureAddressBookData) {
        var self = this;

        this.$futureAddressBookData = futureAddressBookData;
        this.$futureAddressBookData.then(function(data) {
            AddressBook.$timeout(function() {
                angular.extend(self, data);
                // Also extend AddressBook instance from data of addressbooks list.
                // Will inherit attributes such as isEditable and isRemote.
                angular.forEach(AddressBook.$all(), function(o, i) {
                    if (o.id == self.id) {
                        angular.extend(self, o);
                    }
                });
                // Instanciate Card objects
                angular.forEach(self.cards, function(o, i) {
                    self.cards[i] = new AddressBook.$Card(o);
                });
            });
        }, function(data) {
            angular.extend(self, data);
            self.isError = true;
        });
    };

    // $omit returns a sanitized object used to send to the server
    AddressBook.prototype.$omit = function() {
        var addressbook = {};
        angular.forEach(this, function(value, key) {
            if (key != 'constructor' &&
                key != 'card' &&
                key != 'cards' &&
                key[0] != '$') {
                addressbook[key] = value;
            }
        });
        return addressbook;
    };
})();
