if($('prov_heading') != undefined) {
	$('prov_heading').addTip('This etymon is provisional and should not be considered an "official" STEDT reconstruction.', 'Provisional Root', {className:'glass'});
}

setup['lexicon']['lexicon.rn'].transform = function (v) {
	if (stedtuserprivs & 2) {
		return '<a href="' + baseRef + 'edit/lexicon' + '?lexicon.rn=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
	else return v;
};
setup['lexicon']['languagegroups.grpno'].hide = true;
setup['lexicon']['languagegroups.genetic'] = {hide:true};
setup['lexicon']['notes.rn'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		var addlink = '<a href="#" class="lexadd" title="Add a note to this lexical item">[+]</a>';
		if (v === '0') return (stedtuserprivs & 1) ? addlink : '';
		var a = v.match(/\d+/g).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '" class="footlink">' + s + '</a>';
		});
		if (stedtuserprivs & 1) { a.push(addlink) };
		return a.join(' ');
	}
};
// override language transform from stedtconfig.js because lgid is in a different spot (for some reason)
setup['lexicon']['languagenames.language'].transform = function (v, key, rec, n) {
				return '<a href="' + baseRef + 'group/' + rec[n+1] + '/' + rec[n-4] + '"'
				+ ' title="' + rec[n+2] + ' - ' + rec[n+3].replace(/"/g,'&quot;') + '"'
				+ ' target="stedt_grps">' + v + '</a>';
};
if (stedt_other_username) {
	setup['lexicon']['user_an']['label'] = stedt_other_username + '\'s analysis';
	setup['lexicon']['user_an']['transform'] = function (v) {
		if (!v) return '';
		var s = v.replace(/, */g,', ');
		// hilite this gray if it doesn't contain the etyma we're concerned with on this page
		var to_be_approved = v.split(',').any(function (t) { return skipped_roots[t]; });
		if (to_be_approved) return s;
		return '<div class="approve-ignore">' + s + '</div>';
	};
	setup['lexicon']['analysis']['transform'] = function (v,key,rec,n) {
		var s = v.replace(/, */g,', ');
		// hilite this magenta if it would get clobbered on approval, i.e.
		// if it's not empty, the two cols are different, and the user_an is not gray
		if (v && v !== rec[n+1] && rec[n+1].split(',').any(function (t) { return skipped_roots[t]; })) {
			return '<div class="approve-replacing">' + s + '</div>';
		}
		return s;
	};
}
for (var i = 1; i < num_tables; i++) {
	TableKit.Raw.init('lexicon' + i, 'lexicon', setup['lexicon'], stedtuserprivs&1 ? baseRef+'update' : 0);
	TableKit.Rows.stripe('lexicon' + i);
	TableKit.tables['lexicon' + i].editAjaxExtraParams += '&uid2=' + uid2;
}

function show_meso_editform(e)
{
	var row = e.findElement().up('tr');
	var tag = row.up('table').getAttribute("tag");
	var grpid = row.id.substring(7);
	new Ajax.Updater('edit_meso_form', baseRef + 'tags/mesoforms', {
		parameters: {tag:tag,grp:grpid}
	});
	$('edit_meso_form').innerHTML = '';
	$('edit_meso_form').show();
	e.stop();
}

function submit_meso_editform(f)
{
	var rowid = 'grprow_' + f.grp.value;
	var reconstructions = $(rowid).down('span.pform');
	var cell = reconstructions.up('td');
	new Ajax.Updater(reconstructions, baseRef + 'tags/meso_edit', {
		parameters: f.serialize(true)
	});
	Effect.ScrollTo(cell, {offset:-100});
	$('edit_meso_form').hide();
	return false;
}

// prompt user to get new tag for migrating reflexes
function migrate_prompt(tag, grp_name, grp_num)
{
	var new_tag = prompt('Subgroup: ' + grp_name + '\nCurrent tag: #' + tag + '\nEnter new tag: ');

	// make sure user entered integer
	if (new_tag == null || new_tag == '')
	{
		// just ignore (they pressed 'cancel')
	}
	else if((parseFloat(new_tag) !== parseInt(new_tag)) || isNaN(new_tag))
	{
		alert('\"' + new_tag + '\" is not a valid tag number!');
	}
	else if(new_tag == tag)
	{
		alert('Reflexes are already tagged as #' + tag);
	}
	else
	{
		// create temporary hidden form to submit data to migration subroutine
		var temp_form = new Element('form', {method: 'post', action: baseRef + 'tags/migrate_tag'});
		temp_form.insert(new Element('input', {name: 'tag', value: tag, type: 'hidden'}));
		temp_form.insert(new Element('input', {name: 'grpno', value: grp_num, type: 'hidden'}));
		temp_form.insert(new Element('input', {name: 'new_tag', value: new_tag, type: 'hidden'}));
		$(document.body).insert(temp_form);
		temp_form.submit();		
	}	 
}

// put in section headings for language groups (and subgroup approval button)
var grp_confirm = function (tag, grp_name) {
	return confirm('Are you sure you want to approve tagging by ' + stedt_other_username
		+ ' for tag #' + tag + ' in subgroup ' + grp_name + '?');
};

if ($('languagegroups.grpno')) var grpno_index = $('languagegroups.grpno').cellIndex;
	// Counting backwards doesn't work (i.e., "tbody.rows[0].cells.length - 3")
	// because there may or may not be a HIST column depending on if the user is logged in.
	// Note that having multiple <TH> elements with the same id value ("languagegroups.grpid", etc.)
	// is technically incorrect HTML, but in this case seems to have no ill effect.

// You have to add these in *after* tablekit does its thing, otherwise it tries to apply transforms, etc.
// Though I suppose we could modify tablekit to ignore certain rows.
for (var i = 1; i < num_tables; i++) {
	var tbody = $('lexicon' + i).tBodies[0];
	var table_tag = $('lexicon' + i).getAttribute("tag"); // access a custom HTML attribute
	tbody.on('click', 'a.et_grp_add', function (e) {
		showaddform('M', table_tag, e);
		e.stop();
	});
	tbody.on('click', 'a.meso_editlink', show_meso_editform);
	var lastgrpno = '';
	var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
	var addlink = ' <a href="#" class="et_grp_add" title="Add a note to this subgroup">[+]</a>';
	var seen_grpnos = {};
	var insert_parent_bands = function (next_grpno, row) {
		var cell1, cell2, cell5;
		if (next_grpno.substr(0,1) === '0') return; // skip ST and TB
		while (next_grpno.length > 1) {
			next_grpno = next_grpno.substr(0, next_grpno.length-2); // chop off the last ".N"
			if (seen_grpnos[next_grpno]) return;
			if (!all_subgroups[next_grpno]) continue; // skip if it's not in the table
			if (all_subgroups[next_grpno].genetic === '0') continue; // skip if it's not a genetic node
			newrow = new Element('tr', {'class':'lggroup', 'id':'grprow_' + all_subgroups[next_grpno].grpid});
			row.insert({before:newrow});
			row = newrow;
			seen_grpnos[next_grpno] = 1;
			cell1 = newrow.insertCell(-1);
			cell2 = newrow.insertCell(-1);
			cell5 = newrow.insertCell(-1);
			cell1.colSpan = stedtuserprivs&1 ? 3 : 2;
			cell2.colSpan = visiblecols - (stedtuserprivs&1 ? 5 : 3);
			cell5.colSpan = stedtuserprivs&1 ? 2 : 1;
			cell2.className = "noedit";
			cell5.className = "noedit";
			cell1.innerHTML = all_subgroups[next_grpno].grpno + ' ' + all_subgroups[next_grpno].grp;
			if (stedtuserprivs & 1) {
				cell2.innerHTML = '<span class="pform"></span>  <small><a href="#" class="meso_editlink">add/edit reconstruction</a></small>';
				cell5.innerHTML += addlink;
			}
		}
	};
	$A(tbody.rows).each(function (row, j) {
		var grpno = row.cells[grpno_index].innerHTML;
		var grp = row.cells[grpno_index+1].innerHTML;
		var grp_isgenetic = parseInt(row.cells[grpno_index+2].innerHTML, 10);
		var grpid = row.cells[grpno_index-1].innerHTML;
		var newrow, meso, footnote, cell1, cell2, cell3, cell4, tmp_string;
		if (lastgrpno !== grpno) {
			// put in any mesoroots with no (immediate daughter) supporting forms
			// and same with the subgroup notes
			while ((mesoroots.length && mesoroots[0].grpno.localeCompare(grpno) < 0)
				|| (subgroupnotes.length && subgroupnotes[0].grpno.localeCompare(grpno) < 0)) {
				// yes we're working through two arrays and we have to interleave the values
				// if both arrays have something in them, we need to find which one comes first:
				if (mesoroots.length && subgroupnotes.length) {
					var cmp = mesoroots[0].grpno.localeCompare(subgroupnotes[0].grpno);
					if (cmp === 0) {
						meso = mesoroots.shift();
						footnote = subgroupnotes.shift();
					} else if (cmp < 0) {
						meso = mesoroots.shift();
						footnote = null;
					} else {
						footnote = subgroupnotes.shift();
						meso = null;
					}
				}
				// otherwise we only need to worry about one of the two arrays
				else if (mesoroots.length) {
					meso = mesoroots.shift();
					footnote = null;
				} else {
					footnote = subgroupnotes.shift();
					meso = null;
				}

				newrow = new Element('tr', {'class':'lggroup'});
				insert_parent_bands(meso?meso.grpno:footnote.grpno, row);
				row.insert({before:newrow});
				cell1 = newrow.insertCell(-1);
				cell2 = newrow.insertCell(-1);
				cell5 = newrow.insertCell(-1);
				cell1.colSpan = stedtuserprivs&1 ? 3 : 2;
				cell2.colSpan = visiblecols - (stedtuserprivs&1 ? 5 : 3);
				cell5.colSpan = stedtuserprivs&1 ? 2 : 1;
				cell2.className = "noedit";
				cell5.className = "noedit";
				if (meso) {
					seen_grpnos[meso.grpno] = 1;
					cell1.innerHTML = '<a name="' + meso.grpno + '">' + meso.grpno + ' ' + meso.grp + '</a>';
					tmp_string = '<span class="pform">' + (meso.variant?'('+meso.variant+') ':'') + meso.plg + ' *' + meso.form + ' ' + meso.gloss;
					// there may be multiple mesoroots for this node, so check for those too
					while (mesoroots.length && mesoroots[0].grpno === meso.grpno) {
						meso = mesoroots.shift();
						tmp_string += ',<br>' + (meso.variant?'('+meso.variant+') ':'') + meso.plg + ' *' + meso.form + ' ' + meso.gloss;
					}
					tmp_string += '</span>';
					newrow.id = 'grprow_' + meso.grpid;
					if (meso.genetic && (stedtuserprivs & 1)) tmp_string += ' <small><a href="#" class="meso_editlink">add/edit reconstruction</a></small>';
					cell2.innerHTML = tmp_string;
				}
				if (footnote) {
					seen_grpnos[footnote.grpno] = 1;
					cell1.innerHTML = footnote.grpno + ' ' + all_subgroups[footnote.grpno].grp;
					cell5.innerHTML = '<a href="#foot' + footnote.ind + '" id="toof' + footnote.ind + '" class="footlink">' + footnote.ind + '</a>';
					while (subgroupnotes.length && subgroupnotes[0].grpno === footnote.grpno) {
						footnote = subgroupnotes.shift();
						cell5.innerHTML += ' <a href="#foot' + footnote.ind + '" id="toof' + footnote.ind + '" class="footlink">' + footnote.ind + '</a>';
					}
				}
				if (stedtuserprivs & 1) cell5.innerHTML += addlink;
			}
			// check if current group has an explicit mesoroot
			if (mesoroots.length && mesoroots[0].grpno === grpno) {
				meso = mesoroots.shift();
			} else {
				meso = null;
			}
			// check if there's a subgroup note
			if (subgroupnotes.length && subgroupnotes[0].grpno === grpno) {
				footnote = subgroupnotes.shift();
			} else {
				footnote = null;
			}
			
			newrow = new Element('tr', {'class':'lggroup', 'id':'grprow_' + grpid});
			insert_parent_bands(grpno, row);
			row.insert({before:newrow});
			// there's not enough columns when you're not logged in, so adjust accordingly by not creating TD's for the approval and migration buttons
			cell1 = newrow.insertCell(-1);
			cell2 = newrow.insertCell(-1);
			if (stedtuserprivs & 1) cell3 = newrow.insertCell(-1);
			if (stedtuserprivs & 1) cell4 = newrow.insertCell(-1);
			cell5 = newrow.insertCell(-1);
			cell1.colSpan = stedtuserprivs & 1 ? 3 : 2;
			cell2.colSpan = stedtuserprivs & 1 ? 2 : visiblecols - 3;
			if (stedtuserprivs & 1) cell3.colSpan = 1;
			if (stedtuserprivs & 1) cell4.colSpan = visiblecols - 8;
			cell5.colSpan = stedtuserprivs & 1 ? 2 : 1;
			cell2.className = "noedit"; // prevent tablekit from trying to edit this cell. Not needed for cell1 since it's in the rn column
			if (stedtuserprivs & 1) cell3.className = "noedit";
			if (stedtuserprivs & 1) cell4.className = "noedit";
			cell5.className = "noedit";
			cell1.innerHTML = '<a name="' + grpno + '">' + grpno + ' ' + grp + '</a>';
			seen_grpnos[grpno] = 1;
			if (meso) {
				tmp_string = '<span class="pform">' + (meso.variant?'('+meso.variant+') ':'') + meso.plg + ' *' + meso.form + ' ' + meso.gloss;
				// there may be multiple mesoroots for this node, so check for those too
				while (mesoroots.length && mesoroots[0].grpno === meso.grpno) {
					meso = mesoroots.shift();
					tmp_string += ',<br>' + (meso.variant?'('+meso.variant+') ':'') + meso.plg + ' *' + meso.form + ' ' + meso.gloss;
				}
				tmp_string += '</span>';
				cell2.innerHTML = tmp_string;
			}
			if (grp_isgenetic && (stedtuserprivs & 1)) {
				if (!meso) cell2.innerHTML = '<span class="pform"></span>';
				cell2.innerHTML += ' <small><a href="#" class="meso_editlink">add/edit reconstruction</a></small>';
			}
			if (footnote) {
				cell5.innerHTML = '<a href="#foot' + footnote.ind + '" id="toof' + footnote.ind + '" class="footlink">' + footnote.ind + '</a>';
				while (subgroupnotes.length && subgroupnotes[0].grpno === footnote.grpno) {
					footnote = subgroupnotes.shift();
					cell5.innerHTML += ' <a href="#foot' + footnote.ind + '" id="toof' + footnote.ind + '" class="footlink">' + footnote.ind + '</a>';
				}
			}
			if (stedtuserprivs & 1) cell5.innerHTML += addlink;
			if (stedtuserprivs & 8) {
				// insert html form for approving this subgroup only
				grp = grp.replace(/"/g,'&quot;'); // escape quotes for inclusion in the string below
				cell3.innerHTML = '<form action="' + baseRef + 'tags/accept" method="post" '
					+ 'onsubmit="return grp_confirm(' + table_tag + ',\'' + grp + '\')">'
					+ '<input name="tag" value="' + table_tag + '" type="hidden">'
					+ '<input name="uid" value="' + uid2 + '" type="hidden">'
					+ '<input name="grpno" value="' + grpno + '" type="hidden">'
					+ '<input type="submit" value="Accept ' + grpno + ' only..."></form>';
				// insert html form for migrating tagged reflexes in this subgroup
				cell4.innerHTML += '<input type="button" value="Move tagged reflexes to another tag..." onclick="migrate_prompt(' + table_tag + ',\'' + grp
					+ '\'' + ',\'' + grpno + '\'); return false">';
			}
			lastgrpno = grpno;
		}
	});
}
