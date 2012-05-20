#! /bin/sh
# WARNING:
# this is highly unstable. Don't use it if you don't understand it ;)

## BUGS:
# when there is a bad password in hosts.cnf, the empty session remains open.
# when there are errors in the empty interaction, the session remains open.
# when the name of the file is duplicated in destination, the tests fail and one steps over another
# 

## OPTIONS

# Base Directory. Change this to put all the files in a single directory
BASEDIR="remoteFiles"

# Logfile. Default is recopilatron.$BASEDIR.log
LOGFILE=recopilatron.$BASEDIR.log

# Timeout. a little extra time for the transfers to finish. a minute is not so much time (it takes around 30min to get 120 files)
TIMEOUT=60

# Avoids use of empty Variables
set -o nounset 


extract_field() {
	echo $host_line | awk "BEGIN{FS=\":\"} { print $1 }"
}

run() {
	# creates an "empty" session with independent logfile, so we can re-assemble them after.
	passwd=$1
	shift
	empty -f  -L $BASEDIR/$destdir/$archivo~$LOGFILE $*
	empty -w -t 30 "assword:" "$passwd\n"
	#TODO aqui se podria tomar la salida de la sesion de empty. lo que no se es si respetaria el orden del log o el del fork.
	logit "salida de segundo empty ->  $?"
}

logit() {
	echo $*
	echo $* >> $LOGFILE
}


# I use a temporary file #TODO: change this with a regular expression
mv hosts.cnf hosts.tmp
cat hosts.tmp | grep -v ^# > hosts.cnf

# start loggin
logit "$(basename $0)"
logit "--- BEGIN $(date) --- "

for host_line in $(cat hosts.cnf); do
	cstr=$(extract_field '$1')
	passwd=$(extract_field '$2')
	srcdir=$(extract_field '$3')
	destdir=$(echo $cstr | sed 's/.*@\(.*\)/\1/')

	logit "Destination: "$BASEDIR/$destdir" - Origin: "$cstr":"$srcdir
	
	# creates the destination directory
	if [ ! -d $BASEDIR/$destdir ]; then
		mkdir -p $BASEDIR/$destdir
	fi
	
	#Check if the file already exists in destination, and if so, make backup.
	archivo=$( basename $srcdir )
	
	if [ -r $BASEDIR/$destdir/$archivo ]; then
		logit "Exists in destination. Making backup of $BASEDIR/$destdir/$archivo"
		mv --backup=numbered $BASEDIR/$destdir/$archivo $BASEDIR/$destdir/$archivo.bck
	fi
	
	# executes the comand to bring the files here
	run $passwd scp $cstr:$srcdir $BASEDIR/$destdir

done

# we have to wait a little bit, so all transfers can finish properly. You can adjust this manually in the above options
sleep $TIMEOUT

logit "$(date)"
logit "Starting post-checks"

# And after all, do the checks and logfile assembly
for host_line in $(cat hosts.cnf); do
	cstr=$(extract_field '$1')
	srcdir=$(extract_field '$3')
	destdir=$(echo $cstr | sed 's/.*@\(.*\)/\1/')
	archivo=$( basename $srcdir )
	# Check if destination exists.
        if [ -e $BASEDIR/$destdir/$archivo ]; then
	        logit "File $destdir/$archivo obtained" 
	else
		logit "ERROR file $archivo in $destdir has not arrived well"
        fi

	# add the result from "empty's" logs to the logfile
	logit "$(cat $BASEDIR/$destdir/$archivo~$LOGFILE)"
	# and cleans the "empty" temporal logfiles
	# rm $BASEDIR/$destdir/$archivo~$LOGFILE
done 

# Set back the original hosts.cnf
mv hosts.cnf hosts.old
mv hosts.tmp hosts.cnf

logit " -- END $( date ) --\
	"
exit

