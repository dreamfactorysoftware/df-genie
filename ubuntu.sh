#!/bin/bash

# Obtain username passed via command argument
CURRENT_USER=$1

DEFAULT_PHP_VERSION="php7.2"

# Obtain the PHP version. If PHP is not installed, identify
# it as undefined.
PHP_VERSION=$(php --version | head -n 1 | cut -d " " -f 2 | cut -c 1,3)

if [[ $PHP_VERSION =~ ^-?[0-9]+$ ]]; then
  PHP_VERSION="$(echo $PHP_VERSION | cut -c 1).$(echo $PHP_VERSION | cut -c 2)";
  PHP_VERSION="php${PHP_VERSION}";
else
  PHP_VERSION="undefined";
fi

# Install a few helper packages

apt install git curl zip unzip ca-certificates apt-transport-https composer
wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list

# Update the system
apt update
apt upgrade

# If PHP isn't installed, install it
if [ $PHP_VERSION == "undefined" ]; then
  apt install $DEFAULT_PHP_VERSION
else
  echo "PHP version ${PHP_VERSION} installed."
fi

# Retrieve location of php.ini file
PHP_INI_LOC=$(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;q}')

# Identify and install desired PHP modules
declare -a MODULES_POSTFIX=(
  "bcmath"
  "cli"
  "common"
  "curl"
  "dev"
  "json"
  "mbstring"
  "mcrypt"
  "mysqlnd"
  "soap", 
  "sqlite", 
  "sybase"
  "xml" 
  "zip", 
);

# Build version-specific module list
for module_postfix in "${MODULES_POSTFIX[@]}"; do 
  PHP_MODULES=("${PHP_MODULES[@]}" "php${PHP_VERSION}-${module_postfix}");
done

apt install ${PHP_MODULES[@]}

######
# Install ODBC
######

curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list
apt-get update --fix-missing
ACCEPT_EULA=Y apt-get install msodbcsql17
ACCEPT_EULA=Y apt-get install mssql-tools
sudo -u $CURRENT_USER echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
sudo -u $CURRENT_USER echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
sudo -u $CURRENT_USER source ~/.bashrc
apt install unixodbc-dev

######
# Install MS SQL Server
# On Debian 8 I actually had to remove the -n from pecl as described here, madness:
# https://serverfault.com/questions/589877/pecl-command-produces-long-list-of-errors
######

pecl install sqlsrv

echo "extension=sqlsrv.so" | sudo tee -a PHP_INI_LOC

pecl install pdo_sqlsrv
echo "extension=pdo_sqlsrv.so" | sudo tee -a PHP_INI_LOC

######
#
# SQLAnywhere
#
######




