#!/bin/bash
# Colors schemes for echo:
RD='\033[0;31m' # Red
GN='\033[0;32m' # Green
MG='\033[0;95m' # Magenta
NC='\033[0m'    # No Color

ERROR_STRING="Installation error. Exiting"
CURRENT_PATH=$(pwd)

CURRENT_OS=$(grep -e VERSION_ID /etc/os-release | cut -d "=" -f 2 | cut -c 2)

ERROR_STRING="Installation error. Exiting"

CURRENT_PATH=$(pwd)
# CHECK FOR KEYS
while [[ -n $1 ]]; do
  case "$1" in
  --with-oracle) ORACLE=TRUE ;;
  --with-mysql) MYSQL=TRUE ;;
  --with-apache) APACHE=TRUE ;;
  --with-db2) DB2=TRUE ;;
  --with-cassandra) CASSANDRA=TRUE ;;
  --with-tag=*)
    DREAMFACTORY_VERSION_TAG="${1/--with-tag=/}"
    ;;
  --with-tag)
    DREAMFACTORY_VERSION_TAG="$2"
    shift;
    ;;
  --debug) DEBUG=TRUE ;;
  --help) HELP=TRUE ;;
  -h) HELP=TRUE ;;
  *)
    echo -e "\n${RD}Invalid flag detected… aborting.${NC}"
    HELP=TRUE
    break
    ;;
  esac
  shift
done

if [[ $HELP == TRUE ]]; then
  echo -e "\nList of available keys:\n"
  echo "   --with-oracle                  Install driver and PHP extensions for work with Oracle DB"
  echo "   --with-mysql                   Install MariaDB as default system database for DreamFactory"
  echo "   --with-apache                  Install Apache2 web server for DreamFactory"
  echo "   --with-db2                     Install driver and PHP extensions for work with IBM DB2"
  echo "   --with-cassandra               Install driver and PHP extensions for work with Cassandra DB"
  echo "   --with-tag=<tag name>          Install DreamFactory with specific version.  "
  echo "   --debug                        Enable installation process logging to file in /tmp folder."
  echo -e "   -h, --help                     Show this help\n"
  exit 1
fi

if [[ ! $DEBUG == TRUE ]]; then
  exec 5>&1            # Save a copy of STDOUT
  exec >/dev/null 2>&1 # Redirect STDOUT to Null
else
  exec 5>&1 # Save a copy of STDOUT. Used because all echo redirects output to 5.
  exec >/tmp/dreamfactory_installer.log 2>&1
fi

clear >&5

echo_with_color() {
  case $1 in
  Red | RED | red)
    echo -e "${NC}${RD} $2 ${NC}"
    ;;
  Green | GREEN | green)
    echo -e "${NC}${GN} $2 ${NC}"
    ;;
  Magenta | MAGENTA | magenta)
    echo -e "${NC}${MG} $2 ${NC}"
    ;;
  *)
    echo -e "${NC} $2 ${NC}"
    ;;
  esac
}

# Make sure script run as sudo
if ((EUID != 0)); then
  echo -e "${RD}\nPlease run script with root privileges: sudo bash $0 \n${NC}" >&5
  exit 1
fi

# Retrieve executing user's username
CURRENT_USER=$(logname)

if [[ -z $SUDO_USER ]] && [[ -z $CURRENT_USER ]]; then
  echo_with_color red "Enter username for installation DreamFactory:" >&5
  read -r CURRENT_USER
fi

if [[ -n $SUDO_USER ]]; then
  CURRENT_USER=${SUDO_USER}
fi

### STEP 1. Install system dependencies
echo_with_color green "Step 1: Installing system dependencies...\n" >&5
yum update -y
yum install -y git \
  curl \
  zip \
  unzip \
  ca-certificates \
  lsof \
  readline-devel \
  libzip-devel \
  wget

# Check installation status
if (($? >= 1)); then
  echo_with_color red "\n${ERROR_STRING}" >&5
  exit 1
fi

echo_with_color green "The system dependencies have been successfully installed.\n" >&5

### Step 2. Install PHP
echo_with_color green "Step 2: Installing PHP...\n" >&5

# Install the php repository
if ((CURRENT_OS == 7)); then
  rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
else
  echo_with_color red "The script support only CentOS(RedHat) 7 versions. Exit.\n " >&5
  exit 1
fi

yum-config-manager --enable remi-php72

#Install PHP
yum --enablerepo=remi-php72 install -y php-common \
  php-xml \
  php-cli \
  php-curl \
  php-json \
  php-mysqlnd \
  php-sqlite3 \
  php-soap \
  php-mbstring \
  php-bcmath \
  php-devel \
  php-ldap \
  php-pgsql \
  php-interbase \
  php-pdo-dblib \
  php-gd \
  php-zip

