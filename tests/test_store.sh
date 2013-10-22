#!/bin/sh

# Unittests for jsaccess jstore.sh

jstoresh=../jstore.sh
TMP=test_store.tmp
export JSA_PASS=jsa_unittest_passphrase
export JSA_FORCE=1

echo
echo "=== INIT ==="

$jstoresh init store ||exit 1
[ -d store ] ||exit 2

echo
echo "=== LOCAL ==="

$jstoresh add example.txt ||exit 10
[ -d ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/ ] ||exit 11
[ -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 12
$jstoresh ls > $TMP ||exit 20
[ `grep -c "example.txt" $TMP` -eq 1 ] || exit 21
rm $TMP
$jstoresh rm example.txt ||exit 30
[ ! -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 31
$jstoresh ls > $TMP ||exit 40
[ `grep -c "example.txt" $TMP` -eq 0 ] || exit 41
rm $TMP

$jstoresh add example.txt ||exit 50
[ -d ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/ ] ||exit 51
[ -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 52
$jstoresh rmall ||exit 60
[ ! -d ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/ ] ||exit 61

$jstoresh add-nocrypt example.txt ||exit 70
[ -d ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/ ] ||exit 71
[ -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/example.txt ] ||exit 72
$jstoresh rm example.txt ||exit 80
[ ! -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/example.txt ] ||exit 81
$jstoresh ls > $TMP ||exit 90
[ `grep -c "example.txt" $TMP` -eq 0 ] || exit 91
rm $TMP

$jstoresh add example.txt ||exit 95
[ -d ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/ ] ||exit 96
[ -f ./store/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 97

echo
echo "=== DEPLOY ==="

$jstoresh rset store_push ||exit 100
echo store_push |diff -u - ./store/.rsync_uri ||exit 101

$jstoresh rget > $TMP ||exit 110
[ `grep -c "rsync_uri: store_push" $TMP` -eq 1 ] || exit 21

$jstoresh push ||exit 120
[ -f ./store_push/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 121

$jstoresh clone store/ store_clone ||exit 130
[ -f ./store_clone/ad2c5eb7c4fca722235f5df80e11fa619adbd533/8e895f3f4317fb442747a40b9025d6ad8c9c8cf3 ] ||exit 131

echo
echo "=== WIPE ==="

$jstoresh wipe store ||exit 200
[ ! -d store ] ||exit 201

rm -rf ./store_clone/ ./store_push/
rm $TMP

echo
echo TEST OK
exit 0
