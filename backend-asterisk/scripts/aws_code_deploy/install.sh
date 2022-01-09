#!/bin/bash
# v.1.2 Installer for mass warning/notification system - MaWaSys
#exit on error
set -e

WORK_DIR=/usr/local/utils/covid
#from env: WWW_DIR=/var/www/html
cd ${WORK_DIR} &&

# check if we need to install or update
if [[ -s config_campaign_generator.php ]]; then
  echo "running updates only"
  scripts/update.sh
  exit 0
fi

IVR_DIR=/var/lib/asterisk/sounds/covid2019

#all parameters below are from env, which is set by parameters in cloudformation-template via user-data on ec2
#
#                "DB_NAME")
#                        DBNAME=${VALUE}
#                        ;;
#                "DBUSER")
#                        DBUSER=${VALUE}
#                        ;;
#                "DBPASS")
#                        DBPASS=${VALUE}
#                        ;;
#                "DBHOST")
#                        DBHOST=${VALUE}
#                        ;;
#                "DOMAIN_NAME")
#                        SITE_URL=${VALUE}
#                        ;;
#                "PHONE_NUMBER")
#                        PHONE_NUMBER=${VALUE}
#                        ;;
#                "IP_ADDRESS")
#                        IP_ADDRESS=${VALUE}
#                        ;;
#                "SITE_URL")


#read -p "Database admin user: " DBUSER
#read -p "Database admin pass: " DBPASS
#read -p "Database host: " DBHOST
#read -p "Database name: " DBNAME
#read -p "Phone number: " PHONE_NUMBER
#read -p "Site url (supersite.domain.com): " SITE_URL

if [[ -z ${DBNAME} || -z ${SITE_URL} || -z ${PHONE_NUMBER} ]]; then
  echo "Empty DBNAME or SITE_URL or PHONE_NUMBER or IP_ADDRESS"
  exit 1
fi

mkdir log &&
  mkdir tmp &&
  echo "creating mysql database and user..."
echo "CREATE DATABASE ${DBNAME};" | mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASS}
if [[ $? == 1 ]]; then
  echo "database ${DBNAME} already exists"
  exit 1
fi
MYIP=$(ip a | grep "scope global dynamic eth0" | awk '{print $2}' | awk -F '/' '{print $1}')
NEWDBUSER=$(ip a | grep "scope global dynamic eth0" | awk '{print $2}' | awk -F '/' '{print $1}')"user" &&
  NEWDBPASS=$(openssl rand -base64 19 | tr -dc "[:alnum:]") &&
  #echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, REFERENCES, INDEX, ALTER, SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON ${DBNAME}.* TO '${NEWDBUSER}'@'${MYIP}' IDENTIFIED BY '${NEWDBPASS}';" | mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASS}
  echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON ${DBNAME}.* TO '${NEWDBUSER}'@'${MYIP}' IDENTIFIED BY '${NEWDBPASS}';" | mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASS} &&
  echo "FLUSH PRIVILEGES;" | mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASS} &&
  echo "Creating DB structure..."
#removing mysqldump statement which conflicts with RDS rules. DEFINER xxot@localhost or root@localhost do not exist on RDS
echo "Update DEFINER=xxot database.sql..."
sed -i -e 's/DEFINER=`xxot`@`localhost`//g' database.sql &&
  echo "Update DEFINER=root database.sql..."
sed -i -e 's/DEFINER=`root`@`localhost`//g' database.sql &&
  echo "Update AUTO_INCREMENT database.sql..."
sed -i -e 's/ AUTO_INCREMENT=[0-9]*//g' database.sql &&
  cat database.sql | mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASS} ${DBNAME} &&
  echo "INSERT INTO campaigns (name, description) VALUES ('Main','Main Campaign');" | mysql -h ${DBHOST} -u ${NEWDBUSER} -p${NEWDBPASS} ${DBNAME} &&
  echo "INSERT INTO version (instance_type, version) VALUES ('database','7');" | mysql -h ${DBHOST} -u ${NEWDBUSER} -p${NEWDBPASS} ${DBNAME} &&
  echo "INSERT INTO options (name, value) values ('amount_of_simultaneous_calls', '2';" | mysql -h ${DBHOST} -u ${NEWDBUSER} -p${NEWDBPASS} ${DBNAME} &&
  echo 'INSERT INTO users VALUES (1,'"'"'Admin'"','"'admin@email.net'"',NULL,'"'$2y$10$5QUSkWU5QIUcUXdJAMHuG.iuyeMarnUg3u1qXP4Zun5a3T/tf0TgC'"'"',NULL,NOW(),NOW());' | mysql -h ${DBHOST} -u ${NEWDBUSER} -p${NEWDBPASS} ${DBNAME} &&
  echo "Updating backend config..."
echo "Update template_db_host backend/config_template.yml..."
sed -i -e "s/template_db_host/${DBHOST}/" backend/config_template.yml &&
  echo "Update template_db_name backend/config_template.yml..."
sed -i -e "s/template_db_name/${DBNAME}/" backend/config_template.yml &&
  echo "Update template_db_user backend/config_template.yml..."
