#!/bin/bash

RUNCAMPAIGNFILE=/var/www/html/covid2019-auto-dialer-front/public/runcampaign

cd /usr/local/utils/covid/ &&
if [[ -f ${RUNCAMPAIGNFILE} && ! -f /usr/local/utils/covid/tmp/campaign_in_progress ]];then
	CAMPAIGN_NUMBER=`cat ${RUNCAMPAIGNFILE} | awk -F"," '{print$1}'`
	CAMPAIGN_EMAIL=`cat ${RUNCAMPAIGNFILE} | awk -F"," '{print$2}'`
	CAMPAIGN_LOG_FOLDER=campaign_${CAMPAIGN_NUMBER}_`date +%Y-%m-%d-%H-%M-%S`
	echo "Starting campaign ${CAMPAIGN_NUMBER}. Email: ${CAMPAIGN_EMAIL}"
	touch /usr/local/utils/covid/tmp/campaign_in_progress
	mkdir log/${CAMPAIGN_LOG_FOLDER} &&
	/usr/local/utils/covid/covidcampaigngenerator.php ${CAMPAIGN_NUMBER} ${CAMPAIGN_LOG_FOLDER} > log/${CAMPAIGN_LOG_FOLDER}/campaign_${CAMPAIGN_NUMBER}_`date +%Y-%m-%d-%H-%M-%S`.log &&
	rm -rf /usr/local/utils/covid/tmp/campaign_in_progress
	rm -rf /var/www/html/covid2019-auto-dialer-front/public/runcampaign
	# backup outgoing_done records
	cd /var/spool/asterisk/outgoing_done/ &&
	tar -czf /usr/local/utils/covid/log/${CAMPAIGN_LOG_FOLDER}/outgoing_done_${CAMPAIGN_NUMBER}.tgz * &&
	rm -rf /var/spool/asterisk/outgoing_done/*
fi