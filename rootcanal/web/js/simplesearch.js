var my_dragger;
var horz_dragger = function () {
	return new Draggable('dragger', { constraint: 'vertical', change: function (draggableInstance) {
			var d = $('dragger');
			var mytop = d.offsetTop;
			var ettop = $('etyma').offsetTop;
			$('etyma').setStyle({height:(mytop - ettop) + 'px'});
			$('lexicon').setStyle({top:(d.offsetTop + d.offsetHeight) + 'px'});
		},
		snap : function (x, y, d) {
			var min = $('etyma').offsetTop + 75;
			var max = $('lexicon').offsetTop + $('lexicon').offsetHeight - 100;
			if (y < min) y = min;
			if (y > max) y = max;
			return [x, y];
		}
	});
};
var vert_dragger = function () {
	return new Draggable('dragger', { constraint: 'horizontal', change: function (draggableInstance) {
			var d = $('dragger');
			var mytop = d.offsetLeft;
			var ettop = $('etyma').offsetLeft;
			$('etyma').setStyle({width:(mytop - ettop) + 'px'});
			$('lexicon').setStyle({left:(d.offsetLeft + d.offsetWidth) + 'px'});
		},
		snap : function (x, y, d) {
			var min = 150;
			var max = $('lexicon').offsetLeft + $('lexicon').offsetWidth - 200;
			if (x < min) x = min;
			if (x > max) x = max;
			return [x, y];
		}
	});
};

// this function will be called when loaded (see last line)
function stedt_simplesearch_init() {
	// start with vertical panes by default.
	// show only tag, protoform, and protogloss cols:
	$H(setup.etyma).each(function (fld) {
		if (fld.key.charAt(0) === '_') return; // skip non-fields
		fld.value.old_hide = fld.value.hide;
		fld.value.hide = !fld.value.vert_show;
	});
	$w('etyma lexicon').each(function (t) {
		if ($(t + '_resulttable'))
			TableKit.Raw.init(t + '_resulttable', t, setup[t], stedtuserprivs&1 ? baseRef+'update' : 0);
	});
	var do_search = function (e) {
		var tbl = e.findElement().id.sub('_search', '');
		var params = {
			tbl : tbl,
			s : $F(tbl + '_searchgloss'),
			f : $F(tbl + '_searchform')
		};
		if ($(tbl + '_searchlggrp'))
			params.lggrp = $F(tbl + '_searchlggrp');
		if ($('lg-auto'))
			params.lg = $F('lg-auto');
			// even though this was named 'lexicon_searchlg' in our HTML,
			// the autosuggest package has changed it to lg-auto, as we specified during initialization
		if ($('as-values-lg-auto'))
			params['as_values_lg-auto'] = $F('as-values-lg-auto'); // this will be populated automatically by the autosuggest script
		new Ajax.Request(baseRef + 'search/ajax', {
			method: 'get',
			parameters: params,
			onSuccess: ajax_make_table,
			onFailure: function (transport){ alert('Error: ' + transport.responseText); },
			onComplete: function (transport){ $(tbl + '_search').enable(); }
		});
		$(tbl + '_search').getElements().invoke('blur');
		$(tbl + '_search').disable(); // prevent accidental multiple submit. reversed by onComplete, above.
		return false;
	};
	
	$('etyma_search').onsubmit = do_search;
	$('lexicon_search').onsubmit = do_search;
	my_dragger = vert_dragger();
	Ajax.Responders.register({
		onCreate: function() { $('spinner').show() },
		onComplete: function() { if (0 == Ajax.activeRequestCount) $('spinner' ).hide() }
	});

	// persist search terms in language field from splash page
	// fill in gloss values
	if(document.URL.toQueryParams().t) {
		$('lexicon_searchgloss').value = document.URL.toQueryParams().t;
	}
	// fill in auto-suggested lg values
	var pItems = [];	// array to hold preFill objects for autosuggest setup below
	// get auto-suggested lg param from URL, remove final comma, replace + sign with space, and split multiple lgs selected
	if(document.URL.toQueryParams()['as_values_lg-auto']) {
		// set up 'values' versions (remove final commas, change pluses to spaces, and split by commas)
		var splash_lgs_v = document.URL.toQueryParams()['as_values_lg-auto'].replace(/,$/,'').replace(/\+/g,' ').split(',');
		var splash_lgs_s = splash_lgs_v.invoke('replace',/^=/,''); // display versions (without initial = sign)
		// create array of objects for autoSuggest preFill option
		var lg_object;
		var i;
		for (i = 0; i < splash_lgs_v.length; i += 1) { // iterate through array of lg params and create object for each pair
			lg_object = new Object();
			lg_object.v = splash_lgs_v[i];
			lg_object.s = splash_lgs_s[i];
			pItems[i] = lg_object;
		}
	}

	// there is also a hidden input[name=lg] in #etyma_search, so make sure we get the right one!
	// note that for multiple preFill items, you have to pass in an array of objects
	// see: https://drew.tenderapp.com/discussions/autosuggest/24-an-issue-with-prefill
	jQuery('#lexicon_search input[name=lg]').autoSuggest(baseRef+'autosuggest/lgs',{
		asHtmlID:"lg-auto",
		startText:"",
		selectedItemProp:"s",
		selectedValuesProp:"v",
		searchObjProps:"s",
		preFill: pItems
	});
	
	// pre-fill language search box with any non-auto-suggested entry from the splash page
	// replace pluses with spaces
	if (document.URL.toQueryParams().lg) {
		$('lg-auto').value=document.URL.toQueryParams().lg.replace(/\+/g,' ');
	}
};

