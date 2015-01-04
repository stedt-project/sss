/* Copyright (c) 2007 Andrew Tetlaw & Millstream Web Software
* http://www.millstream.com.au/view/code/tablekit/
* Version: 1.3b 2008-03-23
* modified by Dominic Yu; assumes Prototype 1.6 or later
* 
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without
* restriction, including without limitation the rights to use, copy,
* modify, merge, publish, distribute, sublicense, and/or sell copies
* of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
* NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
* BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
* ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
* CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

/* TableKit is coded in an interesting way. There is a global TableKit object
(it happens to also be a Class, made by Prototype) which basically acts
as a namespace for a whole bunch of functions.

There are also a bunch of options in the global TableKit.options hash.
All options can be specific per-table, but options are loaded dynamically:
if it can't find a table-specific setting, it will default to the global ones,
except for sortable/editable/resizable (see "register :"), which are set to false.

On dom:loaded, TableKit will look for tables which have class "sortable"
(this class name can be customized, and in fact you can have a whole list of
different classes that will init for sortable/editable/resizable).

You can suppress this by setting the global TableKit.options.autoLoad to false.
(The "load" method will still run, but it will end up doing nothing.)
Note that you can also suppress autoloading of individual functions
(sortable, editable, resizable) by setting those options to false. This does
not seem useful, since if you didn't want it, you wouldn't have put the classes
on in the first place, right?

In addition to (or instead of, if you suppress it) using this automatic
initialization, you can init individual tables manually:
TableKit.Sortable|Editable|Resizable.init(table, {options}).

Or you can use the class interface: new TableKit(table, {options}); but this
is really just a wrapper around "manual" method, and all the options are still
stored in the global TableKit.tables hash. The number of methods defined
for the class is also rather paltry, and they're all simple wrappers around
the respective functions in the TableKit.Xxx namespace.
The advantage, of course, is that it's a simpler interface, and perhaps
this is the way to go, assuming we improve the data storage/options problem.

*/

// this creates a class (i.e. a function you can call "new" on)
// whose prototype includes the following functions.
var TableKit = Class.create({
	initialize : function(elm, options) {
		var table = $(elm);
		if (table.tagName !== "TABLE") return; // make sure it *is* a table element
		TableKit.register(table,options);
		this.id = table.id;
		var op = TableKit.option('sortable resizable editable', this.id);
		if(op.sortable) {
			TableKit.Sortable.init(table);
		} 
		if(op.resizable) {
			TableKit.Resizable.init(table);
		}
		if(op.editable) {
			TableKit.Editable.init(table);
		}
	},
	sort : function(column, order) {
		TableKit.Sortable.sort(this.id, column, order);
	},
	resizeColumn : function(column, w) {
		TableKit.Resizable.resize(this.id, column, w);
	},
	editCell : function(row, column) {
		TableKit.Editable.editCell(this.id, row, column);
	}
});

// this adds attributes directly to the TableKit object!
// the global TableKit class-cum-object stores an array of table infos
// in the "tables" attribute.
// the structure of this info object is initialized in "register"
// and contains a copy of all the default options.
// Yes, the info object is a subset of the options object, plus a 'dom' attribute.
// {dom:{head:null,rows:null,cells:{}}

