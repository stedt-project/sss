setup.mesoroots = {
	_key: 'mesoroots.id',
	'mesoroots.id': {
		noedit: true,
		hide: !(stedtuserprivs & 1),
		size: 20
	},
      	_postprocess: function (tbl) {
      		tbl.on('mouseover', 'a.elink', et_info_popup);
      		tbl.on('mouseout', 'a.elink', et_info_popup);
      	},
	'mesoroots.tag' : {
	label: 'tag',
		noedit: true,
		size: 30,
		transform: function (v,k,rec,n) {
			return '<a href="' + baseRef + 'etymon/' + v + '#' + rec[n+5]
				+ '" target="stedt_etymon" class="elink t_' +v+'">' + v + '</a>';
		}
      	},
      	'mesoroots.form' : {
		noedit: true,
      		label: 'form',
      		size: 120
      	},
      	'mesoroots.gloss' : {
		noedit: true,
      		label: 'gloss',
      		size: 200
      	},
      	'mesoroots.grpid': {
		noedit: true,
      		label: 'plg',
      		size: 30,
      		transform: function (v,k,rec,n) {
      			if (v === '0') return '';
      			return rec[n+1] || v;
      		}
      	},
      	'languagegroups.plg': {
		noedit: true,
      		hide: true
      	},
      	'languagegroups.grpno': {
		noedit: true,
      		hide: true
      	},
 	'mesoroots.old_tag': {
		noedit: true,
      		hide: true
      	},
 	'mesoroots.old_note': {
 		label: 'old note',
		noedit: true,
      		hide: false,
      		size: 160
      	},
      	'mesoroots.variant' : {
      		label: 'var.',
		noedit: true,
      		size: 10
      	},
      	'users.username' : {
      		label: 'owner',
      		size: 60,
      		noedit: true
      	},
      	'mesoroots.uid' : { // this is just a search field
      		label: 'owner'
      	}
};