function vert_tog() {
	var t = $('etyma_resulttable'), fields = [];
	$('etyma').setAttribute('style',''); // for some reason removeAttribute doesn't seem to work so well...
	$('lexicon').setAttribute('style','');
	$('dragger').setAttribute('style','');
	$('info').hide();
	my_dragger.destroy();
	if ($('etyma').hasClassName('vert')) {
		$('etyma').removeClassName('vert');
		$('lexicon').removeClassName('vert');
		$('dragger').removeClassName('vert');
		if (t) {
			$A(t.tHead.rows[0].cells).each(function (c, i) {
				setup.etyma[c.id].hide = setup.etyma[c.id].old_hide;
				if (!setup.etyma[c.id].hide) c.style.display = '';
				fields.push(c.id);
			});
			$A(t.tBodies[0].rows).each(function (row) {
				$A(row.cells).each(function (c,i) {
					if (!setup.etyma[fields[i]].hide) c.style.display = '';
				});
			});
		}
		my_dragger = horz_dragger();
	} else {
		$('etyma').addClassName('vert');
		$('lexicon').addClassName('vert');
		$('dragger').addClassName('vert');
		if (t) {
			$A(t.tHead.rows[0].cells).each(function (c, i) {
				if (!setup.etyma[c.id].vert_show) c.style.display = 'none';
				setup.etyma[c.id].old_hide = setup.etyma[c.id].hide;
				setup.etyma[c.id].hide = !setup.etyma[c.id].vert_show;
				fields.push(c.id);
			});
			$A(t.tBodies[0].rows).each(function (row) {
				$A(row.cells).each(function (c,i) {
					if (!setup.etyma[fields[i]].vert_show) c.style.display = 'none';
				});
			});
		}
		my_dragger = vert_dragger();
	}
	return false;
};

function show_advanced_search(tbl) {
	var result_table = $(tbl + '_resulttable');
	var t = new Element('table');
	t.width = '100%';
	t.style.tableLayout = 'fixed';
	var r = t.insertRow(-1);
	$A(result_table.tHead.rows[0].cells).each(function (th) {
		var c = new Element('td');
		c.width = th.getWidth();
		var box = new Element('input', {id:th.id});
		box.setStyle({width:'100%'});
		c.appendChild(box);
		r.appendChild(c);
	});
	result_table.parentNode.insertBefore(t, result_table);
	return false;
};

setup['etyma']['etyma.public'].hide = true;

document.observe("dom:loaded", stedt_simplesearch_init);
