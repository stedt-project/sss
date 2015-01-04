<?php
    ini_set('display_errors', 'On');
    $input = mysql_escape_string($_GET["q"]);
    $data = array();
    // query your DataBase here looking for a match to $input
    $mysql=mysql_connect('localhost','root','');
    mysql_select_db('stedt');
    $query = mysql_query("SELECT word FROM stedt.searchwords WHERE word LIKE '$input%' limit 30");
    while ($row = mysql_fetch_assoc($query)) {
        $json = array();
	$json['value'] = preg_replace("/[\)\(\]\[\*]/","",$row['word']);
        $json['name'] = 'word';
        $data[] = $json;
    }
    // header("Content-type: text/json");
    echo json_encode($data);
?>