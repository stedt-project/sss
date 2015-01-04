<div id="<?php echo $tab ?>">
    <form id="<?php echo $tab ?>_form" onsubmit="return submitForm('<?php echo $tab ?>');">
        <div id="button">
            <button>Search</button>
            <button type="reset">Reset</button>
        </div>
        <div id="data">
            <table>
                <tr>
                    <th class="short">type a few letters of the gloss</th>
                    <td><div id="stedt_dictionary_gloss"><input type="text" value="" /></div></td>
                </tr>
            </table>
            <table>
            </table>
            <div id="<?php echo $tab ?>_result"> </div>
        </div>
    </form>
</div>