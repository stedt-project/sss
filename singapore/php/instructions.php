<div id="instructions">
    <h3>Instructions</h3>

    <p>A browsing interface to the STEDT database, designed with simplicity and discoverablity in mind.</p>

    <h4>Features</h4>
    <ul>
        <li>Multiple, persistent tabs allow access to different views of the database. Your results remain in each tab until you change them.
        <li>Sophisticated "autosuggest" capability in all fields, making it easy to find out what is contained in the database.
        <li>Intuitive approach to building complex queries quickly. For example, the query shown in the first graphic below could be expressed as "show me lexical items meaning 'hand' OR 'arm' OR 'wing' in all the <i>Lolo-Burmese languages</i> in the database.
        <li>Single window eliminates "lost or obscured window" problems.
        <li>Clean, crisp layout, easy to read and comprehend.
        <li>Lightning fast.
    </ul>
    <center>
        <?php
        $images = explode(',', 'screen2lexicon,screen3etyma,screen4languages');
        for ($j = 0; $j < sizeof($images); $j++) {
            ?>
            <p><a href="images/<?php echo $images[$j]; ?>"><img src="images/<?php echo $images[$j]; ?>" width="900"></a></p>
<?php } ?>
    </center>
</div>