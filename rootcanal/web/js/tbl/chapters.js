setup.chapters = {
    _key: 'chapters.id',
    'chapters.id': {
	noedit: true,
	hide: true
    },
    'chapters.indent': {
	noedit: true,
	hide: true
    },
    'chapters.semkey' : {
	label: 'semkey',
	noedit: !(stedtuserprivs & 8),
	size: 140
    },
    'chapters.chaptertitle' : {
	label: 'title',
	noedit: !(stedtuserprivs & 8),
	size: 250
    },
    'etyma' : {
        noedit: true,
        size: 12
    },
    'wcount' : {
	label: 'lexicon records',
	noedit: true,
	size: 24
    },
    'haschart' : {
	label: 'flow chart?',
	noedit: true,
	size: 12
    },
    'notecount' : {
	label: 'notes',
	noedit: true,
	size: 24
    },
    'num_glosswords' : {
	noedit: true,
	hide: true
    },
    'some_glosswords' : {
        label: 'gloss words with this semkey',
        noedit: true,
        size: 250,
	transform : function (v,k,rec,n) {
		if (stedtuserprivs & 2) {
			return v ? rec[n-1] + ': <a href="' + baseRef + 'edit/glosswords?glosswords.semkey=' + rec[0] + '" target="edit_glosswords">' + v + '</a>' : '';
		}
		else {
			return v;
		}
	}
    },
    'gloss_link' : {
        label: 'glosswords',
        noedit: true,
        size: 80,
	transform : function (v,k,rec,n) {
	    return '<a href="' + baseRef + 'edit/glosswords?glosswords.semkey=' + rec[0] + '" target="edit_glosswords">' + v + ' glossword(s)</a>';
	}
    },
    'chapters.v' : {
	label: 'vol',
	noedit: true,
	size: 20
    },
    'chapters.f' : {
	label: 'fasc',
	noedit: true,
	size: 20
    },
    'chapters.c' : {
	label: 'chap',
	noedit: true,
	size: 20
    },
    'chapters.s1' : {
	label: 's1',
	noedit: true,
	size: 20
    },
    'chapters.s2' : {
	label: 's2',
	noedit: true,
	size: 20
    },
    'chapters.s3' : {
	label: 's3',
	noedit: true,
	size: 20
    },
    'chapters.semcat' : {
	label: 'ancient semcat',
	noedit: true,
	size: 80
    },
    'chapters.old_chapter' : {
	label: 'old chapter',
	noedit: true,
	size: 60
    },
    'chapters.old_subchapter' : {
	label: 'old subchapter',
	noedit: true,
	size: 80
    },
    'eDiss' : {
	noedit: true,
	size: 30
    },
    'tagged' : {
	label: 'tagged forms',
	noedit: true,
	size: 24
    },
    'pct' : {
	label: 'pct tagged',
	noedit: true,
	size: 24
    }
};
