setup.etymologies = {
	_key: 'etymologies.RnUidIndTag',
	'etymologies.RnUidIndTag': {
		noedit: true,
		hide: true,
		size: 20
	},
      	_postprocess: function (tbl) {
      		tbl.on('mouseover', 'a.elink', et_info_popup);
      		tbl.on('mouseout', 'a.elink', et_info_popup);
      		
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
      			var grpno_index = t.raw.cols['Lgrps.grpno'];
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
      			window.setTimeout(setup.etymologies._add_lggrp_headers,0); // defer this so tablekit can do its stuff first
      			return true;
      		};
      		if (!$('manual_paging_f1') || !$('manual_paging_f1').sortkey) {
      			// if there's no manual paging, or if there is but there's no 'sortkey' INPUT element, it's the default sort and we can add the subgroup headings
      			window.setTimeout(setup.etymologies._add_lggrp_headers,0);
      		}
      	},
      	_add_lggrp_headers: function () {
      		var t = $('etymologies_resulttable');
      		if (!t.tBodies[0].rows.length) return; // if result table is empty, there's nothing to do
      		var hcell = t.select('th[id="Lgrps.grpno"]')[0];
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
	'etymologies.rn': {
		label: 'rn',
		noedit: true,
		hide: false,
		size: 70,
		transform: function (v) {
			return '<a href="' + baseRef + 'edit/lexicon' + '?lexicon.rn=' + v
			 + '" target="stedt_lexicon" title="Open lexicon record">' + v + '</a>';
		}
	},
	'etymologies.uid': {
		label: 'tagger',
		noedit: true,
		size: 25
	},
	'etymologies.ind': {
		label: 'ind',
		noedit: true,
		hide: true,
		size: 20
	},
	'analysis': {
		label: 'analysis',
		noedit: true,
		hide: false,
		size: 80,
		transform: function (v) {
			return v.replace(/, */g,', ');
		}
	},
  	'lexicon.reflex' : {
  		label: 'form',
  		noedit: true,
  		size: 160,
  		transform: function (v,key,rec) {
  			if (!v) return '';
  			var analysis = rec[4] || ''; // might be NULL from the SQL query
  			var index = parseInt(rec[3],10); // index indicates which syllable is tagged with the etymon on the same row

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
  				if (tags[i]) { // if there is STEDT tagging, then mark it as such.
  					syl_class = 't_' + tags[i] + ' r' + tags[i];
  					link_tag = skipped_roots[tags[i]] ? '' : tags[i];
  				}
  				if (i === index) { // if the current syllable corresponds to the index
					// mark this syllable with the 'cognate' color (just to highlight it)
					syl_class = 't_' + tags[i] + + ' r' + tags[i] + ' cognate';
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
  		noedit: true,
  		size: 160
  	},
  	'lexicon.gfn' : {
  		label: 'gfn',
  		noedit: true,
  		size: 30
  	},
      	'languagenames.language' : {
      		label: 'language',
      		noedit: true,
      		size: 120,
      		transform : function (v, key, rec, n) {
			return '<a href="' + baseRef + 'edit/languagenames?languagenames.language=' +  v + '"'
			+ ' title="' + rec[n+2] + ' - ' + rec[n+3].replace(/"/g,'&quot;') + '"'
			+ ' target="edit_lgs">' + v + '</a>';
      		}
      	},
      	'Lgrps.grpid' : {
      		label: 'grpid',
      		noedit: true,
      		hide: true
      	},
      	'Lgrps.grpno' : {
      		label: 'group',
      		noedit: true,
      		size: 120,
      		hide: true
      	},
      	'Lgrps.grp' : {
      		label: 'grp',
      		noedit: true,
      		hide: true
      	},	
	'num_notes' : {
		label: 'notes',
		noedit: true,
		size: 80,
		transform : function (v) {
			if (v === '0') return '';
			var a = v.match(/\d+/g).map(function (s) {
				return '<a href="#foot' + s + '" id="toof' + s + '" class="footlink">' + s + '</a>';
			});
			return a.join(' ');
		}
	},
	'etyma.tag': {
		label: 'tag #',
		noedit: true,
		hide: false,
		size: 30,
		transform: function (v) {
			return '<a href="' + baseRef + 'edit/etyma' + '?etyma.tag=' + v
			 + '" target="edit_etyma" title="Open etyma record">' + v + '</a>';
		}
	},
      	'etyma.protoform' : {
      		noedit: true,
      		label: 'protoform',
      		size: 120
      	},
      	'etyma.protogloss' : {
      		noedit: true,
      		label: 'protogloss',
      		size: 200
      	},
      	'etyma.grpid': {
      		label: 'plg',
      		noedit: true,
      		hide: true
      	},
      	'Egrps.plg': {
      		label: 'plg',
      		noedit: true,
      		size: 50
      	},
      	'Egrps.grpno': {
      		hide: true
      	}
};
