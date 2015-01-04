// note saving and deleting via AJAX
$(document.body).on('submit', 'form.noteform', function (e) {
	var f = e.findElement(), id = f.noteid.value;
	new Ajax.Request(baseRef + 'notes/save', {
		parameters: f.serialize(),
		onSuccess: function (t,json) {
			// skip if there were no changes
			if (f.mod.value === json.lastmod) return;
			var result = t.responseText.split("\r");
			var note = result.shift(); // first item is main text; remaining items are footnotes, to be handled below
			note = note.replace(/"#foot(\d+)" id="toof\1"><sup>\1/g, function (s, n1) {
				var n =+n1+footnote_counter;
				return '"#foot' + n + '" id="toof' + n + '"><sup>' + n;
			});
			$('preview' + id).innerHTML = note;
			f.mod.value = json.lastmod;
			$('lastmod' + id).innerHTML = json.lastmod;
			$$('.fnote-' + id).invoke('purge');
			$$('.fnote-' + id).invoke('remove');
			$A(result).each(function (text) {
				var n = ++footnote_counter;
				var elem = new Element('p', {'class':'footnote fnote-' + id,
					id:'foot' + n});
				elem.innerHTML = '<a href="#toof' + n + '">^ ' + n + '.</a> '
					+ text;
				f.up('body').insert(elem);
			});
		},
		onFailure: function(t) {
			alert(t.responseText);
		}
	});
	Event.stop(e);
});
$(document.body).on('click', 'form.noteform input[name=delete_btn]', function (e) {
	var f = e.findElement('form'), id = f.noteid.value;
	if (!confirm('Are you sure you want to delete the selected records?'))
		return;
	new Ajax.Request(baseRef + 'notes/delete', {
		parameters: {noteid:id,mod:f.mod.value},
		onSuccess: function (t,json) {
			$$('.fnote-' + id).invoke('purge');
			$$('.fnote-' + id).invoke('remove');
			var x = $('reorddiv_' + id);
			if (x.hasClassName('lexnote')) {// remove the footnotemark if there is one
				var mark = $(x.down('a').id.replace(/^foot/,'toof'));
				mark.purge();
				mark.remove();
			}
			x.purge();
			x.remove();
		},
		onFailure: function(t) {
			alert(t.responseText);
		}
	});
});

// note reordering
$$('.reordcheckbox').each(function (c) {
	var container = $(c).up('.container');
	c.onclick = function (e) {
		if (c.checked) {
			Sortable.create(container.id, {tag:'div', only:'reord', scroll:window, onUpdate:function () {
				new Ajax.Request(baseRef + 'notes/reorder', {
					parameters: {ids:Sortable.serialize(container.id,{name:'z'})},
					onFailure: function(t){ alert('Error: ' + t.responseText) }
				});
			}});
			container.select('form').invoke('hide');
		} else {
			Sortable.destroy(container.id);
			container.select('form').invoke('show');
		}
	};
});

// adding new notes
var addform_fullid;
function showaddform (spec, id, e) {
	// C, E, L; F for comparanda and M for subgroup notes (special handling of notetype)
	if (spec==='L') {
		addform_fullid = id;
		id = id.substring(3); // chop off front of tr id
	}
	var labels = {O:'Orig/src-DON\'T MODIFY', T:'Text', I:'Internal',
					N:'New', G:'Graphic', F:'Final', H:'HPTB'};
	var f = $('addnoteform');

	// constrain notetypes
	// if approver or above, can enter the full range of notetypes, otherwise limit to internal notes
	if (stedtuserprivs & 8) {
		var types = spec === 'L' ? ['T','I','O'] : spec === 'F' ? ['F'] :
			spec === 'E' ? ['T','I','H'] : spec === 'C' ? ['T','I','G'] :
			spec === 'M' ? ['T','I'] : ['I','T'];
	} else {
		types = ['I'];
	}

	// set spec, id
	f.spec.value = spec;
	f.id.value = id;
	if (spec==='M') { // special handling for etyma subgroup notes
		addform_fullid = e.findElement().up('tr').identify(); // save the tr for later access
		f.id2.value = e.findElement().up('tr').id.replace('grprow_','');
	}
	f.fn_counter.value = footnote_counter;
	var menu = f.notetype.options;
	menu.length = 0; // clear out the menu
	for (var i=0; i<types.length; i++) {
		menu[i] = new Option(labels[types[i]],types[i]);
	}
	menu[0].selected = 'selected'; // select the first item
	f.show();
	f.xmlnote.focus();
	return false; // still need this here because etymon and chapter views have inline onclick
};