sed -i -e "s/template_db_user/${NEWDBUSER}/" backend/config_template.yml &&
  echo "Update template_db_pass backend/config_template.yml..."
sed -i -e "s/template_db_pass/${NEWDBPASS}/" backend/config_template.yml &&
  mv backend/config_template.yml backend/config.yml &&
  echo "Update template_number asterisk/extensions_covid2019_ivr.conf..."
sed -i -e "s/template_number/${PHONE_NUMBER}/" asterisk/extensions_covid2019_ivr_template.conf
mv asterisk/extensions_covid2019_ivr_template.conf asterisk/extensions_covid2019_ivr.conf

echo "Update template_db_host config_campaign_generator_template.php..."
sed -i -e "s/template_db_host/${DBHOST}/" config_campaign_generator_template.php &&
  echo "Update template_db_name config_campaign_generator_template.php..."
sed -i -e "s/template_db_name/${DBNAME}/" config_campaign_generator_template.php &&
  echo "Update template_db_user config_campaign_generator_template.php..."
sed -i -e "s/template_db_user/${NEWDBUSER}/" config_campaign_generator_template.php &&
  echo "Update template_db_pass config_campaign_generator_template.php..."
sed -i -e "s/template_db_pass/${NEWDBPASS}/" config_campaign_generator_template.php &&
  mv config_campaign_generator_template.php config_campaign_generator.php &&
  echo "Moving asterisk files in place..."
#unalias cp
cp asterisk/extensions_covid2019.conf /etc/asterisk/
cp asterisk/extensions_covid2019_ivr.conf /etc/asterisk/
cp asterisk/sip_covid2019.conf /etc/asterisk/
if [[ ! -d ${IVR_DIR} ]]; then
  mkdir ${IVR_DIR}
fi
cp -prf covid_sounds/* ${IVR_DIR}/

#check if we need to update asterisk config
SIPCONF_INCLUDE_US=$(cat /etc/asterisk/sip.conf | grep "sip_covid2019" | wc -l)
if [[ ${SIPCONF_INCLUDE_US} == 0 ]]; then
  echo "#include sip_covid2019.conf" >>/etc/asterisk/sip.conf
fi
EXTENSIONS_INCLUDE_US=$(cat /etc/asterisk/extensions.conf | grep "extensions_covid2019" | wc -l)
if [[ ${EXTENSIONS_INCLUDE_US} == 0 ]]; then
  echo "#include extensions_covid2019.conf" >>/etc/asterisk/extensions.conf
fi

/sbin/asterisk -rx "sip reload"
/sbin/asterisk -rx "dialplan reload"

echo "Setup service to run backend..."
cp backend_dialer.service /etc/systemd/system/
systemctl enable backend_dialer
systemctl start backend_dialer

echo "Download frontend..."
cp -prf frontend ${WWW_DIR}/covid2019-auto-dialer-front &&
cd ${WWW_DIR}/ &&
  cd covid2019-auto-dialer-front/
  composer update
npm install npm run dev

echo "Updating owner for frontend (takes time)..."
chown apache:apache /var/www/html/ -R &&
  echo "Updating frontend config..."
cd ${WORK_DIR}/ &&
  echo "Update template_db_host env_template4frontend..."
sed -i -e "s/template_db_host/${DBHOST}/" env_template4frontend &&
  echo "Update template_db_name env_template4frontend..."
sed -i -e "s/template_db_name/${DBNAME}/" env_template4frontend &&
  echo "Update template_db_user env_template4frontend..."
sed -i -e "s/template_db_user/${NEWDBUSER}/" env_template4frontend &&
  echo "Update template_db_pass env_template4frontend..."
sed -i -e "s/template_db_pass/${NEWDBPASS}/" env_template4frontend &&
  echo "Update template_app_url env_template4frontend..."
sed -i -e "s,template_app_url,http://${SITE_URL}," env_template4frontend &&
  NICELY_FORMATTED_PHONE_NUMBER=$(echo "${PHONE_NUMBER:0:3}-${PHONE_NUMBER:3:3}-${PHONE_NUMBER:6:4}") &&
  echo "Update template_phone_number_ivr_update env_template4frontend..."
sed -i -e "s/template_phone_number_ivr_update/${NICELY_FORMATTED_PHONE_NUMBER}/" env_template4frontend &&
  mv env_template4frontend ${WWW_DIR}/covid2019-auto-dialer-front/.env

echo "Updating crontab if necessary"
INCRON=$(cat /var/spool/cron/root | grep cron_campaign_checker | wc -l)
if [[ ${INCRON} == 0 ]]; then
  echo "* * * * * /usr/local/utils/covid/cron_campaign_checker.sh" >>/var/spool/cron/root
  systemctl restart crond
fi
systemctl start httpd

echo "-----------------------------------------"
echo "-----------------Complete----------------"
echo "-----------------------------------------"
echo "Run 
${WWW_DIR}/covid2019-auto-dialer-front/enable_registration.sh on
and register new user. Do not forget to turn registration off after you create all users"

echo "mysql -h ${DBHOST} -u ${NEWDBUSER} -p${NEWDBPASS} ${DBNAME}"