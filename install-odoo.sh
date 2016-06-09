#!/bin/bash
################################################################################
# Script for Installation: ODOO server on Ubuntu 14.04 LTS
# Based on Script of A. Schenkels (https://github.com/aschenkels-ictstudio)
# Author: Mathias Neef
#-------------------------------------------------------------------------------
#  
# This script will install ODOO Server on
# clean Ubuntu 14.04 Server
# It brings all necsessary options include a init-script and a postgresql
# backup script. The master-password is randomly provided.
#-------------------------------------------------------------------------------
# USAGE:
#
# install-odoo.sh
#
# EXAMPLE:
# ./install-odoo.sh
#
################################################################################
 
##fixed parameters
OE_USER="odoo"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="/opt/$OE_USER/$OE_USER-server"
OE_PG_BACKUP="/backup/odoo/postgres"
OE_PG_BACKUP_DAYS="30"

#extra options for init-script
OE_INIT_EXTRA_OPTIONS=""
#OE_INIT_EXTRA_OPTIONS="--db-filter ^%d$"


#Enter version for checkout "9.0" for version 9.0, "8.0" for version 8.0, "7.0 (version 7) and "master" for trunk
OE_VERSION="9.0"

#set the superadmin password
GENPWD=$(cat /dev/urandom| tr -dc 'a-zA-Z0-9-_!@#$%^&*()_+{}|:<>?='| fold -w 16| head -n 1| grep -i '[!@#$%^&*()_+{}|:<>?=]')
OE_SUPERADMIN="$GENPWD"
OE_CONFIG="$OE_USER-server"


#--------------------------------------------------
# Update Server
#--------------------------------------------------

echo "\n==== Update Server and install dependencies ===="
echo "\n----  Update Server ----"
echo "* apt-get update"
sudo apt-get update

echo "* apt-get upgrade"
sudo apt-get upgrade -y


#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------

echo "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql -y


echo "* PostgreSQL $PG_VERSION Settings"
sudo sed -i s/"#listen_addresses = 'localhost'"/"listen_addresses = '*'"/g /etc/postgresql/9.3/main/postgresql.conf


echo "* Creating the ODOO PostgreSQL User"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true



#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------

echo "\n---- Install tool & python packages ----"
echo "* Install tools"
sudo apt-get install python-pip wget subversion git bzr bzrtools curl zip unzip npm fail2ban pgtune -y

echo "* Install more needed packages for Odoo"
sudo apt-get install libpq-dev libjpeg-dev python-imaging python-dev python-lxml libldap2-dev libsasl2-dev libxml2-dev libxslt1-dev libjpeg-turbo8 libxrender1 python-reportlab fontconfig libfontconfig1 -y

echo "* Install Python GEOip"
sudo git clone https://github.com/appliedsec/pygeoip.git
cd pygeoip
sudo python setup.py build
sudo python setup.py install
cd ..

echo "* Install pfber for barcode-printing"
sudo wget http://www.reportlab.com/ftp/pfbfer.zip
sudo unzip pfbfer.zip -d /usr/lib/python2.7/dist-packages/reportlab/fonts/

echo "* Install less-plugins"
sudo npm install -g less less-plugin-clean-css
sudo ln -s /usr/bin/nodejs /usr/bin/node

echo "* Install wkhtml and place on correct place for Odoo 8"
sudo wget http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo dpkg -i wkhtmltox-0.12.1_linux-trusty-amd64.deb
sudo cp /usr/local/bin/wkhtmltopdf /usr/bin
sudo cp /usr/local/bin/wkhtmltoimage /usr/bin

echo "\n---- Do Groundwork for Odoo-Server ----"
echo "* Create ODOO system user"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER

echo "* Create Log directory"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER


#--------------------------------------------------
# Install ODOO
#--------------------------------------------------

echo "\n==== Installing Odoo Server ===="
echo "\n---- Basic Work ----"
echo "* Clone Odoo source from Github"
sudo git clone --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/ 

echo "* Install Python requirements for Odoo"
sudo pip install -r $OE_HOME_EXT/requirements.txt
sudo pip install -I pillow
sudo easy_install pyPdf vatnumber pydot psycogreen suds ofxparse

echo "* Create custom module directory"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo "* Setting permissions on home folder"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo "\n---- Setup INIT and CONFIG files ----"


#--------------------------------------------------
# Adding ODOO's config-file
#--------------------------------------------------

