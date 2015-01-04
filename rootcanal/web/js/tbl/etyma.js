// restrict casual users from editing plg field
setup['etyma']['etyma.grpid'].noedit = !(stedtuserprivs & 1);

// add delete button for approvers
if (stedtuserprivs & 8) {
	setup['etyma']['etyma.status'].transform = function (v) {
		if (v.toUpperCase() === 'DELETE' || v === 'KEEP') return v;
		return v + '<input value="Del" type="button" class="del_btn">';
	};
}
setup['etyma']['etyma.status'].size = 40;
var do_delete_check = function (tag) {
	new Ajax.Request(baseRef + 'tags/delete_check0', {
		parameters: {tag: tag},
		onSuccess: function(transport) {
			var t = transport.responseText;
			if (t) {
				alert("Can't delete #" + tag + ":\n\n" + t);
				return;
			}
			window.open(baseRef + 'tags/delete_check?tag=' + tag, 'delete_check_popup', 'width=800,height=800');
		},
		onFailure: function(transport) {
			alert(transport.responseText);
		}
	});
};
