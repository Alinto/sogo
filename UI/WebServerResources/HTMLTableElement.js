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
	  node.select();
      }
    }
  },

  getColumnsWidth: function(element) {
    element = $(element);
    var widths = new Array();
    if (element.tagName == 'TABLE') {
      var cells = TableKit.getHeaderCells(element);
      for (var i = 0; i < cells.length; i++) {
	widths[i] = $(cells[i]).getWidth();
      }
    }
    return widths;
  },

  setColumnsWidth: function(element, widths) {
    element = $(element);
    if (element.tagName == 'TABLE') {
      for (var i = 0; i < widths.length; i++) {
	TableKit.Resizable.resize(element, i, widths[i]);
      }
    }
  }


}); // Element.addMethods
