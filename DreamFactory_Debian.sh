#!/bin/bash
#Colors schemes for echo:
RD='\033[0;31m' #Red
GN='\033[0;32m' #Green
MG='\033[0;95m' #Magenta
NC='\033[0m' # No Color

DEFAULT_PHP_VERSION="php7.2"

CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 2)

#CHECK FOR KEYS
while [[ -n $1 ]]
do
        case "$1" in
                --oracle) ORACLE=TRUE;;
                --with-mysql) MYSQL=TRUE;;
                --apache) APACHE=TRUE;;
        esac
shift
done

#dev mode:
#set -x

clear

#Check who run script. If not root or without sudo, exit.
if (( $EUID  != 0 ));
then
   echo -e "${RD}\nPlease run script with root privileges: su -mc \"bash $0\" \n${NC}"
   exit 1
fi

#Checking user from who was started script.
CURRENT_USER=$(logname)

if [[ -z $SUDO_USER ]] && [[ -z $CURRENT_USER ]]
then
        echo -e "${RD} \n"
        read -p "Enter username for installation DreamFactory:" CURRENT_USER
        echo -e "${NC} \n"
fi

if [[ ! -z $SUDO_USER ]]
then
        CURRENT_USER=${SUDO_USER}
fi

###STEP1
echo -e "${GN}Step 1: Installing prerequisites applications...\n${NC}"
apt-get -qq update > /dev/null 
apt-get -qq install -y git \
	curl \
	zip \
	unzip \
	ca-certificates \
	apt-transport-https \
	software-properties-common \
	lsof \
	libmcrypt-dev \
	libreadline-dev \
	dirmngr

#Checking status of installation
if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	exit 1
fi

echo -e "${GN}The prerequisites applications installed.\n${NC}"

###STEP2
echo -e "${GN}Step 2: Installing PHP...\n${NC}"

PHP_VERSION=${DEFAULT_PHP_VERSION}
PHP_VERSION_INDEX=$(echo $PHP_VERSION | cut -c 4-6)


# Install the php repository
curl -fsSL https://packages.sury.org/php/apt.gpg | apt-key add -
add-apt-repository "deb https://packages.sury.org/php/ $(lsb_release -cs) main"

# Update the system
apt-get -qq update 

apt-get -qq install -y ${PHP_VERSION}-common \
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
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

echo -e "${GN}${PHP_VERSION} installed.\n${NC}"

###STEP3
echo -e "${GN}Step 3: Configure PHP Extensions...\n${NC}"

apt-get -qq install -y php-pear

if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

pecl channel-update pecl.php.net

### MCRYPT
php -m | grep mcrypt > /dev/null 2>&1
if (( $? >= 1 ))
then
	printf "\n" | pecl -q install mcrypt-1.0.1
	if (( $? >= 1 ))
	then
	       	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	       	exit 1
	fi
	echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mcrypt.ini
	phpenmod mcrypt
	php -m | grep "mcrypt" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension Mcrypt have errors...${NC}"
	fi
fi

### DRIVERS FOR MONGODB
php -m | grep -E "^mongodb" > /dev/null 2>&1
if (( $? >= 1 ))
then
	pecl -q install mongodb
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=mongodb.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mongodb.ini
	phpenmod mongodb
	php -m | grep -E  "^mongodb" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension for MongoDB have errors...${NC}"
	fi
fi

### DRIVERS FOR MSSQL (sqlsrv)
php -m | grep -E "^sqlsrv" > /dev/null 2>&1
if (( $? >= 1 ))
then
	curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
	if (( $CURRENT_OS == 8 ))
	then
		curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list
	elif (( $CURRENT_OS == 9 ))
	then
		curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list	
	else	
		echo -e "${RD} The script support only Debian 8 and 9 versions. Exit.\n ${NC}"
		exit 1
	fi
	apt-get -qq update  
	ACCEPT_EULA=Y apt-get -qq install -y msodbcsql17 mssql-tools unixodbc-dev
	
	pecl -q install sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/sqlsrv.ini
	phpenmod sqlsrv
	php -m | grep -E  "^sqlsrv" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension for MsSQL DB have errors...${NC}"
	fi
fi	


