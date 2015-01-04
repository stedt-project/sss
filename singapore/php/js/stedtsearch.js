// support functions
$(function() {
    $( "#tabs" ).tabs({
        ajaxOptions: {
            error: function( xhr, status, index, anchor ) {
            $( anchor.hash ).html("Couldn't load this tab.");
            }
        }
    });
});

function submitForm(myForm) {
    var myFormId = '#'+myForm+'_form';
    var myResultId = '#'+myForm+'_result';
    //console.log(myResultId);
    // input#gloss.as-input
    $.ajax({type:'POST', url: 'search.php?type='+myForm,
    data:$(myFormId).serialize(),
    success: function(response) {
        $('#content').find(myResultId).html(response);
    }
});
    return false;
}