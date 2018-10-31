#!/bin/bash
#LEMP installation
#Colors schemes for echo:
RD='\033[0;31m'
GN='\033[0;32m'
MG='\033[0;95m'
NC='\033[0m' # No Color

DEFAULT_PHP_VERSION="php7.2"

#dev mode:
#set -x

clear 

#Check who run script. If not root or without sudo, exit.
if (( $EUID  != 0 ));
then
   echo -e "${RD} \nPlease run script with root privileges: su -c \"bash $0\" \n ${NC}"
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

echo -e "${GN}Step 1: Installing prerequisites applications...\n${NC}"
apt-get -qq update  
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

echo -e "${GN}Step 2: Installing PHP...\n${NC}"

PHP_VERSION=$(php --version | head -n 1 | cut -d " " -f 2 | cut -c 1,3 )
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

curl -fsSL https://packages.sury.org/php/apt.gpg | apt-key add -
add-apt-repository "deb https://packages.sury.org/php/ $(lsb_release -cs) main"

# Update the system
apt-get -qq update

apt-get -qq install ${PHP_VERSION}-common \
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
	${PHP_VERSION}-dev \
	${PHP_VERSION}-fpm

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

echo -e "${GN}${PHP_VERSION} installed.\n${NC}"

echo -e "${GN}Step 3: Configure PHP Extensions...\n${NC}"

apt-get -qq install -y php-pear

if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

pecl channel-update pecl.php.net

if [[ $MCRYPT == 0 ]]
then
	printf "\n" | pecl -q install mcrypt-1.0.1
	if (( $? >= 1 ))
	then
        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        	exit 1
	fi
	echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mcrypt.ini
	phpenmod mcrypt
else
	apt-get -qq install ${PHP_VERSION}-mcrypt
fi

pecl -q install mongodb
if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi
echo "extension=mongodb.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mongodb.ini
phpenmod mongodb

echo -e "${GN}PHP Extensions configured.\n${NC}"

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
        	apt-get -qq install -y nginx
        	if (( $? >= 1 ))
            	  then
                	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                	exit 1
        	fi
        # Change php fpm configuration file
        	sed -i 's/\;cgi\.fix\_pathinfo\=1/cgi\.fix\_pathinfo\=0/' $(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;}'| sed 's/cli/fpm/')	
        
        	cd /etc/nginx/sites-available
        
        # Create nginx site entry
        	WEB_PATH=default
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

echo -e "${GN}Step 5: Installing Composer...\n${NC}"

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

#sudo -u $CURRENT_USER bash -c "mkdir $HOME/Composer && php /tmp/composer-setup.php --install-dir=/$HOME/Composer --filename=composer"
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi
echo -e "${GN}Composer installed.\n${NC}"
echo -e "${GN}Step 6: Installing DB for DreamFactory..\n${NC}"

##Need add checking for alredy installed MariaDB 

dpkg -l | grep mysql | cut -d " " -f 3 | grep -E "^mysql" | grep -E -v "^mysql-client" > /dev/null 2>&1
CHECK_MYSQL_INSTALLATION=$(echo $?)

ps aux | grep -v grep | grep mysql > /dev/null 2>&1
CHECK_MYSQL_PROCESS=$(echo $?)

lsof -i :3306 | grep LISTEN > /dev/null 2>&1
CHECK_MYSQL_PORT=$(echo $?)

if (( $CHECK_MYSQL_PROCESS == 0 )) || (( $CHECK_MYSQL_INSTALLATION == 0 )) || (( $CHECK_MYSQL_PORT == 0 ))
then
	echo -e  "${RD}MySQL DB detected in the system. Skipping installation. \n${NC}"
else
	CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 2)
	if (( $CURRENT_OS == 9 ))
        then
        	apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
        	add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian stretch main'
        
	elif (( $CURRENT_OS == 8 ))
        then
        	apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
		add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian jessie main'
        fi
        
        apt-get -qq update
        apt-get -qq install -y mariadb-server
        
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi
	service mariadb start
	if (( $? >= 1 ))
	then
        	echo -e  "${RD}\nSome error while starting service...Exit ${NC}"
        	exit 1
	fi
fi

echo -e "${GN}DB for DreamFactory installed.\n${NC}"

echo -e "${GN}Step 6: Configure installed DB...\n${NC}"

echo -e "${MG}Enter password for DB root user:\n ${NC} " 
read -s DB_PASS

# Test access to DB
mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
if (( $? >= 1 ))
then
	ACCESS=1
	until (( $ACCESS == 0 ))
	do
		echo -e "${RD}Password incorrect!\n ${NC}"
		echo -e "${MG}Enter correct password for root user:\n ${NC} "
		read -s DB_PASS
		mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
		if (( $? == 0 ))
	       	then 
			ACCESS=0
	       	fi
	done        
fi

echo -e "${GN}Access confirmed.\n ${NC}"

echo "CREATE DATABASE dreamfactory;" | mysql -u root -p${DB_PASS} > /dev/null 2>&1

#Generate password for user in DB
DB_ADMIN_PASS=\'$(date +%s | sha256sum | base64 | head -c 8)\'
echo "GRANT ALL PRIVILEGES ON dreamfactory.* to 'dfadmin'@'localhost' IDENTIFIED BY ${DB_ADMIN_PASS};" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1

echo -e "${GN}DB configuration finished.\n${NC}"
echo -e "${GN}Step 7: Installing DreamFactory...\n ${NC}"

#chown -R $CURRENT_USER $(su $CURRENT_USER -c "echo $HOME")/.composer

mkdir /opt/dreamfactory && chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 
su $CURRENT_USER -c 'git clone https://github.com/dreamfactorysoftware/dreamfactory.git ./ && composer install --no-dev'

echo -e "\n "
echo -e "${MG}******************************"
echo -e "* Information for Step 7:    *"
echo -e "* DB for system table: mysql *"
echo -e "* DB host: 127.0.0.1         *"
echo -e "* DB port: 3306              *"
echo -e "* DB name: dreamfactory      *"
echo -e "* DB user: dfadmin           *"
echo -e "* DB password: $(echo $DB_ADMIN_PASS | sed 's/['\'']//g')      *"
echo -e "******************************${NC}\n"

su $CURRENT_USER -c "php artisan df:env"

sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env

echo -e "\n"
su $CURRENT_USER -c "php artisan df:setup"

chown -R www-data:$CURRENT_USER storage/ bootstrap/cache/
chmod -R 2775 storage/ bootstrap/cache/
su $CURRENT_USER -c "php artisan cache:clear"

exit 0
