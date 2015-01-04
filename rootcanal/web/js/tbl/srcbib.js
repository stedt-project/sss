setup.srcbib = {
	_key: 'srcbib.srcabbr',
	'srcbib.srcabbr': {
		noedit: true,
		size:70,
		transform : function (v) {
			return '<a href="' + baseRef + 'source/' + v + '" target="stedt_src">' + v + '</a>';
		}
	},
	'num_lgs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/languagenames?languagenames.srcabbr=' + key + '" target="edit_lgs">' + v + ' lg' + (v == 1 ? '' : 's') + '</a>';
		}
	},
	'num_recs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/lexicon?languagenames.srcabbr=' + key + '" target="stedt_lexicon">' + v + ' r\'s</a>';
		}
	},
	'srcbib.citation': {
		size:100,
		noedit: !(stedtuserprivs & 8)
	},
	'srcbib.author': {
		noedit: !(stedtuserprivs & 8),
		size:120
	},
	'srcbib.year': {
		noedit: !(stedtuserprivs & 8),
		size:50
	},
	'srcbib.title': {
		noedit: !(stedtuserprivs & 8),
		size:120
	},
	'srcbib.imprint': {
		noedit: !(stedtuserprivs & 8),
		size:100
	},
	'srcbib.status': {
		noedit: !(stedtuserprivs & 8),
		size:100,
		transform : function (v, key) {
			v = v.replace(/\n\n+/, '<p>');
			v = v.replace(/\n/, '<br>');
			return v;
		}
	},
	'srcbib.notes': {
		noedit: !(stedtuserprivs & 8),
		size:100
	},
	'srcbib.todo': {
		noedit: !(stedtuserprivs & 8),
		size:100
	},
	'srcbib.format': {
		noedit: !(stedtuserprivs & 8),
		size:100
	},
	'num_notes': {
		label: '#_notes',
		noedit: true,
		size: 55
	}
};
