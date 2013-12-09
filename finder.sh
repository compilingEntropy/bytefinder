#!/bin/bash

time=11
reliable=0
quick=0
params=( $( for arg in "$@"; do echo "$arg"; done ) )
usage="Usage: finder.sh -f ./original -m ./mutated [-t 11] [-q]"

i=0
for arg in "${params[@]}"; do
	if [[ "$arg" == "-f" ]]; then
		original="${params[$i+1]}"
	fi
	if [[ "$arg" == "-m" ]]; then
		mutated="${params[$i+1]}"
	fi
	if [[ "$arg" == "-t" ]]; then
		time="${params[$i+1]}"
	fi
	if [[ "$arg" == "-r" ]]; then
		reliable=1
	fi
	if [[ "$arg" == "-q" ]]; then
		quick=1
	fi
	((i++))
done

if [[ -z "$original" ]]; then
	echo "You must provide an original, unfuzzed file."
	echo "$usage"
	exit
fi
if [[ -z "$mutated" ]]; then
	echo "You must provide a mutated file."
	echo "$usage"
	exit
fi

#check the time
if [ $( echo $time | egrep -c "(^[0-9]+$)|(^[0-9]+[\.][0-9]+$)" ) -ne 1 ]; then
	echo "The time provided isn't valid."
	echo "Please provide a new time."
	echo "$usage"
	exit
fi

path="$( pwd )"
if [[ "${original:0:2}" == "./" ]]; then
	original="$path/${original:2}"
elif [[ "${original:0:3}" == "../" ]]; then
	original="$path/$original"
fi
if [[ "${mutated:0:2}" == "./" ]]; then
	mutated="$path/${mutated:2}"
elif [[ "${mutated:0:3}" == "../" ]]; then
	mutated="$path/$mutated"
fi

files=( $original $mutated )

#check files exist
for file in "${files[@]}"; do
	if [[ ! -e "$file" ]]; then
		echo "The provided file $file does not exist."
		echo "Please check your path and try again."
		exit
	fi
done

if [ $quick -eq 1 ]; then
	echo "Using quick mode."
	echo "Please note that quick mode only works if there's just one byte required to cause your crash."
fi

#crash directories
crashroot="/private/var/mobile/Library/Logs/CrashReporter"
precrashroot="/private/var/logs/CrashReporter"
crashpanics="$crashroot/Panics"
precrashpanics="$precrashroot/Panics"
crashdirs=( "$crashroot" "$precrashroot" "$crashpanics" "$precrashpanics" )

for dir in "${crashdirs[@]}"; do
	if [[ ! -d $dir/ ]]; then
		mkdir -p $dir/
	fi
done

wrkdir=/private/var/www/$( echo $mutated | sed -e 's|\..*||g' -e 's|.*/||g' )
if [[ ! -d $wrkdir/ ]]; then
	mkdir -p $wrkdir/
fi

cp $original $wrkdir/
cp $mutated $wrkdir/
cd $wrkdir/

original=$( echo $original | sed 's|.*/||g' )
mutated=$( echo $mutated | sed 's|.*/||g' )

extension=$( echo $original | sed 's|.*\.||g' )
hotfiles=( $mutated )

#accept a number of segments desired as a param and break a file into that many segments of diffs
segment()
{
	npieces="$1"
	unset pieces
	start=1

	if (( ( $npieces * 2 ) - 1 < $diffs )); then
		length=$(( ( $diffs + $npieces - 1 ) / $npieces )) #use fancy math to divide with ceil instead of floor

		for (( k = 1; k <= $npieces; k++ )); do
			end=$(( $length + $start - 1 ))
			pieces=( "${pieces[@]}" "$start:$end" )
			start=$(( $end + 1 ))

			if [ $start -gt $diffs ]; then
				break
			fi
		done

		last="${pieces[${#pieces[@]} - 1]}"
		slast=$( echo $last | sed 's|:.*||g' ) #start part of the last element
		if [ $(( $diffs - $slast )) -lt $(( $length / 2 )) ]; then
			#remove the last element, extend new last element
			pieces=( "${pieces[@]/$last/}" )
			last="${pieces[${#pieces[@]} - 2]}"
			pieces=( ${pieces[@]/$last/$( echo $last | sed "s|:.*|:$diffs|g" )} )
		fi
	else
		for (( k = $start; k <= $diffs; k++ )); do
			pieces=( "${pieces[@]}" "$k:$k" )
		done
	fi
}

