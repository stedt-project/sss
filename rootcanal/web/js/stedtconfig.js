// if the window loses focuses (e.g., if the user follows a link inside the etymon info popup),
// then prevent the popup from disappearing (we want it to still be there when the user returns to the page)
// doesn't seem to work in Firefox, so maybe can be improved someday using event handlers
jQuery(window).blur(function() { window.clearTimeout(etHideTimer) });

// This is hideous, but necessary for setTimeout to be able to pass arguments to the callback function in IE
// (without using an anonymous closure)
// Otherwise, show_tag doesn't get the event object
// see https://developer.mozilla.org/en-US/docs/DOM/window.setTimeout
/*\
|*|
|*|  IE-specific polyfill which enables the passage of arbitrary arguments to the
|*|  callback functions of javascript timers (HTML5 standard syntax).
|*|
|*|  https://developer.mozilla.org/en-US/docs/DOM/window.setInterval
|*|
|*|  Syntax:
|*|  var timeoutID = window.setTimeout(func, delay, [param1, param2, ...]);
|*|  var timeoutID = window.setTimeout(code, delay);
|*|  var intervalID = window.setInterval(func, delay[, param1, param2, ...]);
|*|  var intervalID = window.setInterval(code, delay);
|*|
\*/
 
if (document.all && !window.setTimeout.isPolyfill) {
  var __nativeST__ = window.setTimeout;
  window.setTimeout = function (vCallback, nDelay /*, argumentToPass1, argumentToPass2, etc. */) {
    var aArgs = Array.prototype.slice.call(arguments, 2);
    return __nativeST__(vCallback instanceof Function ? function () {
      vCallback.apply(null, aArgs);
    } : vCallback, nDelay);
  };
  window.setTimeout.isPolyfill = true;
}
 
if (document.all && !window.setInterval.isPolyfill) {
  var __nativeSI__ = window.setInterval;
  window.setInterval = function (vCallback, nDelay /*, argumentToPass1, argumentToPass2, etc. */) {
    var aArgs = Array.prototype.slice.call(arguments, 2);
    return __nativeSI__(vCallback instanceof Function ? function () {
      vCallback.apply(null, aArgs);
    } : vCallback, nDelay);
  };
  window.setInterval.isPolyfill = true;
}

// function findPos(obj) { // based on http://www.quirksmode.org/js/findpos.html
// 	var curleft = 0, curtop = 0;
// 	if (obj.offsetParent) { // if the browser supports offsetParent
// 		do {
// 			// if (obj === $('lexicon')) break;
// 			curleft += obj.offsetLeft;
// 			curtop += obj.offsetTop;
// 		} while (obj = obj.offsetParent);
// 		return [curleft,curtop];
// 	}
// };

// code to make things draggable and droppable for the subroots
// var makesubroot = function (dragged, destination, e) {
// 	var data = TableKit.tables['etyma_resulttable'].raw.data;
// 	var cols = TableKit.tables['etyma_resulttable'].raw.cols;
// 	var src = dragged.identify().sub('tag',''); // get just the numbers (id is "tag###")
// 	var dst = destination.identify().sub('tag','');
// 	var srcsuper = data[src][cols['etyma.supertag']];
// 	new Ajax.Request(baseRef + 'update', {
// 		parameters: {
// 			tbl:'etyma',
// 			field:'etyma.supertag',
// 			id:src,
// 			value: srcsuper == dst ? src : dst
// 		},
// 		onSuccess: function(transport) {
// 			if (srcsuper == dst) {
// 				// if it's already the subroot of the destination,
// 				// make it a main root, and resort.
// 				data[src][cols['etyma.supertag']] = src;
// 				destination.up('tbody').insert(dragged.up('tr'));
// 				dragged.up('td').nextSibling.innerHTML = '';
// 			} else {
// 				data[src][cols['etyma.supertag']] = dst;
// 				destination.up('tr').insert({after:dragged.up('tr')});
// 				dragged.up('td').nextSibling.innerHTML = dst;
// 			}
// 			
// 			// restripe
// 			TableKit.reload();
// 		},
// 		onFailure: function(transport) {
// 			alert(transport.responseText);
// 		},
// 		onComplete: function() {
// 			dragged.setAttribute('style',''); // put it back where it came from
// 		}
// 	});
// };
// var make_draggable_id = function z(obj) {
// 	// z.scrollElement should be set to the containing element to be scrolled
// 	z.onstart = function(d,e) { z.old_y = e.pointerY() };
// 	z.ondrag = function (d,e) {
// 		if (!z.moved && (Math.abs(e.pointerY()-z.old_y)>2)) z.moved=1
// 	};
// 	new Draggable(obj, { revert: 'failure', constraint:'vertical', scroll:z.scrollElement,
// 		onStart:z.onstart, onDrag:z.ondrag
// 	});
// 	Droppables.add(obj,
// 	  { hoverclass : 'hoverdrop',
// 		accept : 'tagid',
// 		onDrop : makesubroot
// 	  } );
// };