echo "* Creating Odoo-Server config file"
echo '### Odoo Server Configuration File' >> ~/$OE_CONFIG.conf
echo '[options]' >> ~/$OE_CONFIG.conf
echo "addons_path=$OE_HOME_EXT/addons,$OE_HOME/custom/addons" >> ~/$OE_CONFIG.conf
echo "admin_passwd = $OE_SUPERADMIN" >> ~/$OE_CONFIG.conf
echo 'assert_exit_level = error' >> ~/$OE_CONFIG.conf
echo 'worker = 6' >> ~/$OE_CONFIG.conf
echo 'cache_timeout = 100000' >> ~/$OE_CONFIG.conf
echo 'csv_internal_sep = ;' >> ~/$OE_CONFIG.conf
echo 'dbfilter = .*' >> ~/$OE_CONFIG.conf
echo 'db_host = False' >> ~/$OE_CONFIG.conf
echo 'db_maxconn = 64' >> ~/$OE_CONFIG.conf
echo 'db_name = False' >> ~/$OE_CONFIG.conf
echo 'db_password = False' >> ~/$OE_CONFIG.conf
echo 'db_port = False' >> ~/$OE_CONFIG.conf
echo 'db_user = odoo' >> ~/$OE_CONFIG.conf
echo 'debug_mode = False' >> ~/$OE_CONFIG.conf
echo 'demo = {}' >> ~/$OE_CONFIG.conf
echo 'email_from = False' >> ~/$OE_CONFIG.conf
echo 'import_partial =' >> ~/$OE_CONFIG.conf
echo 'lang = de_DE' >> ~/$OE_CONFIG.conf
echo 'list_db = True' >> ~/$OE_CONFIG.conf
echo "logfile = /var/log/odoo/$OE_CONFIG.log" >> ~/$OE_CONFIG.conf
echo 'login_message = False' >> ~/$OE_CONFIG.conf
echo 'log_level = info' >> ~/$OE_CONFIG.conf
echo '; log_level is one of ['debug_rpc_answer', 'debug_rpc', 'debug', 'debug_sql', 'info', 'warn', 'error', 'critical']' >> ~/$OE_CONFIG.conf
echo 'logrotate = True' >> ~/$OE_CONFIG.conf
echo 'log_db = False' >> ~/$OE_CONFIG.conf
echo 'max_cron_threads = 4' >> ~/$OE_CONFIG.conf
echo 'osv_memory_age_limit = 1.0' >> ~/$OE_CONFIG.conf
echo 'osv_memory_count_limit = False' >> ~/$OE_CONFIG.conf
echo 'pg_path = None' >> ~/$OE_CONFIG.conf
echo 'pidfile = None' >> ~/$OE_CONFIG.conf
echo 'reportgz = False' >> ~/$OE_CONFIG.conf
echo 'secure_cert_file = server.cert' >> ~/$OE_CONFIG.conf
echo 'secure_pkey_file = server.pkey' >> ~/$OE_CONFIG.conf
echo 'server_wide_modules = None' >> ~/$OE_CONFIG.conf
echo 'smtp_password = False' >> ~/$OE_CONFIG.conf
echo 'smtp_port = 25' >> ~/$OE_CONFIG.conf
echo 'smtp_server = localhost' >> ~/$OE_CONFIG.conf
echo 'smtp_ssl = False' >> ~/$OE_CONFIG.conf
echo 'smtp_user = False' >> ~/$OE_CONFIG.conf
echo 'static_http_document_root = None' >> ~/$OE_CONFIG.conf
echo 'static_http_enable = False' >> ~/$OE_CONFIG.conf
echo 'static_http_url_prefix = None' >> ~/$OE_CONFIG.conf
echo 'syslog = False' >> ~/$OE_CONFIG.conf
echo 'test_commit = False' >> ~/$OE_CONFIG.conf
echo 'test_disable = False' >> ~/$OE_CONFIG.conf
echo 'test_file = False' >> ~/$OE_CONFIG.conf
echo 'test_report_directory = False' >> ~/$OE_CONFIG.conf
echo 'timezone = False' >> ~/$OE_CONFIG.conf
echo 'translate_modules = ['all']' >> ~/$OE_CONFIG.conf
echo 'unaccent = False' >> ~/$OE_CONFIG.conf
echo 'without_demo = False' >> ~/$OE_CONFIG.conf
echo 'netrpc_interface =' >> ~/$OE_CONFIG.conf
echo 'xmlrpc_interface =' >> ~/$OE_CONFIG.conf
echo 'xmlrpcs_interface =' >> ~/$OE_CONFIG.conf
echo 'netrpc_port = 8070' >> ~/$OE_CONFIG.conf
echo 'xmlrpc_port = 8069' >> ~/$OE_CONFIG.conf
echo 'xmlrpcs_port = 8071' >> ~/$OE_CONFIG.conf
echo 'netrpc = True' >> ~/$OE_CONFIG.conf
echo 'xmlrpcs = True' >> ~/$OE_CONFIG.conf
echo 'xmlrpc = True' >> ~/$OE_CONFIG.conf

