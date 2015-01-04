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
	moveOnHandleClass : 'moveOnHandle',
	ordering : true
});

Object.extend(TableKit.Sortable, {
	_oldSort : TableKit.Sortable._sort,
	_sort: function(e) {
		if(TableKit.Ordering._onHandle) {return;}
		TableKit.Sortable._oldSort(e);
	}
});

TableKit.Ordering = {
	init : function(elm, options) {
		var table = $(elm);
		if(table.tagName !== "TABLE") {return;}
		TableKit.register(table,Object.extend(options || {},{ordering:true}));
		var cells = TableKit.getHeaderCells(table);
		cells.each(function(c) {
			c = $(c);
			Event.observe(c, 'mouseover', TableKit.Ordering.initDetect);
			Event.observe(c, 'mouseout', TableKit.Ordering.killDetect);
		});
	},
	move : function(table, index, newIndex) {
		var cell;
		cell = $(index);
		table = table ? $(table) : cell.up('table');
		var targetCell;
		targetCell = $(newIndex);
		var i1 = TableKit.getCellIndex(index);
		var i2 = TableKit.getCellIndex(newIndex);
		if (cell !== targetCell) {
			var rows = TableKit.getBodyRows(table);
			for (var i = 0; i < rows.length; i++) {
				TableKit.Ordering.arrange (rows[i], i1, i2);
			}
			var th = cell.up();
			TableKit.Ordering.arrange (th, i1, i2);
		}
	},
	arrange : function(row, oldIndex, newIndex) {
		if (newIndex == oldIndex) {
			return;
		}
		var temp = Element.remove(row.cells[oldIndex]);
		if (newIndex < row.cells.length) {
			row.insertBefore(temp, row.cells[newIndex]);
		} else {
			row.appendChild(temp);
		}
	},
	initDetect : function(e) {
		e = TableKit.e(e);
		var cell = Event.element(e);
		Event.observe(cell, 'mousemove', TableKit.Ordering.detectHandle);
		Event.observe(cell, 'mousedown', TableKit.Ordering.startMove);
	},
	detectHandle : function(e) {
		e = TableKit.e(e);
		var cell = Event.element(e);
		if(TableKit.Ordering.pointerPos(cell, Event.pointerX(e), Event.pointerY(e))){
  			cell.addClassName(TableKit.option('moveOnHandleClass', cell.up('table').id)[0]);
  			TableKit.Ordering._onHandle = true;
  		} else {
  			cell.removeClassName(TableKit.option('moveOnHandleClass', cell.up('table').id)[0]);
  			TableKit.Ordering._onHandle = false;
  		}
	},
	startMove : function(e) {
		e = TableKit.e(e);
		if(!TableKit.Ordering._onHandle) {return;}
		var cell = Event.element(e);
		Event.stopObserving(cell, 'mousemove', TableKit.Ordering.detectHandle);
		Event.stopObserving(cell, 'mousedown', TableKit.Ordering.startMove);
		Event.stopObserving(cell, 'mouseout', TableKit.Ordering.killDetect);
		TableKit.Ordering._cell = cell;
		var table = cell.up('table');
		TableKit.Ordering._tbl = table;
		if(TableKit.option('showHandle', table.id)[0]) {
			TableKit.Ordering._handle = $(document.createElement('div')).addClassName('move-handle').setStyle({
				'top' : Position.cumulativeOffset(cell)[1] + 'px',
				'left' : Position.cumulativeOffset(cell)[0] + 'px',
				'height' : table.getDimensions().height + 'px',
				'width' : cell.getDimensions().width + 'px'
			});
			document.body.appendChild(TableKit.Ordering._handle);
		}
		Event.observe(document, 'mousemove', TableKit.Ordering.drag);
		Event.observe(document, 'mouseup', TableKit.Ordering.endMove);
		Event.stop(e);
	},
	drag : function(e) {
		e = TableKit.e(e);
		var hoverCell = TableKit.Ordering.getHeaderCell(e);
		if(TableKit.Ordering._handle === null) {
			try {
				TableKit.Ordering.move(TableKit.Ordering._tbl, TableKit.Ordering._cell, hoverCell);
			} catch(e) {}
		} else {
			if (TableKit.getCellIndex(hoverCell) <= TableKit.getCellIndex(TableKit.Ordering._cell)) {
				TableKit.Ordering._handle.setStyle({'left' : Position.cumulativeOffset(hoverCell)[0] + 'px'});
			} else {
				TableKit.Ordering._handle.setStyle({
					'left' : (Position.cumulativeOffset(hoverCell)[0] + hoverCell.getDimensions().width - TableKit.Ordering._cell.getDimensions().width) + 'px'});
			}
		}
		return false;
	},
	endMove : function(e) {
		e = TableKit.e(e);
		var cell = TableKit.Ordering._cell;
		TableKit.Ordering.move(null, cell, TableKit.Ordering.getHeaderCell(e));
		Event.stopObserving(document, 'mousemove', TableKit.Ordering.drag);
		Event.stopObserving(document, 'mouseup', TableKit.Ordering.endMove);
		if(TableKit.option('showHandle', TableKit.Ordering._tbl.id)[0]) {
			$$('div.move-handle').each(function(elm){
				document.body.removeChild(elm);
			});
		}
		Event.observe(cell, 'mouseout', TableKit.Ordering.killDetect);
		TableKit.heads[TableKit.Ordering._tbl.id] = null;
		TableKit.Ordering._tbl = TableKit.Ordering._handle = TableKit.Ordering._cell = null;
		Event.stop(e);
	},
	killDetect : function(e) {
		e = TableKit.e(e);
		TableKit.Resizable._onHandle = false;
		var cell = Event.element(e);
		Event.stopObserving(cell, 'mousemove', TableKit.Ordering.detectHandle);
		Event.stopObserving(cell, 'mousedown', TableKit.Ordering.startMove);
		cell.removeClassName(TableKit.option('moveOnHandleClass', cell.up('table').id)[0]);
	},
	getHeaderCell : function(e) {
		var cell = TableKit.Ordering._cell;
		var heads = TableKit.getHeaderCells(TableKit.Ordering._tbl);
		for (var ix = 0; ix < heads.length; ix++) {
			if (Event.pointerX(e) > Position.cumulativeOffset(heads[ix])[0]) {
				cell = heads[ix];
			}
		}
		return cell;
	},
	pointerPos : function(element, x, y) {
    	var offset = Position.cumulativeOffset(element);
	    return (y >= offset[1] &&
	            y <  offset[1] + 5 &&
	            x >= offset[0] &&
	            x <  offset[0] + element.offsetWidth);
  	},
	_onHandle : false,
	_cell : null,
	_tbl : null,
	_handle : null
}