function show_notes(rn, container) {
	new Ajax.Updater(container, baseRef + 'notes/notes_for_rn', {
		parameters: {rn:rn},
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
};


var current_cog = 0;
function show_cognates(tag) {
	if (current_cog) {
		$$('.r' + current_cog).each(function (item) {item.removeClassName('cognate')});
	}
	$$('.r' + tag).each(function (item) {item.addClassName('cognate')});
	current_cog = tag;
};

var ajax_make_table = function (transport,json){ // function suitable for the onSuccess callback
	if (!transport.responseText) {
		alert("ERROR: no response text");
		return;
	}
	var tabledata = transport.responseText.evalJSON();
	var tablename = tabledata.table;
	var n = tabledata.data.length;
	$(tablename + '_status').update(n ? (n > 4 ? (n + ' records found.') : '') : 'No records found.');
	TableKit.Raw.initByAjax(
		tablename + '_resulttable',
		tablename,
		tabledata,
		setup[tablename],
		stedtuserprivs&1 ? baseRef+'update' : 0,
		tablename + '_results'
	);
	$(tablename + '_resulttable').addClassName('hangindent');
};
function show_supporting_forms(tag) {
	new Ajax.Request(baseRef + 'search/ajax', {
		method: 'get',
		parameters: { tbl:'lexicon', analysis:tag },
		onSuccess: function (transport,json) { ajax_make_table(transport,json); show_cognates(tag); },
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
	return false;
};

function SylStation() {
	var tonechars = "⁰¹²³⁴⁵⁶⁷⁸0-9ˊˋ˥-˩";
	var delimchars = "-=≡≣+.,;/~◦⪤()↮ ";
	var regexp_to_hide_parens = new RegExp('\\(([^' + delimchars + tonechars + ']+)\\)','g');
	var regexp_for_starting_delims = new RegExp('^([' + delimchars + ']+)');
	var rebytonepostfix = "([^" + delimchars + tonechars + "]+[" + tonechars + "]+(?:\\|$)?)([" + delimchars + "]*)";
		// special case "(?:\\|$)?" here to handle trailing overriding delimiter
		// (non-grouping | at end of string; it's double-escaped since the backslash needs to show up in the regex)
	var rebytoneprefix = "([" + tonechars + "]{1,2}[^" + delimchars + tonechars + "]+)([" + delimchars + "]*)";
	var rebydelims = "([^" + delimchars + "]+)([" + delimchars + "]*)";

	var syl_ary;   // array of parsed out "syllables"
	var delim_ary; // array of the delimiters following the "syllables", above
	var prefix = '';    // string that might precede the first syl

	var syllabify_by_regex = function (s, re) {
		// replace parens surrounding "character" chars with temporary full-width equivalents;
		// all remaining parens are treated as delimchars.
		s = s.replace(regexp_to_hide_parens, '（$1）');
		var m, prefix_match, is_suffix = regexp_for_starting_delims.test(s); //s.charAt(0) === '-';
		syl_ary = []; // clear out our return values
		delim_ary = [];
		prefix = '';
		if (is_suffix) {
			prefix_match = regexp_for_starting_delims.exec(s);
			prefix = prefix_match[1];
			s = s.substring(prefix.length);
		}
		re = new RegExp("^" + re);
		while (m = re.exec(s)) {
			s = s.substring(m[0].length);
			if (m[1].indexOf('|')!==-1 && syl_ary.length) { // overriding delim
				syl_ary[syl_ary.length-1] += delim_ary.pop();
				syl_ary[syl_ary.length-1] += m[1].replace('|', '').replace('（','(').replace('）',')');
			} else {
				syl_ary.push(m[1].replace('（','(').replace('）',')'));
			}
			delim_ary.push(m[2].replace(/◦/,'&thinsp;')); // STEDT delim -> thin space
			// if this &thinsp; shows up in the interface, it's because
			// it was overridden by an overriding delimiter. No one should
			// be overriding a STEDT delimiter; they can just delete it.
			// So consider this a feature of sorts... STEDT delims get converted
			// to an escaped HTML char code if they're overridden!
		}
		if (!syl_ary[0]) syl_ary[0] = '';
// 		if (is_suffix) {
// 			syl_ary[0] = prefix + syl_ary[0]; // "-"
// 		}
		if (s) { // if it fails, we should append the residue at the end
			syl_ary[syl_ary.length-1] += s;
		}
		return !s.length; // true if the parsing was exhaustive, false if there's leftover unmatchable cruft
	};
	this.syllabify = function (s, n) { // string and number of tags to match
		if (!syllabify_by_regex(s, rebytonepostfix)) {
			if (!syllabify_by_regex(s, rebytoneprefix)) {
				if (!syllabify_by_regex(s, rebydelims)) {
					// alert("no re matches! " + s + "\n" + syl_ary);
				}
			}
		}
		return [syl_ary, delim_ary, prefix];
	};
};
var SYLSTATION = new SylStation(); // for efficiency, we make this object once

var stedttagger = stedtuserprivs & 1;
var skipped_roots = {};
function show_root(tag) {
	new Ajax.Request(baseRef + 'search/etyma', {
		method: 'get',
		parameters: { 'etyma.tag' : tag },
		onSuccess: function (transport,json) { ajax_make_table(transport,json); show_cognates(tag); },
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
};
$(document.body).insert(new Element('div', {id:'info',style:'display:none'}).update('<div></div>'));
// $(document).on('keydown', function (e) { if (e.keyCode === Event.KEY_ESC) { $('info').hide() } });
var show_tag = function z(e) {
	var tags, elem = e.findElement(),
		classnames = $w(elem.className).findAll(function(s){return s.substring(0,2)==='t_'});
	e.stop();
	// this code is for handling clicks on the same elink; no longer needed
//	if (elem === z.curr_elem && $('info').visible() && event.type === 'click') {
//		$('info').hide();
//		z.curr_elem = '';
//		return;
//	}
	if (classnames.length) tags = classnames.invoke('substring', 2).map(function(n){return parseInt(n,10)}); else return;
	if (z.cache[tags.join(',')]) {
		z.show_info(z.cache[tags.join(',')], elem);
		return;
	}
	new Ajax.Request(baseRef + 'search/elink', {
		method: 'get',
		parameters: { t : tags },
		onSuccess: function (t) {
			t = t.responseText;
			z.show_info(t, elem);
			z.cache[tags.join(',')] = t;
		},
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
};
show_tag.cache = {};
show_tag.show_info = function (t, elem) {
	var x = $('info'), loc = elem.positionedOffset();
	elem.getOffsetParent().insert(x);
	x.down('div').update(t);
	x.setStyle({left:loc[0] + 'px', top:loc[1] + 'px'}).show();
	show_tag.curr_elem = elem;
};

var etShowTimer = 0;
var etHideTimer = 0;
var et_info_popup = function (e) {

	// debugging
	// window.console && console.log && console.log("Event: " + e.type, "| Target: ", e.target);

	if (e.type === 'click' && $w(e.target.className)[0] === 'elink') {  // if the user clicks on an elink, show the info popup immediately
		window.clearTimeout(etHideTimer);
		window.clearTimeout(etShowTimer);
		show_tag(e);
	}
	else if (e.type === 'mouseover' && $w(e.target.className)[0] === 'elink') {  // the user moused over an elink
	
		if (e.findElement() === show_tag.curr_elem && $('info').visible()) {
			// if the info popup is visible and is associated with the current elink, then
			// stop any countdown to clear the info popup
			window.clearTimeout(etHideTimer);
		}
		else {
			// otherwise, show the new info popup after a delay
			// (the mouseout/mouseleave event will handle hiding the old info popup)
			etShowTimer = window.setTimeout(show_tag, 500, e);		
		}
	}
	else if (e.type === 'mouseout' && $w(e.target.className)[0] === 'elink') {  // the user moused off an elink
		// if the user moused off the elink before the info popup showed, prevent it from showing
		window.clearTimeout(etShowTimer);
		
		// set a small delay before the info div hides
		etHideTimer = window.setTimeout(function () { $('info').hide() }, 375);
	}
	else if (e.type === 'mouseenter') {	// this event type is only associated with the info popup, so we don't have to check the target
		// the user moused into the info popup
		// don't let the info popup disappear
		window.clearTimeout(etHideTimer);
	}
	else if (e.type === 'mouseleave') {	// this event type is only associated with the info popup, so we don't have to check the target
		// the user moused out of the info popup
		// set a small delay before the info div hides
		etHideTimer = window.setTimeout(function () { $('info').hide() }, 375);
	}
};

// use jQuery hover (combo of mouseenter & mouseleeave) to handle mouse movements into the info popup (which has an unnamed inner div)
// NOTE that these will pass jQuery-type event objects to et_info_popup (not Prototype)
// so you can't use stuff like findElement()
jQuery("#info").hover(et_info_popup);


// How to activate tagging mode? (== box around some syllable somewhere)
// -> double-click a syllable
//		OR hit up/down arrow
//	This should activate a new column of numbers 1-9 in the etyma table.
// How to end?
// -> hit Esc when no changes are pending.
// Esc will (1) hide info (2) cancel changes (3) exit tagging mode.
function type$less (e) { // yes, $ is allowed in variable names!
//	right/left: Select next/prev syllable.
//		Show selection with heavy border around syllable and corresponding tag numbers, if any.
//	up/down/return: prev/next lex record.
//		Save the current tagging, if different.
//		Select an appropriate syllable of the next record. Try to skip morphemes marked as p/s.
//		Scroll to visible (1/3 from top or bottom) if it's above/below the line.
//	1-9: tag currently selected syllable with the etymon with that number
//		highlight (yellow fade) the current syllable, and update the 
//	Esc: undo changes to current record.
//		Highlight unsaved changes in yellow.
//		Put a little gray box with white text underneath it to remind the user.

// 	if (e.keyCode === Event.) {
// 	
// 	}
};

// setup is accessible above because vars are "hoisted" in js
var setup = { // in the form setup.[tablename].[fieldname]
	etyma : {
		_key: 'etyma.tag',   // maybe send it from the server?
// 		_postprocess_onadd: function (row) {
// 			if (stedtuserprivs & 1) make_draggable_id(row.down('span.tagid'));
// //			console.log(row);
// //			console.log(row.down('span.tagid'));
// 		},
		_postprocess: function (tbl) {
// 			var z = make_draggable_id;
// 			if (stedtuserprivs & 1) { // don't allow making mesoroots by dragging unless user has tagging privileges
// 				z.scrollElement = $('etyma') || window; // if we're not in the combo view, there's no etyma div; if we pass a nonexistent element to Draggable, prototype will crash (in firefox and possibly other browsers)
// 				tbl.select('span.tagid').each(z);
// 				tbl.on('click', 'span.tagid', function (e) {
// 					if (z.moved) e.stop();  // don't follow the link if it was dragged
// 					z.moved=0; // reset
// 				});
// 			}
			tbl.on('click', 'a.lexlink', function (e) {
				show_supporting_forms(e.findElement('tr').id.substring(3));
				e.stop();
			});
			tbl.on('click', 'input.del_btn', function (e) {
				e.stop();
				// do_delete_check is defined in etyma.js; OK to put here because all the input.del_btn's are also created there
				do_delete_check(e.findElement('tr').id.substring(3));
			});
			tbl.on('mouseover', 'a.elink', et_info_popup);
			tbl.on('mouseout', 'a.elink', et_info_popup);
		},
		'etyma.tag' : {
			label: '#',
			vert_show: true,
			noedit: true,
			size: 40,
			transform: function (v) {
				return '<a href="' + baseRef + 'etymon/' + v
						+ '" target="stedt_etymon" class="elink t_'+v+'">' + (stedtuserprivs ? '' : '#') + v + '</a>';
			}
		},
		'num_recs' : {
			label: 'reflexes',
			noedit: true,
			size: 30
		},
		'u_recs' : {
			label: 'u',
			noedit: true,
			size: 30
		},
		'o_recs' : {
			label: 'o',
			noedit: true,
			size: 30
		},
		'chapters.chaptertitle' : {
			hide: true,
			noedit: true
		},
		'etyma.chapter' : {
			label: 'ch.',
			size: 70,
			noedit: !(stedtuserprivs & 1),
			hide: !(stedtuserprivs & 2),
			transform : (stedtuserprivs & 2)
				? function (v, key, rec, n) {
					return '<a href="' + baseRef + 'chap/' + v + '" target="stedt_chapters" title="'
					+ rec[n-1].replace(/&/g,'&amp;') + '">' + v + '</a>';
				  }
				: null
		},
		'etyma.protoform' : {
			vert_show: true,
			noedit: !(stedtuserprivs & 1),
			label: 'protoform',
			size: 120
		},
		'etyma.protogloss' : {
			vert_show: true,
			noedit: !(stedtuserprivs & 1),
			label: 'protogloss',
			size: 200
		},
		'etyma.grpid': {
			label: 'plg',
			size: 50,
			transform: function (v,k,rec,n) {
				if (v === '0') return '';
				return rec[n+1] || v;
			},
			noedit: true // disable on the main page for now until we figure out how to get the popup menu to show up everywhere (not just in edit.tt)
		},
		'languagegroups.plg': {
			hide: true
		},
		'languagegroups.grpno': {
			hide: true
		},
		'is_mesoroot' : {
			hide: true
		},
		'etyma.notes' : {
			label: 'tagging note',
			hide: !(stedtuserprivs & 2),
			noedit: !(stedtuserprivs & 1),
			size: 160
		},
		'num_notes' : {
			label: 'notes',
			noedit: true,
			hide: !(stedtuserprivs & 2),
			size: 30,
			transform: function (v,k,rec,n) {
				if (rec[n+1] === '0') return v;
				return v + ' (' + rec[n+1] + ' Ch.)';
			}
		},
		'num_comparanda' : {
			label: 'comparanda',
			noedit: true,
			hide: true
		},
		'etyma.xrefs' : {
			label: 'xrefs',
			size: 20
		},
		'etyma.status' : {
			label: 'status',
			hide: !(stedtuserprivs & 2),
			noedit: !(stedtuserprivs & 8),
			size: 20
		},
		'etyma.exemplary' : {
			label: 'x',
			size: 10
		},
		'etyma.sequence'  : {
			label: 'seq',
			noedit: true,
			hide: !(stedtuserprivs & 2),
			size: 50,
			transform: function (v,k,rec,n) {
				if (v !== '0.0') {
					if (v.substr(-2) === '.0') v = v.slice(0,-2);
					else v = v.slice(0,-2) + String.fromCharCode(96+ +v.substr(-1));
					v = '(' + v + ')';
				} else {
					v = rec[n-1] ? '[-]' : '';
				}
				if (stedtuserprivs & 8 && rec[n-1]) {
					return '<a href="' + baseRef + 'chapters/seq?c=' + rec[n-1]
					+ '" target="stedt_sequencer">' + v + '</a>'
				}
				return v;
			}
		},
		'etyma.semkey' : {
			label: 'semkey',
			size: 50,
			transform : function (v) {
				return '<a href="' + baseRef + 'edit/etyma' + '?etyma.semkey=' + v + '" target="edit_etyma">' + v + '</a>';
			}
		},
	    'etyma.prefix' : {
		label: 'pfx',
		hide: false,
		size: 30
	    },
	    'etyma.initial' : {
		label: 'I',
		hide: false,
		size: 30
	    },
	    'etyma.rhyme' : {
		label: 'R',
		hide: false,
		size: 30
	    },
	    'etyma.tone' : {
		label: 'T',
		hide: false,
		size: 30
	    },
		'etyma.possallo'  : {
			label: '⪤?',
			size: 40
		},
		'etyma.allofams' : {
			label: '⪤',
			size: 20
		},
		'etyma.public' : {
			label: 'public',
			size: 15,
			noedit: !(stedtuserprivs & 16)
		},
		'users.username' : {
			label: 'owner',
			hide: !(stedtuserprivs & 2),
			size: 60,
			noedit: true
		},
		'etyma.uid' : { // this is just a search field
			label: 'owner'
		}
	},
	lexicon : {
		_key: 'lexicon.rn',
		_cols_done: function (c) {
			if (c['user_an']) setup.lexicon._an2 = true;
		},
		_postprocess: function (tbl) {
			tbl.on('click', 'a.lexadd', function (e) {
				showaddform('L', e.findElement('tr').id); // not sure why this works, since showaddform is defined in another file!
				e.stop();
			});
			tbl.on('click', 'a.note_retriever', function (e) {
				show_notes(e.findElement('tr').id.substring(3), e.findElement('td'));
				e.stop();
			});
			tbl.on('mouseover', 'a.note_retriever', function (e) {
				var rn = e.findElement('tr').id.substring(3);
				Tips.add(e.findElement(), e, {ajax:{url:baseRef + 'notes/notes_for_rn', options:{parameters:{rn:rn}}},
					stem:true, delay:0, fixed:true, showEffectDuration:0, className:'glass'});
			});
			tbl.on('mouseover', 'a.elink', et_info_popup);
			tbl.on('mouseout', 'a.elink', et_info_popup);
			tbl.on('click', 'a.elink', function (e) { e.stop(); et_info_popup(e) });

			// stop here if it's etymon view, which (a) doesn't allow sorting,
			// and (b) does its own thing for adding language group headers
			if (tbl.id !== 'lexicon_resulttable') return;

			// special sort function
			// this makes makes "language" sort by grpno, then languagename
			var t = TableKit.tables[tbl.id];
			t.customSortFn = function (rows, index, tkstdt, order) {
				var lg_index = t.raw.cols['languagenames.language'];
				$$('.lggroup').invoke('remove');
				// after removing a bunch of TR's from the DOM in the above line,
				// the "rows" array may now include some deleted rows
				// because "rows" came from TableKit.getBodyRows, which
				// made a copy using $A(). So, we need to manually modify "rows"
				// to excise the offending items; otherwise they might get
				// reinserted (e.g. by Firefox) when tablekit reinserts the
				// contents of the rows array into the table.
				for (var i = rows.length-1; i >= 0; --i) {
					if ($(rows[i]).hasClassName('lggroup')) {
						rows.splice(i, 1);
					}
				}
				if (index !== lg_index) return false;
				var grpno_index = t.raw.cols['languagegroups.grpno'];
				rows.sort(function (a,b) {
					var a_id = a.id.substring(3); // strip off the "le_" part of the tr's id.
					var b_id = b.id.substring(3);
					// sort by grno first
					var result = TableKit.Sortable.Type.compare(t.raw.data[a_id][grpno_index], t.raw.data[b_id][grpno_index]);
					if (result === 0) {
						result = tkstdt.compare(t.raw.data[a_id][lg_index], t.raw.data[b_id][lg_index]);
					}
					return result*order;
				});
				window.setTimeout(setup.lexicon._add_lggrp_headers,0); // defer this so tablekit can do its stuff first
				return true;
			};
			if (!$('manual_paging_f1') || !$('manual_paging_f1').sortkey) {
				// if there's no manual paging, or if there is but there's no 'sortkey' INPUT element, it's the default sort and we can add the subgroup headings
				window.setTimeout(setup.lexicon._add_lggrp_headers,0);
			}
		},
		_add_lggrp_headers: function () {
			var t = $('lexicon_resulttable');
			if (!t.tBodies[0].rows.length) return; // if result table is empty, there's nothing to do
			var hcell = t.select('th[id="languagegroups.grpno"]')[0];
			if (!hcell) {
				window.console && console.log && console.log('couldn\'t find grpno_index!');
				return;
			}
			var grpno_index = hcell.cellIndex;
			var tbody = t.tBodies[0];
			var lastgrpno = '';
			var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
			$A(tbody.rows).each(function (row, j) {
				var grpno = row.cells[grpno_index].innerHTML;
				var grp = row.cells[grpno_index+1].innerHTML;
				if (lastgrpno !== grpno) {
					var newrow = new Element('tr', {'class':'lggroup'});
					var c = newrow.insertCell(-1);
					c.colSpan = visiblecols;
					c.innerHTML = grpno + ' ' + grp;
					row.insert({before:newrow});
					lastgrpno = grpno;
				}
			});
		},
		'lexicon.rn' : {
			label: 'rn',
			noedit: true,
			hide: !(stedtuserprivs & 2),
			size: 70
		},
		'analysis' : {
			label: 'analysis',
			noedit: !(stedtuserprivs & 8),
			hide: !(stedtuserprivs & 2),
			size: 80,
			transform: function (v) {
				return v.replace(/, */g,', ');
			}
		},
		'user_an' : {
		        label: 'your analysis',
			size: 80,
			hide: !(stedtuserprivs & 2),
			transform: function (v) {
				return v.replace(/, */g,', ');
			}
		},
		'other_an' : {
			label: 'others\' analyses',
			noedit: true,
			size: 80,
			transform: function (v) {
				if (v==='') return '';
				var a, i, l, m, last_user = 0;
				a = v.split(',');
				l = a.length;
				v = '';
				for (i=0; i<l; ++i) {
					m = a[i].match(/^(\d+):(.+)/);
					if (m[1] !== last_user) {
						if (last_user !== 0)
							v += '<p>';
						v += m[1] + ':';
						last_user = m[1];
					} else {
						v += ', ';
					}
					if (parseInt(m[2],10))
					{ v += '<a href="#" class="elink t_' + m[2] + '">' + m[2] + '</a>'; }
					else v += m[2];
				}
				return v;
			}
		},
		'languagenames.lgid' : {
			label:'lgid',
			noedit: true,
			hide: true
		},
		'lexicon.reflex' : {
			label: 'form',
			noedit: !(stedtuserprivs & 1),
			size: 160,
			transform: function (v,key,rec) {
				if (!v) return '';
				var analysis = rec[1] || ''; // might be NULL from the SQL query
				var an2, t2;
				if (setup.lexicon._an2) {
					an2 = rec[2] || '';
					t2 = an2.split(',');
				} else {
					t2 = [];
				}
				var tags = analysis.split(',');
				var result = SYLSTATION.syllabify(v.unescapeHTML());
				// since the transform receives escaped HTML, but SylStation
				// treats semicolons as delims, we have to unescape (e.g.
				// things like "&amp;" back to "&") before passing to SylStation
				// and re-escape below when putting together the HTML string.
				var i, l = result[0].length, a = result[2], s, delim, link_tag, syl_class;
				for (i=0; i<l; ++i) {
					s = result[0][i];
					delim = result[1][i] || '&thinsp;'
					link_tag = '';
					syl_class = '';
					// figure out what class to assign (so it shows up with the right color)
					if (tags[i] && t2[i]) {
						syl_class = 't_' + tags[i]; // put this in for div#info purposes
						if (tags[i]===t2[i]) {
							// if stedt and user tags match, use the user's style
							syl_class += ' u' + t2[i];
							link_tag = skipped_roots[t2[i]] ? '' : t2[i];
						} else {
							// otherwise mark this syllable as a conflict
							syl_class += ' t_' + t2[i] + ' approve-conflict';
							link_tag = parseInt(t2[i],10) || tags[i];	// make sure syllable gets a link even if user tag is non-number (such as 'm')
						}
					} else if (tags[i]) { // if only one or the other of the columns is defined, then simply mark it as such.
						syl_class = 't_' + tags[i] + ' r' + tags[i];
						link_tag = skipped_roots[tags[i]] ? '' : tags[i];
					} else if (t2[i]) {
						syl_class = 't_' + t2[i] + ' u' + t2[i];
						link_tag = skipped_roots[t2[i]] ? '' : t2[i];
					}
					a += parseInt(link_tag,10)
						? '<a href="#"' + ' class="elink ' + syl_class + '">'
							+ s.escapeHTML() + '</a>' + delim
						: '<span class="' + syl_class + '">' + s.escapeHTML() + '</span>' + delim;
				}
				return a;
			}
		},
		'lexicon.gloss' : {
			label: 'gloss',
			noedit: !(stedtuserprivs & 16),
			size: 160
		},
		'lexicon.gfn' : {
			label: 'gfn',
			noedit: !(stedtuserprivs & 16),
			size: 30
		},
		'languagenames.language' : {
			label: 'language',
			noedit: true,
			size: 120,
			transform : function (v, key, rec, n) {
				return '<a href="' + baseRef + 'group/' + rec[n+1] + '/' + rec[n-1] + '"'
				+ ' title="' + rec[n+2] + ' - ' + rec[n+3].replace(/"/g,'&quot;') + '"'
				+ ' target="stedt_grps">' + v + '</a>';
			}
		},
		'languagegroups.grpid' : {
			label: 'grpid',
			noedit: true,
			hide: true
		},
		'languagegroups.grpno' : {
			label: 'group',
			noedit: true,
			size: 120,
			hide: true
		},
		'languagegroups.grp' : {
			label: 'grp',
			noedit: true,
			hide: true
		},
		'citation' : {
			label: 'source',
			noedit: true,
			size: 140,
			transform : function (v, key, rec, n) {
				return '<a href="' + baseRef + 'source/' + rec[n+1] + '" target="stedt_src" title="Click for bibliographic info">' + (v||rec[n+1]) + '</a>';
				// show srcabbr if citation is blank
			}
		},
		'languagenames.srcabbr' : {
			label: 'srcabbr',
			noedit: true,
			size: 80,
			hide: true
		},
		'lexicon.srcid' : {
			label: 'srcid',
			size: 60,
			noedit: !(stedtuserprivs & 16)
		},
		'lexicon.semcat' : {
			label: 'semcat'
		},
		'lexicon.semkey' : {
		    label: 'semkey',
			noedit: false,
			size: 50,
			hide: !(stedtuserprivs & 2),
			transform : function (v, key, rec, n) {
				// if chaptertitle (rec[n+1]) is blank, then the replace function makes the javascript just stop without errors (strange)
				// when the ajax search is performed
				// so only do this transform if rec[n+1] is not blank
				if (rec[n+1]) { return '<a href="' + baseRef + 'edit/glosswords' + '?glosswords.semkey=' + v + '" target="edit_glosswords" title="' + rec[n+1].replace(/&/g,'&amp;') + '">' + v + '</a>'; }
				else return v;
			}
		},
		'chapters.chaptertitle' : {
			noedit: true,
			hide: true
		},
		'num_notes' : {
			label: 'notes',
			noedit: true,
			size: 200,
			transform: function (v) {
				if (v == 0) return '';
				return '<a href="#" class="note_retriever">'
					+ v + '&nbsp;note' + (v == 1 ? '' : 's')
					+ '</a>';
			}
		},
		'lexicon.status' : {
			label:'status',
			noedit: false,
			size: 20,
			hide: !(stedtuserprivs & 1)
		}
	}
};
