#!/bin/bash
# $id: installPhoenix.sh 2011-07-09 22:37:01Z mabuse $
#
# installPhoenix.sh - install TYPO3 Phoenix to the current working directory
# usage: installPhoenix.sh --ARGUMENT1 --ARGUMENT2 ... 
#

COMMANDLINE_USER=$(whoami)
if [ $COMMANDLINE_USER!="root" ]; then
	echo "You probably want to execute this script as superuser. If you experience errors please execute this script with 'sudo'"
	echo "e.g. sudo installPhoenix --dbname=phoenix --dbuser=mydbuser --dbpass=keepMeSoSecret"
fi

##
# Set the defaults

dbhost=127.0.0.1
dbname=phoenix
package=TYPO3v5
subfolder=TYPO3v5

##
# Set the configuration for this script

MANDATORY="dbuser,dbpass,gituser"
OIFS=$IFS
IFS=,

##
# Get some system information

mywd=$(pwd)
mydate=$(date)
phoenixpath=$mywd/$subfolder

function prepareLogging(){
	
	logfile="$mywd/installPhoenix.log"
	errorlogfile="$mywd/installPhoenixError.log"
	
	echo " Script started at $mydate by $COMMANDLINE_USER" >> $logfile
}

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
	--subfolder=TYPO3v5		Provide the name of the subfolder in which Phoenix will be installed
	--debug			Print debug information and exit
EOF
		exit 1
}


##
# Escape given args

append_arg_to_args () {
  args="$args "`shell_quote_string "$1"`
}


##
# Process the given arguments, check for mandatory ones

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
			--subfolder=*) subfolder="$val"; 
				if [ $subfolder=="" ]; then
					returnError 6 "--subfolder must not be empty or contain a slash when given"
				fi
				echo $mywd
				#unset phoenixpath; 
				phoenixpath=$mywd/$subfolder 
			;;

			--guided) guidedInstallation ;;

			--help) usage ;;
			
			--debug) debug ;;

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
#	subfolder

check_requirements () {
	
	# Check mandatories
	for i in $MANDATORY 
	do
		if [ ! -n "${!i}" ] 
		then
			errors=$i" $errors"
		fi
	done
	if [ -n "$errors" ]; then
		returnError 1 $errors
	fi
	
	#check path
	
	#check SQL Connection
}

##
# Prints out an error message
# arg1 int type of error
# arg2 string messages
#
# 1 = Mandatory field(s) missing
# 2 = Connection to MySQL not possible
# 3 = subfolder not empty
# 4 = Could not connect to git repo
# 5 = Permission problem

returnError() {
echo
echo
echo "ERROR:"
echo
case $1 in 
1)
	IFS=" "
	echo "Some mandatory arguments were not set. Please correct this and start this script again"
	echo 
	for singleError in $2
	do
		echo "Missing: --$singleError "
	done
	exit 1
	;;
2)
	echo "Connection to the DB was not possible, please check your credentials."
	exit 1
	;;
3)
	echo "The subfolder you specified is not empty. Please use another folder or delete the contents of the chosen one."
	exit 1
	;;
4)
	echo "The git-repository could not be reached due to network problems. Do you have connection to internet?"
	exit 1
	;;
5)
	echo "You don't have enough permissions to execute this file operation. Please try executing this script with 'sudo'"
	exit 1
	;;
6)
	echo $2
	exit 1
	;;
*)
	echo "An error occured, plase have a look at $errorlogfile."
	exit 1
	;;
esac
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
	git clone --recursive git://git.typo3.org/TYPO3v5/Distributions/Base.git $subfolder 1>>$logfile 2>$errorlogfile
	if [ $? -gt 0 ]; then
		returnError 4
	fi

	cd $subfolder

	scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/
	if [ $? -gt 0 ]; then
		returnError 4
	fi
	git submodule foreach 'scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/'
	if [ $? -gt 0 ]; then
		returnError 4
	fi
	git submodule foreach 'git config remote.origin.push HEAD:refs/for/master'
	if [ $? -gt 0 ]; then
		returnError 4
	fi
	git submodule foreach 'git checkout master; git pull'
	if [ $? -gt 0 ]; then
		returnError 4
	fi
}

function getFLOW3() {
	echo "Soon!"
	exit 0
}

##
# Create file Configuration/Settings.yaml

function createSettings(){

cd $subfolder
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
	echo "Installation of TYPO3 phoenix finished. If you are using xdebug please make sure that
	   xdebug.max_nesting_level is set to a value like 1000 inside php.ini"
	echo
	echo "Please have fun with your new system! Inspire people to share"
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
	setPermissions
	initializeFLOW3
	returnSuccessMessage
}

function debug(){
	parse_arguments PICK-ARGS-FROM-ARGV "$@"
	echo "
	--package=$package
	--dbhost=*$dbhost
	--dbname=$dbname
	--dbuser=$dbuser
	--dbpass=$dbpass
	--gituser=$gituser
	--subfolder=$subfolder
	phoenixpath=$phoenixpath
	"
	exit 0
}
##
# Beginning the work

prepareLogging
parse_arguments PICK-ARGS-FROM-ARGV "$@"
check_requirements

doInstall
exit 0