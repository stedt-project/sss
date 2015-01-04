setup.hptb = {
	_key: 'hptb.hptbid',
	'hptb.hptbid': {
		label: 'id',
		noedit: true,
		size:4
	},
	'hptb.protoform': {
		label: 'protoform',
		noedit: true,
		size:15
	},
	'hptb.protogloss': {
		label: 'protogloss',
		noedit: true,
		size:20
	},
	'hptb.plg': {
		label: 'pLg',
		noedit: true,
		size:4
	},
	'tags' : {
		label: 'tags',
		size:4,
		noedit: true
	},
	'hptb.mainpage': {
		label: 'main page',
		noedit: !(stedtuserprivs & 16),
		size:4
	},
	'hptb.pages': {
		label: 'HPTB pages',
		noedit: !(stedtuserprivs & 16),
		size:20
	},
	'hptb.tags': {
		label: 'guessed tag #\'s',
		size:20,
		noedit: true,
		transform: function (v) {
				return v.replace(/, */g,', ');
			}
	},
	'hptb.semclass1': {
		label: 'semclass1',
		noedit: true,
		size:20
	},
	'hptb.semclass2': {
		label: 'semclass2',
		noedit: true,
		size:20
	}
};
