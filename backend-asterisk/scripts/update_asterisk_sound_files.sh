#!/bin/bash
#exit on error
set -e
WORK_DIR=/usr/local/utils/covid/

cd ${WORK_DIR} &&
echo "Moving asterisk files in place..."
cp -prf ${WORK_DIR}/covid_sounds/* /var/lib/asterisk/sounds/covid2019/