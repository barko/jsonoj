#!/bin/sh

# Requires the suite test from http://www.json.org/JSON_checker/
# The JSON files should be unzipped in the parent directory, resulting
# in a test directory that contains pass*.json and fail*.json.

dir=../test
if ! test -x ./jsoncat; then 
    echo "./jsoncat is missing!"; 
    exit 1
fi

for file in $dir/fail*.json; do
    if ./jsoncat $* $file > /dev/null ; then
	echo "ERROR: $file shouldn't pass!"
    else
	echo "OK: $file doesn't pass, as expected."
    fi
done

for file in $dir/pass*.json; do
    if ./jsoncat $* $file > /dev/null ; then
	echo "OK: $file passes."
    else
	echo "ERROR: $file should pass!"
    fi
done
