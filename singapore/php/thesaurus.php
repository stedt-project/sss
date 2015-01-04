<div id="<?php echo $tab ?>">
    <link rel="stylesheet" href="css/jqtree.css">
    <script src="js/tree.jquery.js"></script>
    <form id="<?php echo $tab ?>_form" onsubmit="return submitForm('<?php echo $tab ?>');">
        <div id="thesaurusTop">
            <button>Search</button>
            <button type="reset">Reset</button>
        </div>
        <div id="data">
            <div id="tree1" data-url="nodes/"></div>
            <button id="add">Add!</button>
        </div>
    </form>
    <script>
        $(function() {
            var $tree = $('#tree1');

            $tree.tree({
                dragAndDrop: true
            });
            console.log('tree started');
        });

        $('#tree1').bind(
                'tree.open',
                function(e) {
                    //console.log(e.node);
                    for (i = 0, len = e.node['children'].length; i < len; i++) {
                        var child = e.node['children'][i];
                        console.log(child);
                        if (child['children'].len == 0) {
                            console.log('0 len child');
                            e.node['children'][i]['load_on_demand'] = false;
                        }
                    }
                    switch(e.node['type']) {
                    case 'reflexes':
                        console.log('reflex!');
                        //delete e.node['children'];
                    case 'etyma':
                        console.log('etyma!');
                        //delete e.node['children'];
                    case 'subgroup':
                        console.log('subgroup!');
                        //delete e.node['children'];
                    }
                }
        );
    </script>
</div>