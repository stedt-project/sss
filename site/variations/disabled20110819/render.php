<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<?php include("head.php"); ?>
<body>
<div id="wrapper1"><!-- sets background to white and creates full length leftcol-->	
<div id="wrapper2"><!-- sets background to white and creates full length rightcol-->
<div id="maincol"><!-- begin main content area -->
<div id="banner">
<?php include("banner.php"); ?>
</div>
<div id="leftcontent">
<?php include("leftcontent.php"); ?>
</div>
<div id="rightcontent">
<?php include("rightcontent.php"); ?>
</div>
<div id="centercontent">
<?php
    ini_set('display_errors', 'On');
    $input = mysql_escape_string($_GET["page"]);
?>
<?php include("$input.html"); ?>
</div>
<div id="footer"><!-- begin footer -->
  <p>The STEDT Project</p>
</div><!-- end footer -->
</div><!-- end maincol -->
</div><!-- end wrapper2 -->
</div><!-- end wrapper1 -->
</body>
</html>
