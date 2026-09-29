#!/bin/sh
# Oracle harness: run the test programs under CRuby with the REAL loofah
# gem (and the real nokogiri and crass beneath it) and diff against the
# committed snapshots. `-I` is not passed, so `require "loofah"` resolves
# to the gem, not this package: the snapshot is what the gem answers, and
# `spin test` holds the compiled mirror to it.
#
# Usage: sh oracle/run.sh           (from the repo root)
#        sh oracle/run.sh --regen   (rewrite the snapshots from the gem)
# Needs: ruby with the loofah gem (gem install loofah -v 2.25.2) and
# nokogiri 1.19.4, the version spinel-nokogiri is held to.

OUTDIR=build/oracle
mkdir -p "$OUTDIR"
fails=0
ran=0
for t in test/*_test.rb; do
  name=$(basename "$t" .rb)
  ruby -e 'gem "loofah", "2.25.2"; gem "nokogiri", "1.19.4"' -e "load '$t'" > "$OUTDIR/$name.out" 2>&1
  ran=$((ran + 1))
  if [ "$1" = "--regen" ]; then
    cp "$OUTDIR/$name.out" "$t.expected"
    echo "regen $name"
  elif diff -u "$t.expected" "$OUTDIR/$name.out" > "$OUTDIR/$name.diff" 2>&1; then
    echo "ok   $name"
    rm -f "$OUTDIR/$name.diff"
  else
    echo "FAIL $name (see $OUTDIR/$name.diff)"
    fails=$((fails + 1))
  fi
done
echo "$((ran - fails))/$ran match loofah"
[ $fails -eq 0 ]
