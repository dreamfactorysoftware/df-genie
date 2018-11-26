#!/bin/bash
# Colors schemes for echo:
RD='\033[0;31m' #Red
GN='\033[0;32m' #Green
MG='\033[0;95m' #Magenta
NC='\033[0m' # No Color

DEFAULT_PHP_VERSION="php7.2"

CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 2-3)

ERROR_STRING="Installation error. Exiting"

# CHECK FOR KEYS
while [[ -n $1 ]]
do
	case "$1" in
        	--with-oracle) ORACLE=TRUE;;
		--with-mysql) MYSQL=TRUE;;
		--with-apache) APACHE=TRUE;;
		--debug) DEBUG=TRUE;;
	esac
shift
done

if [[ ! $DEBUG == TRUE ]]
then
	exec 5>&1 # Save a copy of STDOUT
	exec > /dev/null 2>&1 # Redirect STDOUT to Null
else
	exec 5>&1 # Save a copy of STDOUT. Used because all echo redirects output to 5.
	exec > /tmp/dreamfactory_installer.log 2>&1
fi

clear >&5

# Make sure script run as sudo
if (( $EUID  != 0 ));
then
   echo -e "${RD}\nPlease run script with sudo: sudo bash $0 \n${NC}" >&5
   exit 1
fi

# Retrieve executing user's username
CURRENT_USER=$(logname)

if [[ -z $SUDO_USER ]] && [[ -z $CURRENT_USER ]]
then
        echo -e "${RD} Enter username for installation DreamFactory:${NC}" >&5
        read  CURRENT_USER
fi

if [[ ! -z $SUDO_USER ]]
then
        CURRENT_USER=${SUDO_USER}
fi

### STEP 1. Install system dependencies
echo -e "${GN}Step 1: Installing system dependencies...\n${NC}" >&5
apt-get update 
apt-get install -y git \
	curl \
	zip \
	unzip \
	ca-certificates \
	apt-transport-https \
	software-properties-common \
	lsof \
	libmcrypt-dev \
	libreadline-dev

# Check installation status
if (( $? >= 1 ))
then
	echo -e  "${RD}\n${ERROR_STRING}${NC}" >&5
	exit 1
fi

echo -e "${GN}The system dependencies have been successfully installed.\n${NC}" >&5

### Step 2. Install PHP
echo -e "${GN}Step 2: Installing PHP...\n${NC}" >&5

PHP_VERSION=$(php --version 2> /dev/null | head -n 1 | cut -d " " -f 2 | cut -c 1,3 )
MCRYPT=0

if [[ $PHP_VERSION =~ ^-?[0-9]+$ ]]
then
	if (( $PHP_VERSION == 71 ))
	then
		PHP_VERSION=php7.1
		MCRYPT=1
  	else
		PHP_VERSION=${DEFAULT_PHP_VERSION}
	fi
else
	PHP_VERSION=${DEFAULT_PHP_VERSION}
fi

PHP_VERSION_INDEX=$(echo $PHP_VERSION | cut -c 4-6)

# Install the php repository
add-apt-repository ppa:ondrej/php -y

# Update the system
apt-get update  > /dev/null

apt-get install -y ${PHP_VERSION}-common \
	${PHP_VERSION}-xml \
	${PHP_VERSION}-cli \
	${PHP_VERSION}-curl \
	${PHP_VERSION}-json \
	${PHP_VERSION}-mysqlnd \
	${PHP_VERSION}-sqlite \
	${PHP_VERSION}-soap \
	${PHP_VERSION}-mbstring \
	${PHP_VERSION}-zip \
	${PHP_VERSION}-bcmath \
	${PHP_VERSION}-dev 

if (( $? >= 1 ))
then
        echo -e  "${RD}\n${ERROR_STRING}${NC}" >&5
        exit 1
fi

echo -e "${GN}${PHP_VERSION} installed.\n${NC}" >&5

### Step 3. Configure PHP development tools
echo -e "${GN}Step 3: Configuring PHP Extensions...\n${NC}" >&5

apt-get install -y php-pear

if (( $? >= 1 ))
then
	echo -e  "${RD}\n${ERROR_STRING}${NC}">&5
        exit 1
fi

