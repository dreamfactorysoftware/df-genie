#!/bin/bash
#LAMP installation
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
   echo -e "${RD}\nPlease run script with sudo: sudo bash $0 \n${NC}"
   exit 1
fi

#Checking user from who was started script.
CURRENT_USER=$(logname > /dev/null 2>&1)

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
	libreadline-dev

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
add-apt-repository ppa:ondrej/php -y

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

echo -e "${GN}Step 4: Installing Apache2...\n${NC}"

# Check apache installation in the system
ps aux | grep -v grep | grep apache2 > /dev/null 2>&1
CHECK_APACHE_PROCESS=`echo $?`

dpkg -l | grep apache2 | cut -d " " -f 3 | grep -E "apache2$" > /dev/null 2>&1
CHECK_APACHE_INSTALLATION=`echo $?`

if (( $CHECK_APACHE_PROCESS == 0 )) || (( $CHECK_APACHE_INSTALLATION == 0 ))
then
	echo -e  "${RD}Apache2 detected in the system. Skipping installation Apache2. Configure Apache2 manualy.\n${NC}"
else
        # Install Apache

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
        
        	cd /etc/apache2/sites-available
        	
        # Create apache2 site entry
        	WEB_PATH=000-default.conf
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
        CURRENT_OS=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d "=" -f 2)
        if [[ $CURRENT_OS == xenial ]]
        then
                apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
                add-apt-repository 'deb [arch=amd64,arm64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/ubuntu xenial main'

        elif [[ $CURRENT_OS == bionic ]]
        then
                apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
                add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mariadb.petarmaric.com/repo/10.3/ubuntu bionic main'
        fi

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

echo "CREATE DATABASE dreamfactory;" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1

#Generate password for user in DB
DB_ADMIN_PASS=\'$(date +%s | sha256sum | base64 | head -c 8)\'
echo "GRANT ALL PRIVILEGES ON dreamfactory.* to 'dfadmin'@'localhost' IDENTIFIED BY ${DB_ADMIN_PASS};" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS}   > /dev/null 2>&1

echo -e "${GN}DB configuration finished.\n${NC}"
echo -e "${GN}Step 7: Installing DreamFactory...\n ${NC}"

mkdir /opt/dreamfactory && chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 
sudo -u $CURRENT_USER bash -c "git clone https://github.com/dreamfactorysoftware/dreamfactory.git ./ && composer install --no-dev"

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

sudo -u $CURRENT_USER bash -c "php artisan df:env"

sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env

echo -e "\n"
sudo -u $CURRENT_USER bash -c "php artisan df:setup"

chown -R www-data:$CURRENT_USER storage/ bootstrap/cache/
chmod -R 2775 storage/ bootstrap/cache/
sudo -u $CURRENT_USER bash -c "php artisan cache:clear"

exit 0
