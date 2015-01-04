<?php

function getCounts($query,$type) {
    $sqlquery = mysql_query($query . ' limit 500;');
    $countq = mysql_query("SELECT FOUND_ROWS()");
    $count = mysql_fetch_array($countq);
    $count = $count[0];
    return array($count,$type,$sqlquery);
}

//ini_set('display_errors', 'On');
$nodekey = mysql_escape_string($_GET["node"]);
//$level = mysql_escape_string($_GET["type"]);
// kludge: strip double quotes, should they be present...get this right someday.
$nodekey = str_replace('\"', '', $nodekey);
list($semkey, $tag, $subgroup, $rn) = explode("/", $nodekey);
//print 'nodekey '.$nodekey . "\n";
//print "$semkey, $tag, $subgroup, $rn\n";
//$chapter = mysql_escape_string($_GET["chapter"]);
// build database query
mysql_connect('localhost', 'root', '');
mysql_select_db('stedt');
mysql_query('SET NAMES utf8');
$etymacount = 0;
$subgroupcount = 0;
$reflexcount = 0;

if ($semkey) {
    // this gets the chapters one level down from the current semkey
    $query = "select v,f,c,s1,s2,s3,semkey,concat('0.',replace(semkey,'.0','')) as semroot,chaptertitle," .
            "(SELECT COUNT(*) FROM etyma WHERE chapter = chapters.semkey AND etyma.status != 'DELETE' ) as etymacount, " .
            "0 as cumulative " .
            "FROM chapters WHERE semkey RLIKE '^$semkey.[1-9]+$' order by v,f,c,s1,s2,s3 "; 
    list($semcatcount,$show,$sqlquery) = getCounts($query, 'semcats');
    //print $query;
} 

else {
    // the reason this query works is a mystery known only to the initiated
    $query = "select v,f,c,s1,s2,s3,replace(semkey,'.0','') as semkey,chaptertitle," .
            "(SELECT COUNT(*) FROM etyma WHERE chapter = chapters.semkey AND etyma.status != 'DELETE' ) as etymacount, " .
            "0 as cumulative " .
            "FROM chapters WHERE f = 0 order by v,f,c,s1,s2,s3 ";
    list($semcatcount,$show,$sqlquery) = getCounts($query, 'semcats');
    //print $query;
}

# if we didn't find any VFC's
if ($semcatcount == 0) {
    $etymaquery = "select chapter,protoform,protogloss,l.plg as plg,tag,sequence "
            . ' from etyma,languagegroups l where '
            . " etyma.grpid = l.grpid and chapter='$semkey'"
            . ' order by chapter,sequence,protoform,protogloss ';
    list($etymacount,$show,$sqlquery) = getCounts($etymaquery, 'etyma');
}
elseif ($tag) {
    $etymaquery = "select chapter,protoform,protogloss,l.plg as plg,tag,sequence "
            . ' from etyma,languagegroups l where '
            . " etyma.grpid = l.grpid and chapter='$semkey'"
            . ' order by chapter,sequence,protoform,protogloss ';
    list($etymacount,$show,$sqlquery) = getCounts($etymaquery, 'etyma');
}
if ($subgroup) {
    $reflexquery = "SELECT DISTINCT languagegroups.grpno as grpno, grp, language, lexicon.rn as rn, 
(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
reflex, gloss, gfn, languagenames.srcabbr, lexicon.srcid, notes.rn, '$semkey' as chapter, '$tag' as tag
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = '$tag' and grpno = '$subgroup'
AND lx_et_hash.rn=lexicon.rn AND lx_et_hash.uid=8
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid)
ORDER BY languagegroups.grp0, languagegroups.grp1, languagegroups.grp2, languagegroups.grp3, languagegroups.grp4, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
";
    //print $reflexquery;
    list($reflexcount,$show,$sqlquery) = getCounts($reflexquery, 'reflexes');
}
elseif ($tag) {
    $subgroupquery = "SELECT languagegroups.grpno as grpno, grp, '$semkey' as chapter, 
'$tag' as tag, count(*) as n
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = '$tag'
AND lx_et_hash.rn=lexicon.rn AND lx_et_hash.uid=8
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid)
GROUP BY grpno
ORDER BY languagegroups.grp0, languagegroups.grp1, languagegroups.grp2, languagegroups.grp3, languagegroups.grp4, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
";
    //print $subgroupquery;
    list($subgroupcount,$show,$sqlquery) = getCounts($subgroupquery, 'subgroup');
}

// this gets the etyma for a chapter
 
//print $show;
//print "\n";
//print 's'.$semcatcount.'e'.$etymacount.'g'.$subgroupcount.'r'.$reflexcount."\n";
$data = array();
//if ($etymacount == 0 && $semcatcount == 0 && $subgroupcount == 0 && $reflexcount == 0) {
//    print "end of the line";
//} else {
if (TRUE) {
    while ($row = mysql_fetch_assoc($sqlquery)) {
        $json['load_on_demand'] = true;
        if ($show == 'semcats') {
            $json['label'] = $row['semkey'] . ' ' . $row['chaptertitle'];
            //$json['id'] = intval(str_replace('.','0',$row['semkey']));
            $json['id'] = $row['semkey'];
        } elseif ($show == 'etyma') {
            //print "showingetyma\n";
            $json['label'] = $row['sequence'] . ' ' . $row['plg'] . ' ' .
                    $row['protoform'] . ' ' . $row['protogloss'] . ' [' . $row['tag'] . ']';
            //$json['id'] = intval(str_replace('.','0',$row['semkey']));
            $json['id'] = $row['chapter'] . '/' . $row['tag'] . '/';
        } elseif ($show == 'subgroup') {
            $json['label'] = $row['grpno'] . ' ' . $row['grp'];
            //$json['id'] = intval(str_replace('.','0',$row['semkey']));
            $json['id'] = $row['chapter'] . '/' . $row['tag'] . '/' . $row['grpno'];
        } elseif ($show == 'reflexes') {
            $json['label'] = $row['language'] . ' ' .
                    $row['reflex'] . ' ' . $row['gloss'];
            $json['id'] = $row['chapter'] . '/' . $row['tag'] . '/' . $row['grpno'] . '/' . $row['rn'];
            // reflexes are the leaf nodes.
            $json['load_on_demand'] = false;
        }
        $json['type'] = $show;
        $data[] = $json;
    }
}
header("Content-type: application/json");
echo json_encode($data);
?>