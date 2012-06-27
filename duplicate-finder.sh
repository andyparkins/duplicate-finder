#!/bin/sh

# Here is a way of testing this script:
#
#  $ mkdir test1 test2
#  $ echo "unique-in-test1" > test1/unique-in-test1
#  $ echo "common-in-test1-and-test2" > test1/common-in-test1-and-test2
#  $ echo "common-in-test1-and-test2" > test2/common-in-test1-and-test2
#  $ echo "unique-in-test2" > test2/unique-in-test2
#  $ echo "duplicate-in-test1" > test1/duplicate1-in-test1
#  $ echo "duplicate-in-test1" > test1/duplicate2-in-test1
#  $ echo "duplicate-in-test2" > test2/duplicate1-in-test2
#  $ echo "duplicate-in-test2" > test2/duplicate2-in-test2
#  $ tree
#  .
#  |-- test1
#  |   |-- common-in-test1-and-test2
#  |   |-- duplicate1-in-test1
#  |   |-- duplicate2-in-test1
#  |   `-- unique-in-test1
#  `-- test2
#      |-- common-in-test1-and-test2
#      |-- duplicate1-in-test2
#      |-- duplicate2-in-test2
#      `-- unique-in-test2
#

ROOT1=$1
ROOT2=$2
HASHER=md5sum
HASHWIDTH=32

if [ -z "$ROOT2" ]; then
	ROOT2=$ROOT1
fi
if [ -z "$ROOT1" -o -z "$ROOT2" ]; then
	echo "$0 <root1> <root2>"
	exit 1
fi

# Tidy up
for suffix in hash-sorted unique duplicates minimal wasteful; do
	rm -f "ROOT1-$suffix"
	rm -f "ROOT2-$suffix"
done
for suffix in combined duplicates minimal; do
	rm -f "ROOT1-ROOT2-$suffix"
done

echo "Creating hashes"
if [ ! -f "ROOT1-hash" ]; then
	echo " - hashing $ROOT1"
	cd $ROOT1
	find . -type f -exec ${HASHER} {} \; > "${OLDPWD}/ROOT1-hash"
	cd - > /dev/null
	printf " - %d hashes created for %s\n" $(wc -l ROOT1-hash)
fi
if [ ! -f "ROOT2-hash" -a "$ROOT1" != "$ROOT2" ]; then
	echo " - hashing $ROOT2"
	cd $ROOT2
	find . -type f -exec ${HASHER} {} \; > "${OLDPWD}/ROOT2-hash"
	cd - > /dev/null
	printf " - %d hashes created for %s\n" $(wc -l ROOT2-hash)
fi

echo "Sorting hashes by hash"
if [ ! -f "ROOT1-hash-sorted" ]; then
	echo " - sorting $ROOT1 hashes"
	sort < ROOT1-hash > ROOT1-hash-sorted
fi
if [ ! -f "ROOT2-hash-sorted" -a "$ROOT1" != "$ROOT2" ]; then
	echo " - sorting $ROOT2 hashes"
	sort < ROOT2-hash > ROOT2-hash-sorted
fi

echo "Unique"
if [ ! -f "ROOT1-unique" ]; then
	echo " - Uniqueness of $ROOT1"
	uniq --check-chars=$HASHWIDTH -u ROOT1-hash-sorted > ROOT1-unique
	printf " - %d hashes in %s\n" $(wc -l ROOT1-unique)
	# unique-in-test1
	# common-in-test1-and-test2
fi
if [ ! -f "ROOT2-unique" -a "$ROOT1" != "$ROOT2" ]; then
	echo " - Uniqueness of $ROOT2"
	uniq --check-chars=$HASHWIDTH -u ROOT2-hash-sorted > ROOT2-unique
	printf " - %d hashes in %s\n" $(wc -l ROOT2-unique)
	# unique-in-test2
	# common-in-test1-and-test2
fi