if (($? >= 1)); then
  echo_with_color red "\n${ERROR_STRING}" >&5
  exit 1
fi

echo_with_color green "PHP installed.\n" >&5

### Step 3. Install Apache
if [[ $APACHE == TRUE ]]; then ### Only with key --apache
  echo_with_color green "Step 3: Installing Apache...\n" >&5
  # Check Apache installation status
  ps aux | grep -v grep | grep httpd
  CHECK_APACHE_PROCESS=$?

  yum list installed | grep -E "^httpd.x86_64"
  CHECK_APACHE_INSTALLATION=$?

  if ((CHECK_APACHE_PROCESS == 0)) || ((CHECK_APACHE_INSTALLATION == 0)); then
    echo_with_color red "Apache2 detected. Skipping installation. Configure Apache2 manually.\n" >&5
  else
    # Install Apache
    # Check if running web server on port 80
    lsof -i :80 | grep LISTEN
    if (($? == 0)); then
      echo_with_color red "Port 80 taken.\n " >&5
      echo_with_color red "Skipping installation Apache2. Install Apache2 manually.\n " >&5
    else
      yum install -y httpd php
      if (($? >= 1)); then
        echo_with_color red "\nCould not install Apache. Exiting." >&5
        exit 1
      fi
      # Create apache2 site entry
      echo "
<VirtualHost *:80>
    DocumentRoot /opt/dreamfactory/public
    <Directory /opt/dreamfactory/public>
        AddOutputFilterByType DEFLATE text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript
        Options -Indexes +FollowSymLinks -MultiViews
        AllowOverride All
        AllowOverride None
        Require all granted
        RewriteEngine on
        RewriteBase /
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^.*$ /index.php [L]
        <LimitExcept GET HEAD PUT DELETE PATCH POST>
            Allow from all
        </LimitExcept>
    </Directory>
</VirtualHost>" >/etc/httpd/conf.d/dreamfactory.conf

      service httpd restart
      systemctl enable httpd.service

      firewall-cmd --add-service=http

      echo_with_color green "Apache2 installed.\n" >&5
    fi
  fi

else
  echo_with_color green "Step 3: Installing Nginx...\n" >&5 ### Default choice

  # Check nginx installation in the system
  ps aux | grep -v grep | grep nginx
  CHECK_NGINX_PROCESS=$?

  yum list installed | grep -E "^nginx.x86_64"
  CHECK_NGINX_INSTALLATION=$?

  if ((CHECK_NGINX_PROCESS == 0)) || ((CHECK_NGINX_INSTALLATION == 0)); then
    echo_with_color red "Nginx detected. Skipping installation. Configure Nginx manually.\n" >&5
  else
    # Install nginx
    # Checking running web server
    lsof -i :80 | grep LISTEN
    if (($? == 0)); then
      echo_with_color red "Port 80 taken.\n " >&5
      echo_with_color red "Skipping Nginx installation. Install Nginx manually.\n " >&5
    else
      yum --enablerepo=remi-php72 install -y php-fpm nginx
      if (($? >= 1)); then
        echo_with_color red "\nCould not install Nginx. Exiting." >&5
        exit 1
      fi
      # Change php fpm configuration file
      sed -i 's/\;cgi\.fix\_pathinfo\=1/cgi\.fix\_pathinfo\=0/' $(php -i | sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;}')
      # Create nginx site entry
      echo "
server {

  listen 80 default_server;
  listen [::]:80 default_server ipv6only=on;
  root /opt/dreamfactory/public;
  index index.php index.html index.htm;
  gzip on;
  gzip_disable \"msie6\";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
  location / {

    try_files \$uri \$uri/ /index.php?\$args;
  }

  error_page 404 /404.html;
  error_page 500 502 503 504 /50x.html;

  location = /50x.html {

    root /usr/share/nginx/html;
  }
  location ~ \.php$ {

    try_files \$uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
  }
}" >/etc/nginx/conf.d/dreamfactory.conf

      #Need to remove default entry in nginx.conf
      grep default_server /etc/nginx/nginx.conf
      if (($? == 0)); then
        sed -i "s/default_server//g" /etc/nginx/nginx.conf
      fi
      service php-fpm restart && service nginx restart
      systemctl enable nginx.service && systemctl enable php-fpm.service
      firewall-cmd --add-service=http

      echo_with_color green "Nginx installed.\n" >&5
    fi
  fi
fi

### Step 4. Configure PHP development tools
echo_with_color green "Step 4: Configuring PHP Extensions...\n" >&5

yum --enablerepo=remi-php72 install -y php-pear
if (($? >= 1)); then
  echo_with_color red "\n${ERROR_STRING}" >&5
  exit 1
