#!/bin/bash

apt update

apt install -y curl wget vim htop fail2ban default-jre-headless
apt install -y python3 python3-dev python3-pip python3-mysqldb
apt install -y mariadb-server-core-10.3 mariadb-client-10.3 libmariadb-dev libmariadbclient-dev

pip3 install 'apache-airflow[mysql]==1.10.15'

if [ -z "$(id airflow)" ]; then
  addgroup --gid 9487 airflow
  adduser --home /home/airflow --shell /bin/bash --uid 9487 --gid 9487 --disabled-login airflow
else
  echo "Skipped, airflow user/group creation"
fi

mkdir -p /run/airflow
chown -R airflow:airflow /run/airflow

curl https://raw.githubusercontent.com/apache/airflow/1.10.15/scripts/systemd/airflow -o /etc/default/airflow
sed -i -e 's#sysconfig#default#' /etc/default/airflow

curl https://raw.githubusercontent.com/apache/airflow/1.10.15/scripts/systemd/airflow.conf -o /etc/tmpfiles.d/airflow.conf

mkdir -p /usr/lib/systemd/system

curl https://raw.githubusercontent.com/apache/airflow/1.10.15/scripts/systemd/airflow-webserver.service -o /usr/lib/systemd/system/airflow-webserver.service
sed -i -e 's#^ExecStart=/bin/airflow#ExecStart=/usr/local/bin/airflow#' -e 's#sysconfig#default#' /usr/lib/systemd/system/airflow-webserver.service

curl https://raw.githubusercontent.com/apache/airflow/1.10.15/scripts/systemd/airflow-scheduler.service -o /usr/lib/systemd/system/airflow-scheduler.service
sed -i -e 's#^ExecStart=/bin/airflow#ExecStart=/usr/local/bin/airflow#' -e 's#sysconfig#default#' /usr/lib/systemd/system/airflow-scheduler.service

# NOTE: need to execute by 'airflow'
if [ ! -d "/home/airflow/airflow" ]; then
  su - airflow -c 'airflow initdb'
else
  echo "Skipped, airflow initdb"
fi

# we don't need those examples
sed -i -e '/load_examples/s/True/False/' /home/airflow/airflow/airflow.cfg
sed -i -e '/load_default_connections/s/True/False/' /home/airflow/airflow/airflow.cfg

# generate random_secret
RANDOM_SECRET=$(openssl rand -hex 30)
sed -i -e 's/^secret_key = .*/secret_key = '${RANDOM_SECRET}'/g' /home/airflow/airflow/airflow.cfg

systemctl daemon-reload

systemctl enable airflow-webserver.service
systemctl start airflow-webserver.service

systemctl enable airflow-scheduler.service
systemctl start airflow-scheduler.service

# extra dependencies for airflow dags
pip3 install google-api-python-client google-cloud google-auth google-auth-httplib2 google-auth-oauthlib oauth2client
pip3 install google-ads googleads

# sepcial rules for "google-cloud-bigquery"
pip3 install 'google-cloud-bigquery>=1.24.0,<2.0.0'
pip3 install 'six>=1.16.0,<2.0.0'

# tabcmd
wget https://downloads.tableau.com/esdalt/2021.1.2/tableau-tabcmd-2021-1-2_all.deb -O /tmp/tableau-tabcmd-2021-1-2_all.deb
apt install -y /tmp/tableau-tabcmd-2021-1-2_all.deb

su - airflow -c '/opt/tableau/tabcmd/bin/tabcmd --accepteula'

echo "===================================================================="
echo " All done, please try to connect airflow with the following link:   "
echo " - http://localhost:8080                                            "
echo "===================================================================="
