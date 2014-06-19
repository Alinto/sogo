(function() {
    'use strict';

    angular.module('SOGo', ['ngRoute', 'ngSanitize', 'mm.foundation', 'mm.foundation.offcanvas'])
        .constant('sgSettings', {
            'baseURL': '/SOGo/so/francis/Contacts'
        });
})();