echo "* Secure server config file"
sudo mv ~/$OE_CONFIG.conf /etc/$OE_CONFIG.conf
sudo chown $OE_USER:$OE_USER /etc/$OE_CONFIG.conf
sudo chmod 640 /etc/$OE_CONFIG.conf


#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo "* Creating Odoo-Server INIT-Script"
echo '#!/bin/bash' >> ~/$OE_CONFIG
echo '### BEGIN INIT INFO' >> ~/$OE_CONFIG
echo '# Provides: $OE_CONFIG' >> ~/$OE_CONFIG
echo '# Required-Start: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Required-Stop: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Should-Start: $network' >> ~/$OE_CONFIG
echo '# Should-Stop: $network' >> ~/$OE_CONFIG
echo '# Default-Start: 2 3 4 5' >> ~/$OE_CONFIG
echo '# Default-Stop: 0 1 6' >> ~/$OE_CONFIG
echo '# Short-Description: Enterprise Business Applications' >> ~/$OE_CONFIG
echo '# Description: ODOO Business Applications' >> ~/$OE_CONFIG
echo '### END INIT INFO' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '### Settings' >> ~/$OE_CONFIG
echo 'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin' >> ~/$OE_CONFIG
echo "DAEMON=$OE_HOME_EXT/odoo.py" >> ~/$OE_CONFIG
echo "NAME=$OE_CONFIG" >> ~/$OE_CONFIG
echo "DESC=$OE_CONFIG" >> ~/$OE_CONFIG
echo "USER=$OE_USER" >> ~/$OE_CONFIG
echo "OPTIONS=\"$OE_INIT_EXTRA_OPTIONS\"" >> ~/$OE_CONFIG
echo "CONFIGFILE=/etc/$OE_CONFIG.conf" >> ~/$OE_CONFIG
echo 'PIDFILE=/var/run/${NAME}.pid' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '### Extras' >> ~/$OE_CONFIG
echo 'export LOGNAME=$USER' >> ~/$OE_CONFIG
echo 'test -x $DAEMON || exit 0' >> ~/$OE_CONFIG
echo 'set -e' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '### Functions' >> ~/$OE_CONFIG
echo 'function _start() {' >> ~/$OE_CONFIG
echo '    start-stop-daemon --start --quiet --pidfile $PIDFILE --chuid $USER:$USER --background --make-pidfile --exec $DAEMON -- --config $CONFIGFILE $OPTIONS' >> ~/$OE_CONFIG
echo '}' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'function _stop() {' >> ~/$OE_CONFIG
echo '    start-stop-daemon --stop --quiet --pidfile $PIDFILE --oknodo --retry 3' >> ~/$OE_CONFIG
echo '    rm -f $PIDFILE' >> ~/$OE_CONFIG
echo '}' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'function _status() {' >> ~/$OE_CONFIG
echo '   start-stop-daemon --status --quiet --pidfile $PIDFILE' >> ~/$OE_CONFIG
echo '    return $?' >> ~/$OE_CONFIG
echo '}' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '### Cases' >> ~/$OE_CONFIG
echo 'case "$1" in' >> ~/$OE_CONFIG
echo '        start)' >> ~/$OE_CONFIG
echo '                echo -n "Starting $DESC: "' >> ~/$OE_CONFIG
echo '                _start' >> ~/$OE_CONFIG
echo '                echo "OK"' >> ~/$OE_CONFIG
echo '                ;;' >> ~/$OE_CONFIG
echo '        stop)' >> ~/$OE_CONFIG
echo '                echo -n "Stopping $DESC: "' >> ~/$OE_CONFIG
echo '                _stop' >> ~/$OE_CONFIG
echo '                echo "OK"' >> ~/$OE_CONFIG
echo '                ;;' >> ~/$OE_CONFIG
echo '        restart|force-reload)' >> ~/$OE_CONFIG
echo '                echo -n "Restarting $DESC: "' >> ~/$OE_CONFIG
echo '                _stop' >> ~/$OE_CONFIG
echo '                sleep 2' >> ~/$OE_CONFIG
echo '                _start' >> ~/$OE_CONFIG
echo '                echo "OK"' >> ~/$OE_CONFIG
echo '                ;;' >> ~/$OE_CONFIG
echo '        status)' >> ~/$OE_CONFIG
echo '                echo -n "Status of $DESC: "' >> ~/$OE_CONFIG
echo '                _status && echo "running" || echo "stopped"' >> ~/$OE_CONFIG
echo '                ;;' >> ~/$OE_CONFIG
echo '        *)' >> ~/$OE_CONFIG
echo '                echo "Usage: $0 {start|stop|restart|force-reload|status}"' >> ~/$OE_CONFIG
echo '                exit 1' >> ~/$OE_CONFIG
echo '                ;;' >> ~/$OE_CONFIG
echo 'esac' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'exit 0' >> ~/$OE_CONFIG