### DRIVERS FOR MSSQL (pdo_sqlsrv)
php -m | grep -E "^pdo_sqlsrv" > /dev/null 2>&1
if (( $? >= 1 ))
then
	pecl -q install pdo_sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=pdo_sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/pdo_sqlsrv.ini
	phpenmod pdo_sqlsrv
	php -m | grep -E  "^pdo_sqlsrv" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
		echo -e  "${RD}\nExtension for MsSQL DB have errors...${NC}"
	fi
fi

### DRIVERS FOR ORACLE ( ONLY WITH KEY --oracle )
php -m | grep oci8 > /dev/null 2>&1
if (( $? >= 1 ))
then
	if [[ $ORACLE == TRUE ]]
	then
		echo -e "${MG}"
		echo -e "${MG}"
                read -p "Enter path to the Oracle drivers: [./] " DRIVERS_PATH
		if [[ -z $DRIVERS_PATH ]]
			then
			DRIVERS_PATH="."
		fi
		echo -e "${NC}"
		unzip "$DRIVERS_PATH/instantclient-*.zip" -d /opt/oracle > /dev/null 2>&1
	        if (( $? == 0 ))
		then	
			apt-get -qq install -y libaio1
			echo "/opt/oracle/instantclient_18_3" > /etc/ld.so.conf.d/oracle-instantclient.conf
	        	ldconfig
	        	printf "instantclient,/opt/oracle/instantclient_18_3\n" | pecl -q install oci8
	        	if (( $? >= 1 ))
			then
	        		echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        		exit 1
			fi
			echo "extension=oci8.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/oci8.ini
	        	phpenmod oci8
			
			php -m | grep oci8 > /dev/null 2>&1
			if (( $? >= 1 ))
	        	then
	        	        echo -e  "${RD}\nExtension for OracleDB have errors...${NC}"
	        	fi
		else
			echo -e  "${RD}Drivers not found. Skipping...\n${NC}"
		fi
		
	fi
fi
echo -e "${GN}PHP Extensions configured.\n${NC}"

###STEP4
if [[ $APACHE == TRUE ]] ### Only with key --apache
then
	echo -e "${GN}Step 4: Installing Apache...\n${NC}"
	# Check apache installation in the system
	ps aux | grep -v grep | grep apache2 > /dev/null 2>&1
	CHECK_APACHE_PROCESS=`echo $?`
	dpkg -l | grep apache2 | cut -d " " -f 3 | grep -E "apache2$" > /dev/null 2>&1
	CHECK_APACHE_INSTALLATION=`echo $?`
	if (( $CHECK_APACHE_PROCESS == 0 )) || (( $CHECK_APACHE_INSTALLATION == 0 ))
	then
	        echo -e  "${RD}Apache2 detected in the system. Skipping installation Apache2. Configure Apache2 manualy.\n${NC}"
	else # Install Apache
	        #Cheking running web server on 80 port 
	        lsof -i :80 | grep LISTEN > /dev/null 2>&1
	        if (( $? == 0 ))
	        then
	                echo -e  "${RD}Some web server already running on http port.\n ${NC}"
	                echo -e  "${RD}Skipping installation Apache2. Install Apache2 manualy.\n ${NC}"
	        else
	                apt-get -qq install -y apache2 libapache2-mod-${PHP_VERSION}
	                if (( $? >= 1 ))
	                  then
	                        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
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
	
	                echo -e "${GN}Apache2 installed.\n${NC}"
	        fi
	fi
else
	echo -e "${GN}Step 4: Installing Nginx...\n${NC}"
	
	# Check nginx installation in the system
	ps aux | grep -v grep | grep nginx > /dev/null 2>&1
	CHECK_NGINX_PROCESS=`echo $?`
	
	dpkg -l | grep nginx | cut -d " " -f 3 | grep -E "nginx$" > /dev/null 2>&1
	CHECK_NGINX_INSTALLATION=`echo $?`
	
	if (( $CHECK_NGINX_PROCESS == 0 )) || (( $CHECK_NGINX_INSTALLATION == 0 ))
	then
		echo -e  "${RD}Nginx detected in the system. Skipping installation Nginx. Configure Nginx manualy.\n${NC}"
	else
	        # Install nginx
	        #Cheking running web server
	        lsof -i :80 | grep LISTEN > /dev/null 2>&1
	        if (( $? == 0 ))
	        then
	               	echo -e  "${RD}Some web server already running on http port.\n ${NC}"
	               	echo -e  "${RD}Skipping installation Nginx. Install Nginx manualy.\n ${NC}"
	        else
	        	apt-get -qq install -y nginx ${PHP_VERSION}-fpm
	        	if (( $? >= 1 ))
	            	  then
	                	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
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
	        
	        	echo -e "${GN}Nginx installed.\n${NC}"
	        fi
	fi
