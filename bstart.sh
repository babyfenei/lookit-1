#!/bin/sh

CACTI_VER=latest

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

export TERM=xterm
#Export default DB Password
DB_USER=cactiuser
DB_PASS=cactiuser
DB_ADDRESS=localhost
TIMEZONE=Asia/Shanghai
#Cacti installation directory
path=/var/www/html
dir_path=$(pwd)
mkdir -p $dir_path/container-files/packages/{rrdtool,cacti,spine}
#Please enter the characters you want to modify, which can be chinese. After the input (input enter special characters please add in front of two escape character \\)
rrdlogo="AMSINPUL Data\\/陕西西普数据通信股份有限公司"
echo -e "\033[35m The RRDTOOL watermark you want to modify is:$rrdlogo \033[0m"
echo -e "\033[35m Your Cacti installation path is:$path \033[0m"
# Bash Colors
green=`tput setaf 2`
bold=`tput bold`
reset=`tput sgr0`


log() {
        if [[ "$@" ]]; then 
                echo "${bold}${green}[LOG `date +'%T'`]${reset} $@";
        else 
                echo; fi
        }


install_dependency_packs() {
        log "Install dependency packs"
       		mkdir -p $path/logs/
        	\cp -rf container-files/* /
		curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos7_base.repo
		yum install -y epel-release
		rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
		yum clean all
        	yum makecache
		yum localinstall -y /packages/mysql/*
		yum localinstall -y /packages/goffice/*
		yum install -y  --enablerepo=remi-php56 php php-redis php-snmp php-opcache php-devel php-mbstring php-mcrypt php-mysqlnd php-phpunit-PHPUnit php-pecl-xdebug php-pecl-xhprof  php-gmp php-gd php-ldap
		#yum install -y php php-redis php-snmp php-opcache php-devel php-mbstring php-mcrypt php-mysqlnd php-phpunit-PHPUnit php-pecl-xdebug php-pecl-xhprof  php-gmp php-gd php-ldap
		#yum install -y mysql-community-server mysql-community-client  mysql-devel
		yum install -y automake perl-devel   wget gzip help2man libtool make net-snmp-devel m4 openssl-devel dos2unix redis \
        	dejavu-fonts-common dejavu-lgc-sans-mono-fonts dejavu-sans-mono-fonts   \
        	net-snmp net-snmp-utils  gcc pango-devel libxml2-devel net-snmp-devel cronie \
        	sendmail  httpd  rsyslog-mysql vim ntpdate perl-devel
        	rpm --rebuilddb && yum clean all
        }
install_rrdtool() {
        log "### Install rrdtool###"
    		mkdir -p /rrdtool/ && rm -rf /rrdtool/*
  	  	rm -rf /packages/rrdtool/* &&  wget -O /packages/rrdtool/rrdtool.tar.gz  http://oss.oetiker.ch/rrdtool/pub/rrdtool-1.7.0.tar.gz 
    		tar zxvf /packages/rrdtool/rrdtool*.tar.gz -C /rrdtool --strip-components=1
    		cd /rrdtool/
        	sed -i "s/RRDTOOL \/ TOBI OETIKER/$rrdlogo/g" src/rrd_graph.c
        	#Modify watermark transparency
        	sed -i 's/water_color.alpha = 0.3;/water_color.alpha = 0.5;/g' src/rrd_graph.c
        	./configure --prefix=/usr/local/rrdtool && make && make install
    		rm -rf /bin/rrdtool
    		ln -s /usr/local/rrdtool/bin/rrdtool /bin/rrdtool
    		rm -rf /packages/rrdtool/rrdtool*.tar.gz && rm -rf /rrdtool
        }

install_cacti() {
        log "### ### Install cacti"
        	rm -rf /packages/cacti/* && wget -O /packages/cacti/cacti.tar.gz   http://www.cacti.net/downloads/cacti-$CACTI_VER.tar.gz 
        	mkdir -p /cacti/ && rm -rf /cacti/*
        	tar zxvf /packages/cacti/cacti*.tar.gz -C /cacti --strip-components=1
    		rm -rf /packages/cacti/cacti*.tar.gz
        }



install_spine() {
        log "### ### Install spine"
    		rm -rf /packages/spine/* && wget -O /packages/spine/cacti-spine.tar.gz http://www.cacti.net/downloads/spine/cacti-spine-$CACTI_VER.tar.gz
    		mkdir -p /spine && rm -rf /spine/*
    		tar xf /packages/spine/cacti-spine*.gz -C /spine --strip-components=1
    		rm -f /packages/spine/cacti-spine*.tar.gz
    		cd /spine/ && ./bootstrap && ./configure && make && make install
    		rm -rf /usr/bin/spine
    		ln -s /usr/local/spine/bin/spine /usr/bin/spine
    		\cp -rf /usr/local/spine/etc/spine.conf.dist /etc/spine.conf
    		rm -rf /spine
    		yum clean all
        }



move_cacti() {
    if [ -e "/cacti" ]; then
                log "Moving Cacti into Web Directory"
                rm -rf $path/*
                \cp -rf  /cacti/* $path/
                mkdir -p $path/{log,cache}
                touch $path/log/cacti.log
                chown -R apache:apache $path
                # If you need to open the URL directly, cacti does not need to add the suffix pattern of http://url/cacti You need cancels the downlink annotation to make it run
                # sed -i "s/$url_path = '\/cacti\/';/$url_path = '\/';/g" $path/include/config.php 
                sed -i "s/'--maxrows=10000' . RRD_NL;/'--maxrows=1000000000' . RRD_NL;/" $path/lib/rrd.php
                sed -i "s/\$gprint_prefix = '|host_hostname|';/\$gprint_prefix = '|query_ifName|';/" $path/graphs.php
                sed -i "s/'default' => AGGREGATE_TOTAL_NONE/'default' => AGGREGATE_TOTAL_ALL/g" $path/include/global_form.php
                #Modify the graph_xport.php file encoding so that the exported files support Chinese
                vi +':w ++ff=unix' +':q' $path/graph_xport.php
                { echo ':set encoding=utf-8';echo ':set bomb';echo ':wq';} | vi $path/graph_xport.php;
                log "Cacti moved"
    fi
        }
move_config_files() {
    if [ -e "/config.php" ]; then
                log "Moving Config files"
                #\cp -rf  /config.php $path/include/config.php
                #\cp -rf /global.php $path/include/global.php
                chown -R apache:apache $path
                log "Config files moved"
    fi
        }
                
                
install_plugins() {
        log "install cacti plugins"
        mkdir -p $dir_path/container-files/plugins/
        cd $dir_path/container-files/plugins/
        #git clone https://github.com/Cacti/plugin_syslog.git
		\cp -rf /plugins/* $path/plugins/
		chown -R apache.apache $path/plugins/
        log "The Cacti plug-in installation is complete"
        }


download_install_plugins() {
        log "install cacti plugins"
        mkdir -p $dir_path/container-files/plugins/
        cd $dir_path/container-files/plugins/
        #git clone https://github.com/Cacti/plugin_syslog.git
        if [ ! -d "monitor" ]; then
        	git clone https://github.com/Cacti/plugin_monitor.git
                mv plugin_monitor monitor
        fi
        if [ ! -d "audit" ]; then
                git clone https://github.com/Cacti/plugin_audit.git
                mv plugin_audit audit
        fi
        if [ ! -d "thold" ]; then
                git clone https://github.com/Cacti/plugin_thold.git
                mv plugin_thold thold
        fi
        if [ ! -d "maint" ]; then
                git clone https://github.com/Cacti/plugin_maint.git
                mv plugin_maint maint
        fi
        if [ ! -d "routerconfigs" ]; then
                git clone https://github.com/Cacti/plugin_routerconfigs.git
                mv plugin_routerconfigs routerconfigs
        fi
        if [ ! -d "mactrack" ]; then
                git clone https://github.com/Cacti/plugin_mactrack.git
                mv plugin_mactrack mactrack
        fi
        if [ ! -d "hmib" ]; then
                git clone https://github.com/Cacti/plugin_hmib.git
        	mv plugin_hmib hmib
	fi
        if [ ! -d "mikrotik" ]; then
                git clone https://github.com/Cacti/plugin_mikrotik.git
                mv plugin_mikrotik mikrotik
        fi
        if [ ! -d "webseer" ]; then
                git clone https://github.com/Cacti/plugin_webseer.git
                mv plugin_webseer webseer
        fi
        if [ ! -d "flowview" ]; then
                git clone https://github.com/Cacti/plugin_flowview.git
                mv plugin_flowview flowview
        fi
        if [ ! -d "cycle" ]; then
                git clone https://github.com/Cacti/plugin_cycle.git
                mv plugin_cycle cycle
        fi
        if [ ! -d "rrdproxy" ]; then
                git clone https://github.com/Cacti/rrdproxy.git
        fi
        if [ ! -d "syslog" ]; then
                git clone https://github.com/Cacti/plugin_syslog.git
                mv plugin_syslog syslog
        fi 
        if [ ! -d "reportit" ]; then
                git clone https://github.com/Cacti/plugin_reportit.git
                mv plugin_reportit reportit
        fi
	#for i in plugin_*; do mv $i ${i#plugin_}; done > /dev/null 2>&1
        \cp -rf   * $path/plugins/
        log "The Cacti plug-in installation is complete"
        }

                
                
create_db(){
    log "Creating Cacti Database"
	systemctl enable mariadb
	systemctl enable mysqld
    	systemctl restart mariadb
    	systemctl restart mysqld
        mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql
    	mysql  -e "set collation_server = utf8mb4_unicode_ci;"
   	mysql  -e "set character_set_client = utf8mb4;"
  	mysql  -e "CREATE DATABASE  IF NOT EXISTS cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
	mysql  -e "grant all on cacti.* to '$DB_USER'@'localhost' identified by '$DB_PASS'"
	mysql  -e "grant select on mysql.time_zone_name to '$DB_USER'@'localhost' identified by '$DB_PASS'"
	mysql  -e "ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  	  mysql  -e "flush privileges;"
    log "Database created successfully"
        }
import_db() {
    log "Importing Database..."
    	mysql  cacti  < $path/cacti.sql
    log "Database Imported successfully"
       	 }
cacti_db_update() {
    log "Update databse with cacti config details"
    	mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('font_method', '0');"
    	mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('max_title_data_source', '150');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('poller_type', '2');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('plugin_watermark_text', '$rrdlogo');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('num_rows_device', '100');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('num_rows_data_query', '100');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('num_rows_data_source', '100');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('num_rows_graph', '250');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('max_title_graph ', '100');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('max_data_query_field_length', '100');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('extended_paths', 'on');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('boost_png_cache_enable', 'on');"
        mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('automation_graphs_enabled', 'on');"
	mysql  -e "INSERT INTO cacti.settings (name, value) VALUES ('realtime_cache_path', '/var/www/html/cache/');"
    log "Cacti Database updated"
        }
spine_db_update() {
    log "Update databse with spine config details"
    mysql  -e "REPLACE INTO cacti.settings SET name='path_spine', value='/usr/bin/spine';"
    log "Database updated"
        }
update_cacti_db_config() {
    log "Updating default Cacti config file"
    sed -i 's/$DB_ADDRESS/'$DB_ADDRESS'/g' $path/include/config.php
    sed -i 's/$DB_USER/'$DB_USER'/g' $path/include/config.php
    sed -i 's/$DB_PASS/'$DB_PASS'/g' $path/include/config.php
    log "Config file updated with Database credentials"
        }
update_cacti_global_config() {
    log "Updating default Cacti global config file"
    sed -i 's/$DB_ADDRESS/'$DB_ADDRESS'/g' $path/include/global.php
    sed -i 's/$DB_USER/'$DB_USER'/g' $path/include/global.php
    sed -i 's/$DB_PASS/'$DB_PASS'/g' $path/include/global.php
    log "Config file updated with global Database credentials"
        }
update_spine_config() {
    log "Updating Spine config file"
    if [ -e "/spine.conf" ]; then
                \cp -rf /spine.conf /usr/local/spine/etc/spine.conf
                sed -i 's/$DB_ADDRESS/'$DB_ADDRESS'/g' /usr/local/spine/etc/spine.conf
                sed -i 's/$DB_USER/'$DB_USER'/g' /usr/local/spine/etc/spine.conf
                sed -i 's/$DB_PASS/'$DB_PASS'/g' /usr/local/spine/etc/spine.conf
                log "Spine config updated"
    fi
    }

update_backup_config() {
    log "Updating backup config file"
    if [ -e "/bash/backup.sh" ]; then
                sed -i 's/$DB_ADDRESS/'$DB_ADDRESS'/g' /bash/backup.sh
                sed -i 's/$DB_USER/'$DB_USER'/g' /bash/backup.sh
                sed -i 's/$DB_PASS/'$DB_PASS'/g' /bash/backup.sh
                sed -i 's#$path#'$path'#g' /bash/backup.sh
                chmod +x /bash/backup.sh
                log "backup config updated"
    fi
    }

update_export_config() {
    log "Updating export config file"
    if [ -e "/bash/export.sh" ]; then
                sed -i 's/$DB_ADDRESS/'$DB_ADDRESS'/g' /bash/export.sh
                sed -i 's/$DB_USER/'$DB_USER'/g' /bash/export.sh
                sed -i 's/$DB_PASS/'$DB_PASS'/g' /bash/export.sh
                chmod +x /bash/export.sh
                log "export config updated"
    fi
    }

load_temple_config(){
        log "$(date +%F_%R) [New Install] Installing supporting template files."
        #cp -r /templates/resource $path
        #cp -r /templates/scripts $path
        # install additional templates
        for filename in /templates/*.xml; do
           echo "$(date +%F_%R) [New Install] Installing template file $filename"
           php -q $path/cli/import_template.php --filename=$filename  > /dev/null
        done
        rm -rf  /templates/
        }




install_syslog() {
        # Create a new syslog database and grant permissions
        mysql -e 'create database `syslog` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;'
        mysql -e "GRANT ALL ON syslog.* TO 'cactiuser'@localhost IDENTIFIED BY 'cactiuser';"
        mysql -e 'flush privileges;'
        # Change the syslog configuration using a separate database
        \cp -rf   $path/plugins/syslog/config.php.dist $path/plugins/syslog/config.php
        sed -i 's/$use_cacti_db = true;/$use_cacti_db = false;/' $path/plugins/syslog/config.php
        # Modify the rsyslog section parameters before enabling syslog
        echo '*.* @@localhost:514' >> /etc/rsyslog.conf
        echo '$ModLoad imudp' >> /etc/rsyslog.conf
        echo '$ModLoad imklog' >> /etc/rsyslog.conf
        echo '$ModLoad immark' >> /etc/rsyslog.conf
        echo '$ModLoad imtcp' >> /etc/rsyslog.conf
        echo '$UDPServerRun 514' >> /etc/rsyslog.conf
        echo '$ModLoad ommysql' >> /etc/rsyslog.conf
        echo "\$template cacti_syslog,\"INSERT INTO syslog_incoming(facility_id, priority_id, program, date, time, host, message) \\ " >> /etc/rsyslog.conf
        echo "values (%syslogfacility%, %syslogpriority%, '%programname%', '%timereported:::date-mysql%', '%timereported:::date-mysql%', '%HOSTNAME%', TRIM('%msg%'))\" , SQL" >> /etc/rsyslog.conf
        echo '*.*   >localhost,syslog,cactiuser,cactiuser;cacti_syslog' >> /etc/rsyslog.conf
        chkconfig rsyslog on
        systemctl enable rsyslog
        systemctl restart rsyslog
	}

change_auth_config() {
        log "change export auth file"
        sed -i "s/auth.php/global.php/" $path/graph_xport.php
        sed -i "s/auth.php/global.php/" $path/graph_image.php
	sed -i "s/\/usr\/local\/bin\/rrdtool/\/usr\/bin\/rrdtool/" $path/install/index.php
	# chinese language support
	# sed -i "2 s/^/setlocale(LC_CTYPE,\"UTF8\",\"en_US.UTF-8\");\n/"  /var/www/html/lib/functions.php
        log "export auth file changed"
        }
update_cron() {
    log "Updating Cron jobs"
    # Add Cron jobs
    	sed -i 's#$path#'$path'#' /etc/cron.d/cacti
	chmod 644 /etc/cron.d/cacti
    log "Crontab updated."
        }
set_timezone() {
    	if [[ $(grep "date.timezone = ${TIMEZONE}" /etc/php.ini) != "date.timezone = ${TIMEZONE}" ]]; then
                log "Updating TIMEZONE"
                echo "date.timezone = ${TIMEZONE}" >> /etc/php.ini
                log "TIMEZONE set to: ${TIMEZONE}"
    	fi
    	rm -rf /etc/localtime
    	ln -s  /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        sed -i 's/LANG="en_US.UTF-8"/LANG="zh_CN.UTF-8"/' /etc/sysconfig/i18n
	source /etc/sysconfig/i18n
	}
update_httpd() {
    log "Updating httpd config"
    sed -i 's#$path#'$path'#' /etc/httpd/conf.d/cacti.conf
        
    log "httpd config updated."
        }

# ## Magic Starts Here

install_dependency_packs
set_timezone
install_rrdtool
install_cacti
install_spine
move_cacti
move_config_files
install_plugins
download_install_plugins
# Check Database Status and update if needed
if [[ $(mysql -e "show databases" | grep cacti) != "cacti" ]]; then
    create_db
    import_db
    cacti_db_update
    spine_db_update
    change_auth_config
fi
# Update Cacti config
#update_cacti_db_config
#update_cacti_global_config
#update_spine_config
update_backup_config
update_export_config
install_syslog
#load_temple_config
update_cron
update_httpd

systemctl enable httpd
systemctl enable crond
systemctl enable snmpd
systemctl enable redis
systemctl restart mysqld
systemctl restart httpd
systemctl restart crond
systemctl restart snmpd
systemctl restart redis
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload
setenforce 0
/usr/bin/php /var/www/html/poller.php --force
log "Cacti Server UP."
