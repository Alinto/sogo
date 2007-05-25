if (navigator.vendor == "Apple Computer, Inc." || navigator.vendor == "KDE") { // WebCore/KHTML  
  /*
    Crossbrowser HTMLElement Prototyping
    Copyright (C) 2005  Jason Davis, http://www.browserland.org
    Additional thanks to Brothercake, http://www.brothercake.com
    
    This code is licensed under the LGPL:
    http://www.gnu.org/licenses/lgpl.html
  */

  (function(c) {
    for (var i in c)
      window["HTML" + i + "Element"] = document.createElement(c[ i ]).constructor;
  })({
		Html: "html", Head: "head", Link: "link", Title: "title", Meta: "meta",
			Base: "base", IsIndex: "isindex", Style: "style", Body: "body", Form: "form",
			Select: "select", OptGroup: "optgroup", Option: "option", Input: "input",
			TextArea: "textarea", Button: "button", Label: "label", FieldSet: "fieldset",
			Legend: "legend", UList: "ul", OList: "ol", DList: "dl", Directory: "dir",
			Menu: "menu", LI: "li", Div: "div", Paragraph: "p", Heading: "h1", Quote: "q",
			Pre: "pre", BR: "br", BaseFont: "basefont", Font: "font", HR: "hr", Mod: "ins",
			Anchor: "a", Image: "img", Object: "object", Param: "param", Applet: "applet",
			Map: "map", Area: "area", Script: "script", Table: "table", TableCaption: "caption",
			TableCol: "col", TableSection: "tbody", TableRow: "tr", TableCell: "td",
			FrameSet: "frameset", Frame: "frame", IFrame: "iframe"
			});
  
  function HTMLElement() {}
  //HTMLElement.prototype     = HTMLHtmlElement.__proto__.__proto__;	
  var HTMLDocument          = document.constructor;
  var HTMLCollection        = document.links.constructor;
  var HTMLOptionsCollection = document.createElement("select").options.constructor;
  var Text                  = document.createTextNode("").constructor;
  //var Node                  = Text;
  
  // More efficient for Safari 2
  function Document() {} 
  function Event() {} 
  function HTMLCollection() {} 
  function HTMLElement() {} 
  function Node() {} 
  Document.prototype = window["[[DOMDocument]]"]; 
  Event.prototype = window["[[DOMEvent]]"]; 
  HTMLCollection.prototype = window["[[HTMLCollection.prototype]]"]; 
  HTMLElement.prototype = window["[[DOMElement.prototype]]"]; 
  Node.prototype = window["[[DOMNode.prototype]]"]; 
}

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
    if (typeof(this.childNodes[i]) == "object"
        && this.childNodes[i].tagName
        && this.childNodes[i].tagName.toUpperCase() == tagName)
      matchingNodes.push(this.childNodes[i]);
  }

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

HTMLElement.prototype.onContextMenu = function(event) {
  var popup = this.sogoContextMenu;

  if (document.currentPopupMenu)
    hideMenu(event, document.currentPopupMenu);

  var menuTop = event.pageY;
  var menuLeft = event.pageX;
  var heightDiff = (window.innerHeight
		    - (menuTop + popup.offsetHeight));
  if (heightDiff < 0)
    menuTop += heightDiff;

  var leftDiff = (window.innerWidth
		  - (menuLeft + popup.offsetWidth));
  if (leftDiff < 0)
    menuLeft -= popup.offsetWidth;

  popup.style.top = menuTop + "px;";
  popup.style.left = menuLeft + "px;";
  popup.style.visibility = "visible;";

  bodyOnClick = "" + document.body.getAttribute("onclick");
  document.body.setAttribute("onclick", "onBodyClick(event);");
  document.currentPopupMenu = popup;
}

HTMLElement.prototype.attachMenu = function(menuName) {
  this.sogoContextMenu = $(menuName);
  Event.observe(this, "contextmenu", this.onContextMenu);
}

HTMLElement.prototype.select = function() {
  this.addClassName('_selected');
}

HTMLElement.prototype.deselect = function() {
  this.removeClassName('_selected');
}

HTMLElement.prototype.deselectAll = function () {
  for (var i = 0; i < this.childNodes.length; i++) {
    var node = this.childNodes.item(i);
    if (node.nodeType == 1)
      node.deselect();
  }
}
