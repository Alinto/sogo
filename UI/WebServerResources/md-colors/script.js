(function() {
   "use strict";
   //Use an IIFE

   AppController.$inject = ['ThemeColors']
   function AppController(ThemeColors) {
      this.version = angular.version.full + " " + angular.version.codeName;
      
      this.th = ThemeColors;
   }
   
 
   //Hook up all my function into angular
   angular.module('myPlunk', [
      'ngMaterial',
      'mdColors'
   ])
      .controller('AppController', AppController)
 
}());