pecl channel-update pecl.php.net

### Install MCrypt
php -m | grep -E "^mcrypt"
if (( $? >= 1 ))
then
	if [[ $MCRYPT == 0 ]]
	then
		printf "\n" | pecl install mcrypt-1.0.1
		if (( $? >= 1 ))
		then
	        	echo -e  "${RD}\nMcrypt extension installation error.${NC}" >&5
	        	exit 1
		fi
		echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mcrypt.ini
		phpenmod mcrypt
	else
		apt-get install ${PHP_VERSION}-mcrypt
	fi
	php -m | grep -E "^mcrypt" 
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nMcrypt installation error.${NC}" >&5
	fi
fi

### Install MongoDB drivers
php -m | grep -E "^mongodb"
if (( $? >= 1 ))
then
	pecl install mongodb
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nMongo DB extension installation error.${NC}" >&5
	        exit 1
	fi
	echo "extension=mongodb.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mongodb.ini
	phpenmod mongodb
	php -m | grep -E  "^mongodb"
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nMongoDB installation error.${NC}" >&5
	fi
fi

### Install MS SQL Drivers
php -m | grep -E "^sqlsrv"
if (( $? >= 1 ))
then
	curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
	if (( $CURRENT_OS == 16 ))
	then
		curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
	elif (( $CURRENT_OS == 18 ))
	then
		curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
	else	
		echo -e "${RD} The script support only Ubuntu 16 and 18 versions. Exit.\n ${NC}">&5
		exit 1
	fi
	apt-get update  
	ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools unixodbc-dev
	sudo -u $CURRENT_USER bash -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bash_profile"
	sudo -u $CURRENT_USER bash -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bashrc"
	sudo -u $CURRENT_USER bash -c "source $HOME/.bashrc"
	
	pecl install sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nMS SQL Server extension installation error.${NC}" >&5
	        exit 1
	fi
	echo "extension=sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/sqlsrv.ini
	phpenmod sqlsrv
	php -m | grep -E  "^sqlsrv" 
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nMS SQL Server extension installation error.${NC}" >&5
	fi
fi	

### DRIVERS FOR MSSQL (pdo_sqlsrv)
php -m | grep -E "^pdo_sqlsrv"
if (( $? >= 1 ))
then
	pecl install pdo_sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\npdo_sqlsrv extension installation error.${NC}" >&5
	        exit 1
	fi
	echo "extension=pdo_sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/pdo_sqlsrv.ini
	phpenmod pdo_sqlsrv
	php -m | grep -E  "^pdo_sqlsrv"
	if (( $? >= 1 ))
	then
		echo -e  "${RD}\nCould not install pdo_sqlsrv extension${NC}" >&5
	fi
fi

### DRIVERS FOR ORACLE ( ONLY WITH KEY --oracle )
php -m | grep -E "^oci8" 
if (( $? >= 1 ))
then
	if [[ $ORACLE == TRUE ]]
	then
		echo -e "${MG}Enter path to the Oracle drivers: [./]${NC} " >&5
        	read DRIVERS_PATH 
        	if [[ -z $DRIVERS_PATH ]]
        	then
                	DRIVERS_PATH="."
        	fi
		unzip "$DRIVERS_PATH/instantclient-*.zip" -d /opt/oracle
		if (( $? == 0 ))
		then
			echo -e  "${GN}Drivers found.\n${NC}" >&5
	        	apt-get install -y libaio1
			echo "/opt/oracle/instantclient_18_3" > /etc/ld.so.conf.d/oracle-instantclient.conf
	        	ldconfig
	        	sudo -u $CURRENT_USER bash -c "echo export LD_LIBRARY_PATH=/opt/oracle/instantclient_18_3:$LD_LIBRARY_PATH >> $HOME/.bash_profile"
	        	sudo -u $CURRENT_USER bash -c "echo export LD_LIBRARY_PATH=/opt/oracle/instantclient_18_3:$LD_LIBRARY_PATH >> $HOME/.bashrc"
	        	sudo -u $CURRENT_USER bash -c "echo export PATH=/opt/oracle/instantclient_18_3:$PATH >> $HOME/.bash_profile"
	        	sudo -u $CURRENT_USER bash -c "echo export PATH=/opt/oracle/instantclient_18_3:$PATH >> $HOME/.bashrc"
	        	sudo -u $CURRENT_USER bash -c "source $HOME/.bashrc"
	        	printf "instantclient,/opt/oracle/instantclient_18_3\n" | pecl install oci8
	        	if (( $? >= 1 ))
			then
	        		echo -e  "${RD}\nOracle instant client installation error${NC}" >&5
	        		exit 1
			fi
			echo "extension=oci8.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/oci8.ini
	        	phpenmod oci8
			
			php -m | grep oci8 
			if (( $? >= 1 ))
	        	then
	        	        echo -e  "${RD}\nCould not install oci8 extension.${NC}" >&5
	        	fi
		else
			echo -e  "${RD}Drivers not found. Skipping...\n${NC}" >&5
		fi
	fi
