(function() {
    'use strict';

    /* Constructor  */
    function Resource($http, $q, path) {
        angular.extend(this, {
            _http: $http,
            _q: $q,
            _path: path
        });
    }

    /* The factory we'll use to register with Angular */
    Resource.$factory =  ['$http', '$q', function($http, $q) {
        return function(path) {
            return new Resource($http, $q, path);
        };
    }];

    /* Factory registration in Angular module */
    angular.module('SOGo.Common').factory('sgResource', Resource.$factory);

    /* Instance methods */

    Resource.prototype.path = function(uid) {
        return (uid ? this._path + '/' + uid : this._path) + '/view';
    };

    Resource.prototype.find = function(uid) {
        var deferred = this._q.defer();

        this._http.get(this.path(uid))
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.filter = function(uid, params) {
        var deferred = this._q.defer();

        this._http({
            method: 'GET',
            url: this.path(uid),
            params: params
        })
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.set = function(uid, newValue) {
        var deferred = this._q.defer();
        var path = this._path + '/' + uid + '/save';

        this._http
            .post(path, newValue)
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

})();