Object.extend(TableKit, {
	getBodyRows : function(table) {
		table = $(table);
		var id = table.id;
		if(!TableKit.tables[id].dom.rows) {
			TableKit.tables[id].dom.rows = (table.tHead && table.tHead.rows.length > 0) ? $A(table.tBodies[0].rows) : $A(table.rows).slice(1);
		}
		return TableKit.tables[id].dom.rows;
	},
	getHeaderCells : function(table, cell) {
		if(!table) { table = $(cell).up('table'); }
		var id = table.id;
		if(!TableKit.tables[id].dom.head) {
			TableKit.tables[id].dom.head = $A((table.tHead && table.tHead.rows.length > 0) ? table.tHead.rows[table.tHead.rows.length-1].cells : table.rows[0].cells);
		}
		return TableKit.tables[id].dom.head;
	},
	getRowIndex : function(row) {
		return $A(row.parentNode.rows).indexOf(row);
	},
	// getCellText is called by various sorting routines, and also editing.
	getCellText : function(cell) {
		if(!cell) { return ""; }
		var data = TableKit.getCellData(cell);
		if(data.refresh || !data.textContent) {
			data.textContent = cell.textContent || cell.innerText;
			data.refresh = false;
		}
		return data.textContent || ''; // return empty to avoid "undefined" in firefox
	},
	// getCellData manages a cache of data for cells that have been accessed.
	// textContent stores stuff for getCellText, and htmlContent and active
	// are used for editing. htmlContent is cached so it can be restored
	// if a user cancels editing; and active keeps tabs on which cells have
	// open editors so they can be removed if unloadTable (possibly in reloadTable)
	// is called. With TableKit.Raw, this seems slightly redundant,
	// and it may be possible to split apart these two functions, but at
	// least the number of "celldata"s is bounded by the number td's on the page...
	getCellData : function(cell) {
	  var t = null;
		if(!cell.id) {
			t = $(cell).up('table');
			cell.id = t.id + "-cell-" + TableKit._getc();
		}
		var tblid = t ? t.id : cell.id.match(/(.*)-cell.*/)[1];
		if(!TableKit.tables[tblid].dom.cells[cell.id]) {
			TableKit.tables[tblid].dom.cells[cell.id] = {textContent : '', htmlContent : '', active : false};
		}
		return TableKit.tables[tblid].dom.cells[cell.id];
	},
	register : function(table, options) {
		if(!table.id) {
			table.id = "tablekit-table-" + TableKit._getc();
		}
		var id = table.id;
		if (!TableKit.tables[id]) TableKit.tables[id] =
			{dom:{head:null,rows:null,cells:{}}, sortable:false,resizable:false,editable:false};
		if (options) Object.extend(TableKit.tables[id], options);
	},
	// convenience method to change global defaults; should be called before dom:loaded
	setup : function(o) {
		Object.extend(TableKit.options, o || {} );
	},
	option1 : function(s, id) {
		var o = TableKit.tables[id] || {};
		return o[s] !== undefined ? o[s] : TableKit.options[s];
	},
	option : function(s, id) {
		var o1 = TableKit.options;
		var o2 = TableKit.tables[id] || {};
		var key = id + s;
		if(!TableKit._opcache[key]){
			TableKit._opcache[key] = $w(s).inject({},function(h,v){
				h[v] = o2[v] !== undefined ? o2[v] : o1[v]; // o2[v] might be a legitimate false value!
				return h;
			});
		}
		return TableKit._opcache[key];
	},
	tables : {},
	_opcache : {},
	options : {
		autoLoad : true, // actually a global option, not needed for individual tables
		stripe : true,
		sortable : true,
		resizable : true,
		editable : true,
		rowEvenClass : 'roweven',
		rowOddClass : 'rowodd',
		sortableSelector : ['table.sortable'],
		columnClass : 'sortcol',
		descendingClass : 'sortdesc',
		ascendingClass : 'sortasc',
		defaultSortDirection : 1,
		noSortClass : 'nosort',
		sortFirstAscendingClass : 'sortfirstasc',
		sortFirstDecendingClass : 'sortfirstdesc',
		resizableSelector : ['table.resizable'],
		minWidth : 10,
		showHandle : true,
		resizeOnHandleClass : 'resize-handle-active',
		editableSelector : ['table.editable'],
		formClassName : 'editable-cell-form',
		noEditClass : 'noedit',
		editAjaxURI : '/',
		editAjaxOptions : {},
		editAjaxExtraParams : '' // *** DY added
	},
	_c : 0,
	_getc : function() {return TableKit._c += 1;},
	unloadTable : function(table){
	  table = $(table);
	  if(!TableKit.tables[table.id]) {return;} //if not an existing registered table return
		TableKit.Raw.prefixes[TableKit.tables[table.id].rawPrefix] = false;
		var cells = TableKit.getHeaderCells(table);
		var op = TableKit.option('sortable resizable editable noSortClass descendingClass ascendingClass columnClass sortFirstAscendingClass sortFirstDecendingClass', table.id);
		 //unregister all the sorting and resizing events
		cells.each(function(c){
			c = $(c);
			if(op.sortable) {
  			if(!c.hasClassName(op.noSortClass)) {
  				Event.stopObserving(c, 'mousedown', TableKit.Sortable._sort);
  				c.removeClassName(op.columnClass);
  				c.removeClassName(op.sortFirstAscendingClass);
  				c.removeClassName(op.sortFirstDecendingClass);
  				//ensure that if table reloaded current sort is remembered via sort first class name
  				if(c.hasClassName(op.ascendingClass)) {
  				  c.removeClassName(op.ascendingClass);
  				  c.addClassName(op.sortFirstAscendingClass)
  				} else if (c.hasClassName(op.descendingClass)) {
  				  c.removeClassName(op.descendingClass);
  				  c.addClassName(op.sortFirstDecendingClass)
  				}  				
  			}
		  }
		  if(op.resizable) {
  			Event.stopObserving(c, 'mouseover', TableKit.Resizable.initDetect);
  			Event.stopObserving(c, 'mouseout', TableKit.Resizable.killDetect);
		  }
		});
		//unregister the editing events and cancel any open editors
		if(op.editable) {
		  Event.stopObserving(table.tBodies[0], 'click', TableKit.Editable._editCell);
		  for(var c in TableKit.tables[table.id].dom.cells) {
		    if(TableKit.tables[table.id].dom.cells[c].active) {
		      var cell = $(c);
  	      var editor = TableKit.Editable.getCellEditor(cell);
  	      editor.cancel(cell);
		    }
  	  }
		}
		//delete the cache
		TableKit.tables[table.id].dom = {head:null,rows:null,cells:{}}; // TODO: watch this for mem leaks
	},
	reloadTable : function(table){
	  table = $(table);
	  TableKit.unloadTable(table);
	  var op = TableKit.option('sortable resizable editable', table.id);
	  if(op.sortable) {TableKit.Sortable.init(table);}
	  if(op.resizable) {TableKit.Resizable.init(table);}
	  if(op.editable) {TableKit.Editable.init(table);}
	},
	reload : function() {
	  for(var k in TableKit.tables) {
	    TableKit.reloadTable(k);
	  }
	},
	// this runs only once, on dom:loaded
	load : function() {
		if(TableKit.options.autoLoad) {
			if(TableKit.options.sortable) {
				$A(TableKit.options.sortableSelector).each(function(s){
					$$(s).each(function(t) {
						TableKit.Sortable.init(t);
					});
				});
			}
			if(TableKit.options.resizable) {
				$A(TableKit.options.resizableSelector).each(function(s){
					$$(s).each(function(t) {
						TableKit.Resizable.init(t);
					});
				});
			}
			if(TableKit.options.editable) {
				$A(TableKit.options.editableSelector).each(function(s){
					$$(s).each(function(t) {
						TableKit.Editable.init(t);
					});
				});
			}
		}
	}
});