fi
echo -e "${GN}PHP Extensions configured.\n${NC}" >&5

### Step 4. Install Apache
if [[ $APACHE == TRUE ]] ### Only with key --apache
then
	echo -e "${GN}Step 4: Installing Apache...\n${NC}" >&5
	# Check Apache installation status
	ps aux | grep -v grep | grep apache2
	CHECK_APACHE_PROCESS=$(echo $?)

	dpkg -l | grep apache2 | cut -d " " -f 3 | grep -E "apache2$" 
	CHECK_APACHE_INSTALLATION=$(echo $?)
	
	if (( $CHECK_APACHE_PROCESS == 0 )) || (( $CHECK_APACHE_INSTALLATION == 0 ))
	then
	        echo -e  "${RD}Apache2 detected. Skipping installation. Configure Apache2 manually.\n${NC}" >&5
	else 
		# Install Apache
	        # Check if running web server on port 80
		lsof -i :80 | grep LISTEN 
	        if (( $? == 0 ))
	        then
	                echo -e  "${RD}Port 80 taken.\n ${NC}" >&5
	                echo -e  "${RD}Skipping installation Apache2. Install Apache2 manually.\n ${NC}" >&5
	        else
	                apt-get -qq install -y apache2 libapache2-mod-${PHP_VERSION}
	                if (( $? >= 1 ))
	                  then
	                        echo -e  "${RD}\nCould not install Apache. Exiting.${NC}" >&5
	                        exit 1
	                fi
	                a2enmod rewrite
	                echo "extension=pdo_sqlsrv.so" >> /etc/php/${PHP_VERSION_INDEX}/apache2/conf.d/30-pdo_sqlsrv.ini
	                echo "extension=sqlsrv.so" >> /etc/php/${PHP_VERSION_INDEX}/apache2/conf.d/20-sqlsrv.ini
	                # Create apache2 site entry
	                WEB_PATH=/etc/apache2/sites-available/000-default.conf
			echo '<VirtualHost *:80>' > $WEB_PATH
	                echo 'DocumentRoot /opt/dreamfactory/public' >> $WEB_PATH
	                echo '<Directory /opt/dreamfactory/public>' >> $WEB_PATH
	                echo 'AddOutputFilterByType DEFLATE text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript' >> $WEB_PATH
	                echo 'Options -Indexes +FollowSymLinks -MultiViews' >> $WEB_PATH
	                echo 'AllowOverride All' >> $WEB_PATH
	                echo 'AllowOverride None' >> $WEB_PATH
	                echo 'Require all granted' >> $WEB_PATH
	                echo 'RewriteEngine on' >> $WEB_PATH
	                echo 'RewriteBase /' >> $WEB_PATH
	                echo 'RewriteCond %{REQUEST_FILENAME} !-f' >> $WEB_PATH
	                echo 'RewriteCond %{REQUEST_FILENAME} !-d' >> $WEB_PATH
	                echo 'RewriteRule ^.*$ /index.php [L]' >> $WEB_PATH
	                echo '<LimitExcept GET HEAD PUT DELETE PATCH POST>' >> $WEB_PATH
	                echo 'Allow from all' >> $WEB_PATH
	                echo '</LimitExcept>' >> $WEB_PATH
	                echo '</Directory>' >> $WEB_PATH
	                echo '</VirtualHost>' >> $WEB_PATH
	
	                service apache2 restart
	
	                echo -e "${GN}Apache2 installed.\n${NC}" >&5
	        fi
	fi

