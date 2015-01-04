setup.morphemes = {
    _key: 'morphemes.id',
    'morphemes.id' : {
	label: 'id',
	noedit: true,
	hide: true,
	size: 70
    },
    'morphemes.rn' : {
	label: 'rn',
	noedit: true,
	hide: true,
	size: 70
    },
    'morphemes.tag' : {
	label: 'tag',
	noedit: !(stedtuserprivs & 16),
	hide: false,
	size: 30
    },
    'morphemes.prefx' : {
	label: 'pfx',
	noedit: true,
	hide: false,
	size: 20
    },
    'morphemes.initial' : {
	label: 'I',
	noedit: true,
	hide: false,
	size: 20
    },
    'morphemes.rhyme' : {
	label: 'R',
	noedit: true,
	hide: false,
	size: 20
    },
    'morphemes.tone' : {
	label: 'T',
	noedit: true,
	hide: false,
	size: 20
    },
    'tag' : {
	label: 'stedt',
//	noedit: !(stedtuserprivs & 8),
	noedit: true,
	hide: !(stedtuserprivs & 16),
	size: 30,
	transform: function (v) {
	    return v.replace(/, */g,', ');
	}
    },
    'morphemes.reflex' : {
	label: 'form',
	noedit: true,
	size: 60
    },
    'morphemes.morpheme' : {
	label: 'morpheme',
	hide: false,
	noedit: !(stedtuserprivs & 16),
	size: 30
    },
    'lexkey' : {
	label: 'key',
	noedit: true,
	size: 80
    },
    'shortdisp' : {
	label: 'lexical item',
	noedit: true,
	size: 450
    },
    'morphemes.handle' : {
	label: 'handle',
	noedit: true,
	size: 40
    },
    'morphemes.glosshandle' : {
	label: 'glosshandle',
	noedit: true,
	size: 40
    },
    'morphemes.gloss' : {
	label: 'gloss',
	noedit: !(stedtuserprivs & 16),
	size: 80
    },
    'morphemes.gfn' : {
	label: 'gfn',
	noedit: !(stedtuserprivs & 16),
	size: 20
		},
    'morphemes.language' : {
	label: 'language',
	noedit: true,
	size: 60,
	transform : function (v, key, rec, n) {
	    return '<a href="' + baseRef + 'group/' + rec[n+1] + '/' + rec[n-1] + '" target="stedt_grps">' + v + '</a>';
	}
    },
    'morphemes.grpno' : {
	label: 'group',
	noedit: true,
	size: 70
//	transform : function (v, key, rec, n) {
//	    return v + ' - ' + rec[n+1];
//	}
    },
    'morphemes.grp' : {
	label: 'grp',
	noedit: true,
	hide: true
    },
    'morphemes.srcid' : {
	label: 'source',
	size: 140,
	noedit: true,
	hide: true
    },
    'morphemes.semcat' : {
	label: 'semcat',
	hide: true
    },
    'morphemes.semkey' : {
	label: 'semkey',
	noedit: true,
	size: 40,
	hide: false
    },
    'morphemes.status' : {
	label:'status',
	noedit: false,
	size: 20,
	hide: false
    }
};
