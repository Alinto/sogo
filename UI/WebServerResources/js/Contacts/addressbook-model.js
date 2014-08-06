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

    AddressBook.$all = function(data) {
        if (data) {
            this.$addressbooks = data;
        }
        return this.$addressbooks;
    };

    /* Fetch list of cards */
    AddressBook.$find = function(addressbook_id) {
        var futureAddressBookData = AddressBook.$$resource.find(addressbook_id); // should return attributes of addressbook +
        // AddressBook.$selectedId(addressbook_id);
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
                return AddressBook.$timeout(function() {
                    self.cards = data.cards;
                    return self.cards;
                });
            });
        });
    };

    AddressBook.prototype.$getCard = function(card_id) {
        var self = this;
        return this.$id().then(function(addressbook_id) {
            var card = AddressBook.$Card.$find(addressbook_id, card_id);

            AddressBook.$timeout(function() {
                self.card = card;
            });

            return card.$futureCardData.then(function() {
                angular.forEach(self.cards, function(o, i) {
                        if (o.c_name == card_id) {
                            angular.extend(self.card, o);
                        }
                    });

                return self.card;
            });
        });
    };

    AddressBook.prototype.$resetCard = function() {
        this.$getCard(this.card.id);
    };

    AddressBook.prototype.$viewerIsActive = function(editMode) {
        return (!angular.isUndefined(this.card) && !editMode);
    };

    // Unwrap a promise
    AddressBook.prototype.$unwrap = function(futureAddressBookData) {
        var self = this;

        this.$futureAddressBookData = futureAddressBookData;
        this.$futureAddressBookData.then(function(data) {
            AddressBook.$timeout(function() {
                angular.extend(self, data);
                self.$id().then(function(addressbook_id) {
                    angular.forEach(AddressBook.$all(), function(o, i) {
                        if (o.id == addressbook_id) {
                            angular.extend(self, o);
                        }
                    });
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

    AddressBook.prototype.$save = function() {
        return AddressBook.$$resource.set(this.id, this.$omit()).then(function (data) {
            return data;
        });
    };
})();
