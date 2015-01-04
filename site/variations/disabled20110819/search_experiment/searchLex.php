<?php
    ini_set('display_errors', 'On');
    $input = mysql_escape_string($_GET["q"]);
    $data = array();
    // query your DataBase here looking for a match to $input
    $mysql=mysql_connect('localhost','root','');
    mysql_set_charset('utf8',$mysql); 
    mysql_select_db('stedt');
    $query = mysql_query("SELECT gloss,reflex,language FROM lexicon join languagenames using (lgid) WHERE gloss LIKE '%$input%' ORDER BY gloss,language limit 30");
    while ($row = mysql_fetch_assoc($query)) {
        $json = array();
	$json['gloss'] = $row['gloss'];
        $json['reflex'] = $row['reflex'];
        $json['language'] = $row['language'];
        $data[] = $json;
    }
    // header("Content-type: text/json");
    echo json_encode($data);
?>