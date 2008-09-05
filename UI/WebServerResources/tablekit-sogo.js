Object.extend(TableKit, {
  getHeaderCells : function(table, cell) {
      if(!table) { table = $(cell).up('table'); }
      var id = table.id;
      if(!TableKit.tables[id].dom.head) {
	// If there are tHead parts, use the first part, not the last one.
	TableKit.tables[id].dom.head = $A((table.tHead && table.tHead.rows.length > 0) ? table.tHead.rows[0].cells : table.rows[0].cells);
      }
      return TableKit.tables[id].dom.head;
    }
  });