// to keep row id's unique, we use a two-letter prefix
// which we generate based on the table name on init.
// we assume that we will never have more than 676(=26*26) tables on one page.
String.prototype.az_succ = function(){return this=='zz'?'aa':this.charAt(1)==='z'?(String.fromCharCode(this.charCodeAt(0)+1)+'a'):this.succ()};
TableKit.Raw = {
	prefixes : {},
	// init takes a table (or id for a table) that is already populated with data.
	// the column (or th's') id's should already be set.
	// we assume the headers are in the first row of the tHead.
	// config must be an object
	// <tablename> is the name of the key for the info in the config hash.
	// config._cols_done is called after the cols have been set up
	init : function (t, tablename, config, edituri) {
		var fields = [];
		TableKit.options.defaultSortDirection = 1;
		var t = $(t);
		t.width = '100%';
		t.style.tableLayout = 'fixed';
		var thead = t.tHead;
		var row = thead.rows[0];
		var rawDataCols = {}; // lookup table for column id -> index

		if (!config) config = {};

		var k = -1; // to find index of key field
		$A(row.cells).each(function (cell, i) {
			var fld = cell.id;
			if (!config[fld]) {
				config[fld] = { noedit:true, nostore:true };
				// "unexpected" columns should not be editable or sortable,
				// and we don't store copies of their contents in rawData (to save memory)
				cell.addClassName('nosort');
			}
			if (config[fld].label) {
				if (cell.down('a')) {
					// don't clobber a link if there is one
					cell.down('a').innerHTML = config[fld].label;
				} else {
					cell.innerHTML = config[fld].label;
				}
			}
			if (config[fld].hide)
				cell.style.display = 'none';
			if (config[fld].noedit)
				cell.addClassName('noedit');
			if (config[fld].size)
				cell.width = config[fld].size;
			rawDataCols[fld] = i;
			if (k < 0 && config['_key'] === fld) {
				k = i;
			}
			fields.push(fld);
		});
		if (config._cols_done) config._cols_done(rawDataCols);
		
		// make unique prefix
		var prefix = tablename.substring(0,2);
		while (TableKit.Raw.prefixes[prefix]) { prefix = prefix.az_succ() }
		TableKit.Raw.prefixes[prefix] = true;
		prefix += '_';

		var rawData = {};
		var i, rows = t.tBodies[0].rows, l = rows.length, id;
		var j, m, data, cells;
		for (i=0; i<l; ++i) {
			id = rows[i].cells[k].innerHTML;
			rows[i].id = prefix + id;
			data = rawData[id] = [];
			cells = rows[i].cells;
			m=cells.length;
			// you must compile rawData first, since the transform functions
			// might refer to cells after themselves!
			for (j=0; j<m; ++j) {
				if (config[fields[j]].nostore) continue;
				data[j] = cells[j].innerHTML.unescapeHTML();
				if (config[fields[j]].hide) cells[j].style.display = 'none';
			}
			for (j=0; j<m; ++j) {
				var xform = config[fields[j]].transform;
				if (xform) cells[j].innerHTML = xform(data[j].escapeHTML(), id, data, j);
			}
		}
		
		TableKit.Resizable.init(t); // you have to init before setting the following
		TableKit.tables[t.id].rawPrefix = prefix.substring(0,2);
		TableKit.tables[t.id].raw = {};
		TableKit.tables[t.id].raw.tblname = tablename;
		TableKit.tables[t.id].raw.config = config;
		TableKit.tables[t.id].raw.data = rawData;
		TableKit.tables[t.id].raw.cols = rawDataCols;
		if (edituri) {
			TableKit.Editable.init(t);
			TableKit.tables[t.id].editAjaxURI = edituri;
		}
		if (config._postprocess) config._postprocess(t);
	},
	// yes, this function is awfully similar to the one above, but there's
	// enough different about them that it's not really worth trying to factor out stuff
	initByAjax: function (t_id, tablename, tabledata, config, edituri, container_id) {
		// make a table
		var t = $(t_id);
		if (t) {
			TableKit.unloadTable(t);
			t.purge(); // save memory by removing event handlers
			t.remove();
		}
		if (!tabledata.data.length) return; // stop here if no results
		t = $(document.createElement('table')); // $() extends it into a Prototype Element
		t.id = t_id;
		t.width = '100%';
		t.style.tableLayout = 'fixed';
		$(container_id).appendChild(t);
		if (!config) config = {};
	
		// make the header
		// this is where we make columns editable (by setting the id) or not
		var thead = t.createTHead();
		var row = thead.insertRow(-1); // -1 is the index value for "at the end", and is required for firefox
		var rawDataCols = {}; // lookup table for column id -> index
		tabledata.fields.each(function (fld, i) {
			if (!config[fld]) {
				config[fld] = { noedit:true, nosort:true };
			}
			var c = $(document.createElement('th'));
			c.id = fld;
			if (config[fld].noedit)
				c.addClassName('noedit');
			if (config[fld].nosort)
				c.addClassName('nosort');
			if (config[fld].size)
				c.width = config[fld].size;
			c.innerHTML = config[fld].label || fld;
			row.appendChild(c);
			if (config[fld].hide)
				c.style.display = 'none';
			rawDataCols[fld] = i;
		});
		if (config._cols_done) config._cols_done(rawDataCols);
		
		// find index of key field
		var k;
		for (k = 0; k < tabledata.fields.length; ++k) {
			if (tabledata.fields[k] == config._key)
				break;
		}
	
		// make unique prefix
		var prefix = tablename.substring(0,2);
		while (TableKit.Raw.prefixes[prefix]) { prefix = prefix.az_succ() }
		TableKit.Raw.prefixes[prefix] = true;
		prefix += '_';
	
		// stick in the data
		var tbody = $(document.createElement('tbody'));
		var rawData = {};
		t.appendChild(tbody);
		var i, l = tabledata.data.length, rec, id, j, m, cell, xform, v;
		for (i=0; i<l; ++i) {
			rec = tabledata.data[i];
			id = rec[k];
			row = tbody.insertRow(-1);
			row.id = prefix + id;	// set this for TableKit.Editable
			rawData[id] = rec;
			for (j=0, m=rec.length; j<m; ++j) {
				v = (rec[j]||'').escapeHTML();
				// everything we get from the server is a string, so even "0" is truthy
				// but we might get null values, in which case we change it to ""
				cell = row.insertCell(-1);
				xform = config[tabledata.fields[j]].transform;
				cell.innerHTML = xform	? xform(v, id, rec, j) : v;
				if (config[tabledata.fields[j]].hide) cell.style.display = 'none';
			}
		}
		
		// activate TableKit!
		// t.addClassName('sortable'); // not needed if manually initing
		TableKit.Sortable.init(t);
		TableKit.Resizable.init(t);
		TableKit.options.defaultSort = 1;
		TableKit.tables[t.id].rawPrefix = prefix.substring(0,2);
		TableKit.tables[t.id].raw = {};
		TableKit.tables[t.id].raw.tblname = tablename;
		TableKit.tables[t.id].raw.config = config;
		TableKit.tables[t.id].raw.data = rawData;
		TableKit.tables[t.id].raw.cols = rawDataCols;
		if (edituri) {
			TableKit.Editable.init(t);
			TableKit.tables[t.id].editAjaxURI = edituri;
		}
		if (config._postprocess) config._postprocess(t);
	}
};


TableKit.Rows = {
	stripe : function(t) {
		var rows = TableKit.getBodyRows(t);
		var r1 = TableKit.option1('rowOddClass', t.id);
		var r2 = TableKit.option1('rowEvenClass', t.id);
		var css, cn, newCn, i, x, l, l2;
		for (i = 0, l = rows.length; i < l; ++i) {
			// copied code from addStripeClass for efficiency
			css = i&1 ? r1 : r2;
			cn = rows[i].className.split(/\s+/);
			newCn = [];
			for (x = 0, l2 = cn.length; x < l2; ++x) {
				if (cn[x] !== r1 && cn[x] !== r2) newCn.push(cn[x]);
			}
			newCn.push(css);
			rows[i].className = newCn.join(" ");
		}
	}
};

