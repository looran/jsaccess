/* jsaccess - private web file sharing using client side crypto
 * jsa.js: Main javascript file */

/*
 * Copyright (c) 2013 Laurent Ghigonis <laurent@gouloum.fr>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* Reference code */
//console.log(JSON.stringify(xhr));

/* ===== PUBLIC - called by html ===== */

/* Called on "body" load */
function jsainit() {
	/* Focus password field */
	$("input:text:visible:first").focus();

	/* Banner text */
	$.ajax({
		url: "banner/banner.txt",
		beforeSend: function ( xhr ) {
			xhr.overrideMimeType("text/plain");
		},
		success: function (data) {
			$('#header h1').html(data);
		}
	});
	/* Banner image */
	$.ajax({
		url: "banner/banner.png",
		beforeSend: function ( xhr ) {
			xhr.overrideMimeType("image/png");
		},
		success: function (data) {
			$('#banner img').attr('src', "banner/banner.png");
			/* Banner image link */
			$.ajax({
				url: "banner/banner-png-href.txt",
				beforeSend: function ( xhr ) {
					xhr.overrideMimeType("text/plain");
				},
				success: function (data) {
					$('#banner a').attr('href', data);
				}
			});
		},
		error: function (data) {
			$('#banner img').remove();
		}
	});
}

/* Called on "Get files list" click */
function jsagetlist() {
	var pass = document.getElementById('password').value;
	var RMD160 = new Hashes.RMD160;
	var hash = RMD160.hex(pass);

	_status("Getting file list ...");
	listreq = $.ajax({
		url: 'store/' + hash + '/index.txt',
		beforeSend: function ( xhr ) {
			xhr.overrideMimeType("application/base64");
		},
		success: function ( data ) {
			_status("We have file list");
			_showfiles(data, pass, hash);
		},
		error: function (xhr, opts, err) {
			// XXX differentiate crypto and permission errors
			_status("Bad password");
			document.getElementById('files').innerHTML = "";
			throw(err);
		}
	});
}

/* Called on "Download" click */
function jsadl() {
	var pass = document.getElementById('password').value;
	var file = $('input[name=file]:checked').val();

	if (!file)
		_status("You have to select a file");
	else
		obj = _dl(file, pass);
}

/* ===== PRIVATE - called within this javascript file ===== */

function _index_read(file) {
	var name = file.substring(0, file.lastIndexOf(" "));
	var meta = file.split(" ").pop().replace("(", "").replace(")", "");
	var size = meta.split(",")[0];
	var crypt = meta.split(",")[1];
	return {name: name, size: size, crypt: crypt};
}

function _showfiles(data, pass, hash) {
	try {
		var decrypted = GibberishAES.dec(data, pass);
	} catch(err) {
		_status(err.toString());
		throw err;
	}

	document.getElementById('files').innerHTML = "";
	lines = decrypted.split("\n").filter(function(n){return n});
	$.each(lines,
		function( idx, obj ){
			obj = obj.trim();
			var meta = _index_read(obj);
			console.log(meta);
			extra = "";
			if (meta.crypt == 'nocrypt')
				extra = " (c)";
			var btn = $('<label><input type="radio" name="file" value="'+obj+'">'+meta.name+' ['+meta.size+']'+extra+'</input></label><br/>');
			btn.appendTo('#files');
		});
	$("input:radio[name=file]:first").attr('checked', true);
}

function _dl(file, pass) {
	var RMD160 = new Hashes.RMD160;

	var dirhash = RMD160.hex(pass);
	var meta = _index_read(file);
	_status("Downloading \""+meta.name+"\" ...");

	/* File is not encrypted */
	if (meta.crypt == 'nocrypt') {
		var path = 'store/' + dirhash + '/' + meta.name;
		_status("File is in your hands,<br/>Have a good day.<br/>");
		window.location = path;
		return;
	}

	/* File is encrypted */
	var path = 'store/' + dirhash + '/' + RMD160.hex(dirhash + meta.name);
	dlreq = $.ajax({
		url: path,
		beforeSend: function ( xhr ) {
			xhr.overrideMimeType("application/base64");
		},
		success: function ( data ) {
			_status("Download complete, decrypting ...",
				function() { _decrypt(data, pass, meta.name); });
		},
		error: function (xhr, opts, err) {
			_status("Dowload failed (status="+xhr.status+")");
			throw(err);
		}
	});
}

function _decrypt(obj, pass, name) {
	try {
		var decrypted = GibberishAES.dec(obj, pass);
	} catch(err) {
		_status(err.toString());
		throw err;
	}
	out = $.base64.decode(decrypted.toString());
	_status("Decrypted successfuly, saving ...");
	_save(out, name);
}

function _save(obj, name) {
	var ab = new ArrayBuffer(obj.length);
	var ia = new Uint8Array(ab);
	for (var i = 0; i < obj.length; i++) {
		ia[i] = obj.charCodeAt(i);
	}
	var blob = new Blob([ia], {type:"application/octet-binary"});
	saveAs(blob, name);
	_status("File is in your hands,<br/>Have a good day.<br/>");
}

function _status(txt, run_func) {
	var div = document.getElementById('status_p');
	div.innerHTML = div.innerHTML + '<br/>' + txt;
	/* force refresh with trick */
	jQuery.fn.redraw = function() {
		return this.hide(0, function() {
			$(this).show();
		});
	};
	$('#status_p').redraw();
	/* force refresh with async execution */
	if (run_func)
		setTimeout(run_func, 100);
}

