#!/bin/sh

# jsaccess - private web file sharing using client side crypto
# jstore.sh: file store manager for encrypting new files and deploy to server

# Copyright (c) 2013 Laurent Ghigonis <laurent@gouloum.fr>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

VERSION=0.4

PROHIBITED_FILE_NAMES="index.html index.txt"

usage_exit() {
	echo "jsaccess jstore.sh v$VERSION"
	echo "usage: jstore.sh [-v] [action] [action arguments...] [store]"
	echo
	echo "actions on local store for a given passphrase:"
	echo "  ls                   [store] # default action if no arguments"
	echo "  add  <file>          [store] # default action if one argument"
	echo "  add-nocrypt <file>   [store]"
	echo "  rm   <file_in_store> [store]"
	echo "  rmall                [store]"
	echo "  edit                 [store]"
	echo
	echo "actions on local store for all passphrases:"
	echo "  init                 <store>"
	echo "  wipe                 <store>"
	echo
	echo "actions to deploy local store to remote:"
	echo "  push                 [store]"
	echo "  rset <rsync_uri>     [store]"
	echo "  rget                 [store]"
	echo "  clone <rsync_uri>    <store>"
	echo
	echo "actions to get informations:"
	echo "  help|-h"
	echo "  version|-V"
	echo
	echo "By default store is ./store/ or ./jsa/store/"
	echo "Use \"unset HISTFILE; export JSA_PASS=mypass\" to avoid typing the passphrase"
	echo "Use \"unset JSA_PASS\" to forget the passphrase"
	clean_exit 1
}

clean_exit() {
	ret=9
	[ X"$1" != X"" ] && ret=$1
	rm -f $tmp
	exit $ret
}

confirm_exit() {
	if [ X"$JSA_FORCE" = X"" ]; then
		echo -n "Are you sure ? [y/N] "
		read r
		[ X"$r" != X"y" ] && clean_exit 0
	fi
}

__store_test() {
	dir=$1
	[ ! -d $dir ] && return 1
	[ ! -f $dir/index.html ] && return 1
	[ X"`grep -c "The monster has emptied me" $dir/index.html 2>/dev/null`" != X"1" ] && return 1
	return 0
}

_store_get() {
	store=$1
	local_tries="./ ./store/ ./jsa/store/"
	if [ X"$store" = X"" ]; then
		for s in $local_tries; do
			__store_test $s && store=$s && break
		done
	else
		__store_test $store
		[ $? -ne 0 ] && echo "ERROR: specified store is invalid !" && \
			clean_exit 1
	fi
	[ -z $store ] && echo "ERROR: store not found !" && \
		echo "Not specified as argument and local stores" \
			"$local_tries not found" && clean_exit 1
	store=`readlink -f $store`
	echo "Using store \"$store\""
}

_pass_read() {
	if [ X"$JSA_PASS" != X"" ]; then
		pass=$JSA_PASS
	else
		echo "Enter encryption passphrase"
		echo -n "> "
		read pass
	fi
	[ -z $pass ] && echo "ERROR: empty passphrase" && clean_exit 1
	enc_dir_hash=`echo -n $pass |openssl rmd160 |cut -d' ' -f2`
	enc_path="$store/$enc_dir_hash"
}

_index_decrypt() {
	if [ -f $enc_path/index.txt ]; then
		echo -n $pass |openssl enc -d -a -aes-256-cbc -in $enc_path/index.txt -out $tmp -pass stdin ||clean_exit 2
	else
		echo > $tmp
	fi
}

_index_encrypt() {
	rm -f $enc_path/index.txt
	echo -n $pass |openssl enc -e -a -aes-256-cbc -in $tmp -out $enc_path/index.txt -pass stdin ||clean_exit 2
	echo "UPDATED file $enc_path/index.txt"
}