TableKit.Sortable = {
	init : function(elm, options){
		var table = $(elm);
		if(table.tagName !== "TABLE") {
			return;
		}
		TableKit.register(table,Object.extend(options || {},{sortable:true}));
		var sortFirst;
		var cells = TableKit.getHeaderCells(table);
		var op = TableKit.option('noSortClass columnClass sortFirstAscendingClass sortFirstDecendingClass', table.id);
		cells.each(function(c){
			c = $(c);
			if(!c.hasClassName(op.noSortClass)) {
				Event.observe(c, 'mousedown', TableKit.Sortable._sort);
				c.addClassName(op.columnClass);
				if(c.hasClassName(op.sortFirstAscendingClass) || c.hasClassName(op.sortFirstDecendingClass)) {
					sortFirst = c;
				}
			}
		});

		if(sortFirst) {
			if(sortFirst.hasClassName(op.sortFirstAscendingClass)) {
				TableKit.Sortable.sort(table, sortFirst, 1);
			} else {
				TableKit.Sortable.sort(table, sortFirst, -1);
			}
		} else { // just add row stripe classes
			TableKit.Rows.stripe(table);
		}
	},
	reload : function(table) {
		table = $(table);
		var cells = TableKit.getHeaderCells(table);
		var op = TableKit.option('noSortClass columnClass', table.id);
		cells.each(function(c){
			c = $(c);
			if(!c.hasClassName(op.noSortClass)) {
				Event.stopObserving(c, 'mousedown', TableKit.Sortable._sort);
				c.removeClassName(op.columnClass);
			}
		});
		TableKit.Sortable.init(table);
	},
	_sort : function(e) {
		if(TableKit.Resizable._onHandle) {return;}
		Event.stop(e);
		var cell = Event.element(e);
		while(!(cell.tagName && cell.tagName.match(/td|th/gi))) {
			cell = cell.parentNode;
		}
		TableKit.Sortable.sort(null, cell);
	},
	sort : function(table, index, order) {
		var cell;
		if(typeof index === 'number') {
			if(!table || (table.tagName && table.tagName !== "TABLE")) {
				return;
			}
			table = $(table);
			index = Math.min(table.rows[0].cells.length, index);
			index = Math.max(1, index);
			index -= 1;
			cell = (table.tHead && table.tHead.rows.length > 0) ? $(table.tHead.rows[table.tHead.rows.length-1].cells[index]) : $(table.rows[0].cells[index]);
		} else {
			cell = $(index);
			table = table ? $(table) : cell.up('table');
			index = cell.cellIndex;
		}
		var op = TableKit.option('noSortClass descendingClass ascendingClass defaultSortDirection', table.id);
		
		if(cell.hasClassName(op.noSortClass)) {return;}	
		order = order || op.defaultSortDirection;
		var rows = TableKit.getBodyRows(table);

		if((cell.hasClassName(op.ascendingClass) || cell.hasClassName(op.descendingClass)) && !TableKit.tables[table.id].customSortFn) {
			rows.reverse(); // if it was already sorted we just need to reverse it.
			order = cell.hasClassName(op.descendingClass) ? 1 : -1;
		} else {
			var datatype = TableKit.Sortable.getDataType(cell,index,table);
			var tkst = TableKit.Sortable.types;
			if (TableKit.tables[table.id].customSortFn) {
				if (cell.hasClassName(op.ascendingClass) || cell.hasClassName(op.descendingClass)) {
					order = cell.hasClassName(op.descendingClass) ? 1 : -1;
				}
				if (!TableKit.tables[table.id].customSortFn(rows, index, tkst[datatype], order)) {
					// this is just copy-pasted from below...
					rows.sort(function(a,b) {
						return order * tkst[datatype].compare(TableKit.getCellText(a.cells[index]),TableKit.getCellText(b.cells[index]));
					});
				}
			} else {
				rows.sort(function(a,b) {
					return order * tkst[datatype].compare(TableKit.getCellText(a.cells[index]),TableKit.getCellText(b.cells[index]));
				}); //\raw
			}
		}
		var tb = table.tBodies[0];
		var r1 = TableKit.option1('rowOddClass', table.id);
		var r2 = TableKit.option1('rowEvenClass', table.id);
		var css, cn, newCn, i, x, l, l2;
		for (i = 0, l = rows.length; i < l; ++i) {
			tb.appendChild(rows[i]);
			// copied code from addStripeClass for efficiency
			css = i&1 ? r1 : r2;
			cn = rows[i].className.split(/\s+/);
			newCn = [];
			for (x = 0, l2 = cn.length; x < l2; ++x) {
				if (cn[x] !== r1 && cn[x] !== r2) newCn.push(cn[x]);
			}
			newCn.push(css);
			rows[i].className = newCn.join(" ");
		}
		var hcells = TableKit.getHeaderCells(null, cell);
		$A(hcells).each(function(c,i){
			c = $(c);
			c.removeClassName(op.ascendingClass);
			c.removeClassName(op.descendingClass);
			if(index === i) {
				if(order === 1) {
					c.addClassName(op.ascendingClass);
				} else {
					c.addClassName(op.descendingClass);
				}
			}
		});
	},
	types : {},
	detectors : $w('date-iso date date-eu date-au time currency datasize semkey number casesensitivetext text'),
	addSortType : function() {
		$A(arguments).each(function(o){
			TableKit.Sortable.types[o.name] = o;
		});
	},
	getDataType : function(cell,index,table) {
		cell = $(cell);
		index = (index || index === 0) ? index : cell.cellIndex;
		
		var colcache = TableKit.Sortable._coltypecache;
		var cache = colcache[table.id] ? colcache[table.id] : (colcache[table.id] = {});
		
		if(!cache[index]) {
			var t = '';
			// first look for a data type id on the heading row cell
			if(cell.id && TableKit.Sortable.types[cell.id]) {
				t = cell.id;
			}
			if(!t) {
  			t = $w(cell.className).detect(function(n){ // then look for a data type classname on the heading row cell
  				return (TableKit.Sortable.types[n]) ? true : false;
  			});
			}
			if(!t) {
				var rows = TableKit.getBodyRows(table);
				var s = '';
				// look for the first row with a non-empty value
				for (var i = 0; i < rows.length; ++i) {
					s = TableKit.getCellText(rows[i].cells[index]); // grab same index cell from body row to try and match data type
					if (s !== '') break;
				}
				t = TableKit.Sortable.detectors.detect(
						function(d){
							return TableKit.Sortable.types[d].detect(s);//\raw
						});
			}
			cache[index] = t;
		}
		return cache[index];
	},
	_coltypecache : {}
};

TableKit.Sortable.Type = Class.create();
TableKit.Sortable.Type.prototype = {
	initialize : function(name, options){
		this.name = name;
		options = Object.extend({
			normal : function(v){
				return v;
			},
			pattern : /.*/
		}, options || {});
		this.normal = options.normal;
		this.pattern = options.pattern;
		if(options.compare) {
			this.compare = options.compare;
		}
		if(options.detect) {
			this.detect = options.detect;
		}
	},
	compare : function(a,b){
		return TableKit.Sortable.Type.compare(this.normal(a), this.normal(b));
	},
	detect : function(v){
		return this.pattern.test(v);
	}
};

TableKit.Sortable.Type.compare = function(a,b) {
	return a < b ? -1 : a === b ? 0 : 1;
};