echo "Duplicates (in-tree only)"
if [ ! -f "ROOT1-duplicates" ]; then
	echo " - Duplicates in $ROOT1"
	uniq --check-chars=$HASHWIDTH -D ROOT1-hash-sorted > ROOT1-duplicates
	printf " - %d hashes in %s\n" $(wc -l ROOT1-duplicates)
	# duplicate1-in-test1
	# duplicate2-in-test1
fi
if [ ! -f "ROOT2-duplicates" -a "$ROOT1" != "$ROOT2" ]; then
	echo " - Duplicates in $ROOT2"
	uniq --check-chars=$HASHWIDTH -D ROOT2-hash-sorted > ROOT2-duplicates
	printf " - %d hashes in %s\n" $(wc -l ROOT2-duplicates)
	# duplicate1-in-test2
	# duplicate2-in-test2
fi

echo "Minimal (unnecessary duplicates removed within a tree)"
if [ ! -f "ROOT1-minimal" ]; then
	sort --merge --unique --key=1,1 ROOT1-hash-sorted > ROOT1-minimal
	printf " - %d hashes in %s\n" $(wc -l ROOT1-minimal)
	# unique-in-test1
	# duplicate1-in-test1
	# common-in-test1-and-test2
fi
if [ ! -f "ROOT2-minimal" -a "$ROOT1" != "$ROOT2" ]; then
	sort --merge --unique --key=1,1 ROOT2-hash-sorted > ROOT2-minimal
	printf " - %d hashes in %s\n" $(wc -l ROOT2-minimal)
	# unique-in-test2
	# duplicate1-in-test2
	# common-in-test1-and-test2
fi

echo "Wasteful (files with duplicates within a tree)"
if [ ! -f "ROOT1-wasteful" ]; then
	uniq --check-chars=$HASHWIDTH -d ROOT1-hash-sorted > ROOT1-wasteful
	printf " - %d hashes in %s\n" $(wc -l ROOT1-wasteful)
	# duplicate1-in-test1
fi
if [ ! -f "ROOT2-wasteful" ]; then
	uniq --check-chars=$HASHWIDTH -d ROOT2-hash-sorted > ROOT2-wasteful
	printf " - %d hashes in %s\n" $(wc -l ROOT2-wasteful)
	# duplicate1-in-test2
fi


if [ "$ROOT1" = "$ROOT2" ]; then
	return
fi

echo "Combining minimal lists"
if [ ! -f "ROOT1-ROOT2-combined" ]; then
	grep -H "" ROOT1-minimal ROOT2-minimal | sed 's/^\([^:]\+\):/\1 /' > ROOT1-ROOT2-combined
	# ROOT1: unique-in-test1
	# ROOT1: duplicate1-in-test1
	# ROOT1: common-in-test1-and-test2
	# ROOT2: unique-in-test2
	# ROOT2: duplicate1-in-test2
	# ROOT2: common-in-test1-and-test2
fi

echo "Duplicates (across trees, excluding in-tree duplicates)"
if [ ! -f "ROOT1-ROOT2-duplicates" ]; then
	sort --key=2,2 ROOT1-ROOT2-combined | \
		uniq --skip-fields=1 --check-chars=$HASHWIDTH -D > ROOT1-ROOT2-duplicates
	# ROOT1: common-in-test1-and-test2
	# ROOT2: common-in-test1-and-test2
	printf " - %d hashes in %s\n" $(wc -l ROOT1-ROOT2-duplicates)
fi

echo "Minimal (across trees, excluding in-tree duplicates)"
if [ ! -f "ROOT1-ROOT2-minimal" ]; then
	sort --key=2,2 --unique ROOT1-ROOT2-combined > ROOT1-ROOT2-minimal
	# ROOT1: duplicate1-in-test1
	# ROOT1: unique-in-test1
	# ROOT2: unique-in-test2
	# ROOT2: duplicate1-in-test2
	# ROOT1,2: common-in-test1-and-test2
	printf " - %d hashes in %s\n" $(wc -l ROOT1-ROOT2-minimal)
fi