else
	echo -e "${GN}Step 4: Installing Nginx...\n${NC}" >&5 ### Default choice 

	# Check nginx installation in the system
	ps aux | grep -v grep | grep nginx
	CHECK_NGINX_PROCESS=$(echo $?)
	
	dpkg -l | grep nginx | cut -d " " -f 3 | grep -E "nginx$" 
	CHECK_NGINX_INSTALLATION=$(echo $?)
	
	if (( $CHECK_NGINX_PROCESS == 0 )) || (( $CHECK_NGINX_INSTALLATION == 0 ))
	then
		echo -e  "${RD}Nginx detected. Skipping installation. Configure Nginx manually.\n${NC}" >&5
	else
	        # Install nginx
	        # Checking running web server
	        lsof -i :80 | grep LISTEN 
	        if (( $? == 0 ))
	        then
	               	echo -e  "${RD}Port 80 taken.\n ${NC}" >&5
	               	echo -e  "${RD}Skipping Nginx installation. Install Nginx manually.\n ${NC}" >&5
	        else
	        	apt-get install -y nginx ${PHP_VERSION}-fpm
	        	if (( $? >= 1 ))
	            	  then
	                	echo -e  "${RD}\nCould not install Nginx. Exiting.${NC}" >&5
	                	exit 1
	        	fi
	        	# Change php fpm configuration file
	        	sed -i 's/\;cgi\.fix\_pathinfo\=1/cgi\.fix\_pathinfo\=0/' $(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;}'| sed 's/cli/fpm/')	
	        
	        	# Create nginx site entry
	        	WEB_PATH=/etc/nginx/sites-available/default
	                echo 'server {' > $WEB_PATH
	                echo 'listen 80 default_server;' >> $WEB_PATH
	                echo 'listen [::]:80 default_server ipv6only=on;' >> $WEB_PATH
	                echo 'root /opt/dreamfactory/public;' >> $WEB_PATH
	                echo 'index index.php index.html index.htm;' >> $WEB_PATH
	                echo 'server_name server_domain_name_or_IP;' >> $WEB_PATH
	                echo 'gzip on;' >> $WEB_PATH
	                echo 'gzip_disable "msie6";' >> $WEB_PATH
	                echo 'gzip_vary on;' >> $WEB_PATH
	                echo 'gzip_proxied any;' >> $WEB_PATH
	                echo 'gzip_comp_level 6;' >> $WEB_PATH
	                echo 'gzip_buffers 16 8k;' >> $WEB_PATH
	                echo 'gzip_http_version 1.1;' >> $WEB_PATH
	                echo 'gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;' >> $WEB_PATH
	                echo 'location / {' >> $WEB_PATH
	                echo 'try_files $uri $uri/ /index.php?$args;}' >> $WEB_PATH
	                echo 'error_page 404 /404.html;' >> $WEB_PATH
	                echo 'error_page 500 502 503 504 /50x.html;' >> $WEB_PATH
	                echo 'location = /50x.html {' >> $WEB_PATH
	                echo 'root /usr/share/nginx/html;}' >> $WEB_PATH
	                echo 'location ~ \.php$ {' >> $WEB_PATH
	                echo 'try_files $uri =404;' >> $WEB_PATH
	                echo 'fastcgi_split_path_info ^(.+\.php)(/.+)$;' >> $WEB_PATH
	                echo "fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;" >> $WEB_PATH
	                echo 'fastcgi_index index.php;' >> $WEB_PATH
	                echo 'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' >> $WEB_PATH
	                echo 'include fastcgi_params;}}' >> $WEB_PATH
	        	
	        
	        	service ${PHP_VERSION}-fpm restart && service nginx restart
	        
	        	echo -e "${GN}Nginx installed.\n${NC}" >&5
	        fi
	fi
fi
	
### Step 5. Installing Composer
echo -e "${GN}Step 5: Installing Composer...\n${NC}" >&5

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (( $? >= 1 ))
then
        echo -e  "${RD}\n${ERROR_STRING}${NC}" >&5
        exit 1