_index_read() {
	clear_name=$1
	index_entry=`egrep "^$clear_name .*$" $tmp 2>/dev/null`
	if [ X"$index_entry" = X"" ]; then
		echo "File does not exist for this passphrase"
		clean_exit 1
	fi
	meta=`echo $index_entry |awk '{ print $(NF) }' |sed s/"(\(.*\))"/\\\1/g`
	size=`echo $meta |cut -d',' -f1`
	crypt=`echo $meta |cut -d',' -f2`
}

_index_check() {
	clear_name=$1
	if [ `egrep -c "^$clear_name .*$" $tmp` -ne 0 ]; then
		echo "File already present with this passphrase"
		clean_exit 1
	fi
}

_index_add() {
	clear_name=$1
	size=$2
	do_crypt=$3
	if [ $do_crypt -eq 0 ]; then
		index_text="$clear_name ($size,nocrypt)"
	else
		index_text="$clear_name ($size,base64+aes256)"
	fi
	echo $index_text >> $tmp
}

_index_rm() {
	clear_name=$1
	sed -i /"^$clear_name .*$"/d $tmp
}

__file_get_encname() {
	clear_name=$1
	enc_name=`echo -n ${enc_dir_hash}${clear_name} |openssl rmd160 |cut -d' ' -f2`
}

_file_add() {
	clear_path=$1
	clear_name=$2
	do_crypt=$3
	__file_get_encname $clear_name
	if [ ! -d $enc_path ]; then
		mkdir -p $enc_path
		touch $enc_path/index.html
		echo "CREATED directory $enc_path (new passphrase)"
	fi
	if [ $do_crypt -eq 1 ]; then
		base64 -w0 $clear_path > $tmp ||clean_exit 2
		echo -n $pass |openssl enc -e -a -aes-256-cbc -in $tmp -out $enc_path/$enc_name -pass stdin ||clean_exit 2
		echo "CREATED file $enc_path/$enc_name"
	else
		cp $clear_path $enc_path/$clear_name
		echo "CREATED file $enc_path/$clear_name"
	fi
}

_file_rm() {
	clear_name=$1
	do_crypt=$2
	if [ $do_crypt -eq 1 ]; then
		__file_get_encname $clear_name
		rm $enc_path/$enc_name ||clean_exit 1
		echo "DELETED file $enc_path/$enc_name"
	else
		rm $enc_path/$clear_name ||clean_exit 1
		echo "DELETED file $enc_path/$clear_name"
	fi
}

_rset() {
	rsync_uri=$1
	if [ -f $store/.rsync_uri ]; then
		echo "This will overwrite existing rsync_uri:"
		cat $store/.rsync_uri
		confirm_exit
	fi
	echo $rsync_uri > $store/.rsync_uri
}

_rget() {
	[ ! -f $store/.rsync_uri ] && echo "ERROR: no rsync_uri set !" && \
		echo "set it with \"jstore.sh rset <rsync_uri> $store\"" && \
		clean_exit 1
	rsync_uri=`cat $store/.rsync_uri`
}

action_ls() {
	_pass_read
	_index_decrypt
	[ ! -f $enc_path/index.txt ] && \
		echo "Passphrase not used in store !" && clean_exit 1
	echo "$enc_dir_hash/index.txt:"
	cat $tmp
}

action_add() {
	clear_path=$1
	do_crypt=$2
	clear_name=`basename $clear_path`
	[ `echo $PROHIBITED_FILE_NAMES |grep -c "\<$clear_name\>"` -ne 0 ] && \
		echo "ERROR: file name $clear_name is prohibited, sorry" && \
		echo -e "Prohibited names list : $PROHIBITED_FILE_NAMES" && \
		clean_exit 1
	_pass_read
	_index_decrypt
	_index_check $clear_name
	_file_add $clear_path $clear_name $do_crypt
	_index_decrypt
	if [ $do_crypt -eq 1 ]; then
		size=`ls -sh $enc_path/$enc_name |cut -d' ' -f1 |tr ',' '.'`
	else
		size=`ls -sh $clear_path |cut -d' ' -f1 |tr ',' '.'`
	fi
	_index_add $clear_name $size $do_crypt
	_index_encrypt
}