TableKit.Sortable.addSortType(
	new TableKit.Sortable.Type('semkey', {	// sort type for chapter and semkey fields
		pattern : /^[\dx]+\.[\dx]+(\.[\d]+)*$/, // matches digits or (first two) x's separated by decimal points; required to end with digit
		compare : function(a,b) {
			// alert(a + " vs. " + b);
			if(a === b) {	// this also covers cases in which both a and b are 'x.x' or blank
				return 0;
			}
			// sort x.x's after real semkeys, then blanks finally
			if(a === '') {		// if only a is blank, then a > b
				return 1;
			} else if(b === '') {	// else if only b is blank, then b > a
				return -1;
			} else if(a === 'x.x') {	// else if a is x.x and b is a real semkey, then a > b
				return 1;
			} else if(b === 'x.x') {	// else if b is x.x and a is a real semkey, then b > a
				return -1;
			}
			
			// now split the VFCSSS levels
			var aLevels = a.split('.');
			var bLevels = b.split('.');
			// loop through the levels
			for (var i = 0; i < aLevels.length; ++i) {
				// if we've reached the end of b but a has additional levels, then a is greater
				if (bLevels.length == i) {
					return 1;
				}
				if (aLevels[i] === bLevels[i]) {	// if the levels are equal, continue to the next level
					continue;
				}
				else if (parseInt(aLevels[i],10) > parseInt(bLevels[i],10)) {	// a's level is greater than b's, so a > b
					return 1;
				}
				else {	// b's level is greater than a's, so b > a
					return -1;
				}
			}
			return -1;
			// we've reached the end of a, so if b has additional levels, then b is greater
// 			if (aLevels.length != bLevels.length) {
// 				return -1;
// 			}
// 			// otherwise, they're the same (this should never execute, since the equivalency case was handled above)
// 			return 0;
		}}),
	new TableKit.Sortable.Type('number', {
		pattern : /^[-+]?[\d]*\.?[\d]+(?:[eE][-+]?[\d]+)?/,
		normal : function(v) {
			// This will grab the first thing that looks like a number from a string, so you can use it to order a column of various srings containing numbers.
			v = parseFloat(v.replace(/^.*?([-+]?[\d]*\.?[\d]+(?:[eE][-+]?[\d]+)?).*$/,"$1"));
			return isNaN(v) ? 0 : v;
		}}),
	new TableKit.Sortable.Type('text',{
		normal : function(v) {
			return v ? v.toLowerCase().replace(/ /g,"") : ''; // ignore THIN spaces (U+2009) when sorting (produced by stedt delimiters)
		}}),
	new TableKit.Sortable.Type('casesensitivetext',{pattern : /^[A-Z]+$/}),
	new TableKit.Sortable.Type('datasize',{
		pattern : /^[-+]?[\d]*\.?[\d]+(?:[eE][-+]?[\d]+)?\s?[k|m|g|t]b$/i,
		normal : function(v) {
			var r = v.match(/^([-+]?[\d]*\.?[\d]+([eE][-+]?[\d]+)?)\s?([k|m|g|t]?b)?/i);
			var b = r[1] ? Number(r[1]).valueOf() : 0;
			var m = r[3] ? r[3].substr(0,1).toLowerCase() : '';
			var result = b;
			switch(m) {
				case  'k':
					result = b * 1024;
					break;
				case  'm':				
					result = b * 1024 * 1024;
					break;
				case  'g':
					result = b * 1024 * 1024 * 1024;
					break;
				case  't':
					result = b * 1024 * 1024 * 1024 * 1024;
					break;
			}
			return result;
		}}),
	new TableKit.Sortable.Type('date-au',{
		pattern : /^\d{2}\/\d{2}\/\d{4}\s?(?:\d{1,2}\:\d{2}(?:\:\d{2})?\s?[a|p]?m?)?/i,
		normal : function(v) {
			if(!this.pattern.test(v)) {return 0;}
			var r = v.match(/^(\d{2})\/(\d{2})\/(\d{4})\s?(?:(\d{1,2})\:(\d{2})(?:\:(\d{2}))?\s?([a|p]?m?))?/i);
			var yr_num = r[3];
			var mo_num = parseInt(r[2],10)-1;
			var day_num = r[1];
			var hr_num = r[4] ? r[4] : 0;
			if(r[7]) {
				var chr = parseInt(r[4],10);
				if(r[7].toLowerCase().indexOf('p') !== -1) {
					hr_num = chr < 12 ? chr + 12 : chr;
				} else if(r[7].toLowerCase().indexOf('a') !== -1) {
					hr_num = chr < 12 ? chr : 0;
				}
			} 
			var min_num = r[5] ? r[5] : 0;
			var sec_num = r[6] ? r[6] : 0;
			return new Date(yr_num, mo_num, day_num, hr_num, min_num, sec_num, 0).valueOf();
		}}),
	new TableKit.Sortable.Type('date-us',{
		pattern : /^\d{2}\/\d{2}\/\d{4}\s?(?:\d{1,2}\:\d{2}(?:\:\d{2})?\s?[a|p]?m?)?/i,
		normal : function(v) {
			if(!this.pattern.test(v)) {return 0;}
			var r = v.match(/^(\d{2})\/(\d{2})\/(\d{4})\s?(?:(\d{1,2})\:(\d{2})(?:\:(\d{2}))?\s?([a|p]?m?))?/i);
			var yr_num = r[3];
			var mo_num = parseInt(r[1],10)-1;
			var day_num = r[2];
			var hr_num = r[4] ? r[4] : 0;
			if(r[7]) {
				var chr = parseInt(r[4],10);
				if(r[7].toLowerCase().indexOf('p') !== -1) {
					hr_num = chr < 12 ? chr + 12 : chr;
				} else if(r[7].toLowerCase().indexOf('a') !== -1) {
					hr_num = chr < 12 ? chr : 0;
				}
			} 
			var min_num = r[5] ? r[5] : 0;
			var sec_num = r[6] ? r[6] : 0;
			return new Date(yr_num, mo_num, day_num, hr_num, min_num, sec_num, 0).valueOf();
		}}),
	new TableKit.Sortable.Type('date-eu',{
		pattern : /^\d{2}-\d{2}-\d{4}/i,
		normal : function(v) {
			if(!this.pattern.test(v)) {return 0;}
			var r = v.match(/^(\d{2})-(\d{2})-(\d{4})/);
			var yr_num = r[3];
			var mo_num = parseInt(r[2],10)-1;
			var day_num = r[1];
			return new Date(yr_num, mo_num, day_num).valueOf();
		}}),
	new TableKit.Sortable.Type('date-iso',{
		pattern : /[\d]{4}-[\d]{2}-[\d]{2}(?:T[\d]{2}\:[\d]{2}(?:\:[\d]{2}(?:\.[\d]+)?)?(Z|([-+][\d]{2}:[\d]{2})?)?)?/, // 2005-03-26T19:51:34Z
		normal : function(v) {
			if(!this.pattern.test(v)) {return 0;}
		    var d = v.match(/([\d]{4})(-([\d]{2})(-([\d]{2})(T([\d]{2}):([\d]{2})(:([\d]{2})(\.([\d]+))?)?(Z|(([-+])([\d]{2}):([\d]{2})))?)?)?)?/);		
		    var offset = 0;
		    var date = new Date(d[1], 0, 1);
		    if (d[3]) { date.setMonth(d[3] - 1) ;}
		    if (d[5]) { date.setDate(d[5]); }
		    if (d[7]) { date.setHours(d[7]); }
		    if (d[8]) { date.setMinutes(d[8]); }
		    if (d[10]) { date.setSeconds(d[10]); }
		    if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
		    if (d[14]) {
		        offset = (Number(d[16]) * 60) + Number(d[17]);
		        offset *= ((d[15] === '-') ? 1 : -1);
		    }
		    offset -= date.getTimezoneOffset();
		    if(offset !== 0) {
		    	var time = (Number(date) + (offset * 60 * 1000));
		    	date.setTime(Number(time));
		    }
			return date.valueOf();
		}}),
	new TableKit.Sortable.Type('date',{
		pattern: /^(?:sun|mon|tue|wed|thu|fri|sat)\,\s\d{1,2}\s(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s\d{4}(?:\s\d{2}\:\d{2}(?:\:\d{2})?(?:\sGMT(?:[+-]\d{4})?)?)?/i, //Mon, 18 Dec 1995 17:28:35 GMT
		compare : function(a,b) { // must be standard javascript date format
			if(a && b) {
				return TableKit.Sortable.Type.compare(new Date(a),new Date(b));
			} else {
				return TableKit.Sortable.Type.compare(a ? 1 : 0, b ? 1 : 0);
			}
		}}),
	new TableKit.Sortable.Type('time',{
		pattern : /^\d{1,2}\:\d{2}(?:\:\d{2})?(?:\s[a|p]m)?$/i,
		compare : function(a,b) {
			var d = new Date();
			var ds = d.getMonth() + "/" + d.getDate() + "/" + d.getFullYear() + " ";
			return TableKit.Sortable.Type.compare(new Date(ds + a),new Date(ds + b));
		}}),
	new TableKit.Sortable.Type('currency',{
		pattern : /^[$����]/, // dollar,pound,yen,euro,generic currency symbol
		normal : function(v) {
			return v ? parseFloat(v.replace(/[^-\d\.]/g,'')) : 0;
		}})
);

TableKit.Resizable = {
	init : function(elm, options){
		var table = $(elm);
		if(table.tagName !== "TABLE") {return;}
		TableKit.register(table,Object.extend(options || {},{resizable:true}));		 
		var cells = TableKit.getHeaderCells(table);
		cells.each(function(c){
			c = $(c);
			Event.observe(c, 'mouseover', TableKit.Resizable.initDetect);
			Event.observe(c, 'mouseout', TableKit.Resizable.killDetect);
		});
	},
	resize : function(table, index, w) {
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
			index = cell.cellIndex;
		}
		var pad = parseInt(cell.getStyle('paddingLeft'),10) + parseInt(cell.getStyle('paddingRight'),10);
		w = Math.max(w-pad, TableKit.option1('minWidth', table.id));
		
		cell.setStyle({'width' : w + 'px'});
	},
	initDetect : function(e) {
		var cell = Event.element(e);
		Event.observe(cell, 'mousemove', TableKit.Resizable.detectHandle);
		Event.observe(cell, 'mousedown', TableKit.Resizable.startResize);
	},
	detectHandle : function(e) {
		var cell = Event.element(e);
  		if(TableKit.Resizable.pointerPos(cell,Event.pointerX(e),Event.pointerY(e))){
  			cell.addClassName(TableKit.option1('resizeOnHandleClass', cell.up('table').id));
  			TableKit.Resizable._onHandle = true;
  		} else {
  			cell.removeClassName(TableKit.option1('resizeOnHandleClass', cell.up('table').id));
  			TableKit.Resizable._onHandle = false;
  		}
	},
	killDetect : function(e) {
		TableKit.Resizable._onHandle = false;
		var cell = Event.element(e);
		Event.stopObserving(cell, 'mousemove', TableKit.Resizable.detectHandle);
		Event.stopObserving(cell, 'mousedown', TableKit.Resizable.startResize);
		cell.removeClassName(TableKit.option1('resizeOnHandleClass', cell.up('table').id));
	},
	startResize : function(e) {
		if(!TableKit.Resizable._onHandle) {return;}
		var cell = Event.element(e);
		Event.stopObserving(cell, 'mousemove', TableKit.Resizable.detectHandle);
		Event.stopObserving(cell, 'mousedown', TableKit.Resizable.startResize);
		Event.stopObserving(cell, 'mouseout', TableKit.Resizable.killDetect);
		TableKit.Resizable._cell = cell;
		var table = cell.up('table');
		TableKit.Resizable._tbl = table;
		if(TableKit.option1('showHandle', table.id)) {
			TableKit.Resizable._handle = $(document.createElement('div')).addClassName('resize-handle').setStyle({
				'top' : cell.cumulativeOffset()[1] + 'px',
				'left' : Event.pointerX(e) + 'px',
				'height' : table.getDimensions().height + 'px'
			});
			document.body.appendChild(TableKit.Resizable._handle);
		}
		Event.observe(document, 'mousemove', TableKit.Resizable.drag);
		Event.observe(document, 'mouseup', TableKit.Resizable.endResize);
		Event.stop(e);
	},
	endResize : function(e) {
		var cell = TableKit.Resizable._cell;
		TableKit.Resizable.resize(null, cell, (Event.pointerX(e) - cell.cumulativeOffset()[0]));
		Event.stopObserving(document, 'mousemove', TableKit.Resizable.drag);
		Event.stopObserving(document, 'mouseup', TableKit.Resizable.endResize);
		if(TableKit.option1('showHandle', TableKit.Resizable._tbl.id)) {
			$$('div.resize-handle').each(function(elm){
				document.body.removeChild(elm);
			});
		}
		Event.observe(cell, 'mouseout', TableKit.Resizable.killDetect);
		TableKit.Resizable._tbl = TableKit.Resizable._handle = TableKit.Resizable._cell = null;
		Event.stop(e);
	},
	drag : function(e) {
		if(TableKit.Resizable._handle === null) {
			try {
				TableKit.Resizable.resize(TableKit.Resizable._tbl, TableKit.Resizable._cell, (Event.pointerX(e) - TableKit.Resizable._cell.cumulativeOffset()[0]));
			} catch(e) {}
		} else {
			TableKit.Resizable._handle.setStyle({'left' : Event.pointerX(e) + 'px'});
		}
		return false;
	},
	pointerPos : function(element, x, y) {
    	var offset = $(element).cumulativeOffset();
	    return (y >= offset[1] &&
	            y <  offset[1] + element.offsetHeight &&
	            x >= offset[0] + element.offsetWidth - 5 &&
	            x <  offset[0] + element.offsetWidth);
  	},
	_onHandle : false,
	_cell : null,
	_tbl : null,
	_handle : null
};


