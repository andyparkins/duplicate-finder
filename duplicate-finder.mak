#!/usr/bin/make -f
SHELL=/bin/bash

ROOT1 ?= /tmp
ROOT2 ?= /tmp

HASHER := md5sum
HASHWIDTH := 32


TOP := $(shell pwd)
SELF := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))


# --------------------

# Split on :
PART1_1 := $(word 1,$(subst :, ,$(ROOT1)))
PART1_2 := $(word 2,$(subst :, ,$(ROOT1)))
PART2_1 := $(word 1,$(subst :, ,$(ROOT2)))
PART2_2 := $(word 2,$(subst :, ,$(ROOT2)))

# Create remote-run part
ifeq ($(PART1_2),)
	# if PARTx_2 is not set, then PARTx_1 is the ROOT, and there is no host
	HOST1 := sh -c
	DIR1 := $(PART1_1)
else
	# if PARTx_2 is set, then it is the new ROOTx
	HOST1 := ssh $(PART1_1)
	DIR1 := $(PART1_2)
endif

ifeq ($(PART2_2),)
	# if PARTx_2 is not set, then PARTx_1 is the ROOT, and there is no host
	HOST2 := sh -c
	DIR2 := $(PART2_1)
else
	# if PARTx_2 is set, then it is the new ROOTx
	HOST2 := ssh $(PART2_1)
	DIR2 := $(PART2_2)
endif



default: help

all: \
	ROOT1-duplicates \
	ROOT2-duplicates \
	ROOT1-minimal \
	ROOT2-minimal \
	ROOT1-wasteful \
	ROOT2-wasteful \
	ROOT1-ROOT2-combined \
	ROOT1-ROOT2-minimal \
	ROOT1-ROOT2-duplicates \
	ROOT1-ROOT2-duplicates-inclusive \
	ROOT1-ROOT2-diff \
	ROOT1-ROOT2-broken \
	ROOT1-ROOT2-describe.txt

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
	@echo "                         ROOT2, exclusive of in-tree duplicates"
	@echo " ROOT1-ROOT2-duplicates-inclusive"
	@echo "                         Files that are duplicated across ROOT1 and"
	@echo "                         ROOT2, inclusive of in-tree duplicates"
	@echo " ROOT1-ROOT2-minimal     Minimal set to get one copy of everything"
	@echo "                         in ROOT1 and ROOT2"
	@echo " ROOT1-ROOT2-diff        The differences between ROOT1 and ROOT2"
	@echo " ROOT1-ROOT2-broken      Files with the same path in ROOT1 and ROOT2,"
	@echo "                         but different content"
	@echo ""

info:
	@echo "TOP     := $(TOP)"
	@echo "SELF    := $(SELF)"
	@echo ""
	@echo "PART1_1 := $(PART1_1)"
	@echo "PART1_2 := $(PART1_2)"
	@echo "HOST1   := $(HOST1)"
	@echo "DIR1    := $(DIR1)"
	@echo ""
	@echo "PART2_1 := $(PART2_1)"
	@echo "PART2_2 := $(PART2_2)"
	@echo "HOST2   := $(HOST2)"
	@echo "DIR2    := $(DIR2)"


# Here is a way of testing this script:
test: testenv
	$(MAKE) -f $(SELF) ROOT1=test1 ROOT2=test2 \
		ROOT1-hash-sorted ROOT2-hash-sorted \
		ROOT1-duplicates ROOT2-duplicates \
		ROOT1-minimal ROOT2-minimal \
		ROOT1-wasteful ROOT2-wasteful \
		ROOT1-ROOT2-duplicates \
		ROOT1-ROOT2-duplicates-inclusive \
		ROOT1-ROOT2-minimal \
		ROOT1-ROOT2-diff \
		ROOT1-ROOT2-broken \
		ROOT1-ROOT2-describe.txt
	@echo "-----------"
#	# I include these tests in the knowledge that they don't succeed.  The
#   # problem is that "sort --unique" and "uniq -d" aren't outputting
#   # complimentary sets.  "sort --unique" outputs the first in an equal run
#   # but "uniq -d" _doesn't_ necessarily _not_ output the first in an equal
#   # run; it can chose to drop any of the equal run.
	@[ $$(sort ROOT1-wasteful ROOT1-minimal | md5sum | cut -f 1 -d " ") \
		= $$(md5sum ROOT1-hash-sorted | cut -f 1 -d " ") ] \
		|| echo "WARNING: ROOT1-wasteful + ROOT1-minimal != ROOT1-hash-sorted"
	@[ $$(sort ROOT2-wasteful ROOT2-minimal | md5sum | cut -f 1 -d " ") \
		= $$(md5sum ROOT2-hash-sorted | cut -f 1 -d " ") ] \
		|| echo "WARNING: ROOT2-wasteful + ROOT2-minimal != ROOT2-hash-sorted"
	@echo "-----------"
	cat < ROOT1-duplicates
	cat < ROOT1-minimal
	cat < ROOT1-wasteful
	@echo ""
	cat < ROOT2-duplicates
	cat < ROOT2-minimal
	cat < ROOT2-wasteful
	@echo ""
	cat < ROOT1-ROOT2-duplicates
	cat < ROOT1-ROOT2-duplicates-inclusive
	cat < ROOT1-ROOT2-minimal
	cat < ROOT1-ROOT2-diff
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


