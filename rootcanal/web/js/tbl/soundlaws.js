
setup.soundlaws = {
    _key: 'soundlaws.id',
    'soundlaws.id': {
	label: 'id',
	noedit: true,
	hide: false,
	transform : function (v, key, rec, n) {
	    var slot = {'I': 'initial', 'R' : 'rhyme', 'T': 'tone'}[rec[2]];
	    return '<a href="' + baseRef + 'edit/soundlawsupport?soundlawsupport.slid=' + v + '" target="edit_etyma">' + v + '</a>';
	},
	size: 40
    },
   'soundlaws.slid' : {
       label: 'slID',
       noedit: true,
       hide: true,
       size: 30
    },
    'soundlaws.slot' : {
	label: 'slot',
	noedit: true,
	hide: false,
	size: 40
    },
    'soundlaws.protolg' : {
	label: 'protolg',
	noedit: true,
	hide: false,
	size: 60
    },
    'soundlaws.ancestor' : {
	label: 'ancestor',
	noedit: true,
	hide: false,
	size: 50
    },
    'soundlaws.outcome' : {
	label: 'outcome',
	noedit: true,
	hide: false,
	size: 50
    },
    'soundlaws.language' : {
	label: 'language',
	noedit: true,
	hide: false,
	size: 100
    },
    'soundlaws.context' : {
	label: 'context',
	noedit: true,
	hide: false,
	size: 50
    },
    'soundlaws.n' : {
	label: 'N',
	noedit: true,
	hide: false,
	size: 30
    }
};
