#!/bin/bash
# you can set odoo version as 1st argument
export VER=13.0		 # set odoo version - should work with any version after 11.0 - tested with 12 & 13
[[ -n $1 ]] && export VER="$1" 
### Config vars - you may change these - but defaults are good 
export SFX=$(echo -n $VER | awk -F\. '{print $1}')	 # Odoo folder suffix version without ".0"
[[ $SFX = 'master' ]] && export SFX=99
export BWS="$HOME/workspace"		 # Base workspace folder default ~/workspace
export ODIR="$BWS/Odoo_$SFX"		 # Odoo dir name, default ~/workspace/Odoo13

##################### Do Not make changes below this line #####################
{ #exports
	export LOGFILE="$HOME/OdooInstaller.log"
	export aria2c='aria2c -c -x4 -s4'
	export OGH="https://github.com/odoo/odoo"
	export REQ="https://raw.githubusercontent.com/odoo/odoo/master/requirements.txt"
	export RQF=$(mktemp)
	export DISTS="Ubuntu: xenial bionic focal, Debian: stretch buster"

	which apt-get &>>$LOGFILE && export DIST=$(lsb_release -c | awk '{print $2}')
	echo $DISTS | grep -i $DIST &>>$LOGFILE || export DIST=bionic
	which apt-get &>>$LOGFILE && export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.${DIST}_amd64.deb"
	which dnf &>>$LOGFILE && export WKURL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos8.x86_64.rpm"
	which apt-get &>>$LOGFILE && export VSURL="https://go.microsoft.com/fwlink/?LinkID=760868"
	which dnf &>>$LOGFILE && export VSURL="https://go.microsoft.com/fwlink/?LinkID=760867"
}

{ #Colors - ref: https://stackoverflow.com/a/5947802
	export RED='\033[0;31m'
	export GREEN='\033[0;32m'
	export BLUE='\033[0;34m'
	export LRED='\033[1;31m'
	export LGREEN='\033[1;32m'
	export LBLUE='\033[1;34m'
	export NC='\033[0m' # No Color
}

die(){ # Function to print an error and kill the script
	export MSG=$1; export ERR=$2; 
	echo -e "${LRED}Error: $MSG ${NC}" #error msg
	echo -e "${LRED}
	Something went wrong ...
	Plz check the previous messages for errors
	and try re-running the installation again.
	You may delete $ODIR before restarting.
	${NC}"
	[[ -n $ERR ]] && exit $ERR || exit 9
}

sayok(){ 
	echo -e "${LGREEN} OK ${NC}" 
}

echo $VER | grep "master\|.0" || die "Version should have .0 like 12.0 not 12 or master" 9999 # Check version arg

{ # Intro
	touch $LOGFILE
	echo -e "${LBLUE}
	#############################################################
	#  Welcome to Odoo installer script by 
	#  ${LGREEN}Mohamed M. Hagag https://linkedin.com/in/mohamedhagag${LBLUE}
	#  released under GPL3 License
	#-----------------------------------------------------------
	#  ${LRED}Caution: This script For development use only
	#         And should not used for production use.${LBLUE}
	#  This should work on ${LGREEN}Ubuntu 18.04+, Debian 9+ & Fedora 30+.${LBLUE}
	#  You can set odoo version by calling ${NC}$0 \${VER}$LBLUE
	#  for ex. $NC# $0 14.0 ${LBLUE}to install odoo v 14.0
	#-----------------------------------------------------------
	#  Now we will install Odoo v.${LRED} $VER $LBLUE
	#  In$LGREEN $BWS/Odoo_$SFX $LBLUE
	#  On success:
	#  - you can re/start odoo by running Odoo_Start_$SFX
	#  - stop odoo by running Odoo_Stop_$SFX
	#  - Odoo config file $LGREEN $ODIR/Odoo_$SFX.conf $LBLUE
	#  - Odoo  will be running on$LRED http://localhost:80$SFX $LBLUE
	#  - VSCode will be installed and configured for Odoo Dev
	############################################################

	Press Enter to continue or CTRL+C to exit :
	${NC}" | tee -a $LOGFILE && read && sudo ls &>/dev/null
}
while :; do sleep 10; sudo ls &>/dev/null; done & # to avoid asking for passwd again

# create workspace dir
mkdir -p $BWS && cd $BWS || die "Can not create $BWS folder" 888

# create user's bin and add it to $PATH
mkdir -p $HOME/bin 
cat ~/.bashrc | grep "~/bin\|HOME/bin" &>>$LOGFILE || echo "PATH=~/bin:\$PATH:/snap/bin" >>~/.bashrc

echo "Updating system ... "
which apt-get &>>$LOGFILE && sudo apt-get update &>>$LOGFILE 
# sudo apt-get -y dist-upgrade &>>$LOGFILE && sayok

echo -n "Installing base tools ..."
which apt-get &>>$LOGFILE && ( sudo apt-get install -y --no-install-recommends snapd aria2 wget curl python3-{dev,pip,virtualenv} &>>$LOGFILE && sayok || die "Failed" )
which apt-get &>>$LOGFILE && sudo apt-get -y install python3-virtualenvwrapper &>>$LOGFILE
# Fedora/CentOS
which dnf &>>$LOGFILE && ( sudo dnf install -y snapd aria2 wget curl python3-{devel,pip,virtualenvwrapper} &>>$LOGFILE && sayok || die "Failed" )

