setup['lexicon']['languagenames.language'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/languagenames?languagenames.language=' +  v + '"'
		+ ' title="' + rec[n+2] + ' - ' + rec[n+3].replace(/"/g,'&quot;') + '"'
		+ ' target="edit_lgs">' + v + '</a>';
};
setup['lexicon']['num_notes'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		var addlink = (stedtuserprivs & 1) ? '<a href="#" class="lexadd" title="Add a note to this lexical item">[+]</a>' : '';
		if (v === '0') return addlink;
		var a = v.match(/\d+/g).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '" class="footlink">' + s + '</a>';
		});
		a.push(addlink);
		return a.join(' ');
	}
};

// setup['lexicon']['analysis'].label =
//	$("uid1").options[$("uid1").selectedIndex].text + '\'s analysis';
	
setup['lexicon']['analysis'] = {
	label: ((stedtuserprivs & 1) ? '(A) ' : '') + $("uid1").options[$("uid1").selectedIndex].text + '\'s analysis',
	noedit: !(stedtuserprivs & 8),
	hide: false,
	size: 80,
	transform: function (v) {
		return v.replace(/, */g,', ');
	}
};

setup['lexicon']['user_an'] = {
	label: ((stedtuserprivs & 1) ? '(B) ' : '') + $("uid2").options[$("uid2").selectedIndex].text  + '\'s analysis',
	noedit: !(stedtuserprivs & 1),
	hide: false,
	size: 80,
	transform: function (v) {
		return v.replace(/, */g,', ');
	}
};

setup['lexicon']['lexicon.semkey'] = {
	label: 'semkey',
	noedit: !(stedtuserprivs & 16),
	size: 50,
	hide: false,
	transform : function (v, key, rec, n) {
		return '<a href="' + baseRef + 'edit/glosswords' + '?glosswords.semkey=' + v + '" target="edit_glosswords" title="' + rec[n+1].replace(/&/g,'&amp;') + '">' + v + '</a>';
	}
};
//setup['lexicon']['user_an'].label =
//	$("uid2").options[$("uid2").selectedIndex].text  + '\'s analysis';

// citation field in edit/lexicon links to edit/srcbib
setup['lexicon']['citation'] = {
	label: 'source',
	noedit: true,
	size: 140,
	transform : function (v, key, rec, n) {
		return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + rec[n+1] + '" target="edit_src" title="srcabbr: ' + 
		rec[n+1] + '">' + (v||rec[n+1]) + '</a>';
		// show srcabbr if citation is blank
	}
};
