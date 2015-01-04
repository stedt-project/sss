<?php

ini_set('display_errors', 'On');
// loop through post data for form, make up individual query expressions
$numterms = 0;
if (isset($_GET["debug"])) {
    $debug = $_GET["debug"];
} else {
    $debug = False;
}
$queryterms = array();
$querytype = $_GET["type"];
foreach ($_POST as $key => $value) {
    if ($debug) {
        printf('%s = "%s"<br/>', $key, $value);
    }
    //$key = str_replace("as_values_","",$key);
    $key = preg_replace('/as_values_stedt_.*?_/', '', $key);
    $values = explode(",", $value);
    $subelements = array();
    foreach ($values as $v) {
        if ($v != '') {
            //printf('%s = "%s"<br/>', $key, $v);
            if ($key == 'lggroup') {
                $v = preg_replace('/ :.*$/', '', $v);
                $subelements[] = sprintf('grpno LIKE "%s%%"', $v);
            } elseif ($querytype == 'bibliography') {
                $v = preg_replace('/^ /', '', $v);
                $subelements[] = sprintf('%s LIKE "%%%s%%"', $key, $v);
            } elseif ($querytype == 'dictionary') {
                $v = preg_replace('/^ /', '', $v);
                $subelements[] = sprintf('%s LIKE "%%%s%%"', $key, $v);
            } else {
                $subelements[] = sprintf('%s = "%s"', $key, $v);
            }
            $numterms++;
        }
    }
    if (sizeof($subelements) > 0) {
        if ($querytype == 'bibliography') {
            $queryterms[] = implode(" and ", $subelements);
        } else {
            $queryterms[] = implode(" or ", $subelements);
        }
    }
}
// whew! now makeup the WHERE clause
$where = "(" . implode(") and (", $queryterms) . ")";
if ($where == '()') {
    print "<h3>Please enter something to search for.</h3>";
    return;
}
// figure out which complicated query to issue
if ($querytype == 'lexicon') {
    $query = 'select reflex,gloss,l.language as language,concat(g.grpno," : ",g.grp) as lggroup,'
            . ' GROUP_CONCAT(DISTINCT s.citation SEPARATOR ", ") as citation,'
            . ' CONCAT(LEFT(g.grpno,6)," : ",LEFT(gloss,10)," : ",reflex) AS lexkey '
            . ' from lexicon,'
            . ' languagenames l,srcbib s,languagegroups g '
            . ' where l.lgid=lexicon.lgid and s.srcabbr=l.srcabbr and g.grpid=l.grpid and ' . $where
            . ' group by lexkey,language order by lexkey,language limit 500';
} elseif ($querytype == 'dictionary') {
    $query = 'select gloss,l.language as language,reflex,'
            . ' GROUP_CONCAT(DISTINCT s.citation SEPARATOR ", ") as citation,'
            . ' concat(g.grpno," : ",g.grp) as lggroup,'
            . ' CONCAT(LEFT(g.grpno,6)," : ",LEFT(gloss,10)," : ",reflex) AS lexkey '
            . ' from lexicon,'
            . ' languagenames l,srcbib s,languagegroups g '
            . ' where l.lgid=lexicon.lgid and s.srcabbr=l.srcabbr and g.grpid=l.grpid and ' . $where
            . ' group by gloss,lexkey,language order by gloss,lexkey,language limit 500';
} elseif ($querytype == 'etyma') {
    $query = 'select chapter,protoform,protogloss,l.plg as plg '
            . ' from etyma,languagegroups l where '
            . ' etyma.grpid = l.grpid and ' . $where
            . ' group by chapter,protoform,protogloss order by protoform,protogloss limit 500';
} elseif ($querytype == 'bibliography') {
    $where = str_replace("citation2", "citation", $where);
    $query = 'select * from (select citation,author,year,title,imprint,concat(author,year,title) as keyword'
            . ' from srcbib) as x where ' . $where
            . ' order by author,year,title limit 500';
} elseif ($querytype == 'languages') {
    $where = str_replace("citation2", "citation", $where);
    $query = 'select l.language,l.silcode,concat(g.grpno," : ",g.grp) as lggroup,'
            . ' GROUP_CONCAT(DISTINCT s.citation SEPARATOR ", ") as citation'
            . ' from '
            . ' languagenames l,srcbib s,languagegroups g '
            . ' where s.srcabbr=l.srcabbr and g.grpid=l.grpid and ' . $where
            . ' group by language order by language limit 500';
} elseif ($querytype == 'etymologies') {
    $query = 'select reflex,gloss,l.language as language,concat(g.grpno," : ",g.grp) as lggroup,'
            . ' CONCAT(LEFT(g.grpno,6)," : ",LEFT(gloss,10)," : ",reflex) AS lexkey, '
            . ' GROUP_CONCAT(DISTINCT s.citation SEPARATOR ", ") as citation '
            . ' from lexicon,'
            . ' languagenames l,srcbib s,languagegroups g '
            . ' where l.lgid=lexicon.lgid and s.srcabbr=l.srcabbr and g.grpid=l.grpid and ' . $where
            . ' group by lexkey,language order by lexkey,language limit 500';
}
//print "debug".$debug;
if ($debug) {
    print "<hr/><tt>" . $query . "</tt><hr/>";
}

$mysql = mysql_connect('localhost', 'root', '');
mysql_select_db('stedt');
mysql_query('SET NAMES utf8');
$q = mysql_query($query);
print '<table>';
$gloss = '';
while ($row = mysql_fetch_row($q)) {
    if ($querytype == 'bibliography') {
        print "<tr><td>" . implode("</td><td>", array_slice($row, 0, 4)) . '</td></tr>';
    } elseif ($querytype == 'dictionary') {
        if ($gloss != $row[0]) {
            print sprintf('<tr><td><h4>%s</h4></td></tr>', $row[0]);
            $gloss = $row[0];
        }
        print vsprintf('<tr><td>&nbsp;&nbsp;<tt>%s</tt> <b>%s</b> <i>%s</i> </td></tr>', array_slice($row, 1, 3));
    } else {
        print "<tr><td>" . implode("</td><td>", array_slice($row, 0, 5)) . '</td></tr>';
    }
}
print "</table>";
?>