action_rm() {
	clear_name=$1
	_pass_read
	_index_decrypt
	_index_read $clear_name
	[ $crypt = "nocrypt" ] && do_crypt=0 || do_crypt=1
	_file_rm $clear_name $do_crypt
	_index_decrypt
	_index_rm $clear_name
	_index_encrypt
}

action_rmall() {
	_pass_read
	echo "This will delete all file encrypted with this passphrase"
	confirm_exit
	rm -rf $enc_path
	echo "DELETED directory $enc_path"
}

action_edit() {
	_pass_read
	_index_decrypt
	vim $tmp
	_index_encrypt
}

action_init() {
	store=$1
	mkdir $store ||clean_exit 1
	echo "The monster has emptied me !" > $store/index.html
	echo "<!-- DO NOT EDIT THIS FILE, part of jsaccess -->" >> $store/index.html
	echo "CREATED store \"$store\""
}

action_wipe() {
	echo "This will delete all file encrypted with all passphrases"
	confirm_exit
	rm -rf $store
	echo "DELETED store \"$store\""
}

action_push() {
	_rget
	rm -f $tmp
	cmd="rsync -rvzP --delete-after $store/ $rsync_uri"
	echo "Running \"$cmd\""
	$cmd
}

action_rset() {
	_rset $1
}

action_rget() {
	_rget
	echo "rsync_uri: $rsync_uri"
}

action_clone() {
	rsync_uri=$1
	store=$2
	[ -e $store ] && echo "ERROR: $store already exists" && clean_exit 1
	cmd="rsync -rvzP --delete-after $rsync_uri $store"
	echo "Running \"$cmd\""
	$cmd
	echo "CREATED store \"store\""
}

# Check for dependencies
if [ X"`which base64`" = X"" \
	-o X"`which openssl`" = X"" ]; then
	echo "You need to have openssl and base64 available in your path !"
	clean_exit 1
fi

# Initialize temporary stuff
sumask=$(umask)
umask 077
tmp=`mktemp ./jsaXXXXXXXX` # Used for storing index / new files
umask $sumask
trap clean_exit INT TERM

# Run action
case $1 in
ls)
	[ $# -ne 1 -a $# -ne 2 ] && usage_exit
	_store_get $2
	action_ls
	;;
add)
	[ $# -ne 2 -a $# -ne 3 ] && usage_exit
	_store_get $3
	action_add $2 1
	;;
add-nocrypt)
	[ $# -ne 2 -a $# -ne 3 ] && usage_exit
	_store_get $3
	action_add $2 0
	;;
rm)
	[ $# -ne 2 -a $# -ne 3 ] && usage_exit
	_store_get $3
	action_rm $2
	;;
rmall)
	[ $# -ne 1 -a $# -ne 2 ] && usage_exit
	_store_get $2
	action_rmall
	;;
edit)
	[ $# -ne 1 -a $# -ne 2 ] && usage_exit
	_store_get $2
	action_edit
	;;
init)
	[ $# -ne 2 ] && usage_exit
	action_init $2
	;;
wipe)
	[ $# -ne 2 ] && usage_exit
	_store_get $2
	action_wipe
	;;
push)
	[ $# -ne 1 -a $# -ne 2 ] && usage_exit
	_store_get $2
	action_push
	;;
rset)
	[ $# -ne 2 -a $# -ne 3 ] && usage_exit
	_store_get $3
	action_rset $2
	;;
rget)
	[ $# -ne 1 -a $# -ne 2 ] && usage_exit
	_store_get $2
	action_rget
	;;
clone)
	[ $# -ne 3 ] && usage_exit
	action_clone $2 $3
	;;
help|-h|version|-V)
	usage_exit
	;;
"")
	[ $# -ne 0 ] && usage_exit
	_store_get
	action_ls
	;;
*)
	[ $# -ne 1 ] && usage_exit
	_store_get $2
	action_add $1
esac

clean_exit 0

