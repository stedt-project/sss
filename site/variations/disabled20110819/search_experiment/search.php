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
<div id="centercontent">
   <div id="suggestions">
     Search terms (English glosses, please): <input type="text" size="30" id="searchwords" />
   </div>
   <div id="results">
    </div>
</div>
<div id="rightcontent">
<?php include("rightcontent.php"); ?>
</div>
<div id="footer"><!-- begin footer -->
  <p><hr>The STEDT Project</p>
</div><!-- end footer -->
</div><!-- end maincol -->
</div><!-- end wrapper2 -->
</div><!-- end wrapper1 -->
<!-- script type="text/javascript" src="//ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js"></script -->
<script type="text/javascript" src="js/jquery.min.js"></script>
<script type="text/javascript" src="js/jquery.autoSuggest.js"></script>
<script type="text/javascript" src="js/ajax.js"></script>
<script type="text/javascript" src="js/loadData.js"></script>
<script>
$(document).ready(function () {
$("#suggestions input").autoSuggest("searchwords.php", {minChars: 1,
startText: "Enter some text...", matchCase: false,
resultClick: function(data){ loadData(data); }
});
//loadData( { attributes : { value : "foot" } });
});
</script>
</body>
</html>
