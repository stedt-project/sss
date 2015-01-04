<div id="<?php echo $tab ?>">
    <form id="<?php echo $tab ?>_form" onsubmit="return submitForm('<?php echo $tab ?>');">
        <div id="button">
            <button>Search</button>
            <button type="reset">Reset</button>
        </div>
        <div id="data">
            <table>
                <tr>
                    <?php for ($j = 0; $j < sizeof($fields); $j++) { ?>
                        <th><?php echo $fields[$j]; ?></th>
                    <?php } ?>
                </tr>
                <tr>
                    <?php for ($j = 0; $j < sizeof($fields); $j++) { ?>
                        <td>
                            <div id="stedt_<?php echo $tab; ?>_<?php echo $fields[$j]; ?>"><input type="text" value="" /></div>
                        </td>
                    <?php } ?>
                </tr>
            </table>
            <div id="<?php echo $tab ?>_result"> </div>
        </div>
    </form>
</div>