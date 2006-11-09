/* custom extensions to the DOM api */
HTMLElement.prototype.addInterface = function(objectInterface) {
  Object.extend(this, objectInterface);
  if (this.bind)
    this.bind();
}

HTMLElement.prototype.childNodesWithTag = function(tagName) {
  var matchingNodes = new Array();
  var tagName = tagName.toUpperCase();

  for (var i = 0; i < this.childNodes.length; i++) {
//     log("(" + tagName + ") childNodes " + i + " = " + this.childNodes[i]);
    if (typeof(this.childNodes[i]) == "object"
        && this.childNodes[i].tagName
        && this.childNodes[i].tagName.toUpperCase() == tagName)
      matchingNodes.push(this.childNodes[i]);
  }

//   log ("matching: " + matchingNodes.length);

  return matchingNodes;
}

HTMLElement.prototype.addClassName = function(className) {
  var classStr = '' + this.getAttribute("class");

  position = classStr.indexOf(className, 0);
  if (position < 0) {
    classStr = classStr + ' ' + className;
    this.setAttribute('class', classStr);
  }
}

HTMLElement.prototype.removeClassName = function(className) {
  var classStr = '' + this.getAttribute('class');

  position = classStr.indexOf(className, 0);
  while (position > -1) {
    classStr1 = classStr.substring(0, position); 
    classStr2 = classStr.substring(position + 10, classStr.length);
    classStr = classStr1 + classStr2;
    position = classStr.indexOf(className, 0);
  }

  this.setAttribute('class', classStr);
}

HTMLElement.prototype.hasClassName = function(className) {
  var classStr = '' + this.getAttribute('class');
  position = classStr.indexOf(className, 0);
  return (position > -1);
}

HTMLElement.prototype.getParentWithTagName = function(tagName) {
  var currentElement = this;
  tagName = tagName.toUpperCase();

  currentElement = currentElement.parentNode;
  while (currentElement
         && currentElement.tagName != tagName) {
    currentElement = currentElement.parentNode;
  }

  return currentElement;
}

HTMLElement.prototype.cascadeLeftOffset = function() {
  var currentElement = this;

  var offset = 0;
  while (currentElement) {
    offset += currentElement.offsetLeft;
    currentElement = currentElement.getParentWithTagName("div");
  }

  return offset;
}

HTMLElement.prototype.cascadeTopOffset = function() {
  var currentElement = this;
  var offset = 0;

  var i = 0;

  while (currentElement
         && currentElement instanceof HTMLElement) {
    offset += currentElement.offsetTop;
    currentElement = currentElement.parentNode;
    i++;
  }

  return offset;
}

HTMLElement.prototype.dump = function(additionalInfo, additionalKeys) {
  var id = this.getAttribute("id");
  var nclass = this.getAttribute("class");
  
  var str = this.tagName;
  if (id)
    str += "; id = " + id;
  if (nclass)
    str += "; class = " + nclass;

  if (additionalInfo)
    str += "; " + additionalInfo;

  if (additionalKeys)
    for (var i = 0; i < additionalKeys.length; i++) {
      var value = this.getAttribute(additionalKeys[i]);
      if (value)
        str += "; " + additionalKeys[i] + " = " + value;
    }

  log (str);
}

HTMLElement.prototype.getSelectedNodes = function() {
  var selArray = new Array();

  for (var i = 0; i < this.childNodes.length; i++) {
    node = this.childNodes.item(i);
    if (node.nodeType == 1
	&& isNodeSelected(node))
      selArray.push(node);
  }

  return selArray;
}

HTMLElement.prototype.getSelectedNodesId = function() {
  var selArray = new Array();

  for (var i = 0; i < this.childNodes.length; i++) {
    node = this.childNodes.item(i);
    if (node.nodeType == 1
	&& isNodeSelected(node))
      selArray.push(node.getAttribute("id"));
  }

  return selArray;
}
