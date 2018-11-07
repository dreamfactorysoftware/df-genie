#!/bin/bash
#LEMP installation
#Colors schemes for echo:
RD='\033[0;31m' #Red
GN='\033[0;32m' #Green
MG='\033[0;95m' #Magenta
NC='\033[0m' # No Color

CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 1-2)

#CHECK FOR --oracle 
case "$1" in
        --oracle) ORACLE=TRUE
	       	  DRIVERS_PATH=$2 ;;
esac


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

echo -e "${GN}Step 1: Installing prerequisites applications...\n${NC}"
dnf -q install -y git \
	curl \
	zip \
	unzip \
	ca-certificates \
	lsof \
	libmcrypt-devel \
	readline-devel \

#Checking status of installation
if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	exit 1
fi

echo -e "${GN}The prerequisites applications installed.\n${NC}"

echo -e "${GN}Step 2: Installing PHP...\n${NC}"

# Install the php repository
if (( $CURRENT_OS == 26 )) || (( $CURRENT_OS == 27 ))
then
	rpm -Uvh http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-stable.noarch.rpm
	rpm -Uvh http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-stable.noarch.rpm
	rpm -Uvh http://rpms.famillecollet.com/fedora/remi-release-${CURRENT_OS}.rpm
elif (( ! $CURRENT_OS == 28 ))
then
	echo -e "${RD} The script support only Fedora 26/27/28 versions. Exit.\n ${NC}"
        exit 1
fi

#Install PHP
if (( $CURRENT_OS == 26 )) || (( $CURRENT_OS == 27 ))
then
	dnf -q --enablerepo=remi --enablerepo=remi-php72 install -y php-common \
        php-xml \
        php-cli \
        php-curl \
        php-json \
        php-mysqlnd \
        php-sqlite3 \
        php-soap \
        php-mbstring \
        php-zip \
        php-bcmath \
        php-devel \
        php-fpm
else 
	dnf -q install -y php-common \
        php-xml \
        php-cli \
        php-curl \
        php-json \
        php-mysqlnd \
        php-sqlite3 \
        php-soap \
        php-mbstring \
        php-zip \
        php-bcmath \
        php-devel \
        php-fpm
fi
if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

echo -e "${GN}PHP installed.\n${NC}"

echo -e "${GN}Step 3: Configure PHP Extensions...\n${NC}"

dnf -q install -y php-pear
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
	echo "extension=mcrypt.so" > /etc/php.d/20-mcrypt.ini
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
	echo "extension=mongodb.so" > /etc/php.d/20-mongodb.ini
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
	if (( $CURRENT_OS == 28 ))
	then
		curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/mssql-release.repo
	#elif (( $CURRENT_OS == 27 || $CURRENT_OS == 26 ))
	#then
	#	curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list	
	#else	
	#	echo -e "${RD} The script support only Debian 8 and 9 versions. Exit.\n ${NC}"
	#	exit 1
	fi
	ACCEPT_EULA=Y yum -q install -y msodbcsql17 mssql-tools unixODBC-devel
	if (( $? >= 1 ))
	then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi
	#sudo -u $CURRENT_USER bash -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bash_profile"
	#sudo -u $CURRENT_USER bash -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bashrc"
	#sudo -u $CURRENT_USER bash -c "source $HOME/.bashrc"
	
	pecl -q install sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=sqlsrv.so" > /etc/php.d/20-sqlsrv.ini
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
	echo "extension=pdo_sqlsrv.so" > /etc/php.d/20-pdo_sqlsrv.ini
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
		dnf -q install -y libaio
		echo -e "${MG}"
		if [[ -z $DRIVERS_PATH ]]
		then
			DRIVERS_PATH="."
		fi
		echo -e "${NC}"
		yum -q install -y oracle-instantclient18.3-*-18.3.0.0.0-1.x86_64.rpm
		if (( $? >= 1 ))
	        then
                        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                        exit 1
                fi
		echo "/usr/lib/oracle/18.3/client64/lib" > /etc/ld.so.conf.d/oracle-instantclient.conf
	        ldconfig
	        printf "\n" | pecl -q install oci8
	        if (( $? >= 1 ))
		then
	        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        	exit 1
		fi
		echo "extension=oci8.so" > /etc/php.d/20-oci8.ini
		ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so.1	
		php -m | grep oci8 > /dev/null 2>&1
		if (( $? >= 1 ))
	        then
	                echo -e  "${RD}\nExtension for OracleDB have errors...${NC}"
	        fi
		
	fi
fi
echo -e "${GN}PHP Extensions configured.\n${NC}"

echo -e "${GN}Step 4: Installing Nginx...\n${NC}"

# Check nginx installation in the system
ps aux | grep -v grep | grep nginx > /dev/null 2>&1
CHECK_NGINX_PROCESS=`echo $?`

yum list installed | grep -E "^nginx.x86_64" > /dev/null 2>&1
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
        	dnf -q install -y nginx
        	if (( $? >= 1 ))
            	  then
                	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                	exit 1
        	fi
        # Change php fpm configuration file
        	sed -i 's/\;cgi\.fix\_pathinfo\=1/cgi\.fix\_pathinfo\=0/' $(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;}')	
        
        # Create nginx site entry
        	WEB_PATH=/etc/nginx/conf.d/dreamfactory.conf
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
                echo "fastcgi_pass unix:/var/run/php-fpm/www.sock;" >> $WEB_PATH
                echo 'fastcgi_index index.php;' >> $WEB_PATH
                echo 'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' >> $WEB_PATH
                echo 'include fastcgi_params;}}' >> $WEB_PATH
        	
       		#Need to remove default entry in nginx.conf 
		grep default_server /etc/nginx/nginx.conf
		if (( $? == 0 ))
		then
			sed -i "s/default_server//g" /etc/nginx/nginx.conf         	
		fi
		service php-fpm restart && service nginx restart
		systemctl enable nginx.service && systemctl enable php-fpm.service
		
		firewall-cmd --add-service=http

        	echo -e "${GN}Nginx installed.\n${NC}"
        fi