fi
echo -e "${GN}Composer installed.\n${NC}" >&5

### Step 6. Installing MySQL
if [[ $MYSQL == TRUE ]] ### Only with key --with-mysql
then
	echo -e "${GN}Step 6: Installing Database for DreamFactory...\n${NC}" >&5

	dpkg -l | grep mysql | cut -d " " -f 3 | grep -E "^mysql" | grep -E -v "^mysql-client" 
	CHECK_MYSQL_INSTALLATION=$(echo $?)
	
	ps aux | grep -v grep | grep -E "^mysql"
	CHECK_MYSQL_PROCESS=$(echo $?)
	
	lsof -i :3306 | grep LISTEN
	CHECK_MYSQL_PORT=$(echo $?)
	
	if (( $CHECK_MYSQL_PROCESS == 0 )) || (( $CHECK_MYSQL_INSTALLATION == 0 )) || (( $CHECK_MYSQL_PORT == 0 ))
	then
		echo -e  "${RD}MySQL Database detected in the system. Skipping installation. \n${NC}" >&5
		DB_FOUND=TRUE
	else
		if (( $CURRENT_OS == 16 ))
	        then
	        	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 
	        	add-apt-repository 'deb [arch=amd64,arm64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/ubuntu xenial main'
	        
		elif (( $CURRENT_OS == 18 ))
	        then
	        	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
	        	add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.petarmaric.com/repo/10.3/ubuntu bionic main'
		else
			echo -e "${RD} The script support only Ubuntu 16 and 18 versions. Exit.\n ${NC}" >&5
			exit 1
	        fi
	       
		apt-get update
	       
		echo -e  "${MG}Please choose a strong MySQL root user password: ${NC}" >&5
        	read DB_PASS
		if [[ -z $DB_PASS ]]
                then
                        until [[ ! -z $DB_PASS ]]
                        do
                                echo -e "${RD}The password can't be empty!${NC}" >&5
                                read DB_PASS
                        done
                fi

		echo -e  "${GN}\nPassword accepted.${NC}\n" >&5
	        # Disable interactive mode in installation mariadb. Set generated above password.
		export DEBIAN_FRONTEND="noninteractive"
		debconf-set-selections <<< "mariadb-server mysql-server/root_password password $DB_PASS"
		debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $DB_PASS" 

		apt-get install -y mariadb-server
	        
	        if (( $? >= 1 ))
	        then
	                echo -e  "${RD}\n${ERROR_STRING}${NC}" >&5
	                exit 1
	        fi
	
		service mariadb start
		if (( $? >= 1 ))
        	then
                	echo -e  "${RD}\nCould not start MariaDB.. Exit ${NC}" >&5
                	exit 1
        	fi
	fi
	
	echo -e "${GN}Database for DreamFactory installed.\n${NC}" >&5

	### Step 7. Configuring DreamFactory system database
	echo -e "${GN}Step 7: Configure DreamFactory system database.\n${NC}" >&5
	
	DB_INSTALLED=FALSE

	# The MySQL database has already been installed, so let's configure
	# the DreamFactory system database.	
	if [[ $DB_FOUND == TRUE ]]
	then
	        echo -e "${MG}Is DreamFactory MySQL system database already configured? [Yy/Nn] ${NC}" >&5
	        read DB_ANSWER
	        if [[ -z $DB_ANSWER ]]
	        then
	                DB_ANSWER=Y
	        fi
	        if [[ $DB_ANSWER =~ ^[Yy]$ ]]
	        then
	                DB_INSTALLED=TRUE

		# MySQL system database is not installed, but MySQL is, so let's
		# prompt the user for the root password.
		else
			echo -e "\n${MG}Enter MySQL root password: ${NC} " >&5
	        	read DB_PASS
	
	        	# Test DB access
	        	mysql -h localhost -u root -p$DB_PASS -e"quit" 
	        	if (( $? >= 1 ))
	        	then
	                	ACCESS=FALSE
				TRYS=0
	                	until [[ $ACCESS == TRUE ]]
	                	do
	                        	echo -e "${RD}\nPassword incorrect!\n ${NC}" >&5
	                        	echo -e "${MG}Enter root user password:\n ${NC}" >&5
	                        	read DB_PASS
	                        	mysql -h localhost -u root -p$DB_PASS -e"quit" 
	                        	if (( $? == 0 ))
	                        		then
	                                	ACCESS=TRUE
	                        	fi
					TRYS=$((TRYS + 1))
					if (( $TRYS == 3 ))
					then
						echo -e "\n${RD}Exitr.\n${NC}" >&5
						exit 1	
					fi
	                	done
	        	fi
	
		fi
	fi

	# If the DreamFactory system database not already installed,
	# let's install it.
	if [[ $DB_INSTALLED == FALSE ]]
	then
	
	        # Test DB access
	        mysql -h localhost -u root -p$DB_PASS -e"quit"
	        if (( $? >= 1 ))
	        then
	                echo -e "${RD}Connection to Database failed. Exit \n${NC}" >&5
	                exit 1
	        fi
		echo -e "${MG}What would you like to name your system database? (e.g. dreamfactory) ${NC}" >&5
		read DF_SYSTEM_DB
		if [[ -z $DF_SYSTEM_DB ]]
                then
			until [[ ! -z $DF_SYSTEM_DB ]]
			do
				echo -e "${RD}The name can't be empty!${NC}" >&5
				read DF_SYSTEM_DB
			done
                fi

	        echo "CREATE DATABASE ${DF_SYSTEM_DB};" | mysql -u root -p${DB_PASS}
	
		echo -e "\n${MG}Please create a MySQL DreamFactory system database user name (e.g. dfadmin): ${NC}" >&5
		read DF_SYSTEM_DB_USER
		if [[ -z $DF_SYSTEM_DB_USER ]]
                then
                        until [[ ! -z $DF_SYSTEM_DB_USER ]]
                        do
                                echo -e "${RD}The name can't be empty!${NC}" >&5
                                read DF_SYSTEM_DB_USER
                        done
                fi


		echo -e "\n${MG}Please create a secure MySQL DreamFactory system database user password: ${NC}" >&5
		read DF_SYSTEM_DB_PASSWORD
                if [[ -z $DF_SYSTEM_DB_PASSWORD ]]
		then
                        until [[ ! -z $DF_SYSTEM_DB_PASSWORD ]]
                        do
                                echo -e "${RD}The name can't be empty!${NC}" >&5
                                read DF_SYSTEM_DB_PASSWORD
                        done
                fi	
	        # Generate password for user in DB
	        echo "GRANT ALL PRIVILEGES ON ${DF_SYSTEM_DB}.* to \"${DF_SYSTEM_DB_USER}\"@\"localhost\" IDENTIFIED BY \"${DF_SYSTEM_DB_PASSWORD}\";" | mysql -u root -p${DB_PASS} 
		echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS} 
	
	        echo -e "\n${GN}Database configuration finished.\n${NC}" >&5
	else
	        echo -e "${GN}Skipping...\n${NC}" >&5
	fi
