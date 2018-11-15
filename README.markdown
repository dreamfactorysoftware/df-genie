# DreamFactory installation script for Ubuntu 16/18

This is semi-automatic installation script for Ubuntu 16.04 and 18.04 OS. The script assumes a more or less blank server. If you have existing resources installed on the server the script will skip installation some parts or you will need to work around them. This instruction assumes that  DreamFactory will be the only/default web app on this server. If you have other sites (virtual hosts) you will need to adjust the configuration accordingly.

For example: 
* If our server has already installed PHP version 7.1, the script will install all extensions for DreamFactory compatible with that version PHP.

**!Version PHP 7.0 not supporting. The script will install PHP version 7.2.**
* If your server has already installed Apache, Nginx or MySQL/MariaDB a script will show warning notification and skip installation/configuration.

By default, without any keys, a script will install DreamFactory with PHP extensions and Nginx web server **without any database server!**. 

As options, the script has next keys:

  ```--with-mysql```  The script will additionally install MariaDB and configure access DreamFactory to the installed database.
  
  ```--oracle```  The script will additionally install PHP extension to work with Oracle database.
  
  ```--apache```  The DreamFactory will be installed with Apache2 web server instead default Nginx web server.

## Getting Started

This instruction will get you a copy of the bash script and all steps to install DreamFactory on your system.

### Prerequisites

You need Bash in your system (it must be already in your Ubuntu). Your license keys and Oracle drivers if you want to install it. If you do not have a license the sript will install open source version of DreamFactory. Also, you need root privileges and installed sudo in the system (it must be already in your Ubuntu by default).
If you choose installation without ```--with-mysql``` key you need already installed database server and root access to it. DreamFactory can work with next databases:
* SQLite
* MySQL
* pgSQL
* SQL Server

For connecting to Oracle DB you need to use drivers from Oracle. You can download it from official page Oracle:
[Drivers](https://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html) Download the basic and sdk instant client files:
* instantclient-basic-linux.x64-18.3.0.0.0dbru.zip
* instantclient-sdk-linux.x64-18.3.0.0.0dbru.zip

**The script is using only the latest version of Oracle drivers (18.3.0)**

### Installing

Open folder where you save downloaded script via terminal. Add privileges to execute:

```
sudo chmod +x DreamFactory_Ubuntu.sh
```

Start a script with root privileges:

```
sudo bash DreamFactory_Ubuntu.sh
```

If you have license keys you can copy them to the same folder where you saved DreamFactory script or you can type in the path to the folder with the keys in installation progress. 

Follow the installation process. 
After finishing the installation process you can access to DreamFactory by typing your IP address or localhost in the browser. You should be directed to the login page of the admin application.

### Installing with MariaDB database server

Just add key: ```--with-mysql``` to the end of the script and that's all!. The script will do all automatically. In the installation progress, the script will show a password for the root user for the installed database server.

```
sudo bash DreamFactory_Ubuntu.sh --with-mysql
```

**! If you already have MariDB/MySQL server you need start script without ```--with-mysql``` key. But if you want more automatic installation, you can start the script with that key and script will prompt root user password for the already installed database. After you type in the password installation will continue and will stop only on the license key installation and new user creation.**

### Installing with Apache2 web server

Start the script with ```--apache``` key.

```
sudo bash DreamFactory_Ubuntu.sh --apache
```

### Installing Oracle DB drivers 

If you planning to use DreamFactory with Oracle DB, you must add ```--oracle key``` to a script. Also, download and save drivers to the same folder where you saved DreamFactory script or you can type in the path to the folder with the drivers in installation progress:

```
sudo bash DreamFactory_Ubuntu.sh --oracle
```

If you already have the DreamFacroty and want to install Oracle DB drivers. You need to do the same. Just start a script with ```--oracle``` key. 

**!The default path to drivers: the current folder where you start a script.**
**!To use Oracle DB connection feature, you need to have the Silver or Gold subscription**

### Updating license

Simply start the script again and on "Do you have a subscription? [Yy/Nn]" answer "Y". And on next prompt enter path to the folder with keys. The script will copy keys and will do all migrations. At the end check your accessibility to new features in the browser. 

**!The default path to keys: the current folder where you start a script.**

### Example

Start the script with all keys:

```
sudo bash DreamFactory_Ubuntu.sh --apache --oracle --with-mysql
```
Using **su** to start the script:

```
su -mc "bash DreamFactory_Ubuntu.sh"
```

## Troubleshooting

If you get an error at some stage of the installation, fix it and run the script again. The script shows the installation steps to understand at what stage you have a problem.
