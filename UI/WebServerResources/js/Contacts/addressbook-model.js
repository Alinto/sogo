(function() {
    'use strict';

    function AddressBook(futureAddressBookData) {
        /* DATA IS IMMEDIATELY AVAILABLE */
        if (typeof futureAddressBookData.then !== 'function') {
            angular.extend(this, futureAddressBookData);
            return;
        }

        /* THE PROMISE WILL BE UNWRAPPED FIRST */
        this.$unwrap(futureAddressBookData);
    }

    /* THE FACTORY WE'LL USE TO REGISTER WITH ANGULAR */
    AddressBook.$factory = ['$timeout', 'sgSettings', 'sgResource', 'sgContact', function($timeout, Settings, Resource, Contact) {
        angular.extend(AddressBook, {
            $$resource: new Resource(Settings.baseURL),
            $timeout: $timeout,
            $Contact: Contact
        });

        return AddressBook; // return constructor
    }];

    /* ANGULAR MODULE REGISTRATION */
    angular.module('SOGo').factory('sgAddressBook', AddressBook.$factory);

    // AddressBook.$selectedId = function(addressbook_id) {
    //     if (addressbook_id) angular.extend(AddressBook, { $selected_id: addressbook_id });
    //     console.debug("selected id = " + AddressBook.$selected_id);
    //     return AddressBook.$selected_id;
    // };

    /* Fetch list of contacts */
    AddressBook.$find = function(addressbook_id) {
        var futureAddressBookData = this.$$resource.find(addressbook_id); // should return attributes of addressbook +
        // AddressBook.$selectedId(addressbook_id);
        return new AddressBook(futureAddressBookData);
    };

    // Instance methods

    AddressBook.prototype.$id = function() {
        var self = this;
        return this.$futureAddressBookData.then(function(data) {
            return data.id;
        });
    };

    AddressBook.prototype.$getContact = function(contact_id) {
        var self = this;
        // return this.$futureAddressBookData.then(function(data) {
        //     return data.id;
        // }).then(function(addressbook_id) {
        return this.$id().then(function(addressbook_id) {
            var contact = AddressBook.$Contact.$find(addressbook_id, contact_id);

            AddressBook.$timeout(function() {
                self.contact = contact;
            });

            return contact.$futureContactData.then(function() {
                return self.contact;
            });
        });
    };

    AddressBook.prototype.$resetContact = function() {
        this.$getContact(this.contact.id);
    };

    AddressBook.prototype.$viewerIsActive = function(editMode) {
        return (typeof this.contact != "undefined" && !editMode);
    };

    // AddressBook.prototype.$getContacts = function() {
    //     var self = this;

    //     return AddressBook.$timeout(function() {
    //         var contacts = [];
    //         angular.forEach(self.contacts, function(addressBookContact, index) {
    //             var contact = AddressBook.$Contact.$find(addressBookContact.c_name);
    //             angular.extend(contact, addressBookContact); // useless?
    //             this.push(contact);
    //         }, contacts);

    //         AddressBook.$timeout(function() {
    //             self.contacts = contacts;
    //         });

    //         var futureContactData = [];
    //         angular.forEach(contacts, function(contact, index) {
    //             this.push(contact.$futureContactData);
    //         }, futureContactData);
    //         return this._q.all(futureContactData).then(function() {
    //             //self.$$emitter.emit('update');
    //             return self.contacts;
    //         });
    //     });
    // };

    // Unwrap a promise
    AddressBook.prototype.$unwrap = function(futureAddressBookData) {
        var self = this;

        this.$futureAddressBookData = futureAddressBookData;
        this.$futureAddressBookData.then(function(data) {
            // The success callback. Calling _.extend from $timeout will wrap it into a try/catch call
            // and return a promise.
            AddressBook.$timeout(function() { angular.extend(self, data); });
        });
    };

    // $omit returns a sanitized object used to send to the server
    AddressBook.prototype.$omit = function() {
        var addressbook = {};
        angular.forEach(this, function(value, key) {
            if (key != 'constructor' &&
                key != 'contact' &&
                key != 'contacts' &&
                key[0] != '$') {
                addressbook[key] = value;
            }
        });
        console.debug(angular.toJson(addressbook));
        return addressbook;
    };

    AddressBook.prototype.$save = function() {
        return AddressBook.$$resource.set(this.id, this.$omit()).then(function (data) {
            return data;
        });
    };
})();