else
	echo -e "${GN}Step 6: Skipping DreamFactory system database installation.\n" >&5
	echo -e "Step 7: Skipping DreamFactory system database configuration.\n${NC}" >&5
fi

### Step 8. Install DreamFactory		
echo -e "${GN}Step 8: Installing DreamFactory...\n ${NC}" >&5

ls -d /opt/dreamfactory
if (( $? >= 1 ))
then
	mkdir -p /opt/dreamfactory
	git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory
	if (( $? >= 1 ))
	then
        	echo -e  "${RD}\nCould not clone DreamFactory repository. Exiting. ${NC}" >&5
        	exit 1
	fi
	DF_CLEAN_INSTALLATION=TRUE
else
	echo -e  "${RD}DreamFactory installation folder detected. Skipping installation.\n${NC}" >&5
	DF_CLEAN_INSTALLATION=FALSE
fi

echo -e "${MG}Do you have a commercial DreamFactory license? [Yy/Nn]${NC} " >&5
read ANSWER 
if [[ -z $ANSWER ]]
then
	ANSWER=N
fi
if [[ $ANSWER =~ ^[Yy]$ ]]
then
	echo -e "${MG}\nEnter path to license files: [./]${NC}"  >&5
	read LICENSE_PATH 
       	if [[ -z $LICENSE_PATH ]]
	then
		LICENSE_PATH="."
	fi
	ls $LICENSE_PATH/composer.{json,lock,json-dist} 
	if (( $? >= 1 ))
        then
                echo -e  "${RD}\nLicense not found. Skipping.\n${NC}" >&5
        else
		cp $LICENSE_PATH/composer.{json,lock,json-dist} /opt/dreamfactory/
		LICENSE_INSTALLED=TRUE
		echo -e "\n${GN}Licenses installed. ${NC}\n" >&5
	fi
