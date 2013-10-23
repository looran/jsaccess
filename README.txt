jsaccess - private web file sharing using client side crypto
2013, Laurent Ghigonis <laurent@gouloum.fr>

Store files encrypted with symetric key (AES-256) and it will seamlessly be
decrypted in the user web-browser on download.
Files list cannot be accessed without the correct passphrase.
It's possible to store files but not encrypt them with jsaccess, for example
for files already PGP encrypted.
No htaccess, https, or any server side configuration required, as it will just
serve static pre-encrypted files.

Note:
You should still use https to protect against clients targeted attacks like
mitm on the javascript code or mitm on the encrypted archives.


Deployment
==========

Put jsa/ directory on your web server, publicly available.
$ scp -r jsa/ user@myserver:/var/www/htdocs/

Install "jstore" script on your host
$ make install


Share a file
============

[1] Add the file you want to share to the file store

On your machine:
$ jstore add myfile
Then enter the passphase you want to use for encryption.

It will tell you something like:
jsa/store/af022cd820fdad6cbcac8e15ac565c639a47dab0
CREATED file jsa/store/af022cd820fdad6cbcac8e15ac565c639a47dab0/065e18a7f246b800242a778a6e8dd07a3321dac6
UPDATED file jsa/store/af022cd820fdad6cbcac8e15ac565c639a47dab0/index.txt

[2] Synchronise the file store with you online server

On your machine:

Set the rsync url (only once)
$ jstore rset user@myserver:/var/www/htdocs/jsa/store/

Push the file store
$ jstore push

[3] Direct people to the directory jsa/, e.g. http://myserver.com/jsa/


Local demo
==========

$ firefox jsa/index.html
OR
$ google-chrome --allow-file-access-from-files jsa/index.html

Demo password is 'jsa'
Click on 'Get files list' to retrieve the files available for this password
In the demo the only file is 'put_your_encrypted_files_here.txt'
Click on Download
You now have the file decrypted :)


Git content
===========

jsa/ - should be on your webserver, can be renamed
jsa/store/<password_hash>/ - directory of files to download for a given password
jsa/store/<password_hash>/index.txt - list of file name available
jstore - to encrypt the files that will be available for download

There are 2 main parts:
* The jsa/ directory that contains html / javascript files, for the user to
access files list and download. jsa/store/ is the files store.
* The jstore script for the web server owner to manage file store.
It is recommended to run jstore on your machine, and then syncronise the
jsa/store/ with your server via "jstore push".


How it works
============

jstore creates a directory jsa/store/<rmd160_hash_of_passphrase>/.
It encrypts your file using AES256 with the passphrase and stores the result in
jsa/store/<rmd160_hash_of_passphrase>/<rmd160_hash_of_(passphrase+filename)>.
It also updates the index of available files per directory called index.txt,
that contains real file names. The index is also encrypted using AES256 with the
passphrase.

Web UI generates rmd160 hash from the passphrase and get the list of files
available for this passphrase (jsa/store/<rmd160_hash_of_passphrase>/index.txt),
decrypts it and shows the list of files.
When the user clicks on Download, it fetches the file from the rmd160 name,
decrypts it with the passphrase and stores it with the real name using the
Filesaver JS API.


Dependencies / Compatibility
============================

On the host that runs jstore:
* openssl
* base64
* optional: rsync, if you with to use "jstore push" to deploy your file store

On the web server:
* Serving static files is enough
* optional: https, to protect against clients targeted attacks

On the web user machine:
* Tested with Firefox 21 and Chrome 27


Banner
======

You can set your own banner image / link / text without modifying html.
See jsa/banner/README.txt


TODO
====

* web: remove step 3. and show file list as download links
this way user can do right-click "save as"

* web: make password field appear as full of dots after validation

* web: download progress

* web: decrypting progress
Need to modify gibberish-aes
