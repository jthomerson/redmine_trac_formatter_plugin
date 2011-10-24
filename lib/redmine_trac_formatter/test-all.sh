for f in `ls tests/*.in | sed 's|\.in$||g'`; do
echo "TEST: $f";
ruby wiki_formatter.rb $f.in $f.exp;
done