echo "* Secure Odoo's Init File"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo "* Setup to start Odoo on boot"
sudo update-rc.d $OE_CONFIG defaults


#--------------------------------------------------
# Adding Auto-Backup-Script for PostgreSQL
#--------------------------------------------------

echo "\n==== Setup auto-backup for PostgreSQL ===="
echo "* Create backup-dir"
sudo mkdir -p $OE_PG_BACKUP
sudo chown postgres:postgres $OE_PG_BACKUP

echo "* Create auto-backup-script"
echo '#!/bin/sh' >> ~/$OE_CONFIG-backup.sh
echo '#Location to place backups.' >> ~/$OE_CONFIG-backup.sh
echo "backupdir=$OE_PG_BACKUP/" >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo '#String to append to the name of the backup files' >> ~/$OE_CONFIG-backup.sh
echo 'backupdate=$(date +"%s")' >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo '#Numbers of days you want to keep copies of your databases' >> ~/$OE_CONFIG-backup.sh
echo "numberofdays=$OE_PG_BACKUP_DAYS" >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo '#Stop and start postgresql to disconnect' >> ~/$OE_CONFIG-backup.sh
echo 'service postgresql stop' >> ~/$OE_CONFIG-backup.sh
echo 'service postgresql start' >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo '#Do the database actions' >> ~/$OE_CONFIG-backup.sh
echo 'databases=$(su - postgres -c '\''psql -t -A -c "SELECT datname FROM pg_database"'\'')' >> ~/$OE_CONFIG-backup.sh
echo 'for i in $databases; do' >> ~/$OE_CONFIG-backup.sh
echo '    if [ "$i" != "template0" ] && [ "$i" != "template1" ] && [ "$i" != "postgres" ]; then' >> ~/$OE_CONFIG-backup.sh
echo '        su - postgres -c "vacuumdb --full --dbname ${i} --analyze --verbose"' >> ~/$OE_CONFIG-backup.sh
echo '        su - postgres -c "pg_dump -Fc -O -p 5432 ${i} > $backupdir${i}\_$backupdate\.dump"' >> ~/$OE_CONFIG-backup.sh
echo '    fi' >> ~/$OE_CONFIG-backup.sh
echo 'done' >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo '#Remove files which are older than $numberofdays' >> ~/$OE_CONFIG-backup.sh
echo 'find $backupdir -type f -prune -mtime +$numberofdays -exec rm -f {} \;' >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo "rsync -avz $backupdir $syncdir/posgres" >> ~/$OE_CONFIG-backup.sh
echo "rsync -avz $odoodir $syncdir/odoo-server" >> ~/$OE_CONFIG-backup.sh
echo '' >> ~/$OE_CONFIG-backup.sh
echo 'exit 0' >> ~/$OE_CONFIG-backup.sh

echo "* Move backup-script in place"
sudo mkdir $OE_HOME/custom/scripts
sudo mv ~/$OE_CONFIG-backup.sh $OE_HOME/custom/scripts
sudo chmod +x $OE_HOME/custom/scripts/$OE_CONFIG-backup.sh
sudo chown root: $OE_HOME/custom/scripts/$OE_CONFIG-backup.sh

echo "* Set crontab"
crontab -l > tempcron
echo "0 2 * * * $OE_HOME/custom/scripts/$OE_CONFIG-backup.sh" >> ~/tempcron
crontab tempcron
rm tempcron

echo "\n==== Important Password for Database Manager ===="
echo "* Please write carefully down this password. It is used to manage your Odoo-Databases."
echo "------------------------------"
echo "$OE_SUPERADMIN"
echo "------------------------------"

echo "\n==== Start Odoo-Server with INIT-Script ===="
sudo service $OE_CONFIG start
echo "Done! The ODOO server can be started with: service $OE_CONFIG start."
echo "The service is also automaticcaly started on every system reboot or startup."