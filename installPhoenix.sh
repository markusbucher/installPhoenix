#!/bin/bash
# $id: installPhoenix.sh 2011-07-09 22:37:01Z mabuse $
#
# installPhoenix.sh - install TYPO3 Phoenix to the current working directory
# usage: installPhoenix.sh --ARGUMENT1 --ARGUMENT2 ... 
#


##
# Set the defaults

dbhost=127.0.0.1
dbname=phoenix
package=TYPO3v5
##
# Set the configuration for this script

MANDATORY="dbuser,dbpass,gituser,destination"
OIFS=$IFS
IFS=,
##
# Print usage information

usage () {

	cat <<EOF

Usage: $0 [OPTIONS]
	--package=TYPO3v5	Provide the name of the package you like to install
	--dbhost=127.0.0.1	Provide IP-address of the database
	--dbname=phoenix	Provide name of the database
	--dbuser		Provide name of the database user with write access to dbname
	--dbpass		Provide password of the database user
	--gituser		Provide username with access to https://review.typo3.org
	--destination		Provide a path that acts as the destination for Phoenix
EOF
		exit 1
}

append_arg_to_args () {
  args="$args "`shell_quote_string "$1"`
}


##
# process the given arguments, check for mandatory ones

parse_arguments() {
	pick_args=
	if test "$1" = PICK-ARGS-FROM-ARGV
			then
				pick_args=1
				shift
	fi  

	for arg do
		val=`echo "$arg" | sed -e "s;--[^=]*=;;"`
		case "$arg" in
			--package=*) package="$val" ;;
			--dbhost=*) dbhost="$val" ;;
			--dbname=*) dbname="$val" ;;
			--dbuser=*) dbuser="$val" ;;
			--dbpass=*) dbpass="$val" ;;
			--gituser=*) gituser="$val" ;;
			--destination=*) destination="$val" ;;

			--guided) guidedInstallation ;;

			--help) usage ;;

			*)
				echo "You provided unrecognized arguments."
				usage
				exit 1
				;;
		esac
	done
}

##
# check the mandatory arguments, the basedir, the working SQL connection
# Mandatory arguments are:
#	dbuser
#	dbpass
#	gituser
#	destination

check_requirements () {
	
	# Check mandatories
	for i in $MANDATORY 
	do
		if [ -n "${!i}" ] 
		then
			#do some stupid stuff because bash wouldn't like an empty then-statement
			foo="bar"
		else
			errors=$i" $errors"
		fi
	done
	echo $errors
	if [ "$errors" != '' ]; then
		returnMissingArgumentError $errors
	fi
	
	#check path
	
	#check SQL Connection
}

returnMissingArgumentError() {
	IFS=" "
	echo "Some mandatory arguments were not set. Please correct this and start this script again"
	echo 
	for singleError in $errors
	do
		echo "Missing: --$singleError "
	done
	exit 1
}

##
# Quote the given arguments to make sure that any special chars are quoted
# (c) mysqld_safe

shell_quote_string() {
	echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}

##
# Process git clone and register the neccessary submodule

function getPhoenix(){
	git clone --recursive git://git.typo3.org/TYPO3v5/Distributions/Base.git $destination 

	cd $destination

	scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/

	git submodule foreach 'scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/'
	git submodule foreach 'git config remote.origin.push HEAD:refs/for/master'
	git submodule foreach 'git checkout master; git pull'
}

function getFLOW3() {
	echo "Soon!"
	exit 0
}

##
# Create file Configuration/Settings.yaml

function createSettings(){

cd $destination
SETTINGS=$( cat <<.
TYPO3: 
FLOW3: 
    persistence: 
      backendOptions: 
        driver: 'pdo_mysql' 
        dbname: '$DBNAME'   # adjust to your database name 
        user: '$DBUSER'        # adjust to your database user 
        password: '$DBPASS'        # adjust to your database password 
        host: '$DBHOST'   # adjust to your database host 
        path: '$DBHOST'   # adjust to your database host 
        port: 3306 
#      doctrine: 
         # If you have APC, you should consider using it for Production, 
         # also MemcacheCache and XcacheCache exist. 
#        cacheImplementation: 'Doctrine\Common\Cache\ApcCache' 
         # when using MySQL and UTF-8, this should help with connection encoding issues 
#        dbal: 
#          sessionInitialization: 'SET NAMES utf8 COLLATE utf8_unicode_ci' 
)

echo "$SETTINGS" >> Configuration/Settings.yaml;
}

function initializeFLOW3(){
	./flow3 flow3:cache:flush
	./flow3 flow3:core:compile
	./flow3 flow3:doctrine:migrate
	./flow3 typo3:site:import < Packages/Sites/TYPO3/PhoenixDemoTypo3Org/Resources/Private/Content/Sites.xml
}

function returnSuccessMessage(){
	clear
	echo "Installation of TYPO3 phoenix finished. If you are using xdebug pleas make sure that
	   xdebug.max_nesting_level is set to a value like 1000 inside php.ini"
	echo
	echo "Please have fun with your new system! Inspir people to share"
	echo
	echo
	echo
}


function guidedInstallation(){
	# Guided goes here
	echo "Soon"
	exit 0
	
}


function doInstall() {
	getPhoenix
	createSettings
	initializeFLOW3
	returnSuccessMessage
}


parse_arguments PICK-ARGS-FROM-ARGV "$@"
check_requirements
doInstall
exit 0