fi

echo -e "${GN}Step 5: Installing Composer...\n${NC}"

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi
echo -e "${GN}Composer installed.\n${NC}"

echo -e "${GN}Step 6: Installing DB for DreamFactory...\n${NC}"

yum list installed | grep -E "mariadb-server.x86_64" > /dev/null 2>&1
CHECK_MYSQL_INSTALLATION=$(echo $?)

ps aux | grep -v grep | grep mysql > /dev/null 2>&1
CHECK_MYSQL_PROCESS=$(echo $?)

lsof -i :3306 | grep LISTEN > /dev/null 2>&1
CHECK_MYSQL_PORT=$(echo $?)

if (( $CHECK_MYSQL_PROCESS == 0 )) || (( $CHECK_MYSQL_INSTALLATION == 0 )) || (( $CHECK_MYSQL_PORT == 0 ))
then
	echo -e  "${RD}MySQL DB detected in the system. Skipping installation. \n${NC}"
	DB_FOUND=TRUE
else
	if (( $CURRENT_OS == 28 ))
        then
		REPO_PATH=/etc/yum.repos.d/MariaDB.repo
		echo "[mariadb]" > $REPO_PATH
		echo "name = MariaDB" >> $REPO_PATH
		echo "baseurl = http://yum.mariadb.org/10.3/fedora28-amd64" >> $REPO_PATH
		echo "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" >> $REPO_PATH
		echo "gpgcheck=1" >> $REPO_PATH

	elif (( $CURRENT_OS == 27 ))
        then
		echo
        	#ADD Repo for 27
	fi
        
        dnf -q install -y mariadb-server
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi

	service mariadb start

	DB_PASS=$(date +%s | sha256sum | base64 | head -c 8)
	mysqladmin -u root -h localhost password ${DB_PASS}

fi

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while starting service...Exit ${NC}"
        exit 1
fi

echo -e "${GN}DB for DreamFactory installed.\n${NC}"

echo -e "${GN}Step 6: Configure installed Database...\n${NC}"

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
	fi
fi
if [[ $DB_INSTALLED == FALSE ]]
then
	
	# Test access to DB
	mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
		echo "${RD}Connection to Database failed. Exit  \n${NC}"
		exit 1
	fi
	
	echo "CREATE DATABASE dreamfactory;" | mysql -u root -p${DB_PASS} > /dev/null 2>&1
	
	#Generate password for user in DB
	DB_ADMIN_PASS=\'$(date +%s | sha256sum | base64 | head -c 8)\'
	echo "GRANT ALL PRIVILEGES ON dreamfactory.* to 'dfadmin'@'localhost' IDENTIFIED BY ${DB_ADMIN_PASS};" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
	echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
	
	echo -e "${GN}DB configuration finished.\n${NC}"
else
	echo -e "${GN}Skipping...\n${NC}"
fi
		
echo -e "${GN}Step 7: Installing DreamFactory...\n ${NC}"

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
	cp $LICENSE_PATH/composer.{json,lock} /opt/dreamfactory/
	if (( $? >= 1 ))
        then
                echo -e  "${RD}\nLicenses not found. Skipping.\n${NC}"
        else
		echo -e "\n${GN}Licenses installed. ${NC}\n"
		LICENSE_INSTALLED=TRUE
	fi
else
	echo -e  "${RD}Installing OSS version of the DreamFactory...\n${NC}"
fi
chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 

sudo -u $CURRENT_USER bash -c "composer install --no-dev --ignore-platform-reqs"
if [[ $DB_INSTALLED == FALSE ]] 
then
	echo -e "\n "
	echo -e "${MG}******************************"
	echo -e "* DB for system table: mysql *"
	echo -e "* DB host: 127.0.0.1         *"
	echo -e "* DB port: 3306              *"
	echo -e "* DB name: dreamfactory      *"
	echo -e "* DB user: dfadmin           *"
	echo -e "* DB password: $(echo $DB_ADMIN_PASS | sed 's/['\'']//g')      *"
	echo -e "******************************${NC}\n"
	sudo -u  $CURRENT_USER bash -c "php artisan df:env"
	sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
	sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
	echo -e "\n"
fi
if [[  $LICENSE_INSTALLED == TRUE && $DF_CLEAN_INSTALLATION == FALSE ]]
then
	mkdir -p /opt/dreamfactory/storage/framework/cache/data/55/bd/
	php artisan migrate --seed
	sudo -u $CURRENT_USER bash -c "php artisan config:clear"
else
	sudo -u $CURRENT_USER bash -c "php artisan df:setup"
fi
chmod -R 2775 storage/ bootstrap/cache/
chown -R apache:$CURRENT_USER storage/ bootstrap/cache/
sudo -u $CURRENT_USER bash -c "php artisan cache:clear"

#Add rules if SELinux enabled
sestatus | grep SELinux | grep enabled > /dev/null 2>&1
if (( $? == 0 ))
then
	setsebool -P httpd_can_network_connect_db 1
	chcon -t httpd_sys_content_t storage -R
	chcon -t httpd_sys_content_t bootstrap/cache/ -R
	chcon -t httpd_sys_rw_content_t  storage -R
	chcon -t httpd_sys_rw_content_t  bootstrap/cache/ -R
fi

echo -e "\n${GN}Installation finished ${NC}!"
exit 0
