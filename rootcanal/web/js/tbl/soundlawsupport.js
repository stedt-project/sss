
setup.soundlawsupport = {
    _key: 'soundlawsupport.id',
    'soundlawsupport.id': {
	label: 'slID',
	noedit: true,
	hide: true,
	size: 40
    },
    'soundlawsupport.rn': {
	label: 'rn',
	noedit: true,
	hide: false,
	transform : function (v, key, rec, n) {
	    var slot = {'I': 'initial', 'R' : 'rhyme', 'T': 'tone'}[rec[2]];
	    return '<a href="' + baseRef + 'edit/lexicon?lexicon.rn=' + v + '" target="edit_etyma">' + v + '</a>';
	},
	size: 40
    },
   'soundlawsupport.slid' : {
       label: 'slID',
       noedit: true,
       hide: false,
       size: 30
    },
   'soundlawsupport.tag' : {
       label: 'tag',
       noedit: true,
       hide: true,
       size: 30
    },
    'soundlawsupport.slot' : {
	label: 'slot',
	noedit: true,
	hide: false,
	size: 40
    },
    'soundlawsupport.protolg' : {
	label: 'protolg',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlawsupport.ancestor' : {
	label: 'ancestor',
	noedit: true,
	hide: false,
	size: 50
    },
    'soundlawsupport.outcome' : {
	label: 'outcome',
	noedit: true,
	hide: false,
	size: 50
    },
    'soundlawsupport.language' : {
	label: 'language',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlawsupport.protoform' : {
	label: 'etymon',
	noedit: true,
	hide: false,
	size: 40
    },
    'soundlawsupport.protogloss' : {
	label: 'protogloss',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlawsupport.reflex' : {
	label: 'reflex',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlawsupport.gloss' : {
	label: 'gloss',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlawsupport.srcabbr' : {
	label: 'source',
	noedit: true,
	hide: false,
	size: 30
    },
    'soundlawsupport.srcid' : {
	label: 'srcid',
	noedit: true,
	hide: false,
	size: 30
    },
    'soundlawsupport.lgid' : {
	label: 'lgid',
	noedit: true,
	hide: true,
	size: 60
    }
};
