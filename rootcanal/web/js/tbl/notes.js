// tooltip help for various fields
$('notes.id_search').addTip('For <b>Chapter</b> notes, id = chapter (e.g. 1.6.5)<br>For <b>Lexicon</b> notes, id = tag # associated with note<br>For <b>Etyma</b> notes, id = grpid (subgroup note)<br>For <b>Source</b> notes, id = source abbreviation', 'ID', {className:'standard', delay:'0'});
$('notes.notetype_search').addTip('<b>Internal</b> = visible only to logged-in users<br><b>Text</b> = standard note visible to public<br><b>Final</b> = Chinese comparanda note (in etyma)<br><b>HPTB</b> = etyma note containing an HPTB reference (deprecated)<br><b>Graphics</b> = reference to graphics file<br><b>Orig/Src</b> = author\'s note from the original source', 'TYPE', {className:'standard', delay:'0'});
$('notes.rn_search').addTip('Record number (for lexicon notes)', 'RN', {className:'standard', delay:'0'});
$('notes.tag_search').addTip('Tag number (for etyma notes)', 'TAG', {className:'standard', delay:'0'});
$('notes.ord_search').addTip('Order of note if there is more than one note for a particular element', 'ORDER', {className:'standard', delay:'0'});

// convert xmlnote to html for display
function xml2html(xmlnote) {
	var htmlnote = xmlnote;
	
	// flag Chinese characters not inside <hanform></hanform> (change font color to red)
	// match any Han character not followed by "</hanform" or another Han character, then format as red using inline css
	// javascript doesn't support \p{Han}, so have to list unicode ranges for Han characters explicitly
	htmlnote = htmlnote.replace(/([\u2E80-\u2E99\u2E9B-\u2EF3\u2F00-\u2FD5\u3005\u3007\u3021-\u3029\u3038-\u303B‌​\u3400-\u4DB5\u4E00-\u9FCC\uF900-\uFA6D\uFA70-\uFAD9\u3000-\u303F])(?![\u2E80-\u2E99\u2E9B-\u2EF3\u2F00-\u2FD5\u3005\u3007\u3021-\u3029\u3038-\u303B‌​\u3400-\u4DB5\u4E00-\u9FCC\uF900-\uFA6D\uFA70-\uFAD9\u3000-\u303F])(?!<\/hanform)/g, '<span style="color:red;">$1</span>');
	
	htmlnote = htmlnote.replace(/<par>/g, '<p>');
	htmlnote = htmlnote.replace(/<\/par>/g, '</p>');
	htmlnote = htmlnote.replace(/<emph>/g, '<i>');
	htmlnote = htmlnote.replace(/<\/emph>/g, '</i>');
	htmlnote = htmlnote.replace(/<gloss>(.*?)<\/gloss>/g, '$1');	// no formatting for deprecated 'gloss' tag
	htmlnote = htmlnote.replace(/<hanform>(.*?)<\/hanform>/g, '$1');
	htmlnote = htmlnote.replace(/<reconstruction>\*(.*?)<\/reconstruction>/g, format_rxn);
	htmlnote = htmlnote.replace(/<unicode>(.*?)<\/unicode>/g, '&#x$1;');
	
	// for xref, just make it an elink and let the et_info_popup code in stedtconfig.js take care of the rest
	htmlnote = htmlnote.replace(/<xref ref="(\d+)">#\1(.*?)<\/xref>/g,
		'<a href="' + baseRef + 'etymon/$1" target="stedt_etymon" class="elink t_$1">#$1</a>');
	
	
	htmlnote = htmlnote.replace(/<latinform>(.*?)<\/latinform>/g, format_lf);
	// use an anonymous function to pass _qtd the first backreference instead of the whole matched string
	htmlnote = htmlnote.replace(/<plainlatinform>(.*?)<\/plainlatinform>/g, function (match,b1){ return _qtd(b1); });
	
	// no need to convert href because xml=html in that case
	
	// smart quotes
	htmlnote = htmlnote.replace(/(\S)&apos;/g, '$1’');	// right single smart quote
	htmlnote = htmlnote.replace(/&apos;/g, '‘');		// left single smart quote
	htmlnote = htmlnote.replace(/&quot;(?=[\w'])/g, '“');	// left double smart quote
	htmlnote = htmlnote.replace(/&quot;/g, '”');		// right double smart quote
	
	// switch quotes in forms back to 'dumb' quotes (converted to full-width quotes by _qtd)
	htmlnote = htmlnote.replace(/＇/g, '&apos;');
	htmlnote = htmlnote.replace(/＂/g, '&quot;');
	
	// italicize certain abbrevations
	var abbrevs = ['GSR','GSTC','STC','HPTB','TBRS','LTSR','TSR','AHD','VSTB','TBT','HCT','LTBA','BSOAS','CSDPN','TIL','OED'];
	var abbrevs_length = abbrevs.length;
	for (var i = 0; i < abbrevs_length; i++) {
		var abbrev_reg = new RegExp('\\b(' + abbrevs[i] + ')\\b', 'g');	// remember to double-escape word boundary chars when making RegExp object
		htmlnote = htmlnote.replace(abbrev_reg, '<i>$1</i>');		
	}
	
	htmlnote = htmlnote.replace(/&lt;-+&gt;/g, '⟷');	// convert <-> (and <-->, etc.) to double-headed arrow
	htmlnote = htmlnote.replace(/-+&gt;/g, '→');    // convert -> (and -->, etc.) to right arrow
	htmlnote = htmlnote.replace(/&lt;-+/g, '←');    // convert <- (and <--, etc.) to left arrow
	htmlnote = htmlnote.replace(/&lt; /g, '< ');		// no-break space after "comes from" sign
	
	// just do something to set footnotes apart
	htmlnote = htmlnote.replace(/<footnote>/g, '{<i>FOOTNOTE:</i> ');
	htmlnote = htmlnote.replace(/<\/footnote>/g, '}');
	
	
	// remove first surrounding <p> tag pair
	htmlnote = htmlnote.replace(/^<p>/,'');
	htmlnote = htmlnote.replace(/<\/p>$/,'');

//	debugging code
//	console.log(xmlnote);
//	console.log(htmlnote);
	
	return htmlnote;
};

function format_lf(wholeMatch, latinForm) {
//	console.log(wholeMatch);
	return '<b>' + _nonbreak_hyphens(_qtd(latinForm)) + '</b>';
};

function format_rxn(wholeMatch, protoForm) {
	return '<b>*' + _nonbreak_hyphens(protoForm) + '</b>';
};

// (copied from RootCanal/Notes.pm)
function _nonbreak_hyphens(text) {
	text = text.replace(/-/g, '‑');
	return text;	
};

// (copied from RootCanal/Notes.pm)
// this sub is used so that apostrophes in forms are not educated into "smart quotes"
// We need to substitute an obscure unicode char, then switch it back to "&apos;" later.
// Here we use the "full width" variants used in CJK fonts.
function _qtd(text) {
	text = text.replace(/&apos;/g ,'＇');
	text = text.replace(/&quot;/g, '＂');
	return text;
};

setup.notes = {
	_key: 'notes.noteid',
	'notes.noteid': {
		noedit: true,
//		hide: !(stedtuserprivs & 1),
		size: 20
	},
	'notes.spec': {
		label: 'location',
		noedit: true,
		size: 20,
		transform: function (v) {
			switch(v) {	// note that we can only get away w/o break statements because of the returns
				case 'E':
					return 'Etyma';
				case 'L':
					return 'Lexicon';
				case 'C':
					return 'Chapter';
				case 'S':
					return 'Source';
				default:
					return v;			
			}
		}
	},
	'notes.notetype': {
		label: 'type',
		noedit: true,
		size: 20,
		transform: function (v) {
			switch(v) {	// note that we can only get away w/o break statements because of the returns
				case 'T':
					return 'Text';
				case 'I':
					return 'Internal';
				case 'O':
					return 'Orig/Src';
				case 'G':
					return 'Graphics';
				case 'F':
					return 'Final';
				case 'H':
					return 'HPTB';
				default:
					return v;			
			}
		}
	},
	'notes.rn': {
		label: 'rn',
		noedit: true,
		size: 15,
		transform: function (v) {
			if (v != "0") {
				return '<a href="' + baseRef + 'edit/lexicon?lexicon.rn=' + v + '" target="stedt_lexicon">' + v + '</a>';
			} else return '';
		}
	},
      	_postprocess: function (tbl) {
      		tbl.on('mouseover', 'a.elink', et_info_popup);
      		tbl.on('mouseout', 'a.elink', et_info_popup);
      	},
	'notes.tag' : {
		label: 'tag',
		noedit: true,
		size: 10,
		transform: function (v,k,rec,n) {
			if (v != "0") {
				return '<a href="' + baseRef + 'etymon/' + v + '" target="stedt_etymon" class="elink t_' +v+'">' + v + '</a>';
			} else return '';
			
		}
      	},
      	'notes.id': {
		label: 'id',
		noedit: true,
		size: 25,
		transform: function (v,k,rec,n) {
			if (v==='' || v==='0') return v;	// return id if id is blank or zero
			switch(rec[n-4]) {	// interpretation of value in id depends on spec, which is in rec[n-4]
				case 'L':	// lexicon note, so id contains tag num
					return 'tag: <a href="' + baseRef + 'etymon/' + v + '" target="stedt_etymon" class="elink t_' +v+'">' + v + '</a>';
				case 'S':	// source note, so id contains srcabbr
					return '<a href="' + baseRef + 'source/' + v + '" target="stedt_src">' + v + '</a>';
				case 'C':	// chapter note, so id contains chapter
					return 'chap: <a href="' + baseRef + 'chap/' + v + '" target="stedt_chapters">' + v + '</a>';
				case 'E':	// if spec=E and id has a value, then id=grpid for subgroup note; get grpno from next column
					return 'grpid: <a href="' + baseRef + 'etymon/' + rec[n-1] + '#' + rec[n+1] + '" target="stedt_etymon">' + v + '</a>';
				default:
					return v;			
			}
		}
	},
	'grpno': {
		label: 'grpno',
		hide: true,
		noedit: true
	},
	'notes.ord': {
		label: 'order',
		noedit: true,
		size: 13
	},
      	'notes.xmlnote' : {
		noedit: true,
      		label: 'note text',
      		size: 200,
      		transform: function (v,k,rec,n) {
      			return xml2html(rec[n]);
		}
      	},
      	'users.username' : {
      		label: 'owner',
      		size: 20,
      		noedit: true
      	},
      	'notes.uid' : { // this is just a search field
      		label: 'owner'
      	}
};
