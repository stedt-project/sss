/*
 * loadData.js
 */

function loadData(data) {	

    //load search results
    console.log(data);
    var searchResults = {outputFormat: "JSON", pageSection : "results", "q": data.attributes.value};
    loadAjaxData("GET","searchLex.php", searchResults,"JSON", showResults); 
    
    function showResults(jsonData) {
	console.log(jsonData);
	var rowResult = "<table>";
	for ( i = 0; i < jsonData.length; i++ ) {
	    rowResult += '<tr class="row">';
	    rowResult += '<td class="gloss">' + jsonData[i].gloss + '</td>';
	    rowResult += '<td class="reflex">' + jsonData[i].reflex + '</td>';
	    rowResult += '<td class="lg">' + jsonData[i].language + '</span>';
	    rowResult += '</tr>';
	}
	rowResult += '</table>';

	$('#results').html(rowResult);
    }	
}
