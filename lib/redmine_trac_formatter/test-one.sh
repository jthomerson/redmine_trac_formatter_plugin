TEST=$1
if [ "$TEST" == "" ]; then
	echo "You must supply a test name"
	exit
fi
ruby wiki_formatter.rb tests/$TEST.in tests/$TEST.exp show;
