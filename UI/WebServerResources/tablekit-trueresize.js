/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/**
 * This work is licensed under a Creative Commons Attribution 3.0 License
 * (http://creativecommons.org/licenses/by/3.0/).
 *
 * You are free:
 *    to Share - to copy, distribute and transmit the work
 *    to Remix - to adapt the work
 * Under the following conditions:
 *    Attribution. You must attribute the work in the manner specified
 *    by the author or licensor (but not in any way that suggests that
 *    they endorse you or your use of the work).
 *
 * For any reuse or distribution, you must make clear to others the license
 * terms of this work. The best way to do this is with a link to the
 * Creative Commons web page.
 *
 * Any of the above conditions can be waived if you get permission from
 * the copyright holder. Nothing in this license impairs or restricts
 * the author's moral rights.
 *
 * Disclaimer
 *
 * Your fair dealing and other rights are in no way affected by the  above.
 * This is a human-readable summary of the Legal Code (the full license).
 *
 * The author of this work is Vlad Bailescu (http://vlad.bailescu.ro). No
 * warranty or support will be provided for this work, although updates
 * might be made available at http://vlad.bailescu.ro/javascript/tablekit .
 *
 * Licence code and basic description provided by Creative Commons.
 *
 */
Object.extend(TableKit.options || {}, {
	// If true table width gets recalculated on column resize
	trueResize : false,
	// If true table width will be kept constant on column resize
	keepWidth : false
});
	
Object.extend(TableKit.Resizable, {
	resize : function(table, index, w) {
		// This part is taken from Andrew Tetlaw's original TableKit.Resizable.resize
		var cell;
		if(typeof index === 'number') {
			if(!table || (table.tagName && table.tagName !== "TABLE")) {return;}
			table = $(table);
			index = Math.min(table.rows[0].cells.length, index);
			index = Math.max(1, index);
			index -= 1;
			cell = (table.tHead && table.tHead.rows.length > 0) ? $(table.tHead.rows[table.tHead.rows.length-1].cells[index]) : $(table.rows[0].cells[index]);
		} else {
			cell = $(index);
			table = table ? $(table) : cell.up('table');
			index = TableKit.getCellIndex(cell);
		}
		// And now, for the fun stuff
		// Read the new options values for the given table
		var op = TableKit.option('trueResize keepWidth minWidth', table.id);
		// Took also the minWidth as we're gonna use it later anyway
		var pad = parseInt(cell.getStyle('paddingLeft'),10) + parseInt(cell.getStyle('paddingRight'),10);
		// Improvement: add cell border to padding as width incorporates both
		pad += parseInt(cell.getStyle('borderLeftWidth'),10) + parseInt(cell.getStyle('borderRightWidth'),10);
		w = Math.max(w-pad, op.minWidth); // This will also be used later
		if (!op.trueResize) {
			// Original resize method
			cell.setStyle({'width' : w + 'px'});  // Using previously read minWidth instead of the old way
		} else {
			// New stuff
			var delta = (w + pad - parseInt(cell.getWidth()));
			if (!op.keepWidth) {
				// We'll be updating the table width
				var tableWidth = parseInt(table.getWidth()) + delta;
				cell.setStyle({'width' : w + 'px'});
				table.setStyle({'width' : tableWidth + 'px'});
			} else {
				// Let's see what we have to do to keep the table width constant
				var cells = TableKit.getHeaderCells(table);
				if (index < 0 || index > cells.length) { return; }
				var nbour;
				if (index == cells.length - 1) {	// Rightmost cell
					nbour = cells[index - 1];
				} else {	// Left or inner cell
					nbour = cells[index + 1];
				}
				var nbourWidth = parseInt(nbour.getWidth());
				var nbourPad = parseInt(nbour.getStyle('paddingLeft'),10) + parseInt(nbour.getStyle('paddingRight'),10);
				var proposedNbourWidth = nbourWidth - nbourPad  - delta;
				var newNbourWidth;
				if (proposedNbourWidth < op.minWidth) {
					// Don't be mean to neighbours. Step off their porch.
					newNbourWidth = Math.min(nbourWidth - nbourPad, op.minWidth);
					w -= newNbourWidth - proposedNbourWidth;
				} else {
					newNbourWidth = proposedNbourWidth;
				}
				nbour.setStyle({'width' : newNbourWidth + 'px'});
				cell.setStyle({'width' : w + 'px'});
			}
		}
	}
});