fi

pecl channel-update pecl.php.net

### Install MCrypt
php -m | grep -E "^mcrypt"
if (($? >= 1)); then
  yum --enablerepo=remi-php72 install -y libmcrypt-devel
  printf "\n" | pecl install mcrypt-1.0.1
  if (($? >= 1)); then
    echo_with_color red "\nMcrypt extension installation error." >&5
    exit 1
  fi
  echo "extension=mcrypt.so" >/etc/php.d/20-mcrypt.ini
  php -m | grep -E "^mcrypt"
  if (($? >= 1)); then
    echo_with_color red "\nMcrypt installation error." >&5
  fi
fi

### Install MongoDB drivers
php -m | grep -E "^mongodb"
if (($? >= 1)); then
  pecl install mongodb
  if (($? >= 1)); then
    echo_with_color red "\nMongo DB extension installation error." >&5
    exit 1
  fi
  echo "extension=mongodb.so" >/etc/php.d/20-mongodb.ini
  php -m | grep -E "^mongodb"
  if (($? >= 1)); then
    echo_with_color red "\nMongoDB installation error." >&5
  fi
fi

### Install MS SQL Drivers
php -m | grep -E "^sqlsrv"
if (($? >= 1)); then
  curl https://packages.microsoft.com/config/rhel/7/prod.repo >/etc/yum.repos.d/mssql-release.repo
  ACCEPT_EULA=Y yum install -y msodbcsql17 mssql-tools unixODBC-devel
  if (($? >= 1)); then
    echo_with_color red "\nMS SQL Server extension installation error." >&5
    exit 1
  fi

  ACCEPT_EULA=Y yum install -y php-sqlsrv php-pdo_sqlsrv
  if (($? >= 1)); then
    echo_with_color red "\nMS SQL Server extension installation error." >&5
    exit 1
  fi
  php -m | grep -E "^sqlsrv"
  if (($? >= 1)); then
    echo_with_color red "\nMS SQL Server extension installation error." >&5
  fi
  php -m | grep -E "^pdo_sqlsrv"
  if (($? >= 1)); then
    echo_with_color red "\nCould not install pdo_sqlsrv extension" >&5
  fi
fi

### DRIVERS FOR ORACLE ( ONLY WITH KEY --with-oracle )
php -m | grep -E "^oci8"
if (($? >= 1)); then
  if [[ $ORACLE == TRUE ]]; then
    echo_with_color magenta "Enter absolute path to the Oracle drivers, complete with trailing slash: [./] " >&5
    read -r DRIVERS_PATH
    if [[ -z $DRIVERS_PATH ]]; then
      DRIVERS_PATH="."
    fi
    ls -f $DRIVERS_PATH/oracle-instantclient19.*.rpm
    if (($? == 0)); then
      echo_with_color green "Drivers found.\n" >&5
      yum install -y libaio systemtap-sdt-devel $DRIVERS_PATH/oracle-instantclient19.*.rpm
      if (($? >= 1)); then
        echo_with_color red "\nOracle instant client installation error" >&5
        exit 1
      fi
      echo "/usr/lib/oracle/19.5/client64/lib" >/etc/ld.so.conf.d/oracle-instantclient.conf
      ldconfig
      export PHP_DTRACE=yes

      printf "\n" | pecl install oci8
      if (($? >= 1)); then
        echo_with_color red "\nOracle instant client installation error" >&5
        exit 1
      fi
      echo "extension=oci8.so" >/etc/php.d/20-oci8.ini

      php -m | grep -E "^oci8"
      if (($? >= 1)); then
        echo_with_color red "\nCould not install oci8 extension." >&5
      fi
    else
      echo_with_color red "Drivers not found. Skipping...\n" >&5
    fi
    unset DRIVERS_PATH
  fi
