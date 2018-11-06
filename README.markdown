# DreamFactory installation script for Debian 8/9

This is semi-automatic installation script for Debian 8 and Debian 9 OS. The script assumes a more or less blank server. If you have existing resources installed on the server the script will skip installation some parts or you will need to work around them. This instruction assumes that  DreamFactory will be the only/default web app on this server. If you have other sites (virtual hosts) you will need to adjust the configuration accordingly.

**!Version PHP 7.0 and 7.1 not supporting. The script will install PHP version 7.2.**

For example: 
* If your server has already installed Apache, Nginx or MySQL/MariaDB a script will show warning notification and skip installation/configuration.

The script has two versions:
* LAMP - Script will install the DreamFactory with LAMP (Apache + PHP7.2 + MariaDB) stack on board. 
* LEMP - Script will install the DreamFactory with LEMP (Nginx+ PHP7.2 + MariaDB) stack on board. 

## Getting Started

This instruction will get you a copy of the bash script and all steps to install DreamFactory on your system.

### Prerequisites

You need Bash in your system (it must be already in your Debian). Your license keys and Oracle drivers if you want to install it. If you do not have a license the sript will install open source version of DreamFactory. Also, you need root privileges(su).

For connecting to Oracle DB you need to use drivers from Oracle. You can download it from official page Oracle:
[Drivers](https://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html) Download the basic and sdk instant client files:
* instantclient-basic-linux.x64-18.3.0.0.0dbru.zip
* instantclient-sdk-linux.x64-18.3.0.0.0dbru.zip

**The script is using only the latest version of Oracle drivers (18.3.0)**

### Installing

Open folder where you save downloaded script via terminal. Add privileges to execute:

```
su -c "chmod +x DreamFactory_LEMP_Debian.sh"
```

Start a script with root privileges:

```
su -mc "bash  DreamFactory_LEMP_Debian.sh"
```

If you have license keys you can copy them to the same folder where you saved DreamFactory script or you can type in the path to the folder with the keys in installation progress. 

Follow the installation process. 
After finishing the installation process you can access to DreamFactory by typing your IP address or localhost in the browser. You should be directed to the login page of the admin application.

### Installing Oracle DB drivers 

If you planning to use DreamFactory with Oracle DB, you must add --oracle key to a script. Also, download and save drivers to the same folder where you saved DreamFactory script or you can type in the path to the folder with the drivers after --oracle key:
```
su -mc "bash  DreamFactory_LEMP_Debian.sh --oracle"
```

```
su -mc "bash  DreamFactory_LEMP_Debian.sh --oracle /home/employee/drivers"
```
If you already have the DreamFacroty and want to install Oracle DB drivers. You need to do the same. Just start a script with --oracle key. 

**!To use Oracle DB connection feature, you need to have the Silver or Gold subscription**

### Updating license

Simply start the script again and on "Do you have a subscription? [Yy/Nn]" answer "Y". And on next prompt enter path to the folder with keys. The script will copy keys and will do all migrations. At the end check your accessibility to new features in the browser. 

**!The default path to keys: the current folder where you start a script.**

## Troubleshooting

If you get an error at some stage of the installation, fix it and run the script again. The script shows the installation steps to understand at what stage you have a problem.