TableKit.Editable = {
	init : function(elm, options){
		var table = $(elm);
		if(table.tagName !== "TABLE") {return;}
		TableKit.register(table,Object.extend(options || {},{editable:true}));
		Event.observe(table.tBodies[0], 'click', TableKit.Editable._editCell);
	},
	_editCell : function(e) {
		if (Event.findElement(e,'a')) return; // don't edit if clicking on a link
		var cell = Event.findElement(e,'td');
		if(cell) {
			TableKit.Editable.editCell(null, cell, null, e);
		} else {
			return false;
		}
	},
	editCell : function(table, index, cindex, event) {
		var cell, row;
		if(typeof index === 'number') {
			if(!table || (table.tagName && table.tagName !== "TABLE")) {return;}
			table = $(table);
			index = Math.min(table.tBodies[0].rows.length, index);
			index = Math.max(1, index);
			index -= 1;
			cindex = Math.min(table.rows[0].cells.length, cindex);
			cindex = Math.max(1, cindex);
			cindex -= 1;
			row = $(table.tBodies[0].rows[index]);
			cell = $(row.cells[cindex]);
		} else {
			cell = $(event ? Event.findElement(event, 'td') : index);
			table = (table && table.tagName && table.tagName !== "TABLE") ? $(table) : cell.up('table');
			row = cell.up('tr'); // *** assigned but never used?
		}
		var nec = TableKit.option1('noEditClass', table.id);
		if(cell.hasClassName(nec)) {return;}
		
		var head = $(TableKit.getHeaderCells(table, cell)[cell.cellIndex]);
		if(head.hasClassName(nec)) {return;}
		
		var data = TableKit.getCellData(cell);
		if(data.active) {return;}
		data.htmlContent = cell.innerHTML;
		var ftype = TableKit.Editable.getCellEditor(null,null,head);
		ftype.edit(cell, event);
		data.active = true;
	},
	getCellEditor : function(cell, table, head) {
	  var head = head ? head : $(TableKit.getHeaderCells(table, cell)[cell.cellIndex]);
	  var ftype = TableKit.Editable.types['text-input'];
		if(head.id && TableKit.Editable.types[head.id]) {
			ftype = TableKit.Editable.types[head.id];
		} else {
			var n = $w(head.className).detect(function(n){
					return (TableKit.Editable.types[n]) ? true : false;
			});
			ftype = n ? TableKit.Editable.types[n] : ftype;
		}
		return ftype;
	},
	types : {},
	addCellEditor : function(o) {
		if(o && o.name) { TableKit.Editable.types[o.name] = o; }
	}
};