crashcount()
{
	crashcount=$( ls $crashroot/ | grep -c plist )
	let crashcount+=$( ls $precrashroot/ | grep -c plist )
	paniccount=$( ls $crashpanics/ | grep -c plist )
	let paniccount+=$( ls $precrashpanics/ | grep -c plist )
}

#pull times out of the crash files
getcrashtime()
{
	date=( $( grep 'Date' $1 ) )
	crashyear="${date[1]:2:2}"
	crashmonth="${date[1]:5:2}"
	crashday="${date[1]:8:2}"
	crashhour="${date[2]:0:2}"
	crashminute="${date[2]:3:2}"
	crashsecond="${date[2]:6:2}"
}

inject()
{
	echo "Testing $file"
	sbopenurl http://127.0.0.1/$( echo $wrkdir | sed "s|.*www/||g" )/"$file"
	echo "Safari opened"
	sleep $time
	resetsafari
	#killall -KILL mediaserverd
	echo "~$i $( date '+%y.%m.%d-%H.%M.%S' )" >> ./tested.log
}

testfile()
{
	crashcount
	before=$crashcount

	inject

	crashcount
	after=$crashcount
}

#find where the crashtime fits in the logs
comparetimes()
{
if [ $crashyear -eq $syear ]; then
	
	if [ $crashmonth -eq $smonth ]; then
		
		if [ $crashday -eq $sday ]; then
			
			if [ $crashhour -eq $shour ]; then

				if [ $crashminute -eq $sminute ]; then
					
					if [ $crashsecond -gt $ssecond ]; then
						foundit
					fi

				elif [ $crashminute -gt $sminute ]; then
					foundit
				fi

			elif [ $crashhour -gt $shour ]; then
				foundit
			fi

		elif [ $crashday -gt $sday ]; then
			foundit
		fi

	elif [ $crashmonth -gt $smonth ]; then
		foundit
	fi

elif [ $crashyear -gt $syear ]; then
	foundit
fi
}

foundit()
{
	mv "$dir/$crash" "$wrkdir/crashes/"
	echo "Moved $crash"
	((crashes++))
}

stime="$( date '+%y.%m.%d-%H.%M.%S' )"
syear="${stime:0:2}"
smonth="${stime:3:2}"
sday="${stime:6:2}"
shour="${stime:9:2}"
sminute="${stime:12:2}"
ssecond="${stime:15:2}"

#crash reliablilty test
pass=0
fail=0
testnum=15
file=$mutated
if [ $reliable -eq 0 ]; then
	echo "Starting reliablilty test."
	for (( j = 0; j < 3; j++ )); do
		for (( i = 1; i <= $testnum; i++ )); do

			echo "( $i / $testnum )"
			testfile

			if [ $after -gt $before ]; then
				((pass++))
			else
				break
			fi
		done
		if (( $i == ( $testnum + 1 ) )); then
			((i--))
		fi
		reliablilty=$(( ( $pass * 100 ) / $i ))
		echo "Your crash is $reliablilty% reliable."
		if [ $reliablilty -ne 100 ]; then
			#warn, possibly exit
			echo "Not good enough, increasing time..."
			((time+=5))
			pass=0
		else
			echo "Continuing..."
			break
		fi
	done
	if [ $reliablilty -ne 100 ]; then
		echo "Looks like your crash is unreliable. :("
		exit
	fi