fi
### DRIVERS FOR IBM DB2 PDO ( ONLY WITH KEY --with-db2 )
php -m | grep -E "^pdo_ibm"
if (($? >= 1)); then
  if [[ $DB2 == TRUE ]]; then
    echo_with_color magenta "Enter absolute path to the IBM DB2 drivers, complete with trailing slash: [./] " >&5
    read -r DRIVERS_PATH
    if [[ -z $DRIVERS_PATH ]]; then
      DRIVERS_PATH="."
    fi
    tar xzf $DRIVERS_PATH/ibm_data_server_driver_package_linuxx64_v11.1.tar.gz -C /opt/
    if (($? == 0)); then
      echo_with_color green "Drivers found.\n" >&5
      yum install -y ksh
      chmod +x /opt/dsdriver/installDSDriver
      /usr/bin/ksh /opt/dsdriver/installDSDriver
      ln -s /opt/dsdriver/include /include
      git clone https://github.com/dreamfactorysoftware/PDO_IBM-1.3.4-patched.git /opt/PDO_IBM-1.3.4-patched
      cd /opt/PDO_IBM-1.3.4-patched/ || exit 1
      sed -i 's/option_str = Z_STRVAL_PP(data);//' ibm_driver.c
      sed -i '985i\#if PHP_MAJOR_VERSION >= 7\' ibm_driver.c
      sed -i '986i\option_str = Z_STRVAL_P(data);\' ibm_driver.c
      sed -i '987i\#else\' ibm_driver.c
      sed -i '988i\option_str = Z_STRVAL_PP(data);\' ibm_driver.c
      sed -i '989i\#endif' ibm_driver.c
      phpize
      ./configure --with-pdo-ibm=/opt/dsdriver/lib
      make && make install
      if (($? >= 1)); then
        echo_with_color red "\nCould not make pdo_ibm extension." >&5
        exit 1
      fi
      echo "extension=pdo_ibm.so" >/etc/php.d/20-pdo_ibm.ini

      php -m | grep pdo_ibm
      if (($? >= 1)); then
        echo_with_color red "\nCould not install pdo_ibm extension." >&5
      else
        ### DRIVERS FOR IBM DB2 ( ONLY WITH KEY --with-db2 )
        php -m | grep -E "^ibm_db2"
        if (($? >= 1)); then
          printf "/opt/dsdriver/ \n" | pecl install ibm_db2
          if (($? >= 1)); then
            echo_with_color red "\nibm_db2 extension installation error." >&5
            exit 1
          fi
          echo "extension=ibm_db2.so" >/etc/php.d/20-ibm_db2.ini
          php -m | grep ibm_db2
          if (($? >= 1)); then
            echo_with_color red "\nCould not install ibm_db2 extension." >&5
          fi
        fi
      fi
    else
      echo_with_color red "Drivers not found. Skipping...\n" >&5
    fi
    unset DRIVERS_PATH
    cd "${CURRENT_PATH}" || exit 1
    rm -rf /opt/PDO_IBM-1.3.4-patched
  fi
fi

### DRIVERS FOR CASSANDRA ( ONLY WITH KEY --with-cassandra )
php -m | grep -E "^cassandra"
if (($? >= 1)); then
  if [[ $CASSANDRA == TRUE ]]; then
    yum install -y lcgdm gmp-devel openssl-devel #boost cmake
    git clone https://github.com/datastax/php-driver.git /opt/cassandra
    cd /opt/cassandra/ || exit 1
    git checkout v1.3.2 && git pull origin v1.3.2
    wget http://downloads.datastax.com/cpp-driver/centos/7/cassandra/v2.10.0/cassandra-cpp-driver-2.10.0-1.el7.x86_64.rpm
    wget http://downloads.datastax.com/cpp-driver/centos/7/cassandra/v2.10.0/cassandra-cpp-driver-debuginfo-2.10.0-1.el7.x86_64.rpm
    wget http://downloads.datastax.com/cpp-driver/centos/7/cassandra/v2.10.0/cassandra-cpp-driver-devel-2.10.0-1.el7.x86_64.rpm
    wget http://downloads.datastax.com/cpp-driver/centos/7/dependencies/libuv/v1.23.0/libuv-1.23.0-1.el7.centos.x86_64.rpm
    wget http://downloads.datastax.com/cpp-driver/centos/7/dependencies/libuv/v1.23.0/libuv-debuginfo-1.23.0-1.el7.centos.x86_64.rpm
    wget http://downloads.datastax.com/cpp-driver/centos/7/dependencies/libuv/v1.23.0/libuv-devel-1.23.0-1.el7.centos.x86_64.rpm
    yum install -y *.rpm
    if (($? >= 1)); then
      echo_with_color red "\ncassandra extension installation error." >&5
      exit 1
    fi
    sed -i "s/7.1.99/7.2.99/" ./ext/package.xml
    ln -s /usr/lib64/libnsl.so.1 /usr/lib64/libnsl.so
    pecl install ./ext/package.xml
    if (($? >= 1)); then
      echo_with_color red "\ncassandra extension installation error." >&5
      exit 1
    fi
    echo "extension=cassandra.so" >/etc/php.d/20-cassandra.ini

    php -m | grep cassandra
    if (($? >= 1)); then
      echo_with_color red "\nCould not install ibm_db2 extension." >&5
    fi
    cd "${CURRENT_PATH}" || exit
    rm -rf /opt/cassandra
  fi
fi

### INSTALL IGBINARY EXT.
php -m | grep -E "^igbinary"
if (($? >= 1)); then
  pecl install igbinary
  if (($? >= 1)); then
    echo_with_color red "\nigbinary extension installation error." >&5
    exit 1
  fi

  echo "extension=igbinary.so" >/etc/php.d/20-igbinary.ini

  php -m | grep igbinary
  if (($? >= 1)); then
    echo_with_color red "\nCould not install ibm_db2 extension." >&5
  fi