fi

###STEP5
echo -e "${GN}Step 5: Installing Composer...\n${NC}"

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi
echo -e "${GN}Composer installed.\n${NC}"

###STEP6
if [[ $MYSQL == TRUE ]] ### Only with key --with-mysql
then
	echo -e "${GN}Step 6: Installing Database for DreamFactory...\n${NC}"
	
	dpkg -l | grep mysql | cut -d " " -f 3 | grep -E "^mysql" | grep -E -v "^mysql-client" > /dev/null 2>&1
	CHECK_MYSQL_INSTALLATION=$(echo $?)
	
	ps aux | grep -v grep | grep -E "^mysql" > /dev/null 2>&1
	CHECK_MYSQL_PROCESS=$(echo $?)
	
	lsof -i :3306 | grep LISTEN > /dev/null 2>&1
	CHECK_MYSQL_PORT=$(echo $?)
	
	if (( $CHECK_MYSQL_PROCESS == 0 )) || (( $CHECK_MYSQL_INSTALLATION == 0 )) || (( $CHECK_MYSQL_PORT == 0 ))
	then
		echo -e  "${RD}MySQL Database detected in the system. Skipping installation. \n${NC}"
		DB_FOUND=TRUE
	else
		if (( $CURRENT_OS == 8 ))
	        then
	        	apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
	        	add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian jessie main'
		elif (( $CURRENT_OS == 9 ))
	        then
			apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
			add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian stretch main'
		else
			echo -e "${RD} The script support only Debian 8 and 9 versions. Exit.\n ${NC}"
			exit 1
	        fi

                DB_PASS=$(date +%s | sha256sum | base64 | head -c 8)

                apt-get -qq update
                #Disable interactive mode in installation mariadb. Set generated above password.
                export DEBIAN_FRONTEND="noninteractive"
                debconf-set-selections <<< "mariadb-server mysql-server/root_password password $DB_PASS"
                debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $DB_PASS"
	        apt-get -qq update
	        apt-get -qq install -y mariadb-server
	        
	        if (( $? >= 1 ))
	        then
	                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	                exit 1
	        fi
	
		service mariadb start
	fi
	
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while starting service...Exit ${NC}"
	        exit 1
	fi
	
	echo -e "${GN}Database for DreamFactory installed.\n${NC}"
	
	###STEP7
	echo -e "${GN}Step 7: Configure installed Database...\n${NC}"
	
	DB_INSTALLED=FALSE
	
	if [[ $DB_FOUND == TRUE ]]
	then
		echo -e "${MG}"
		read -p 'Database for DreamFactory configured already? [Yy/Nn] ' DB_ANSWER
	        echo -e "${NC}"
		if [[ -z $DB_ANSWER ]]
		then
	        	DB_ANSWER=N	
		fi
		if [[ $DB_ANSWER =~ ^[Yy]$ ]]
		then
			DB_INSTALLED=TRUE
                else
                        echo -e "${MG}Enter password for Database root user:\n ${NC} " 
                        read -s DB_PASS

                        # Test access to DB
                        mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
                        if (( $? >= 1 ))
                        then
                                ACCESS=FALSE
                                TRYS=0
                                until [[ $ACCESS == TRUE ]]
                                do
                                        echo -e "${RD}\nPassword incorrect!\n ${NC}"
                                        echo -e "${MG}Enter correct password for root user:\n ${NC} "
                                        read -s DB_PASS
                                        mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
                                        if (( $? == 0 ))
                                                then
                                                ACCESS=TRUE
                                        fi
                                        TRYS=$((TRYS + 1))
                                        if (( $TRYS == 3 ))
                                        then
                                                break
                                        fi
                                done
                        fi

                fi

	fi
        if [[ $DB_INSTALLED == FALSE ]]
        then

                # Test access to DB
                mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
                if (( $? >= 1 ))
                then
                        echo -e "${RD}Connection to Database failed. Exit  \n${NC}"
                        exit 1
                fi

                echo "CREATE DATABASE dreamfactory;" | mysql -u root -p${DB_PASS} > /dev/null 2>&1

                #Generate password for user in DB
                DB_ADMIN_PASS=\'$(date +%s | sha256sum | base64 | head -c 8)\'
                echo "GRANT ALL PRIVILEGES ON dreamfactory.* to 'dfadmin'@'localhost' IDENTIFIED BY ${DB_ADMIN_PASS};" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
                echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1

                echo -e "${GN}Database configuration finished.\n${NC}"
        else
                echo -e "${GN}Skipping...\n${NC}"
        fi