if($('addnoteform') != undefined) {	// doesn't exist for public users
	$('addnoteform').observe('submit', function (e) {
		e.stop();
		var f = $('addnoteform');
		var spec = f.spec.value;
		var id = f.id.value;
		var container = null; // id of the enclosing div for sorting
		// also set ord
		if (spec === 'E') {
			container = $('allnotes' + id);
		} else if (spec === 'M') {
			// special case, change M -> E
			f.spec.value = 'E';
			f.ord.value = 1;
		} else if (spec === 'F') {
			container = $('allcomparanda' + id);
			f.spec.value = 'E'; // special case, change spec F -> E
		} else if (spec === 'C' || spec === 'S') {
			container = $('allnotes');
		} else { // lexicon note
			f.ord.value = 1;
		}
		if (container) {
			var existing_notes = container.select('.reord');
			if (existing_notes.size()) {
				f.ord.value = +existing_notes.last().down('form').ord.value+1;
			} else { // there are no existing notes; the first note's ord should be 1
				f.ord.value = 1;
			}
		}
		new Ajax.Request(baseRef + 'notes/add', {
			parameters: f.serialize(),
			onSuccess: function (t,json) {
				var result = t.responseText.split("\r");
				var note = result.shift();
				if (container) {
					// insert the HTML in the right place
					container.insert(note);
					// insert footnotes at the end, if necessary
					// *** the code to adjust the footnote numbers is kind of ugly;
					// the prettier way would be to send the current footnote number
					// to the server, then increment footnote_counter by the
					// number of text blocks in result.
					$A(result).each(function (text) {
						var n = ++footnote_counter;
						var elem = new Element('p', {'class':'footnote fnote-' + $F(container.childElements().last().down('form')['noteid']), // the noteid is the value of the form's input named 'noteid'
							id:'foot' + n});
						elem.innerHTML = '<a href="#toof' + n + '">^ ' + n + '.</a> '
							+ text;
						f.up('body').insert(elem);
					});
					// enable the sort box if there are two or more sortable items
					if ((container.select('.reord').length > 1) && container.down('.reordcheckbox'))
						container.down('.reordcheckbox').enable();
				} else {
					// if it's a lex or subgroup note, stick it in at the bottom, and add the footnotemark in the table
					f.up('body').insert(note);
					++footnote_counter;
					var add_link_obj;
					// if this is a lexicon record note, the 'add note' link has class = lexadd
					if(addform_fullid.substr(0,2) === 'le') {
						add_link_obj = $(addform_fullid).select('.lexadd')[0]; // get the object with 'add note' link
					// otherwise, this is a subgroup note, so the 'add note' link has class = et_grp_add
					} else {
						add_link_obj = $(addform_fullid).select('.et_grp_add')[0]; // get the object with 'add note' link
					}
					// get the cell with footnote links, remove the 'add note link',
					// add the new footnote link, and re-insert the 'add note' link at the end
					var cell = add_link_obj.parentNode;
					add_link_obj.remove();
					cell.innerHTML = cell.innerHTML + ' <a href="#foot' + footnote_counter + '" id="toof' + footnote_counter + '" class="footlink">' + footnote_counter + '</a> ';
					cell.appendChild(add_link_obj);
				}
				f.xmlnote.value = ''; // reset the textarea
				f.hide();
			},
			onFailure: function(t) {
				alert(t.responseText);
			}
		});
	});
}

// show/hide the editing form
$(document.body).on('click', 'input:button.note_edit_toggle', function (e) {
	e.findElement().up('.lexnote').down('.noteform').toggle();
	e.stop();
});

// make a separate cheat sheet
if($('cheat_source') != undefined) {	// this doesn't exist for public users
	var notes_cheatsheet = $('cheat_source').clone(true);
	notes_cheatsheet.id = 'notes_markup_cheatsheet';
	notes_cheatsheet.style.display = 'none';
	$('addnoteform').insert({after:notes_cheatsheet});
	$(document.body).on('click', 'a.cheatsheet_link', function (e) {
		$("notes_markup_cheatsheet").toggle();
		e.stop();
	});
}

// fun with popovers
$(document.body).on('mouseover', 'a.footlink', function (e) {
	var elem = e.findElement();
	if (elem.tagName === 'SUP') {	// deal with footnote links inside <sup> tags
		elem = elem.up();
	}
	var footelem = $(elem.id.replace('toof', 'foot'));
	footelem = footelem.up('div.lexnote') || footelem; // see edit.tt; the footnote text could be in two slightly different places depending on privileges
	var foot = footelem.down('div.notepreview');
	var text = foot.innerHTML.replace(/<input.*?>/,''); // hide the "Edit" button
	Tips.add(elem, e, text, {stem:true, delay:0, fixed:true, showEffectDuration:0, className:'glass'});
});