fi

### INSTALL PYTHON BUNCH
yum install -y python python-pip
pip list | grep bunch
if (($? >= 1)); then
  pip install bunch
  if (($? >= 1)); then
    echo_with_color red "\nCould not install python bunch extension." >&5
  fi
fi

### INSTALL PYTHON3 MUNCH
yum install -y python3 python3-pip
pip3 list --format=legacy | grep munch
if (($? >= 1)); then
  pip3 install munch
  if (($? >= 1)); then
    echo_with_color red "\nCould not install python3 munch extension." >&5
  fi
fi

### Install Node.js
node -v
if (($? >= 1)); then
  curl -sL https://rpm.nodesource.com/setup_10.x | bash -
  yum install -y nodejs
  if (($? >= 1)); then
    echo_with_color red "\n${ERROR_STRING}" >&5
    exit 1
  fi
  NODE_PATH=$(whereis node | cut -d" " -f2)
fi
### INSTALL PCS
php -m | grep -E "^pcs"
if (($? >= 1)); then
  pecl install pcs-1.3.3
  if (($? >= 1)); then
    echo_with_color red "\npcs extension installation error.." >&5
    exit 1
  fi
  echo "extension=pcs.so" >/etc/php.d/20-pcs.ini

  php -m | grep pcs
  if (($? >= 1)); then
    echo_with_color red "\nCould not install pcs extension." >&5
  fi
fi

### INSTALL COUCHBASE
php -m | grep -E "^couchbase"
if (($? >= 1)); then
  wget -P /tmp http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-4-x86_64.rpm
  rpm -i /tmp/couchbase-release-1.0-4-x86_64.rpm
  yum install -y libcouchbase-devel
  pecl install couchbase
  if (($? >= 1)); then
    echo_with_color red "\ncouchbase extension installation error." >&5
    exit 1
  fi
  echo "extension=couchbase.so" >/etc/php.d/xcouchbase.ini
  php -m | grep couchbase
  if (($? >= 1)); then
    echo_with_color red "\nCould not install couchbase extension." >&5
  fi
fi

if [[ $APACHE == TRUE ]]; then
  service httpd restart
else
  service php-fpm restart
fi
echo_with_color green "PHP Extensions configured.\n" >&5

### Step 5. Installing Composer
echo_with_color green "Step 5: Installing Composer...\n" >&5

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (($? >= 1)); then
  echo_with_color red "\n${ERROR_STRING}" >&5
  exit 1
fi
echo_with_color green "Composer installed.\n" >&5