else
	echo "Skipping reliablilty test, this is not recommended!"
fi


hexdiff -f ./$original -m ./$mutated > ./$( echo "$mutated" | sed "s|\.$extension||g" )_diff.log

found=0
bookmark=2
i=1 #number of files tested
while [ $found -eq 0 ]; do
	crashed=0

	#calculate diffs using new file
	mutated="${hotfiles[${#hotfiles[@]} - 1]}"
	diffs="$( hexdiff -f ./$original -m ./$mutated -N )"
	#validate with regex
	if [ $( echo $diffs | egrep -c "^[0-9]+$" ) -eq 0 ]; then
		echo "dat aint no thang!"
		exit
	fi

	for (( j = $bookmark; $crashed == 0 && $found == 0; j++ )); do

		bytes=$(( $j - 1 ))
		if [ $j -gt $bookmark ]; then
			echo "At least $bytes bytes are required to cause the crash."
		fi

		if [ $j -ge 3 ] && [ $quick -eq 1 ]; then
			echo "Could not find the magic byte, please try again with quick mode turned off."
			exit
		fi

		if [ $bytes -ge $diffs ]; then
			found=1
			echo "Testing to make sure each remaining byte is important..."
		fi

		segment $j

		for piece in "${pieces[@]}"; do

			echo "~$i $( date '+%y.%m.%d-%H.%M.%S' )"

			file=$( echo $mutated | sed "s|\.$extension|_$i\.$extension|g" )

			hexdiff -f "$original" -m "$mutated" -D -I -R "$piece" -o ./"$file"

			if [[ ! -e "./$file" ]]; then
				echo "Couldn't find the file I just generated...?"
				exit
			fi

			testfile

			((i++))

			if [ $after -gt $before ]; then
				echo "Crashed!"
				if [ $crashed -eq 0 ]; then
					crashed=1
					hotfiles=( "${hotfiles[@]}" "$file" )
				elif [ $crashed -ge 1 ]; then
					((crashed++))
					#test for thirds case scenario
					#multiple bugs!!
					#do something about the fact that there are multiple bugs in the same file (...?)
				fi
				found=0
				if [ $quick -eq 1 ]; then
					break
				fi
			fi

		done

		#bookmark where you are
		bookmark=$j

	done

done

echo ""
solved=$( echo $mutated | sed "s|_.*|_solved\.$extension|g" )
cp ./$mutated ./$solved
hexdiff -f ./$original -m ./$solved > ./$( echo "$mutated" | sed "s|_.*||g" )_solved_diff.log
echo "Diffs found and file generated!"
echo "The file which contains just the magic bytes is:"
echo "$mutated"
echo "This file has been placed at $wrkdir/$solved"
echo "The number of 'magic bytes' required for your crash is: $diffs"
echo "Here are your offsets and their differences:"
grep "0;31;10m" ./$( echo "$mutated" | sed "s|_.*||g" )_solved_diff.log
echo "Enjoy, eh?"

echo ""
echo "Moving crashes to $wrkdir/crashes/"
crashes=0
if [[ ! -d $wrkdir/crashes/ ]]; then
	mkdir -p $wrkdir/crashes/
fi
for dir in "${crashdirs[@]}"; do
	cd "$dir/"
	#Remove Duplicates
	if [ $( ls ./ | grep -c "Latest" ) -ge 1 ]; then
		rm ./Latest*.plist
	fi
	#Fix for iOS7 crashes
	for crash in *.synced; do
		if [ -e "$crash" ]; then
			if [ $( echo "$crash" | grep -c ".synced" ) -ge 1 ]; then
				mv "$dir/$crash" "$dir/$( echo $crash | sed 's|.synced||g' )"
			fi
		fi
	done
	#Move all crashes to directory with solved file
	for crash in *.plist; do
		if [ -e "$crash" ]; then
			getcrashtime "$crash"
			comparetimes
		fi
	done
done
echo "Moved $crashes crashes."