TableKit.Editable.CellEditor = Class.create();
TableKit.Editable.CellEditor.prototype = {
	initialize : function(name, options){
		this.name = name;
		this.options = Object.extend({
			element : 'input',
			attributes : {name : 'value', type : 'text'},
			selectOptions : [],
			showSubmit : true,
			submitText : 'OK',
			showCancel : true,
			cancelText : 'Cancel',
			ajaxURI : null,
			ajaxOptions : null
		}, options || {});
	},
	edit : function(cell) {
		cell = $(cell);
		var op = this.options;
		var table = cell.up('table');
		// *** added DY
		var formwidth = cell.offsetWidth; // getWidth();
		var formheight = cell.getHeight();
		var rowid = cell.up('tr').id.substring(3);
		var colid = $(TableKit.getHeaderCells(table, cell)[cell.cellIndex]).id;
		var raw = TableKit.tables[table.id].raw;
		var rawValue = raw ? raw.data[rowid][raw.cols[colid]] : null;
		var oldValue = raw ? rawValue : TableKit.getCellText(cell);
		// *** DY
		
		var form = $(document.createElement("form"));
		form.id = cell.id + '-form';
		form.addClassName(TableKit.option1('formClassName', table.id));
		form.onsubmit = this._submit.bindAsEventListener(this);
		
		var field = document.createElement(op.element);
			$H(op.attributes).each(function(v){
				field[v.key] = v.value;
			});
			switch(op.element) {
				case 'input':
				case 'textarea':
				// field.value = TableKit.getCellText(cell); // *** DY moved this to the end so the insertion point shows up at the end
				// *** added DY
				if (op.attributes.rows === '1') {
					op.showSubmit = false;
					op.showCancel = false;
					field.observe('keydown', function(event) {
						if (event.keyCode == Event.KEY_ESC) {
							field.onblur = '';
							this.cancel(cell);
						} else if (event.keyCode == Event.KEY_RETURN) {
							field.onblur = '';
							if (field.value == oldValue) {
								this.cancel(cell);
// 								var data = TableKit.getCellData(cell);
// 								cell.innerHTML = data.htmlContent;
// 								data.htmlContent = '';
							} else {
								this._submit(event);
							}
							var nextrow = cell.up('tr').next();
							if (nextrow && (nextrow.id ||  // only if there's another row..., and the row looks like it's operable...
									(nextrow = nextrow.next()) && nextrow.id)) { // or the one after that...
								Event.stop(event); // otherwise the return gets typed into the form
								var colnum = cell.cellIndex;
								var head = $(TableKit.getHeaderCells(table, cell)[colnum]);
								var ftype = TableKit.Editable.getCellEditor(null,null,head);
								
								// adapted from editCell, above
								var nextCell = $(nextrow.childElements()[colnum]);
								var data = TableKit.getCellData(nextCell);
								data.htmlContent = nextCell.innerHTML;
								ftype.edit(nextCell);
								data.active = true;
							}
						} else if (event.keyCode == Event.KEY_TAB ) {
							if (field.value != oldValue) {
								field.onblur = '';
								this._submit(event);
							}
						}
					}.bindAsEventListener(this));
					field.onblur = this._cancel.bindAsEventListener(this);
				} else {
					formheight += 28;
					field.observe('keydown', function(event) {
						if (event.keyCode == Event.KEY_ESC) {
							this.cancel(cell);
						}
					}.bindAsEventListener(this));
				}
				// *** DY
				break;
				
				case 'select':
				op.showSubmit = false;
				op.showCancel = false;
				$A(op.selectOptions).each(function(v){
					field.options[field.options.length] = new Option(v[0], v[1]); // add the value-key pairs to the end of the select.
					if(oldValue === v[1]) {
						field.options[field.options.length-1].selected = 'selected';
					}
				});
				field.observe('keydown', function(event) {
					if (event.keyCode == Event.KEY_ESC) {
						field.onblur = '';
						this.cancel(cell);
					}
				}.bindAsEventListener(this));
				field.observe('change', function(event) {
					this._submit(event);
				}.bindAsEventListener(this));
				field.onblur = this._cancel.bindAsEventListener(this);
				break;
			}
			form.appendChild(field);
			if(op.attributes.rows > 1) { // *** DY
				form.appendChild(document.createElement("br"));
			}
			if(op.showSubmit) {
				var okButton = document.createElement("input");
				okButton.type = "submit";
				okButton.value = op.submitText;
				okButton.className = 'editor_ok_button';
				form.appendChild(okButton);
			}
			if(op.showCancel) {
				var cancelLink = document.createElement("a");
				cancelLink.href = "#";
				cancelLink.appendChild(document.createTextNode(op.cancelText));
				cancelLink.onclick = this._cancel.bindAsEventListener(this);
				cancelLink.className = 'editor_cancel';      
				form.appendChild(cancelLink);
			}
			// *** DY modified
			form.setStyle({'width': formwidth + 'px',
						  'height': formheight + 'px'});
			field.setStyle({'height': cell.getHeight() + 'px'});
			// temporarily undo hanging indent, otherwise the form element is offset bizarrely to the right, but the text input isn't!
			cell.style.paddingLeft = '0px';
			cell.style.textIndent = '0px';
			// cell.innerHTML = '';
			// cell.appendChild(form);
			// stick it in before instead
			cell.insert({ top : form });
			field.value = oldValue; //TableKit.getCellText(cell);
			field.focus(); // reversing these last two lines for now until i can figure out why Safari is showing a blank box otherwise
			// *** DY
	},
	_submit : function(e) { // *** DY comment: this helper fn takes an event arg, and passes on two args to the main submit fn
		var cell = Event.findElement(e,'td');
		var form = Event.findElement(e,'form');
		Event.stop(e);
		this.submit(cell,form);
	},
	submit : function(cell, form) {
		var op = this.options;
		form = form || cell.down('form');
		var head = $(TableKit.getHeaderCells(null, cell)[cell.cellIndex]);
		var row = cell.up('tr');
		var rowid = row.id;
		var table = cell.up('table');
		// *** DY added custom params
		var raw = TableKit.tables[table.id].raw, s, tbl;
		s = 'row=' + (TableKit.getRowIndex(row)+1) + '&cell=' + (cell.cellIndex+1);
		s += TableKit.option1('editAjaxExtraParams', table.id)||'';
		if (raw) {
			s += '&tbl=' + raw.tblname;
			rowid = rowid.substring(3);
		}
		s += '&id=' + rowid + '&field=' + head.id + '&' + Form.serialize(form);
		new Ajax.Request(op.ajaxURI || TableKit.option1('editAjaxURI', table.id), Object.extend(op.ajaxOptions || TableKit.option1('editAjaxOptions', table.id), {
			// *** DY changed Ajax.Update to Request to better handle rawData: escapeHTML on client side, not server side
			postBody : s,
			onSuccess : function(t) {
				var data = TableKit.getCellData(cell), text = t.responseText, xform, colheads, rowdata;
				data.active = false;
				data.refresh = true; // mark cell cache for refreshing, in case cell contents has changed and sorting is applied
				if (raw) {
					if (t.headerJSON) {
						var fields = t.headerJSON.fields;
						rowdata = t.headerJSON.data[0];
						for (var i = 0; i < fields.length; ++i) {
							raw.data[rowid][raw.cols[fields[i]]] = rowdata[i];
						}
					}
					raw.data[rowid][raw.cols[head.id]] = text;
					colheads = table.tHead.rows[0].cells;
					rowdata = raw.data[rowid];
					$A(row.cells).each(function (c,i) {
						if (raw.config[colheads[i].id].transform) {
							c.innerHTML = raw.config[colheads[i].id].transform((rowdata[i]||'').escapeHTML(), rowid, rowdata, i); // see note in initByAjax about null
						} else if (rowdata[i] !== undefined) {
							c.innerHTML = (rowdata[i]||'').escapeHTML();
						}
					});
					if (raw.config._postprocess_each) raw.config._postprocess_each(row);
				} else {
					cell.innerHTML = text.escapeHTML();
				}
				// restore possible hanging ident
				cell.style.paddingLeft = null;
				cell.style.textIndent = null;
			},
			onFailure : function(t) {
				alert('Error: ' + t.responseText);
				// *** DY revert the field
				var data = TableKit.getCellData(cell);
				data.active = false;
				cell.innerHTML = data.htmlContent;
				data.htmlContent = '';
			}
		}));
	},
	_cancel : function(e) {
		var cell = Event.findElement(e,'td');
		Event.stop(e);
		this.cancel(cell);
	},
	cancel : function(cell) {
		var data = TableKit.getCellData(cell);
		cell.innerHTML = data.htmlContent;
		data.htmlContent = '';
		data.active = false;
		// *** DY restore possible hanging ident
		cell.style.paddingLeft = null;
		cell.style.textIndent = null;
		// *** DY
	}
};

