#!/bin/sh

for lang in `cat ./LINGUAS`; do
msgmerge --sort-by-file --backup=off --previous -U ./$lang.po ./template.pot
done