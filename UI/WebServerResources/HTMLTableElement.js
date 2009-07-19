/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

Element.addMethods({
  getSelectedRows: function(element) {
    element = $(element);
    if (element.tagName == 'TABLE') {
      var tbody = (element.getElementsByTagName('tbody'))[0];
      
      return $(tbody).getSelectedNodes();
    }
    else if (element.tagName == 'UL') {
      return element.getSelectedNodes();
    }
  },

  getSelectedRowsId: function(element) {
    element = $(element);
    if (element.tagName == 'TABLE') {
      var tbody = (element.getElementsByTagName('tbody'))[0];
      
      return $(tbody).getSelectedNodesId();
    }
    else if (element.tagName == 'UL') {
      return element.getSelectedNodesId();
    }
  },

  selectRowsMatchingClass: function(element, className) {
    element = $(element);
    if (element.tagName == 'TABLE') {
      var tbody = (element.getElementsByTagName('tbody'))[0];
      var nodes = tbody.childNodes;
      for (var i = 0; i < nodes.length; i++) {
	var node = nodes.item(i);
	if (node.tagName && node.hasClassName(className))
	  node.selectElement();
      }
    }
  }

}); // Element.addMethods
