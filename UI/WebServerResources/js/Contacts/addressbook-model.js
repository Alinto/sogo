(function() {
    'use strict';

    /* Constructor */
    function AddressBook(futureAddressBookData) {
        // Data is immediately available
        if (typeof futureAddressBookData.then !== 'function') {
            angular.extend(this, futureAddressBookData);
            return;
        }

        // The promise will be unwrapped first
        this.$unwrap(futureAddressBookData);
    }

    /* The factory we'll use to register with Angular */
    AddressBook.$factory = ['$timeout', 'sgSettings', 'sgResource', 'sgCard', function($timeout, Settings, Resource, Card) {
        angular.extend(AddressBook, {
            $$resource: new Resource(Settings.baseURL),
            $timeout: $timeout,
            $Card: Card
        });

        return AddressBook; // return constructor
    }];

    /* Factory registration in Angular module */
    angular.module('SOGo.Contacts').factory('sgAddressBook', AddressBook.$factory);

    /* Set or get the list of addressbooks */
    AddressBook.$all = function(data) {
        if (data) {
            this.$addressbooks = data;
        }
        return this.$addressbooks;
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

    AddressBook.prototype.$filter = function(search) {
        var self = this;
        var params = { 'search': 'name_or_address',
                       'value': search,
                       'sort': 'c_cn',
                       'asc': 'true' };

        return this.$id().then(function(addressbook_id) {
            var futureAddressBookData = AddressBook.$$resource.filter(addressbook_id, params);
            return futureAddressBookData.then(function(data) {
                self.cards = data.cards;
                // Instanciate Card objects
                angular.forEach(self.cards, function(o, i) {
                    self.cards[i] = new AddressBook.$Card(o);
                });
                return self.cards;
            });
        });
    };

    AddressBook.prototype.$delete = function() {
        return AddressBook.$$resource.remove(this.id);
    };

    AddressBook.prototype.$save = function() {
        return AddressBook.$$resource.set(this.id, this.$omit()).then(function (data) {
            return data;
        });
    };

    AddressBook.prototype.$getCard = function(card_id) {
        var self = this;
        return this.$id().then(function(addressbook_id) {
            self.card = AddressBook.$Card.$find(addressbook_id, card_id);
            self.card.$id().catch(function() {
                // Card not found
                self.card = null;
            });
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
