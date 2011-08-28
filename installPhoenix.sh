#!/bin/bash
# $id: installPhoenix.sh 2011-07-09 22:37:01Z mabuse $
#
# installPhoenix.sh - install TYPO3 Phoenix to the current working directory
# usage: installPhoenix.sh --ARGUMENT1 --ARGUMENT2 ...
# Released under GNU GPL2 or later
# Author: Markus Bucher, markusbucher@gmx.de
# Author: Gordon Brueggemann, gb@gb-typo3.de

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
installtype=demo

##
# Set the configuration for this script

MANDATORY="dbuser,dbpass"
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
	--dbuser		Provide name of the database user with write access to dbname *
	--dbpass		Provide password of the database user *
	--dbname=phoenix	Provide name of the database
	--dbhost=127.0.0.1	Provide IP-address of the database
	
	--subfolder=TYPO3v5	Provide the name of the subfolder in which Phoenix will be installed
	
	--nodemo		If set FLOW3 will be installed without PhoenixDemoTypo3Org site
	--gituser		Provide username with access to https://review.typo3.org. This enables gitHooks
	--package=TYPO3v5	Provide the name of the package you like to install
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

	if [ "$#" -eq 1 ]; then
		usage
		exit
	fi

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
			--nodemo=) nodemo=1 ;;
			--dbhost=*) dbhost="$val" ;;
			--dbname=*) dbname="$val" ;;
			--dbuser=*) dbuser="$val" ;;
			--dbpass=*) dbpass="$val" ;;
			--gituser=*) gituser="$val" ;;
			--subfolder=*) subfolder="$val"; 
				if [ $subfolder=="" ]; then
					returnError 99 "--subfolder must not be empty or contain a slash when given"
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
	
	#check if path is writable and not empty
	if [ -d "$phoenixpath" ] && [ ! -w "$phoenixpath" ] 
	then
		returnError 99 "You don't have write permissions in the specified folder."
	fi
	
	if [ -d "$phoenixpath" ] && [ "$(ls -A $phoenixpath)" ] 
	then
		returnError 99 "The specified path is not empty."
	fi
	
	#check SQL Connection
	sqlcheck1=$( echo "SHOW DATABASES like '$dbname'" | mysql -u $dbuser -p$dbpass > /dev/null )
	if [ $? -gt 0 ]; then
		returnError 2
		exit
	fi
	sqlcheck2=$( echo "select count(*) as '' from information_schema.tables where table_type = 'BASE TABLE' and table_schema = '$dbname'" | mysql -u $dbuser -p$dbpass  )
	if [ ! "$sqlcheck2"=="0" ]; then
		echo $sqlcheck2
		returnError 99 "The specified database is not empty."
		exit
	fi
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
# 5 = Git access problem
# 6 = Permission problem
# 7 = flow3 script error
# 99 = Use arg2 as error message

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
	echo "The git-repository could not be reached due to access problems. Do you have created an ssh key pair and published the public key in review.typo3.org?"
	exit 1
	;;
6)
	echo "You don't have enough permissions to execute this file operation. Please try executing this script with 'sudo'"
	exit 1
	;;
7)
	echo "An error occured when executing flow3 script. Please have a look at $errorlogfile."
	exit 1
	;;

99)
	echo $2
	exit 1
	;;
*)
	echo "An error occured, please have a look at $errorlogfile."
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
	else
		echo "git clone processed without errors."
	fi
}


##
# Registers all the hooks to publish changes
# inspires to share

function addCommitHooks(){
	cd $phoenixpath

	scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/
	if [ $? -gt 0 ]; then
		returnError 5
	else
		echo "scp processed without errors."
	fi
	git submodule foreach 'scp -p -P 29418 $GITUSER@review.typo3.org:hooks/commit-msg .git/hooks/'
	if [ $? -gt 0 ]; then
		returnError 4
	else
		echo "submodule registered without errors."
	fi
	git submodule foreach 'git config remote.origin.push HEAD:refs/for/master'
	if [ $? -gt 0 ]; then
		returnError 4
	else
		echo "submodule registered without errors."
	fi
	git submodule foreach 'git checkout master; git pull'
	if [ $? -gt 0 ]; then
		returnError 4
	else
		echo "submodule registered without errors."
	fi
}

function getFLOW3() {
	echo "Soon!"
	exit 0
}

##
# Create file Configuration/Settings.yaml

function createSettings(){

cd $phoenixpath

SETTINGS="
TYPO3: 
  FLOW3: 
    persistence: 
      backendOptions: 
        driver: 'pdo_mysql' 
        dbname: '$dbname'   # adjust to your database name 
        user: '$dbuser'        # adjust to your database user 
        password: '$dbpass'        # adjust to your database password 
        host: '$dbhost'   # adjust to your database host 
        path: '$dbhost'   # adjust to your database host 
        port: 3306 
#      doctrine: 
         # If you have APC, you should consider using it for Production, 
         # also MemcacheCache and XcacheCache exist. 
#        cacheImplementation: 'Doctrine\Common\Cache\ApcCache' 
         # when using MySQL and UTF-8, this should help with connection encoding issues 
#        dbal: 
#          sessionInitialization: 'SET NAMES utf8 COLLATE utf8_unicode_ci' 
"

echo "$SETTINGS" >> Configuration/Settings.yaml;
}

function initializeFLOW3(){
cd $phoenixpath
echo "Flushing..."
	./flow3 flow3:cache:flush 1>>$logfile 2>$errorlogfile
if [ $? -gt 0 ]; then
	returnError 7
else
	echo "flow3 script processed without errors."
fi
echo "Compiling..."
	./flow3 flow3:core:compile 1>>$logfile 2>$errorlogfile
if [ $? -gt 0 ]; then
	returnError 7
else
	echo "flow3 script processed without errors."
fi
echo "Migrating doctrine persistance..."
	./flow3 flow3:doctrine:migrate 1>>$logfile 2>$errorlogfile
if [ $? -gt 0 ]; then
	returnError 7
else
	echo "flow3 script processed without errors."
fi
if [ ! -n "$nodemo" ]; then
	echo "Importing PhoenixDemoTypo3Org..."
	./flow3 typo3:site:import < Packages/Sites.TYPO3/PhoenixDemoTypo3Org/Resources/Private/Content/Sites.xml 1>>$logfile 2>$errorlogfile
	if [ $? -gt 0 ]; then
		returnError 7
	else
		echo "flow3 script processed without errors."
	fi
fi
}

function returnSuccessMessage(){
	echo "Installation of TYPO3 phoenix finished. If you are using xdebug please make sure that
	   xdebug.max_nesting_level is set to a value like 1000 inside php.ini"
	echo
	echo "You may want to set a vhost in your apache configuration:"
	echo
	

vhost=" 
<VirtualHost *:80>
    ServerAdmin webmaster@yourwellchosendomain.com
    DocumentRoot '$phoenixpath/Web'
    ServerName phoenix.local
    ServerAlias www.phoenix.local
    ErrorLog 'logs/phoenix.local-error_log'
    CustomLog 'logs/phoenix.local-access_log' common
    <Directory '$phoenixpath/Web'>
      AllowOverride All
    </Directory>
</VirtualHost>	
"

	echo "vhost: $vhost"
	echo "Please have fun with your new system! Inspire people to share."
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
echo "Starting installation."
echo "Getting phoenix"
	getPhoenix
echo "Creating Settings"
	createSettings
#	setPermissions
	if [ -n "$GITUSER" ]; then
		addCommitHooks
	fi
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