echo -n "Creating venv $ODIR ... "
[[ -d $ODIR ]] || ( python3 -m virtualenv -p /usr/bin/python3 $ODIR &>>$LOGFILE && cd $ODIR && source $ODIR/bin/activate ) \
		&& sayok || die "can not create venv" 33

cd $BWS
which apt-get &>>$LOGFILE && $aria2c -o wkhtml.deb "$WKURL" &>>$LOGFILE &
which dnf &>>$LOGFILE && $aria2c -o wkhtml.rpm "$WKURL" &>>$LOGFILE &
#$aria2c -o vscode.deb "$CODE" &>>$LOGFILE &

echo "Cloning odoo git $VER ... "
cd $ODIR || die "$ODIR"
[[ -d odoo ]] || git clone -b $VER --single-branch --depth=1 $OGH &>>$LOGFILE \
	|| die "can not download odoo sources" 45 &

echo -n "Installing Dependencies ... "
which apt-get &>>$LOGFILE && ( sudo apt-get install -y postgresql sassc node-less npm libxml2-dev libsasl2-dev libldap2-dev \
 libxslt1-dev libjpeg-dev libpq-dev cython3 gcc g++ make automake cmake autoconf \
 build-essential &>>$LOGFILE && sayok || die "can not install deps" 11 )

# Fedora/CentOS
which dnf &>>$LOGFILE && ( sudo dnf install -y postgresql{,-server} sassc nodejs-less npm libxml2-devel libgsasl-devel openldap-devel \
 libxslt-devel libjpeg-turbo-devel libpq-devel gcc g++ make automake cmake autoconf \
  &>>$LOGFILE && sayok || die "can not install deps" 11 )

which dnf &>>$LOGFILE && sudo ln -sf /var/lib/snapd/snap / &>>$LOGFILE
export PATH=$PATH:/snap/bin

which dnf &>>$LOGFILE && echo -n "Setting up postgres ..."
which dnf &>>$LOGFILE && ( sudo ls /var/lib/pgsql/initdb_postgresql.log &>>$LOGFILE && sayok || \
    ( sudo /usr/bin/postgresql-setup --initdb &>>$LOGFILE && sudo systemctl enable --now postgresql &>>$LOGFILE && sayok ) \
     || die "Postgres setup failed" )

echo "Installing & Creating VSCode workspace ... "
inst_vsc(){
	sudo systemctl enable --now snapd 
	which code || ( which snap && ( sudo snap install --classic code || sudo snap install --classic code ) || die "Can not install VSCode" )

export vscext="Atishay-Jain.All-Autocomplete
jigar-patel.odoosnippets
coenraads.bracket-pair-colorizer
DotJoshJohnson.xml
formulahendry.auto-close-tag
formulahendry.auto-rename-tag
GrapeCity.gc-excelviewer
janisdd.vscode-edit-csv
magicstack.MagicPython
mechatroner.rainbow-csv
dbaeumer.vscode-eslint
ms-python.python
ms-vscode.atom-keybindings
vscode-icons-team.vscode-icons
Zignd.html-css-class-completion
"
for ext in $vscext; do code --list-extensions | grep $ext || code --install-extension $ext ; done

}
inst_vsc &>>$LOGFILE &

curl $REQ > $RQF 2>/dev/null || die "can not get $REQ " 22

echo -n "Creating postgres user for $USER ..."
sudo su -l postgres -c "psql -qtAc \"\\du\"" | grep $USER &>>$LOGFILE \
&& sayok || ( sudo su -l postgres -c "createuser -d $USER " &>>$LOGFILE && sayok ) || die "Postgres user creation failed"

# install rtlcss requored for RTL support in Odoo
echo -n "Installing rtlcss... "
which rtlcss &>>$LOGFILE && sayok \
|| ( sudo npm install -g rtlcss &>>$LOGFILE && sayok )


echo "Creating start/stop scripts"
echo "#!/bin/bash
find $ODIR/ -type f -name \"*pyc\" -delete
for prc in \$(ps aux | grep -v grep | grep -i \$(basename $ODIR) | grep python | awk '{print \$2}'); do kill -9 \$prc &>/dev/null; done
cd $ODIR && source bin/activate && ./odoo/odoo-bin -c ./Odoo_$SFX.conf \$@
" > $ODIR/.start.sh \
	&& chmod u+x $ODIR/.start.sh \
	&& cp $ODIR/.start.sh ~/bin/Odoo_Start_$SFX \
	|| die "can not create start script"

head -3 $ODIR/.start.sh > $ODIR/.stop.sh && chmod u+x $ODIR/.stop.sh \
	&& cp $ODIR/.stop.sh ~/bin/Odoo_Stop_$SFX \
	|| die "can not create STOP script"