TableKit.Editable.textInput = function(n,attributes) {
	TableKit.Editable.addCellEditor(new TableKit.Editable.CellEditor(n, {
		element : 'textarea', // *** DY always be a textarea, not input
		attributes : Object.extend({name : 'value', rows : '1', cols: '20' /* NOT input and type: 'text' */}, attributes||{})
	}));
};
TableKit.Editable.textInput('text-input');

TableKit.Editable.multiLineInput = function(n,attributes) {
	TableKit.Editable.addCellEditor(new TableKit.Editable.CellEditor(n, {
		element : 'textarea',
		attributes : Object.extend({name : 'value', rows : '5', cols : '20'}, attributes||{})
	}));	
};	
TableKit.Editable.multiLineInput('multi-line-input');

TableKit.Editable.selectInput = function(n,attributes,selectOptions) {
	TableKit.Editable.addCellEditor(new TableKit.Editable.CellEditor(n, {
		element : 'select',
		attributes : Object.extend({name : 'value'}, attributes||{}),
		'selectOptions' : selectOptions
	}));	
};

/*
TableKit.Bench = {
	bench : [],
	start : function(){
		TableKit.Bench.bench[0] = new Date().getTime();
	},
	end : function(s){
		TableKit.Bench.bench[1] = new Date().getTime();
		alert(s + ' ' + ((TableKit.Bench.bench[1]-TableKit.Bench.bench[0])/1000)+' seconds.') //console.log(s + ' ' + ((TableKit.Bench.bench[1]-TableKit.Bench.bench[0])/1000)+' seconds.')
		TableKit.Bench.bench = [];
	}
} */

document.observe("dom:loaded", TableKit.load);