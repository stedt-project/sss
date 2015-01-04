<?php

ini_set('display_errors', 'On');
$input = mysql_escape_string($_GET["q"]);
$elementID = mysql_escape_string($_GET["elementID"]);
// elementID is of the form stedt_sourcediv_tablecolumn
$srchindex = preg_replace('/stedt_(.*?)_/', '', $elementID);
// build database query
$input = preg_replace('/[\)\(\/\]\[]/', '.', $input);
switch ($srchindex) {
    case 'protogloss':
        $query = "select protogloss,count(*) as n from etyma where protogloss like '%$input%' group by protogloss order by n desc";
        break;
    case 'protoform':
        $query = "select protoform,count(*) as n from etyma where protoform like '%$input%' group by protoform order by n desc";
        break;
    case 'gloss':
        $query = "select gloss,count(*) as n from lexicon where gloss like '%$input%' group by gloss order by n desc";
        break;
    case 'plg':
        $query = "select plg,count(*) as n from languagegroups where plg like '%$input%' group by plg order by n desc";
        break;
    case 'protolog':
        $query = "select protogloss,count(*) as n from languagegroups where plg like '%$input%' group by plg order by n desc";
        break;
    case 'keyword':
        $query = "select * from (select author as keyword from srcbib union select year from srcbib union select title from srcbib) as keyword where keyword like '%$input%' group by keyword order by keyword";
        break;
    case 'reflex':
        $query = "SELECT distinct(reflex) FROM lexicon WHERE reflex LIKE '%$input%'";
        break;
    case 'citation':
        $query = "SELECT distinct(citation) FROM srcbib WHERE citation LIKE '%$input%' order by citation";
        break;
    case 'lggroup':
        $query = "SELECT distinct(concat(grpno,' : ',grp)) as lggroup FROM languagegroups WHERE grp LIKE '%$input%' OR grpno LIKE '%$input%' ORDER BY grpno";
        break;
    case 'language':
        $query = "SELECT distinct(language) FROM languagenames WHERE language LIKE '%$input%'";
        break;
    case 'silcode':
        $query = "SELECT distinct(silcode) FROM languagenames WHERE silcode LIKE '%$input%'";
        break;
    case 'languagename':
        $query = "SELECT distinct(language) as languagename FROM languagenames WHERE language LIKE '%$input%'";
        break;
}
//print $query;
$data = array();
$mysql = mysql_connect('localhost', 'root', '');
mysql_select_db('stedt');
mysql_query('SET NAMES utf8');
$sqlquery = mysql_query($query . ' limit 40;');
while ($row = mysql_fetch_assoc($sqlquery)) {
    $json = array();
    $json['value'] = $row[$srchindex];
    $data[] = $json;
}
header("Content-type: application/json");
echo json_encode($data);
?>