else
	echo -e  "\n${RD}Installing DreamFactory OSS version.\n${NC}" >&5
fi
chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 

# If Oracle is not installed, add the --ignore-platform-reqs option
# to composer command
if [[ $ORACLE == TRUE ]]
then
    sudo -u $CURRENT_USER bash -c "/usr/local/bin/composer install --no-dev"
else
    sudo -u $CURRENT_USER bash -c "/usr/local/bin/composer install --no-dev --ignore-platform-reqs"
fi

### Shutdown silent mode because php artisan df:setup and df:env will get troubles with prompts.
exec 1>&5 5>&-

if [[ $DB_INSTALLED == FALSE ]]
then
        sudo -u  $CURRENT_USER bash -c "php artisan df:env -q \
                --db_connection=mysql \
                --db_host=127.0.0.1 \
                --db_port=3306 \
                --db_database=$(echo $DF_SYSTEM_DB) \
                --db_username=$(echo $DF_SYSTEM_DB_USER) \
                --db_password=$(echo $DF_SYSTEM_DB_PASSWORD | sed 's/['\'']//g')"
        sed -i 's/\#DB\_CHARSET\=/DB\_CHARSET\=utf8/g' .env
        sed -i 's/\#DB\_COLLATION\=/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
        echo -e "\n"
	MYSQL_INSTALLED=TRUE

elif [[ ! $MYSQL == TRUE && $DF_CLEAN_INSTALLATION == TRUE ]]
then
	sudo -u  $CURRENT_USER bash -c "php artisan df:env" 
fi

if [[ $DF_CLEAN_INSTALLATION == TRUE ]]
then
	sudo -u $CURRENT_USER bash -c "php artisan df:setup" 
fi 

if [[  $LICENSE_INSTALLED == TRUE || $DF_CLEAN_INSTALLATION == FALSE ]]
then
	php artisan migrate --seed
	sudo -u $CURRENT_USER bash -c "php artisan config:clear -q"
	
	###Add license key to .env file
	if [[ $LICENSE_INSTALLED == TRUE ]]
	then
		grep composer.json .env > /dev/null
		if (( $? >= 1 ))
		then
        		echo -e "\nDF_LICENSE_KEY=/opt/dreamfactory/composer.json" >> .env
        		echo "DF_LICENSE_KEY=/opt/dreamfactory/composer.lock" >> .env
        		echo "DF_LICENSE_KEY=/opt/dreamfactory/composer.json-dist" >> .env
		fi
	fi

fi

chmod -R 2775 storage/ bootstrap/cache/
chown -R www-data:$CURRENT_USER storage/ bootstrap/cache/
sudo -u $CURRENT_USER bash -c "php artisan cache:clear -q"

echo -e "\n${GN}Installation finished! ${NC}"

if [[ $DEBUG == TRUE ]]
then
	echo -e "\n${RD}The log file saved in: /tmp/dreamfactory_installer.log ${NC}"

fi
### Summary table
if [[ $MYSQL_INSTALLED == TRUE ]]
then
	echo -e "\n "
	echo -e "${MG}******************************"
	echo -e " DB for system table: mysql "
	echo -e " DB host: 127.0.0.1         "
	echo -e " DB port: 3306              "
	if [[ ! $DB_FOUND == TRUE ]]
	then
		echo -e " DB root password: $DB_PASS"
	fi
	echo -e " DB name: $(echo $DF_SYSTEM_DB) "
	echo -e " DB user: $(echo $DF_SYSTEM_DB_USER)"
	echo -e " DB password: $(echo $DF_SYSTEM_DB_PASSWORD)"  
	echo -e "******************************${NC}\n"
fi

exit 0



