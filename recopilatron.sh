#! /bin/sh
# WARNING:
# this is highly unstable. Don't use it if you don't understand it ;)

## BUGS:
# when there is a bad password in hosts.cnf, the empty session remains open.
# when there are errors in the empty interaction, the session remains open.
# when the name of the file is duplicated in destination, the tests fail and one steps over another
# 

# Opciones del script
set -o nounset # evita que el script maneje variables vacias.

# Ruta base. Para cuando queremos colocar los archivos en un directorio diferente al de ejecucion
BASEDIR="apachectl"
# Archivo de log. Por defecto es recopilator.log
LOGFILE=recopilator.$BASEDIR.log

# Timeout. a little extra time for the transfers to finish. a minute is not so much time (it takes around 30min to get 120 files)
TIMEOUT=60


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


# I use a temporary file, until i know how to remove the comments out of each line
mv hosts.cnf hosts.tmp
cat hosts.tmp | grep -v ^# > hosts.cnf

# start loggin
logit "$(basename $0)"
logit "$(date)"

for host_line in $(cat hosts.cnf); do
	cstr=$(extract_field '$1')
	passwd=$(extract_field '$2')
	srcdir=$(extract_field '$3')
	destdir=$(echo $cstr | sed 's/.*@\(.*\)/\1/')

	logit "Destino: "$BASEDIR/$destdir" - Origen: "$cstr":"$srcdir
	
	# crea un directorio para el host, si no existe ya
	if [ ! -d $BASEDIR/$destdir ]; then
		mkdir -p $BASEDIR/$destdir
	fi
	
	#Comprueba que no existe el archivo destino, y existe, hace un backup
	archivo=$( basename $srcdir )
	
	if [ -r $BASEDIR/$destdir/$archivo ]; then
		logit "Copia existente. Realizando backup de $BASEDIR/$destdir/$archivo"
		mv --backup=numbered $BASEDIR/$destdir/$archivo $BASEDIR/$destdir/$archivo.bck
	fi
	
	# executes the comand to bring the files here
	run $passwd scp $cstr:$srcdir $BASEDIR/$destdir

done

# we have to wait a little bit, so all transfers can finish properly. You'll have to adjust this manually
sleep $TIMEOUT

logit "$(date)"
logit "comenzamos comprobaciones"

# And after all, do the checks and logfile assembly
for host_line in $(cat hosts.cnf); do
	cstr=$(extract_field '$1')
	srcdir=$(extract_field '$3')
	destdir=$(echo $cstr | sed 's/.*@\(.*\)/\1/')
	archivo=$( basename $srcdir )
	# Comprueba que existe el archivo destino, y sino, lanza un error.
        if [ -e $BASEDIR/$destdir/$archivo ]; then
	        logit "Archivo $destdir/$archivo obtenido correctamente" 
	else
		logit "ERROR El archivo $archivo de $destdir no ha llegado correctamente a su destino"
        fi

	# añade el resultado de empty al log
	logit "$(cat $BASEDIR/$destdir/$archivo~$LOGFILE)"
	# and cleans the "empty" temporal logfiles
	# rm $BASEDIR/$destdir/$archivo~$LOGFILE
done 

# restablecemos el estado del archivo hosts.cnf antes de la limpieza.
mv hosts.cnf hosts.old
mv hosts.tmp hosts.cnf

logit " -- Finalizado $( date ) --\
	"
exit

