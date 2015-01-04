<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
    <?php include("head.php"); ?>
    <body>
        <div id="content">
            <div id="banner">
                <?php include("banner.php"); ?>
            </div>
            <div id="tabs">
                <ul>
                    <li><a href="#thesaurus">Thesaurus</a></li>
                    <li><a href="#dictionary">Dictionary</a></li>
                    <li><a href="#lexicon">Lexicon</a></li>
                    <li><a href="#etyma">Etyma</a></li>
                    <li><a href="#bibliography">Bibliography</a></li>
                    <li><a href="#languages">Languages</a></li>
                    <li><a href="#instructions">Instructions</a></li>
                    <li><a href="#queries">Recent Queries</a></li>
                </ul>
<?php $tab = "thesaurus"   ; include("thesaurus.php") ?>
<?php $tab = "dictionary"  ; include("dictionary.php") ?>
<?php $tab = "lexicon"     ; $fields = explode(",","reflex,gloss,language,lggroup,citation"); include("makepage.php"); ?>
<?php $tab = "etyma"       ; $fields = explode(",","chapter,protoform,protogloss,plg"); include("makepage.php"); ?>
<?php $tab = "bibliography"; $fields = explode(",","keyword,citation"); include("makepage.php") ?>
<?php $tab = "languages"   ; $fields = explode(",","language,silcode,lggroup,citation"); include("makepage.php") ?>
<?php $tab = "queries"     ; $fields = explode(",","query,date,results"); include("makepage.php") ?>
                <div id="instructions">
                    <?php include("instructions.php"); ?>
                </div>
            </div>
        </div>
        <script>
            $(document).ready(function() {

                $('[id]').map(function() {
                    var elementID = $(this).attr('id');
                    if (elementID.indexOf('stedt_') == 0) {
                        console.log(elementID);
                        $('#' + elementID + ' input').autoSuggest("autosuggest.php",
                                {minChars: 2, matchCase: false, startText: "", asHtmlID:
                                            elementID, extraParams: "&elementID=" + elementID});
                    }
                });


            });
        </script>
    </body>
</html>
