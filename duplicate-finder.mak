#!/usr/bin/make -f
SHELL=/bin/bash

ROOT1 ?= /tmp
ROOT2 ?= /tmp

HASHER := md5sum
HASHWIDTH := 32


TOP := $(shell pwd)
SELF := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))


default: help

all: \
	ROOT1-wasteful \
	ROOT2-wasteful \
	ROOT1-ROOT2-combined \
	ROOT1-ROOT2-duplicates \
	ROOT1-ROOT2-broken

help:
	@echo "Usage:"
	@echo "  duplicate-finder <mode> ROOT1=<root1_path> ROOT2=<root2_path>"
	@echo ""
	@echo "Modes:"
	@echo " info                    This page"
	@echo " all                     ROOTx-wasteful ROOT1-ROOT2-*"
	@echo " test                    Make test1 and test2 directories, populate"
	@echo "                         and run duplicate-finder on them"
	@echo " clean                   Remove all output files"
	@echo ""
	@echo "Outputs:"
	@echo " ROOTx-duplicates        Files that are the same within ROOTx"
	@echo " ROOTx-minimal           Minimal set to get one copy of everything"
	@echo "                         in ROOTx"
	@echo " ROOTx-wasteful          Files to remove from ROOTx to leave"
	@echo "                         ROOTx-minimal only"
	@echo " ROOT1-ROOT2-duplicates  Files that are duplicated across ROOT1 and"
	@echo "                         ROOT2"
	@echo " ROOT1-ROOT2-minimal     Minimal set to get one copy of everything"
	@echo "                         in ROOT1 and ROOT2"
	@echo " ROOT1-ROOT2-broken      Files with the same path in ROOT1 and ROOT2,"
	@echo "                         but different content"
	@echo ""


# Here is a way of testing this script:
test: testenv
	$(MAKE) -f $(SELF) ROOT1=test1 ROOT2=test2 \
		ROOT1-duplicates ROOT2-duplicates \
		ROOT1-minimal ROOT2-minimal \
		ROOT1-wasteful ROOT2-wasteful \
		ROOT1-ROOT2-duplicates \
		ROOT1-ROOT2-minimal \
		ROOT1-ROOT2-broken
	@echo "-----------"
	cat < ROOT1-duplicates
	cat < ROOT2-duplicates
	cat < ROOT1-minimal
	cat < ROOT2-minimal
	cat < ROOT1-wasteful
	cat < ROOT2-wasteful
	@echo ""
	cat < ROOT1-ROOT2-duplicates
	cat < ROOT1-ROOT2-minimal
	cat < ROOT1-ROOT2-broken

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
testenv:
	-mkdir test1 test2
	echo "unique-in-test1" > test1/unique-in-test1
	echo "common-in-test1-and-test2" > test1/common-in-test1-and-test2
	echo "common-in-test1-and-test2" > test2/common-in-test1-and-test2
	echo "unique-in-test2" > test2/unique-in-test2
	echo "duplicate-in-test1" > test1/duplicate1-in-test1
	echo "duplicate-in-test1" > test1/duplicate2-in-test1
	echo "duplicate-in-test2" > test2/duplicate1-in-test2
	echo "duplicate-in-test2" > test2/duplicate2-in-test2
	echo "different-in-test1-and-test2" > test1/different-in-test1-and-test2
	echo "different-in-test2-and-test1" > test2/different-in-test1-and-test2


# Master hash list, in directory depth order
%-hash:
	@echo "--- hashing $($*)"
	-cd "$($*)"; find . -type f -readable -exec $(HASHER) {} \; > "$(TOP)/$@"
	@printf " - %d hashes created for %s\n" $$(wc -l $@)

# Hash list sorted by hash.  Duplicates will be next to each other
%-hash-sorted: %-hash
	@echo "--- sorting $($*) hashes"
	sort < $< > $@

# Show only those lines where the hash has no identical neighbour
# unique-in-test1
# common-in-test1-and-test2
%-unique: %-hash-sorted
	@echo "--- Uniqueness of $*"
	uniq --check-chars=$(HASHWIDTH) -u $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Show only those lines where the hash is duplicated, shows both
# Duplicates (in-tree only)
# duplicate1-in-test1
# duplicate2-in-test1
%-duplicates: %-hash-sorted
	uniq --check-chars=$(HASHWIDTH) -D $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Show all unique lines and the first of all duplicated hashes
# unique-in-test1
# duplicate1-in-test1
# common-in-test1-and-test2
%-minimal: %-hash-sorted
	sort --merge --unique --key=1,1 $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Wasteful (files with duplicates within a tree), shows only one of the two
# would be safe to delete from this list
# duplicate1-in-test1
%-wasteful: %-hash-sorted
	uniq --check-chars=$(HASHWIDTH) -d $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Combined
# ROOT1: unique-in-test1
# ROOT1: duplicate1-in-test1
# ROOT1: common-in-test1-and-test2
# ROOT2: unique-in-test2
# ROOT2: duplicate1-in-test2
# ROOT2: common-in-test1-and-test2
ROOT1-ROOT2-combined: ROOT1-minimal ROOT2-minimal
	grep -H "" $^ | sed 's/^\([^:]\+\)-minimal:/\1 /' > $@

# --- Duplicates (across trees, excluding in-tree duplicates)
# ROOT1: common-in-test1-and-test2
# ROOT2: common-in-test1-and-test2
ROOT1-ROOT2-duplicates: ROOT1-ROOT2-combined
	sort --key=2,2 $< | \
		uniq --skip-fields=1 --check-chars=$(HASHWIDTH) -D > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# --- Minimal (across trees, excluding in-tree duplicates)
# ROOT1: duplicate1-in-test1
# ROOT1: unique-in-test1
# ROOT2: unique-in-test2
# ROOT2: duplicate1-in-test2
# ROOT1,2: common-in-test1-and-test2
ROOT1-ROOT2-minimal: ROOT1-ROOT2-combined
	sort --key=2,2 --unique $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# --- Broken (same path, different hashes)
ROOT1-ROOT2-broken: ROOT1-ROOT2-combined
	sort --key=3,3 $< | \
		uniq --skip-fields=2 -D | \
		uniq --skip-fields=1 --check-chars=$(HASHWIDTH) -u > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)


clean:
	-rm -f ROOT{1,2}-{hash,hash-sorted,unique,duplicates,minimal,wasteful}
	-rm -f ROOT1-ROOT2-{combined,duplicates,minimal}
