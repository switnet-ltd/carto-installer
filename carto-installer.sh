#!/bin/bash
# CartoDB Installer - *buntu 16.04 (LTS) based systems.
# SwITNet Ltd © - 2018, https://switnet.net/
# GPLv3 or later.
#
# Initially inspired on:
# https://cartodb.readthedocs.io/en/latest/install.html

clear
echo '
########################################################################
                     Welcome to CartoDB Installer
########################################################################
                    by Software, IT & Networks Ltd
'
CARDPSQL_REPO="$(apt-cache policy | grep http | grep postgresql | awk '{print $3}' | head -n 1 | awk -F '/' '{print $1}')"
GIS_REPO="$(apt-cache policy | grep http | grep gis | awk '{print $3}' | head -n 1 | awk -F '/' '{print $1}')"
RUBY_REPO="$(apt-cache policy | grep http | grep ruby | awk '{print $3}' | head -n 1 | awk -F '/' '{print $1}')"
CDB_PSQL_API="https://api.github.com/repos/CartoDB/cartodb-postgresql/tags"
CDB_LST_TAG="$(curl -s $CDB_PSQL_API | grep \"name\" | awk '{print$2}' |  sort -r | grep -v [a-z] | awk -F'"' '$0=$2' | head -n 1)"
OPT="/opt/"

install_ifnot() {
if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")" == "1" ]; then
	echo " $1 is installed, skipping..."
    else
    	echo -e "\n---- Installing $1 ----"
		apt -yqq install $1
fi
}

# Check if user is root
if ! [ $(id -u) = 0 ]; then
   echo "You need to be root or have sudo privileges!"
   exit 0
fi


# System locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Build essentials dependencies
install_ifnot make 
install_ifnot pkg-config
install_ifnot git

# Postgres Repo
echo "Adding Carto PostgreSQL repository..."
if [ "$CARDPSQL_REPO" = "xenial" ]; then
	echo "Card PostgreSQL repository already installed"
else
	add-apt-repository ppa:cartodb/postgresql-10
	# Install postgres
	apt -y update
	apt -y install postgresql-10 \
						 postgresql-plpython-10 \
						 postgresql-server-dev-10
fi

PSQL_HBA="/etc/postgresql/10/main/pg_hba.conf"
TRUST_LINES="$(grep -n ^[^#] $PSQL_HBA | grep -v replication |  awk -F: 'NR==1 {printf "%d ", $1}; END{print $1}' | sed -e 's| |,|g')"
sed -i "${TRUST_LINES}s|peer|trust|" $PSQL_HBA
sed -i "${TRUST_LINES}s|md5|trust|" $PSQL_HBA

systemctl restart postgresql

createuser publicuser --no-createrole --no-createdb --no-superuser -U postgres
createuser tileuser --no-createrole --no-createdb --no-superuser -U postgres

#TBD
echo "Installed postgres"
read -p "Enter to continue"

cd $OPT
git clone https://github.com/CartoDB/cartodb-postgresql.git
cd cartodb-postgresql
git checkout $CDB_LST_TAG
make all install

#TBD
echo "Installed cartodb-postgres"
read -p "Enter to continue"

# GIS dependancies
echo "Adding GIS repository..."
if [ "$GIS_REPO" = "xenial" ]; then
	echo "Card GIS repository already installed"
else
	add-apt-repository ppa:cartodb/gis
	# Install GDAL
	apt -y update
	apt -y install 	gdal-bin \
					libgdal-dev
fi
export CPLUS_INCLUDE_PATH=/usr/include/gdal
export C_INCLUDE_PATH=/usr/include/gdal
export PATH=$PATH:/usr/include/gdal

# Install PostGIS
	apt -y install 	postgis

createdb -T template0 -O postgres -U postgres -E UTF8 template_postgis
psql -U postgres template_postgis -c 'CREATE EXTENSION postgis;CREATE EXTENSION postgis_topology;'
ldconfig

#TBD
echo "Installed gis/gdal"
read -p "Enter to continue"

# Redis dependancies
echo "Adding Redis repository..."
if [ "$GIS_REPO" = "xenial" ]; then
	echo "Carto GIS repository already installed"
else
	add-apt-repository ppa:cartodb/redis-next
	# Install Redis
	apt -y update
	apt -y install 	redis
fi

# Redis 
# persistance

#TBD
echo "Installed redis"
read -p "Enter to continue"

# Install NodeJS
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
install_ifnot nodejs
#install_ifnot node-gyp

# Check 
node -v
npm -v

install_ifnot libpixman-1-0
install_ifnot libpixman-1-dev
install_ifnot libcairo2-dev
install_ifnot libjpeg-dev
install_ifnot libgif-dev
install_ifnot libpango1.0-dev
npm install forever -g

#TBD
echo "Installed npm"
read -p "Enter to continue"

# SQL API
cd $OPT
git clone git://github.com/CartoDB/CartoDB-SQL-API.git
cd CartoDB-SQL-API
sudo npm install

cp config/environments/development.js.example config/environments/development.js
node app.js development # <--- como chingaos correr esto como servicio -> failed
#forever 

#TBD
echo "Installed carto SQL API"
read -p "Enter to continue"

# MAPS API
cd $OPT
git clone git://github.com/CartoDB/Windshaft-cartodb.git
cd Windshaft-cartodb
sudo npm install

cp config/environments/development.js.example config/environments/development.js
mkdir logs
node app.js development  # <--- worked :-/?

#TBD
echo "Installed windshaft"
read -p "Enter to continue"

# Ruby dependancies
echo "Adding Ruby 2.4 repository..."
if [ "$RUBY_REPO" = "xenial" ]; then
	echo "Carto Ruby repository already installed"
else
	apt-add-repository ppa:brightbox/ruby-ng
	# Install Redis
	apt -y update
	apt -y install 	ruby2.4 \
					ruby2.4-dev \
					ruby-bundler
fi

gem install compass

#TBD
echo "Installed ruby"
read -p "Enter to continue"

# Builder
cd $OPT
#git clone --recursive https://github.com/CartoDB/cartodb.git
git clone -b master --depth 1 https://github.com/CartoDB/cartodb.git
cd cartodb

install_ifnot python-pip
install_ifnot imagemagick
install_ifnot unp
install_ifnot zip
install_ifnot libicu-dev

RAILS_ENV=development bundle install

pip install --no-use-wheel -r python_requirements.txt

#TBD
echo "Installed python_requirements?"
read -p "Enter to continue"
sudo npm install

npm run carto-node
npm run build:static

#TBD
echo "Installed cartodb / python"
read -p "Enter to continue"

#export PATH=$PATH:$PWD/node_modules/grunt-cli/bin
#bundle exec grunt --environment=development

cp config/app_config.yml.sample config/app_config.yml
cp config/database.yml.sample config/database.yml

sudo systemctl start redis-server

RAILS_ENV=development bundle exec rake db:create
RAILS_ENV=development bundle exec rake db:migrate

RAILS_ENV=development bundle exec rails server