echo "Creating odoo config file ..."
echo "[options]
addons_path = ./odoo/odoo/addons,./odoo/addons,./my_adds
xmlrpc_port = 80$SFX
longpolling_port = 70$SFX
limit_time_cpu = 1800
limit_time_real = 3600
log_file = ../Odoo.log
workers = 2
dev = all
"> $ODIR/Odoo_$SFX.conf && mkdir -p $ODIR/my_adds

# change some python pkg versions
sed -i -e "s,psycopg2.*,psycopg2,g" $RQF
sed -i -e "s,num2words.*,num2words,g" $RQF
sed -i -e "s,Werkzeug.*,Werkzeug<1.0.0,g" $RQF
#sed -i -e "s,Babel.*,Babel,g" $RQF
#sed -i -e "s,html2text.*,html2text,g" $RQF
#sed -i -e "s,pytz.*,pytz,g" $RQF
#sed -i -e "s,psutil.*,psutil,g" $RQF
#sed -i -e "s,passlib.*,passlib,g" $RQF
#sed -i -e "s,libsass.*,libsass,g" $RQF
#sed -i -e "s,pillow.*,pillow,g" $RQF
#sed -i -e "s,Pillow.*,Pillow,g" $RQF
#sed -i -e "s,lxml.*,lxml,g" $RQF
#sed -i -e "s,reportlab.*,reportlab,g" $RQF
echo phonenumbers >> $RQF
echo pyaml >> $RQF
echo pylint >> $RQF

# link a folder to avoid an error in pip install lxml
sudo ln -sf /usr/include/libxml2/libxml /usr/include/ &>>$LOGFILE

echo "Installing Python libraries:"
cd $ODIR && source ./bin/activate

while read line 
	do 
		export LMSG=$(echo "$line" | awk '{print $1}')
		echo -n " - Installing $LMSG : "
		pip install "$line" &>>$LOGFILE && sayok \
		|| ( die "$LMSG library install error" )
		sudo ls &>/dev/null # To avoid asking for passwd again
    done < $RQF

echo "Installing WKHTML2PDF ... "
while $(ps aux | grep wkhtml | grep aria2 &>/dev/null); do sleep 5; done
which wkhtmltopdf &>>$LOGFILE || ( which apt-get &>/dev/null && sudo apt-get -y install $BWS/wkhtml.deb &>>$LOGFILE ) 
which wkhtmltopdf &>>$LOGFILE || ( which dnf &>/dev/null && sudo dnf -y install $BWS/wkhtml.rpm &>>$LOGFILE ) 
which wkhtmltopdf &>>$LOGFILE || die "can not install wkhtml2pdf" 777 

mkdir -p $ODIR/.vscode

echo '{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Current File",
            "type": "python",
            "cwd": "${workspaceFolder}",
            "request": "launch",
            "program": "${cwd}/odoo/odoo-bin",
            "args": ["-c","${cwd}/Odoo_*.conf"],
            "env": {"GEVENT_SUPPORT":"True"},
            "console": "integratedTerminal"
        }
    ]
}' >$ODIR/.vscode/launch.json

echo '{
    "python.pythonPath": "bin/python"
}'>$ODIR/.vscode/settings.json

echo '{
	"python.envFile": ${workspaceFolder}/.env,
	"folders": [
		{
			"path": ".."
		}
	]
}'>$ODIR/.vscode/Odoo_${SFX}.code-workspace

echo "PYTHONPATH=$ODIR/odoo" >$ODIR/.env

psql -l | grep zt &>>$LOGFILE || ( createdb ztdb1 &>>$LOGFILE && createdb ztdb2 &>>$LOGFILE)

export shmmax=$(expr $(free | grep Mem | awk '{print $2}') / 2)000
export shmall=$(expr $shmmax / 4096)

cat /etc/sysctl.conf | grep "kernel.shmmax = $shmmax" &>>$LOGFILE \
|| echo "############ Odoo, Postgress & VSCode #########
fs.inotify.max_user_watches = 524288
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = $shmall
kernel.shmmax = $shmmax
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586
" | sudo tee -a /etc/sysctl.conf &>>$LOGFILE; sudo sysctl -p &>>$LOGFILE

ps aux | grep git | grep odoo &>>$LOGFILE && echo "Waiting for git clone ..."
while $(ps aux | grep git | grep odoo &>>$LOGFILE); do sleep 5; done

code $ODIR/.vscode/Odoo_${SFX}.code-workspace

[[ -d $ODIR ]] && [[ -f $ODIR/odoo/odoo-bin ]] && env | grep VIRTUAL &>>$LOGFILE \
&& echo -e "${LGREEN}
#############################################################
#  Looks like everything went well.
#  You should now:
#  - Have Odoo v$VER In $LRED $BWS/Odoo_$SFX $LGREEN
#  - you can re/start odoo by running Odoo_Start_$SFX
#  - stop odoo by running Odoo_Stop_$SFX
#  - Odoo config file $ODIR/Odoo_$SFX.conf
#  - VSCode should be installed & configured for Odoo Devs
#  - Then access odoo on$LRED http://localhost:80$SFX $LGREEN
#############################################################
${LBLUE}***For best results restart this PC now***$LGREEN
Good luck, ;) .
${NC}" || die "Installation Failed" 1010
