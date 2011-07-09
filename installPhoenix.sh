#!/bin/sh
# $id: installPhoenix.sh 2011-07-09 22:37:01Z mabuse $
#
# installPhoenix.sh - install TYPO3 Phoenix to the current working directory
# usage: installPhoenix.sh --ARGUMENT1 --ARGUMENT2 ... 
#


##
# Set the defaults

DBHOST=127.0.0.1
DBNAME=phoenixdb

##
# Print usage information

usage () {

	cat <<EOF

Usage: $0 [OPTIONS]
	--dbhost=127.0.0.1		Provide IP-address of the database
	--dbname=phoenixdb		Provide name of the database
	--dbuser			Provide name of the database user with write access to dbname
	--dbpass			Provide password of the database user
	--gituser			Provide username with access to https://review.typo3.org

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
			--dbhost=*) DBHOST="$val" ;;
			--dbname=*) DBNAME="$val" ;;
			--dbuser=*) DBUSER="$val" ;;
			--dbpass=*) DBPASS="$val" ;;
			--gituser=*) GITUSER="$val" ;;

			--help) usage ;;

			*)
				if test -n "$pick_args"
				then
					append_args_to_args "$arg"
				fi
				;;
		esac
	done
}

##
# Quote the given arguments to make sure that any special chars are quoted
# (c) mysqld_safe

shell_quote_string() {
	echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}


if [ $# -lt 3 ] ;then
	usage 
	exit 1
fi

parse_arguments PICK-ARGS-FROM-ARGV "$@"

echo "--dbhost: $DBHOST --dbuser: $DBUSER --dbpass: $DBPASS --dbname: $DBNAME"

# TODO remove exit
exit 0

echo "Please insert your typo3.org username"
read USERNAME
echo "Your username is set to $USERNAME"
echo
echo
echo "Please insert your Database host's IP address (e.g. 127.0.0.1)"
echo "Pleas note that using 'localhost' is not recommended"
read DBHOST
echo "Your DB host is set to $DBHOST"
echo
echo
echo "Please insert your Database name (e.g. phoenix) "
read DBNAME
echo "Your DB name is set to $DBNAME"
echo
echo
echo "Please insert your Database Username"
read DBUSER
echo "Your DB username is set to $DBUSER"
echo
echo
echo "Please insert your Database password (will not be printed)"
read -s DBPASS
echo "Your Database password is set"
echo
echo
echo "Start git clone to current directory. Proceed?"
read -p "Press any key to start backup..."

git clone --recursive git://git.typo3.org/TYPO3v5/Distributions/Base.git TYPO3v5

cd TYPO3v5/

scp -p -P 29418 $USERNAME@review.typo3.org:hooks/commit-msg .git/hooks/

git submodule foreach 'scp -p -P 29418 $USERNAME@review.typo3.org:hooks/commit-msg .git/hooks/'
git submodule foreach 'git config remote.origin.push HEAD:refs/for/master'
git submodule foreach 'git checkout master; git pull'

# Create file Configuration/Settings.yaml

echo "TYPO3:" >> Configuration/Settings.yaml 
echo "  FLOW3:" >> Configuration/Settings.yaml 
echo "    persistence:" >> Configuration/Settings.yaml 
echo "      backendOptions:" >> Configuration/Settings.yaml 
echo "        driver: 'pdo_mysql'" >> Configuration/Settings.yaml 
echo "        dbname: '$DBNAME'   # adjust to your database name" >> Configuration/Settings.yaml 
echo "        user: '$DBUSER'        # adjust to your database user" >> Configuration/Settings.yaml 
echo "        password: '$DBPASS'        # adjust to your database password" >> Configuration/Settings.yaml 
echo "        host: '$DBHOST'   # adjust to your database host" >> Configuration/Settings.yaml 
echo "        path: '$DBHOST'   # adjust to your database host" >> Configuration/Settings.yaml 
echo "        port: 3306" >> Configuration/Settings.yaml 
echo "#      doctrine:" >> Configuration/Settings.yaml 
echo "         # If you have APC, you should consider using it for Production," >> Configuration/Settings.yaml 
echo "         # also MemcacheCache and XcacheCache exist." >> Configuration/Settings.yaml 
echo "#        cacheImplementation: 'Doctrine\Common\Cache\ApcCache'" >> Configuration/Settings.yaml 
echo "         # when using MySQL and UTF-8, this should help with connection encoding issues" >> Configuration/Settings.yaml 
echo "#        dbal:" >> Configuration/Settings.yaml 
echo "#          sessionInitialization: 'SET NAMES utf8 COLLATE utf8_unicode_ci'" >> Configuration/Settings.yaml 

./flow3 flow3:cache:flush
./flow3 flow3:core:compile
./flow3 flow3:doctrine:migrate
./flow3 typo3:site:import < Packages/Sites/TYPO3/PhoenixDemoTypo3Org/Resources/Private/Content/Sites.xml

clear
echo "Installation of TYPO3 phoenix finished. If you are using xdebug pleas make sure that
   xdebug.max_nesting_level is set to a value like 1000 inside php.ini"
echo
echo "Please have fun with your new system! Inspir people to share"
echo
echo
echo

