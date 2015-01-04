/*
 * ajax.js
 */

function loadAjaxData(reqType, reqURL, reqParamObj, outputType, cbFunction) {
	//reusable function for all ajax calls	
	$.ajax({
		type: reqType,
		url: reqURL,
		data: reqParamObj,
		processData: true,
		dataType: "text",
		error: function (XMLHttpRequest, textStatus, errorThrown) {
			//alert("An error occured, please reload the page and try again (" + textStatus + ":" + errorThrown + ")");
		},
		success: function(rawData, textStatus) {
			try {
				var data = JSON.parse(rawData);
				// if ( data.status.error ) {
			        if ( data.length == 0 ) {
					//alert("An error occured, please reload page and try again (server error:" + data.status.errorMessage + ")");
				}
				else {										
					// execute success callback function
					cbFunction(data);
				}				
			}
			catch (e) {
				//alert("An error occured, please reload the page and try again (exception:" + e.name + "," + e.message + ")");
			}
		}
	})	
}
