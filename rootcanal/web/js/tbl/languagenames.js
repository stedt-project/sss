setup.languagenames = {
	_key: 'languagenames.lgid',
	'languagenames.lgid': {
		noedit: true,
		hide: !(stedtuserprivs & 1),
		size:40
	},
	'num_recs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/lexicon?lexicon.lgid=' + key + '" target="stedt_lexicon">' + v + ' r\'s</a>';
		}
	},
	'languagenames.srcabbr': {
		noedit: true,
		size:70,
 		transform : function (v) {
			return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + v + '" target="edit_src">' + v + '</a>';
		}
	},
	'languagenames.lgabbr': {
		size:100,
		noedit: true
	},
	'languagenames.lgcode': {
		size:40,
		noedit: !(stedtuserprivs & 8)
	},
	'languagenames.silcode': {
		size:40,
		noedit: !(stedtuserprivs & 8),
		transform : function (v) {
			return '<a href="http://www.ethnologue.com/show_language.asp?code=' + v + '" target="stedt_ethnologue">' + v + '</a>';
		}
	},
	'languagenames.language': {
		size:120,
		noedit: !(stedtuserprivs & 8)
	},
	'languagenames.lgsort': {
		size:90,
		noedit: !(stedtuserprivs & 8)
	},
	'languagenames.notes': {
		size:60,
		noedit: !(stedtuserprivs & 8)
	},
	'languagenames.srcofdata': {
		size:50,
		noedit: !(stedtuserprivs & 8)
	},
	'languagegroups.grpno': {
		noedit: true,
		hide: true,
		size:70
	},
	'languagegroups.grp': {
		noedit: true,
		hide: true,
		size:110
	},
	'languagenames.grpid': {
		label: 'group',
		noedit: true,
		size:120,
		transform : function (v, key, rec, i) {
			return '<a href="' + baseRef + 'group/' + rec[i] + '" target="stedt_grps">' +
			rec[i-2] + ' - ' + rec[i-1] + '</a>';
		}
	}
};