### Step 6. Installing MySQL
if [[ $MYSQL == TRUE ]]; then ### Only with key --with-mysql
  echo_with_color green "Step 6: Installing System Database for DreamFactory...\n" >&5

  yum list installed | grep -E "mariadb-server.x86_64"
  CHECK_MYSQL_INSTALLATION=$?

  ps aux | grep -v grep | grep -E "^mysql"
  CHECK_MYSQL_PROCESS=$?

	lsof -i :3306 | grep LISTEN
	CHECK_MYSQL_PORT=$?

  if ((CHECK_MYSQL_PROCESS == 0)) || ((CHECK_MYSQL_INSTALLATION == 0)) || ((CHECK_MYSQL_PORT == 0)); then
    echo_with_color red "MySQL Database detected in the system. Skipping installation. \n" >&5
    DB_FOUND=TRUE
  else
    echo_with_color magenta "Please choose a strong MySQL root user password: " >&5
    read -r DB_PASS
    if [[ -z $DB_PASS ]]; then
      until [[ -n $DB_PASS ]]; do
        echo_with_color red "The password can't be empty!" >&5
        read -r DB_PASS
      done
    fi

    echo_with_color green "\nPassword accepted.\n" >&5

    yum install -y mariadb-server
    if (($? >= 1)); then
      echo_with_color red "\n${ERROR_STRING}" >&5
      exit 1
    fi

    service mariadb start
    if (($? >= 1)); then
      echo_with_color red "\nCould not start MariaDB.. Exit " >&5
      exit 1
    fi
    mysqladmin -u root -h localhost password "${DB_PASS}"

  fi

  echo_with_color green "Database for DreamFactory installed.\n" >&5

  ### Step 7. Configuring DreamFactory system database
  echo_with_color green "Step 7: Configure DreamFactory system database.\n" >&5

  DB_INSTALLED=FALSE

  # The MySQL database has already been installed, so let's configure
  # the DreamFactory system database.
  if [[ $DB_FOUND == TRUE ]]; then
    echo_with_color magenta "Is DreamFactory MySQL system database already configured? [Yy/Nn] " >&5
    read -r DB_ANSWER
    if [[ -z $DB_ANSWER ]]; then
      DB_ANSWER=Y
    fi
    if [[ $DB_ANSWER =~ ^[Yy]$ ]]; then
      DB_INSTALLED=TRUE

    # MySQL system database is not installed, but MySQL is, so let's
    # prompt the user for the root password.
    else
      echo_with_color magenta "\n Enter MySQL root password:  " >&5
      read -r DB_PASS

      # Test DB access
      mysql -h localhost -u root "-p$DB_PASS" -e"quit"
      if (($? >= 1)); then
        ACCESS=FALSE
        TRYS=0
        until [[ $ACCESS == TRUE ]]; do
          echo_with_color red "\nPassword incorrect!\n " >&5
          echo_with_color magenta "Enter root user password:\n " >&5
          read -r DB_PASS
          mysql -h localhost -u root "-p$DB_PASS" -e"quit"
          if (($? == 0)); then
            ACCESS=TRUE
          fi
          TRYS=$((TRYS + 1))
          if ((TRYS == 3)); then
            echo_with_color red "\nExit.\n" >&5
            exit 1
          fi
        done
      fi

    fi
  fi

  # If the DreamFactory system database not already installed,
  # let's install it.
  if [[ $DB_INSTALLED == FALSE ]]; then

    # Test DB access
    mysql -h localhost -u root "-p$DB_PASS" -e"quit"
    if (($? >= 1)); then
      echo_with_color red "Connection to Database failed. Exit \n" >&5
      exit 1
    fi
    echo_with_color magenta "\n What would you like to name your system database? (e.g. dreamfactory) " >&5
    read -r DF_SYSTEM_DB
    if [[ -z $DF_SYSTEM_DB ]]; then
      until [[ -n $DF_SYSTEM_DB ]]; do
        echo_with_color red "\nThe name can't be empty!" >&5
        read -r DF_SYSTEM_DB
      done
    fi

    echo "CREATE DATABASE ${DF_SYSTEM_DB};" | mysql -u root "-p${DB_PASS}"
    if (($? >= 1)); then
      echo_with_color red "\nCreating database error. Exit" >&5
      exit 1
    fi
    echo_with_color magenta "\n Please create a MySQL DreamFactory system database user name (e.g. dfadmin): " >&5
    read -r DF_SYSTEM_DB_USER
    if [[ -z $DF_SYSTEM_DB_USER ]]; then
      until [[ -n $DF_SYSTEM_DB_USER ]]; do
        echo_with_color red "The name can't be empty!" >&5
        read -r DF_SYSTEM_DB_USER
      done
    fi

    echo_with_color magenta "\n Please create a secure MySQL DreamFactory system database user password: " >&5
    read -r DF_SYSTEM_DB_PASSWORD
    if [[ -z $DF_SYSTEM_DB_PASSWORD ]]; then
      until [[ -n $DF_SYSTEM_DB_PASSWORD ]]; do
        echo_with_color red "The name can't be empty!" >&5
        read -r DF_SYSTEM_DB_PASSWORD
      done
    fi
    # Generate password for user in DB
    echo "GRANT ALL PRIVILEGES ON ${DF_SYSTEM_DB}.* to \"${DF_SYSTEM_DB_USER}\"@\"localhost\" IDENTIFIED BY \"${DF_SYSTEM_DB_PASSWORD}\";" | mysql -u root "-p${DB_PASS}"
    if (($? >= 1)); then
      echo_with_color red "\nCreating new user error. Exit" >&5
      exit 1
    fi

    echo "FLUSH PRIVILEGES;" | mysql -u root "-p${DB_PASS}"

    echo -e "\nDatabase configuration finished.\n" >&5
  else
    echo_with_color green "Skipping...\n" >&5
  fi
else
  echo_with_color green "Step 6: Skipping DreamFactory system database installation.\n" >&5
  echo -e "Step 7: Skipping DreamFactory system database configuration.\n" >&5
fi

### Step 8. Install DreamFactory
echo_with_color green "Step 8: Installing DreamFactory...\n " >&5

ls -d /opt/dreamfactory
if (($? >= 1)); then
  mkdir -p /opt/dreamfactory
  if [[ -z "${DREAMFACTORY_VERSION_TAG}" ]]; then
    git clone -b master --single-branch https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory
  else
    git clone -b "${DREAMFACTORY_VERSION_TAG}" --single-branch https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory
  fi
  if (($? >= 1)); then
    echo_with_color red "\nCould not clone DreamFactory repository. Exiting. " >&5
    exit 1
  fi
  DF_CLEAN_INSTALLATION=TRUE
