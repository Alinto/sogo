String.prototype.endsWith = function(suffix) {
  return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

String.prototype.startsWith = function(pattern, position) {
  position = angular.isNumber(position) ? position : 0;
  return this.lastIndexOf(pattern, position) === position;
};

String.prototype._base64_keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
String.prototype.base64encode = function () {
  var output = "";
  var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
  var i = 0;
  
  var input = this.utf8encode();

  while (i < input.length) {
    chr1 = input.charCodeAt(i++);
    chr2 = input.charCodeAt(i++);
    chr3 = input.charCodeAt(i++);
    
    enc1 = chr1 >> 2;
    enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
    enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
    enc4 = chr3 & 63;
    
    if (isNaN(chr2)) {
      enc3 = enc4 = 64;
    } else if (isNaN(chr3)) {
      enc4 = 64;
    }
    
    output = output +
      this._base64_keyStr.charAt(enc1) + this._base64_keyStr.charAt(enc2) +
      this._base64_keyStr.charAt(enc3) + this._base64_keyStr.charAt(enc4);
  }
  
  return output;
};

String.prototype.base64decode = function() { 
  var output = "";
  var chr1, chr2, chr3;
  var enc1, enc2, enc3, enc4;
  var i = 0;
  
  var input = "" + this; // .replace(/[^A-Za-z0-9\+\/\=]/g, "")
  while (i < input.length) {
    enc1 = this._base64_keyStr.indexOf(input.charAt(i++));
    enc2 = this._base64_keyStr.indexOf(input.charAt(i++));
    enc3 = this._base64_keyStr.indexOf(input.charAt(i++));
    enc4 = this._base64_keyStr.indexOf(input.charAt(i++));

    chr1 = (enc1 << 2) | (enc2 >> 4);
    chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
    chr3 = ((enc3 & 3) << 6) | enc4;
    
    output = output + String.fromCharCode(chr1);
    
    if (enc3 != 64) {
      output = output + String.fromCharCode(chr2);
    }
    if (enc4 != 64) {
      output = output + String.fromCharCode(chr3);
    }
  }

  return output;
};

String.prototype.asCSSIdentifier = function() {
  var characters = [ '_'  , '\\.', '#'  , '@'  , '\\*', ':'  , ','   , ' '
                     , "'", '&', '\\+' ];
  var escapeds =   [ '_U_', '_D_', '_H_', '_A_', '_S_', '_C_', '_CO_',
                     '_SP_', '_SQ_', '_AM_', '_P_' ];

  var newString = this;
  for (var i = 0; i < characters.length; i++) {
    var re = new RegExp(characters[i], 'g');
    newString = newString.replace(re, escapeds[i]);
  }

  if (/^\d+/.test(newString)) {
    newString = '_' + newString;
  }

  return newString;
};

function l() {
  var key = arguments[0];
  var value = key;
  if (labels[key]) {
    value = labels[key];
  }
  else if (clabels[key]) {
    value = clabels[key];
  }
  for (var i = 1, j = 0; i < arguments.length; i++, j++) {
    value = value.replace('%{' + j + '}', arguments[i]);
  }

  return value;
}