else
        echo -e "${GN}Step 6: Skipping installation Database for DreamFactory...\n"
        echo -e "Step 7: Skipping configuration DreamFactory access to Database...\n${NC}"
fi

###STEP8
echo -e "${GN}Step 8: Installing DreamFactory...\n ${NC}"

ls -d /opt/dreamfactory > /dev/null 2>&1
if (( $? >= 1 ))
then
	mkdir -p /opt/dreamfactory
	git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory
	if (( $? >= 1 ))
	then
        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        	exit 1
	fi
	DF_CLEAN_INSTALLATION=TRUE
else
	echo -e  "${RD}Folder with DreamFactory detected. Skipping installation DreamFactory...\n${NC}"
	DF_CLEAN_INSTALLATION=FALSE
fi

echo -e "${MG}"
read -p 'Do you have license? [Yy/Nn] ' ANSWER  
echo -e "${NC}"
if [[ -z $ANSWER ]]
then
	ANSWER=N
fi
if [[ $ANSWER =~ ^[Yy]$ ]]
then
        echo -e "${MG}"
        read -p "Enter paht to license files: [./] " LICENSE_PATH
        if [[ -z $LICENSE_PATH ]]
        then
                LICENSE_PATH="."
        fi
        echo -e "${NC}"
        ls $LICENSE_PATH/composer.{json,lock,json-dist} > /dev/null 2>&1
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nLicenses not found. Skipping.\n${NC}"
        else
                cp $LICENSE_PATH/composer.{json,lock,json-dist} /opt/dreamfactory/
                LICENSE_INSTALLED=TRUE
                echo -e "\n${GN}Licenses installed. ${NC}\n"
        fi
else
	echo -e  "${RD}Installing OSS version of the DreamFactory...\n${NC}"
fi
chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 

if [[ $ORACLE == TRUE ]]
then
    su $CURRENT_USER -c "/usr/local/bin/composer install --no-dev"
else
    su $CURRENT_USER -c "/usr/local/bin/composer install --no-dev --ignore-platform-reqs"
fi

if [[ $DB_INSTALLED == FALSE ]] 
then
        su $CURRENT_USER -c "php artisan df:env \
                --db_connection=mysql \
                --db_host=127.0.0.1 \
                --db_port=3306 \
                --db_database=dreamfactory \
                --db_username=dfadmin \
                --db_password=$(echo $DB_ADMIN_PASS | sed 's/['\'']//g')"
        sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
        sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
        echo -e "\n${MG}Database root password:${NC} $DB_PASS"
        echo -e "\n"
elif [[ ! $MYSQL == TRUE && $DF_CLEAN_INSTALLATION == TRUE ]]
then
        su $CURRENT_USER -c "php artisan df:env"
        echo -e "\n"
fi

if [[ $DF_CLEAN_INSTALLATION == TRUE ]]
then
        su $CURRENT_USER -c "php artisan df:setup"
fi

if [[  $LICENSE_INSTALLED == TRUE && $DF_CLEAN_INSTALLATION == FALSE ]]
then
	php artisan migrate --seed
	su $CURRENT_USER -c "php artisan config:clear"
fi

chmod -R 2775 storage/ bootstrap/cache/
chown -R www-data:$CURRENT_USER storage/ bootstrap/cache/
su $CURRENT_USER -c "php artisan cache:clear"
echo -e "\n${GN}Installation finished ${NC}!"
exit 0