else
  echo_with_color red "DreamFactory detected.\n" >&5
  DF_CLEAN_INSTALLATION=FALSE
fi

if [[ $DF_CLEAN_INSTALLATION == FALSE ]]; then
  ls /opt/dreamfactory/composer.{json,lock,json-dist}
  if (($? == 0)); then
    echo_with_color red "Would you like to upgrade your instance? [Yy/Nn]" >&5
    read -r LICENSE_FILE_ANSWER
    if [[ -z $LICENSE_FILE_ANSWER ]]; then
      LICENSE_FILE_ANSWER=N
    fi
    LICENSE_FILE_EXIST=TRUE

  fi

fi

if [[ $LICENSE_FILE_EXIST == TRUE ]]; then
  if [[ $LICENSE_FILE_ANSWER =~ ^[Yy]$ ]]; then
    echo_with_color magenta "\nEnter absolute path to license files, complete with trailing slash: [./]" >&5
    read -r LICENSE_PATH
    if [[ -z $LICENSE_PATH ]]; then
      LICENSE_PATH="."
    fi
    ls $LICENSE_PATH/composer.{json,lock,json-dist}
    if (($? >= 1)); then
      echo_with_color red "\nLicenses not found. Skipping.\n" >&5
    else
      cp $LICENSE_PATH/composer.{json,lock,json-dist} /opt/dreamfactory/
      LICENSE_INSTALLED=TRUE
      echo_with_color green "\nLicenses file installed. \n" >&5
      echo_with_color green "Installing DreamFactory...\n" >&5
    fi
  else
    echo_with_color red "\nSkipping...\n" >&5
  fi
else
  echo_with_color magenta "Do you have a commercial DreamFactory license? [Yy/Nn] " >&5
  read -r LICENSE_FILE_ANSWER
  if [[ -z $LICENSE_FILE_ANSWER ]]; then
    LICENSE_FILE_ANSWER=N
  fi
  if [[ $LICENSE_FILE_ANSWER =~ ^[Yy]$ ]]; then
    echo_with_color magenta "\nEnter absolute path to license files, complete with trailing slash: [./]" >&5
    read -r LICENSE_PATH
    if [[ -z $LICENSE_PATH ]]; then
      LICENSE_PATH="."
    fi
    ls $LICENSE_PATH/composer.{json,lock,json-dist}
    if (($? >= 1)); then
      echo_with_color red "\nLicenses not found. Skipping.\n" >&5
      echo_with_color red "Installing DreamFactory OSS version...\n" >&5
    else
      cp $LICENSE_PATH/composer.{json,lock,json-dist} /opt/dreamfactory/
      LICENSE_INSTALLED=TRUE
      echo_with_color green "\nLicenses file installed. \n" >&5
      echo_with_color green "Installing DreamFactory...\n" >&5
    fi
  else
    echo_with_color red "\nInstalling DreamFactory OSS version.\n" >&5
  fi

fi

chown -R "$CURRENT_USER" /opt/dreamfactory && cd /opt/dreamfactory || exit 1

# If Oracle is not installed, add the --ignore-platform-reqs option
# to composer command
if [[ $ORACLE == TRUE ]]; then
  sudo -u "$CURRENT_USER" bash -c "/usr/local/bin/composer install --no-dev"
else
  sudo -u "$CURRENT_USER" bash -c "/usr/local/bin/composer install --no-dev --ignore-platform-reqs"
fi

### Shutdown silent mode because php artisan df:setup and df:env will get troubles with prompts.
exec 1>&5 5>&-

if [[ $DB_INSTALLED == FALSE ]]; then
  sudo -u "$CURRENT_USER" bash -c "php artisan df:env -q \
                --db_connection=mysql \
                --db_host=127.0.0.1 \
                --db_port=3306 \
                --db_database=${DF_SYSTEM_DB} \
                --db_username=${DF_SYSTEM_DB_USER} \
                --db_password=${DF_SYSTEM_DB_PASSWORD//\'/}"
  sed -i 's/\#DB\_CHARSET\=/DB\_CHARSET\=utf8/g' .env
  sed -i 's/\#DB\_COLLATION\=/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
  echo -e "\n"
  MYSQL_INSTALLED=TRUE

elif [[ ! $MYSQL == TRUE && $DF_CLEAN_INSTALLATION == TRUE ]] || [[ $DB_INSTALLED == TRUE ]]; then
  sudo -u "$CURRENT_USER" bash -c "php artisan df:env"
  if [[ $DB_INSTALLED == TRUE ]]; then
    sed -i 's/\#DB\_CHARSET\=/DB\_CHARSET\=utf8/g' .env
    sed -i 's/\#DB\_COLLATION\=/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
  fi
fi