ROOT1-ROOT2-describe.txt:
	echo "$(DIR1)" > $@
	echo "$(DIR2)" >> $@

# Master hash list, in directory depth order
ROOT%-hash:
	@echo "--- hashing $(ROOT$*)"
	-$(HOST$*) \
		"cd \"$(DIR$*)\" ; \
		find . -type f -readable -exec $(HASHER) {} \\;" | \
		sort --key=2,2 > "$(TOP)/$@"
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
	sort --merge --unique --key=1,1 $< | \
		sort --key=2,2 > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Wasteful (files with duplicates within a tree), shows only one of the two
# would be safe to delete from this list
# duplicate1-in-test1
%-wasteful: %-hash-sorted
	uniq --check-chars=$(HASHWIDTH) -d $< | \
		sort --key=2,2 > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# Combined
# ROOT1: unique-in-test1
# ROOT1: duplicate1-in-test1
# ROOT1: common-in-test1-and-test2
# ROOT2: unique-in-test2
# ROOT2: duplicate1-in-test2
# ROOT2: common-in-test1-and-test2
ROOT1-ROOT2-combined: ROOT1-minimal ROOT2-minimal
	grep -H "" $^ | sed 's/^\([^:]\+\)-minimal:/\1 /' | \
		sort --key=2,3 > $@

# --- Duplicates (across trees, excluding in-tree duplicates)
# ROOT1: common-in-test1-and-test2
# ROOT2: common-in-test1-and-test2
ROOT1-ROOT2-duplicates: ROOT1-ROOT2-combined
	uniq --skip-fields=1 --check-chars=$(HASHWIDTH) -D $< > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# --- Duplicates (across trees, including in-tree duplicates)
# ROOT1: common-in-test1-and-test2
# ROOT2: common-in-test1-and-test2
ROOT1-ROOT2-duplicates-inclusive: ROOT1-hash-sorted ROOT2-hash-sorted
	grep -H "" $^ | sed 's/^\([^:]\+\)-hash-sorted:/\1 /' | \
		sort --key=2,3 | \
		uniq --skip-fields=1 --check-chars=$(HASHWIDTH) -D > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# --- Minimal (across trees, excluding in-tree duplicates)
# ROOT1: duplicate1-in-test1
# ROOT1: unique-in-test1
# ROOT2: unique-in-test2
# ROOT2: duplicate1-in-test2
# ROOT1,2: common-in-test1-and-test2
ROOT1-ROOT2-minimal: ROOT1-ROOT2-combined
	awk '{print $$2, $$1, $$3}' $< | \
		sort | awk '{print $$2, $$1, $$3}' | \
		sort --key=2,2 --merge --unique > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# --- Diff
ROOT1-ROOT2-diff: ROOT1-hash ROOT2-hash
	-diff -u $^ > $@

# --- Broken (same path, different hashes)
ROOT1-ROOT2-broken: ROOT1-ROOT2-combined
	sort --key=3,3 $< | \
		uniq --skip-fields=2 -D | \
		uniq --skip-fields=1 --check-chars=$(HASHWIDTH) -u > $@
	@printf " - %d hashes in %s\n" $$(wc -l $@)

# ---------- Tools
brokenls: ROOT1-ROOT2-broken ROOT1-ROOT2-describe.txt
	@export ROOT1="$$(head -1 ROOT1-ROOT2-describe.txt)"; \
	export ROOT2="$$(tail -1 ROOT1-ROOT2-describe.txt)"; \
	cut -d " " -f1,4- ROOT1-ROOT2-broken \
		| sed -e "s|^ROOT1 \.|$${ROOT1}|" -e "s|^ROOT2 \.|$${ROOT2}|" \
		| while IFS= read path; do ls -l --time-style=long-iso "$$path"; done


clean:
	-rm -f ROOT{1,2}-{unique,duplicates,minimal,wasteful}
	-rm -f ROOT1-ROOT2-{combined,duplicates,duplicates-inclusive,minimal,diff,broken}
	-rm -f ROOT1-ROOT2-describe.txt

distclean: clean
	-rm -f ROOT{1,2}-{hash,hash-sorted}

.PHONY: default all help info test testenv brokenls clean distclean