if [[ $DF_CLEAN_INSTALLATION == TRUE ]]; then
  sudo -u "$CURRENT_USER" bash -c "php artisan df:setup"
fi

if [[ $LICENSE_INSTALLED == TRUE || $DF_CLEAN_INSTALLATION == FALSE ]]; then
  php artisan migrate --seed
  sudo -u "$CURRENT_USER" bash -c "php artisan config:clear -q"

  if [[ $LICENSE_INSTALLED == TRUE ]]; then
    grep DF_LICENSE_KEY .env >/dev/null 2>&1 # Check for existing key.
    if (($? == 0)); then
      echo_with_color red "\nThe license key already installed. Are you want to install a new key? [Yy/Nn]"
      read -r KEY_ANSWER
      if [[ -z $KEY_ANSWER ]]; then
        KEY_ANSWER=N
      fi
      NEW_KEY=TRUE
    fi
    if [[ $NEW_KEY == TRUE ]]; then
      if [[ $KEY_ANSWER =~ ^[Yy]$ ]]; then #Install new key
        CURRENT_KEY=$(grep DF_LICENSE_KEY .env)
        echo_with_color magenta "\nPlease provide your new license key:"
        read -r LICENSE_KEY
        size=${#LICENSE_KEY}
        if [[ -z $LICENSE_KEY ]]; then
          until [[ -n $LICENSE_KEY ]]; do
            echo_with_color red "\nThe field can't be empty!"
            read -r LICENSE_KEY
            size=${#LICENSE_KEY}
          done
        elif ((size != 32)); then
          until ((size == 32)); do
            echo_with_color red "\nInvalid License Key provided"
            echo_with_color magenta "\nPlease provide your license key:"
            read -r LICENSE_KEY
            size=${#LICENSE_KEY}
          done
        fi
        ###Change license key in .env file
        sed -i "s/$CURRENT_KEY/DF_LICENSE_KEY=$LICENSE_KEY/" .env
      else
        echo_with_color red "\nSkipping..." #Skip if key found in .env file and no need to update
      fi
    else
      echo_with_color magenta "\nPlease provide your license key:" #Install key if not found existing key.
      read -r LICENSE_KEY
      size=${#LICENSE_KEY}
      if [[ -z $LICENSE_KEY ]]; then
        until [[ -n $LICENSE_KEY ]]; do
          echo_with_color red "The field can't be empty!"
          read -r LICENSE_KEY
          size=${#LICENSE_KEY}
        done
      elif ((size != 32)); then
        until ((size == 32)); do
          echo_with_color red "\nInvalid License Key provided"
          echo_with_color magenta "\nPlease provide your license key:"
          read -r LICENSE_KEY
          size=${#LICENSE_KEY}
        done
      fi
      ###Add license key to .env file
      echo -e "\nDF_LICENSE_KEY=${LICENSE_KEY}" >>.env
    fi
  fi
fi

chmod -R 2775 /opt/dreamfactory/
chown -R "apache:$CURRENT_USER" /opt/dreamfactory/

### Uncomment nodejs in .env file
grep -E "^#DF_NODEJS_PATH" .env >/dev/null
if (($? == 0)); then
  sed -i "s,\#DF_NODEJS_PATH=/usr/local/bin/node,DF_NODEJS_PATH=$NODE_PATH," .env
fi

sudo -u "$CURRENT_USER" bash -c "php artisan cache:clear -q"

#Add rules if SELinux enabled
sestatus | grep SELinux | grep enabled >/dev/null
if (($? == 0)); then
  setsebool -P httpd_can_network_connect_db 1
  chcon -t httpd_sys_content_t storage -R
  chcon -t httpd_sys_content_t bootstrap/cache/ -R
  chcon -t httpd_sys_rw_content_t storage -R
  chcon -t httpd_sys_rw_content_t bootstrap/cache/ -R
fi

echo_with_color green "\nInstallation finished! "

if [[ $DEBUG == TRUE ]]; then
  echo_with_color red "\nThe log file saved in: /tmp/dreamfactory_installer.log "

fi
### Summary table
if [[ $MYSQL_INSTALLED == TRUE ]]; then
  echo -e "\n "
  echo_with_color magenta "******************************"
  echo -e " DB for system table: mysql "
  echo -e " DB host: 127.0.0.1         "
  echo -e " DB port: 3306              "
  if [[ ! $DB_FOUND == TRUE ]]; then
    echo -e " DB root password: $DB_PASS"
  fi
  echo -e " DB name: $DF_SYSTEM_DB"
  echo -e " DB user: $DF_SYSTEM_DB_USER"
  echo -e " DB password: $DF_SYSTEM_DB_PASSWORD"
  echo -e "******************************${NC}\n"
fi

exit 0
