#!/bin/bash
#--------------------------------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#--------------------------------------------------------

# This script is responsible for starting the LSF components in the containers
# It is invoked as follows:
#  start_lsf.sh  ROLE DIE_ON_FAIL PRODUCT DEPLOYMENT_TYPE
# Where:
#       ROLE = [master|agent|gui|..] - This selects what the pod will do
#       DIE_ON_FAIL = [yes|no]  - If LIM dies should the pod die
#       PRODUCT = {The product name}  - This is used to filter the node list
#                                       to determine which pods are LSF pods
#       DEPLOYMENT_TYPE = [lsf|podscheduler]  - This is used to change the
#                               configuration to enable the K8s integration

# The script version is here to make sure you have the right version when testing
SCRIPT_VER=v1

# The PRODUCT name is used to filter the host lists to determine which hosts are
# part of the cluster.  Use care when changing the names of the deplayments and 
# daemonsets.  It should match with the metadata.labels.lsftype
PRODUCT=ibm-wmla-pod-scheduler-prod



#####################################################################################
#############################  Assorted Helper Functions  ###########################
#####################################################################################

function init_log()
{
    LOGSUPPRESS=0
    LOGFILE="$1"
    if [ ! -e "$LOGFILE" ];then
        touch "$LOGFILE"
        if [ $? != 0 ];then
            echo "ERROR: failed to initial logging. can't create log file $LOGFILE"
	else
	    echo `date` "SCRIPT_VER=$SCRIPT_VER" | tee -a "$LOGFILE"
        fi
    fi
}

function log()
{
    echo `date` "$@" | tee -a "$LOGFILE"
}

function log_info()
{
    if [ $LOGSUPPRESS -eq 0 ]; then
        log "INFO:" "$@"
    fi
}

function log_error()
{
    log "ERROR:" "$@"
}

function log_warn()
{
    log "WARN:" "$@"
}

function log_stop()
{
    LOGSUPPRESS=1
}

function log_start()
{
    LOGSUPPRESS=0
}

# update_etc_hosts - generates the contents of the /etc/hosts file
function update_etc_hosts()
{
    # update etc/hosts file so that no "HOST_NOT_FOUND" issue
    # raised by pmpi, since pmpi depends on 'gethostbyname' get
    # ip/hostname mapping
    log_info "Running: update_etc_hosts()"

    (
cat << EOF
# Kubernetes-managed hosts file.
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
fe00::0 ip6-mcastprefix
fe00::1 ip6-allnodes
fe00::2 ip6-allrouters
`cat $LSF_CONF/hosts`
EOF
    ) > /etc/hosts
}


# start_lsf - Start all the LSF deamons for this ROLE
function start_lsf()
{
    log_info "Running: start_lsf()" 
    log_info "    Start LSF services on $ROLE host $MYHOST..."
    while [ ! -e /opt/ibm/lsfsuite/lsf/conf/profile.lsf ]; do
	log_info "    File /opt/ibm/lsfsuite/lsf/conf/profile.lsf is not ready"
	sleep 5
    done
    source /opt/ibm/lsfsuite/lsf/conf/profile.lsf
    echo "    start_lsf:  Environment has" >> ${LOGFILE}
    env >> ${LOGFILE}
    lsadmin limstartup >>$LOGFILE 2>&1
    ps -elf > /tmp/myps
    lsadmin resstartup >>$LOGFILE 2>&1
    badmin hstartup >>$LOGFILE 2>&1
    # Sourceing the profile.lsf unsets LSF_TOP
    LSF_TOP="/opt/ibm/lsfsuite/lsf"
    log_info "LSF services on $ROLE host $MYHOST started."
}


# stop_lsf - Stop the LSF daemons and batch-driver
function stop_lsf()
{
    log_info "Running: stop_lsf()"
    pgrep lim >/dev/null && kill $(pgrep lim)
    pgrep res >/dev/null && kill $(pgrep res)
    pgrep sbatchd >/dev/null && kill $(pgrep sbatchd)
    pgrep mbatchd >/dev/null && kill $(pgrep mbatchd)
    pgrep mbschd >/dev/null && kill $(pgrep mbschd)
    pgrep batch-driver >/dev/null && kill $(pgrep batch-driver)
}


function generate_lock()
{
    log_info "Running: generatei_lock()"
    echo 1 > $LOCKFILE
    local HOST=$(hostname)
    echo "$HOST" > ${LSF_CONF}/.master-ready
    log_info "LSF Master Ready.  Wrote: ${LSF_CONF}/.master-ready"
}


# dump_logs_stdout  - When not debugging send logs to stdout
function dump_logs_stdout()
{
    if [ ! -e /tmp/debug ]; then
        local CWD=`pwd`
        cd /opt/ibm/lsfsuite/lsf/log
        for i in $(find . -type f ); do
            j=$(basename $i)
            awk '{ print FILENAME " " $0 }' $j
	    cat /dev/null > $i
        done
	cd $CWD
    fi
}


#####################################################################################
############################### GUI Functions  ######################################
#####################################################################################

function init_database()
{
    log_info "Running: init_database()"
    while true; do
        </dev/tcp/127.0.0.1/3306 && break
        sleep 3
        log_info "     waiting for maria database service startup ..."
    done

    # The database password is passed as a Kubernetes secret.
    # The secret is in file:  /opt/ibm/lsfsuite/db-pass/MYSQL_ROOT_PASSWORD
    # Get the secret from that and re-encode it
    MYSQL_PASSWORD=$(< /opt/ibm/lsfsuite/db-pass/MYSQL_ROOT_PASSWORD )
    #source  $PAC_TOP/profile.platform
    #local DB_USER=$( /opt/ibm/lsfsuite/ext/perf/1.2/bin/encryptTool.sh pacuser )
    #local DB_PASS=$( /opt/ibm/lsfsuite/ext/perf/1.2/bin/encryptTool.sh ${DB_RAW_PASS} )

    (
cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<ds:DataSources xmlns:ds="http://www.ibm.com/perf/2006/01/datasource" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xsi:schemaLocation="http://www.ibm.com/perf/2006/01/datasource datasource.xsd">
   <ds:DataSource Name="ReportDB"
        Driver="org.mariadb.jdbc.Driver"
        Connection="jdbc:mysql://127.0.0.1:3306/pac"
        Default="true"
        Cipher="des56"
        UserName="uOTzmooF4Qw="
        Password="uOTzmooF4Qw=">
        <ds:Properties>
            <ds:Property>
                <ds:Name>maxActive</ds:Name>
                <ds:Value>30</ds:Value>
            </ds:Property>
        </ds:Properties>
   </ds:DataSource>
</ds:DataSources>
EOF
    ) > $PAC_TOP/perf/conf/datasource.xml
    log_info "     check whether database already exists."
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -D$DB_NAME -h127.0.0.1 -e "select count(1) from PMC_USER;"
    if [ $? -eq 0 ]; then
        log_info "     pac database already exists."
        return
    fi
    log_info "     creating MYSQL database for Platform Application Center"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "create database if not exists $DB_NAME default character set utf8 default collate utf8_bin;"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "GRANT ALL ON $DB_NAME.* TO pacuser@127.0.0.1 IDENTIFIED BY 'pacuser';"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsf_sql.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/ego/1.2/DBschema/MySQL/egodata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsfdata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_pac_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/init.sql
    log_info "     MYSQL database for Platform Application Center is created."
    log_info "Finished: init_database()"
}


function start_pac()
{
    log_info "Running: start_pac()"
    log_info "     Start PAC services on $ROLE host $MYHOST..."
    source  $PAC_TOP/profile.platform
    pmcadmin https disable >>$LOGFILE 2>&1
    perfadmin start all >>$LOGFILE 2>&1
    pmcadmin start PNC >>$LOGFILE 2>&1
    pmcadmin start EXPLORER >>$LOGFILE 2>&1
    pmcadmin start WEBGUI >>$LOGFILE 2>&1
}

#  monitor_webgui  - Monitor the state of the web gui
function monitor_webgui()
{
    source  $PAC_TOP/profile.platform 2>&1 >/dev/null
    pmcadmin list >>$LOGFILE 2>&1

}


function start_elastic()
{
    export ES_HOME=/opt/ibm/elastic/elasticsearch
    export CONF_DIR=/opt/ibm/elastic/elasticsearch/config
    export DATA_DIR=/opt/ibm/elastic/elasticsearch/data
    export LOG_DIR=/opt/ibm/elastic/elasticsearch/log
    export PID_DIR=/var/run/elasticsearch
    export PIDFile=/var/run/elasticsearch/elasticsearch-for-lsf.pid
    export JAVA_HOME=/opt/ibm/jre
    /opt/ibm/elastic/elasticsearch/bin/elasticsearch-systemd-pre-exec
    /opt/ibm/elastic/elasticsearch/bin/eslauncher.sh -p ${PID_DIR}/elasticsearch-for-lsf.pid --quiet -Edefault.path.logs=${LOG_DIR} -Edefault.path.data=${DATA_DIR} -Edefault.path.conf=${CONF_DIR}
}


function start_logstash()
{
    export CONF_DIR=/opt/ibm/elastic/logstash/config
    export LOG_DIR=/opt/ibm/elastic/logstash/log
    export JAVA_HOME=/opt/ibm/jre
    /opt/ibm/elastic/logstash/bin/logstash "--path.settings" "${CONF_DIR}" "--path.logs" "${LOG_DIR}" 2>&1 >/dev/null &
}


function fix_gui_conf()
{
    log_info "Running:  fix_gui_conf()"
    log_info "    Fix oem strings"
    sed -i -e "s:IBM\ Spectrum\ LSF\ Application\ Center:IBM\ Spectrum\ LSF\ Suite:g" ${PAC_TOP}/gui/conf/oem.json
    sed -i -e "s:LSF\ Application\ Center:LSF\ Suite:g" ${PAC_TOP}/gui/conf/oem.json
    sed -i -e "s:pac.help.generalHelp:IBM Spectrum LSF Suite for Workgroups Help:g" ${PAC_TOP}/gui/conf/oem.json
    sed -i -e 's^"helpUrl": ""^"helpUrl": "https://www.ibm.com/support/knowledgecenter/SSZU9Q/product_welcome_lsf_suite_wg.html"^g' ${PAC_TOP}/gui/conf/oem.json
    log_info "    Updating pmc.conf"
    echo "LSF_SUITE_EDITION=LSF Suite Community Edition" >> ${PAC_TOP}/gui/conf/pmc.conf
    log_info "    Updating pnc-config.xml"
    sed -i -e 's:<restHost>.*:<restHost>localhost</restHost>:g' ${PAC_TOP}/gui/conf/pnc-config.xml
    sed -i -e 's:<wsHost>.*:<wsHost>localhost</wsHost>:g' ${PAC_TOP}/gui/conf/pnc-config.xml
    sed -i -e 's:@PORT@:8081:g' ${PAC_TOP}/gui/conf/pnc-config.xml
    sed -i -e 's:@SSL_PORT@:8444:g' ${PAC_TOP}/gui/conf/pnc-config.xml
    log_info "    Updating perf/1.2/bin/es/initPaTemplate.sh.raw"
    sed -i -e "s:PRI_SHARD_NUM.*:PRI_SHARD_NUM=5:g" ${PAC_TOP}/perf/1.2/bin/es/initPaTemplate.sh.raw
    sed -i -e "s:REP_SHARD_NUM.*:REP_SHARD_NUM=1:g" ${PAC_TOP}/perf/1.2/bin/es/initPaTemplate.sh.raw
    sed -i -e "s^@es_ip@^localhost:9200^g" ${PAC_TOP}/perf/1.2/bin/es/initPaTemplate.sh.raw
    log_info "    Fixing EXEC_HOST"
    local THISHOST=$(hostname)
    sed -i -e "s:EXEC_HOST.*:EXEC_HOST=$THISHOST:g" ${PAC_TOP}/gui/conf/wsm_webgui.conf
    sed -i -e "s:EXEC_HOST.*:EXEC_HOST=$THISHOST:g" ${PAC_TOP}/perf/conf/wsm/wsm_plc_2.conf
    sed -i -e "s:EXEC_HOST.*:EXEC_HOST=$THISHOST:g" ${PAC_TOP}/perf/conf/wsm/wsm_plc_3.conf
    sed -i -e "s:EXEC_HOST.*:EXEC_HOST=$THISHOST:g" ${PAC_TOP}/perf/conf/wsm/wsm_plc.conf
    sed -i -e "s:EXEC_HOST.*:EXEC_HOST=$THISHOST:g" ${PAC_TOP}/perf/conf/wsm/wsm_purger.conf
    local OLDHOST=$(grep JS_HOST ${PAC_TOP}/ppm/conf/js.conf |awk -F'=' '{ print $2 }')
    log_info "    Fixing JS_HOST"
    sed -i -e "s:JS_HOST.*:JS_HOST=$THISHOST:g" ${PAC_TOP}/ppm/conf/js.conf
    echo "JS_PAC_SERVER_URL=http://$THISHOST:8080" >> ${PAC_TOP}/ppm/conf/js.conf
    log_info "Finished: fix_gui_conf()"
}


function init_gui_share_dir()
{
    log_info "Running: init_gui_share_dir()"
    local HOST=$(hostname)
    # Have to wait for the LSF Master to setup the directories
    while [ ! -d $HOME_DIR/lsf/conf ]; do
        sleep 5
        log_info "    waiting for lsf master to make directories ..."
    done
    if [ -d ${LSF_CONF} ]; then
        log_info "    LSF conf dir exists.  Deleting: ${LSF_CONF}"
        rm -rf ${LSF_CONF}
    fi
    log_info "    Making symbolic link:  $HOME_DIR/lsf/conf to ${LSF_CONF}"
    ln -s $HOME_DIR/lsf/conf ${LSF_CONF}
    log_info "    Making symbolic link:  $HOME_DIR/lsf/work to $LSF_TOP/work"
    ln -s $HOME_DIR/lsf/work $LSF_TOP/work

    # Need to relocate the conf and work dirs to the shared storage
    local GUI_SHARE=/opt/ibm/lsfsuite/lsfadmin
    local GUI_LOCAL=/opt/ibm/lsfsuite/ext

    # Make directories as needed from the Primary GUI host
    # TODO:  Figure out how is the primary GUI host
    test -d ${GUI_SHARE}/gui/conf || (mkdir -p ${GUI_SHARE}/gui ;cp -rp ${GUI_LOCAL}/gui/.conf ${GUI_SHARE}/gui/conf )
    test -d ${GUI_SHARE}/gui/work || cp -rp ${GUI_LOCAL}/gui/.work ${GUI_SHARE}/gui/work
    test -d ${GUI_SHARE}/ppm/conf || (mkdir -p ${GUI_SHARE}/ppm ; cp -rp ${GUI_LOCAL}/ppm/.conf ${GUI_SHARE}/ppm/conf )
    test -d ${GUI_SHARE}/ppm/work || cp -rp ${GUI_LOCAL}/ppm/.work ${GUI_SHARE}/ppm/work
    test -d ${GUI_SHARE}/perf/conf || (mkdir -p ${GUI_SHARE}/perf ;cp -rp ${GUI_LOCAL}/perf/.conf ${GUI_SHARE}/perf/conf )
    test -d ${GUI_SHARE}/perf/work || cp -rp ${GUI_LOCAL}/perf/.work ${GUI_SHARE}/perf/work

    # Wait for the shared directories to appear
    while [ ! -d ${GUI_SHARE}/perf/work ]; do
        sleep 5
        log_info "    waiting for GUI master to make directories ..."
    done

    test -h ${GUI_LOCAL}/gui/conf || ( rm -rf ${GUI_LOCAL}/gui/conf ;ln -s ${GUI_SHARE}/gui/conf ${GUI_LOCAL}/gui/conf )
    test -h ${GUI_LOCAL}/gui/work || ( rm -rf ${GUI_LOCAL}/gui/work ;ln -s ${GUI_SHARE}/gui/work ${GUI_LOCAL}/gui/work )
    test -h ${GUI_LOCAL}/ppm/conf || ( rm -rf ${GUI_LOCAL}/ppm/conf ;ln -s ${GUI_SHARE}/ppm/conf ${GUI_LOCAL}/ppm/conf )
    test -h ${GUI_LOCAL}/ppm/work || ( rm -rf ${GUI_LOCAL}/ppm/work ;ln -s ${GUI_SHARE}/ppm/work ${GUI_LOCAL}/ppm/work )
    test -h ${GUI_LOCAL}/perf/conf || ( rm -rf ${GUI_LOCAL}/perf/conf ;ln -s ${GUI_SHARE}/perf/conf ${GUI_LOCAL}/perf/conf )
    test -h ${GUI_LOCAL}/perf/work || ( rm -rf ${GUI_LOCAL}/perf/work ;ln -s ${GUI_SHARE}/perf/work ${GUI_LOCAL}/perf/work )

    log_info "Finished: init_gui_share_dir()"
}

###################################################################################
########################  Functions Common to All  ################################
###################################################################################

# add_authconfig()  - Add any files added in the authconfig section
function add_authconfig()
{
    log_info "Running: add_authconfig()"
    local BASE=/.config
    local SDIR=`pwd`
    local FN=""
    local DN=""
    local DDN=""
    if [ -e ${BASE} ]; then
        cd ${BASE}
        local CONFS=$(find . |grep '..data' |sed 's/^\.//')
        for i in ${CONFS} ; do
            DN=$(dirname $i)
            DDN=$(dirname $DN)
            FN=$(ls -H ${BASE}$i/ )
            echo "        Processing: $i, DN=$DN, DDN=${DDN}"
            echo "        Linking from: $FN"
            if [ ! -e ${DDN} ]; then
                mkdir -p ${DN}
            fi
            if [ -e ${DN} ]; then
                mv ${DN} ${DN}.ORIG
            fi
            echo "        Running: ln -s ${BASE}$i/${FN} $DN"
            ln -s ${BASE}$i/${FN} $DN 2>&1 >> ${LOGFILE}
        done
        cd ${SDIR}
    fi
    log_info "Finished: add_authconfig()"

}

# run_authconfig - Run the authconfig command to setup the username resolution
#                  The command assumes that any other certificates have been provided
function run_authconfig()
{
    log_info "Running: run_authconfig()"

    # Prepare the /etc/pam.d/sshd file
    local PAMSSHD=/etc/pam.d/sshd
    if [ ! -e ${PAMSSHD} ]; then
        cat<<EOF > $PAMSSHD
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
EOF
        log_info "    Prepared: ${PAMSSHD}"
    fi

    # authconfig --enableldap --enableldapauth --ldapserver="ldap://9.21.48.117/,ldap://9.21.48.118/" --ldapbasedn="dc=platformlab,dc=ibm,dc=com" --enablemkhomedir --update --nostart
    if [ -z "${AUTHCFGARGS}" ]; then
        log_info "     Authconfig arguments not provided, aborting"
        log_info "Finished: run_authconfig()"
        return
    fi
    local AUTHCONFIG=/usr/sbin/authconfig
    if [ ! -e ${AUTHCONFIG} ]; then
        log_error "     Unable to find ${AUTHCONFIG}, aborting"
        return
    fi
    log_info "    Running: ${AUTHCONFIG} ${AUTHCFGARGS} --nostart"
    ${AUTHCONFIG} ${AUTHCFGARGS} --nostart 2>&1 >> $LOGFILE
    touch /etc/.userresolve

    log_info "Finished: run_authconfig()"
}

# start_authdaemons - Start the authentication daemon(s)
function start_authdaemons()
{
    log_info "Running: start_authdaemons()"
    #if [ ! -e /etc/.userresolve ]; then
    #    log_info "     User Resoultion is not configured"
    #    return
    #fi

    if [ "${AUTHDAEMONS}" != "" ]; then
        local RESSTR=""
        local CURR_IFS=$IFS
        local DLIST=( )
        local THIS_DAEMON=""
        IFS=$' '
        DLIST=( $AUTHDAEMONS )
        IFS=$CURR_IFS
        for ((i=0; i < ${#DLIST[*]}; i++)); do
            THIS_DAEMON=${DLIST[$i]}
            if [ -e "${THIS_DAEMON}" ]; then
                ${THIS_DAEMON} 2>&1 >> ${LOGFILE}
                log_info "    Starting: ${THIS_DAEMON}"
            else
                log_error "     Image is missing: ${THIS_DAEMON}.  Cannot resolve usernames"
            fi    
        done           
    fi
    log_info "Finished: start_authdaemons()" 
}


function test_image()
{
    log_info "Running:  test_image()"
    rpm -qi lsf-conf || exit 1
    rpm -qi lsf-client || exit 1
    rpm -qi lsf-server || exit 1
    log_info "    Needed rpms are installed"
    log_info "Finished:  test_image()"
}



# config_lsfs - Generate the contents of the LSF config files
#               If this is a failover case we have to deal with
#               Hostname changing AND IP changing.  For a fresh 
#               start we just need to change the hostname
function config_lsfs()
{
    log_info "Running:  config_lsfs()"
    log_info "    config_lsfs:  Fixing LSF_MASTER_LIST = $MYHOST"
    # Maybe using existing conf so update the MASTER host
    # sed -i -e s:^LSF_MASTER_LIST=.*:LSF_MASTER_LIST=\"$MYHOST\":g $HOME_DIR/lsf/conf/lsf.conf
    sed -i -e s:^EGO_MASTER_LIST=.*:EGO_MASTER_LIST=\"$MYHOST\":g $HOME_DIR/lsf/conf/ego/${CLUSTERNAME}/kernel/ego.conf
    sed -i -e s:^MASTER_LIST=.*:MASTER_LIST=\"$MYHOST\":g $HOME_DIR/lsf/conf/lsf.conf
    sed -i -e s:^LSF_SERVER_HOSTS=.*:LSF_SERVER_HOSTS=\"$MYHOST\":g $HOME_DIR/lsf/conf/lsf.conf

    log_info "    config_lsfs:  Fixing lsbatch/${CLUSTERNAME}/configdir/lsb.hosts"
    sed -i -e "s:^master_hosts.*:master_hosts   (${MYHOST}):g" ${LSF_CONF}/lsbatch/${CLUSTERNAME}/configdir/lsb.hosts
    sed -i -e "s:^lsfmaster:${MYHOST}:g" ${LSF_CONF}/lsbatch/${CLUSTERNAME}/configdir/lsb.hosts

    # Check if this is a restart or fresh
    if [ -e "${LSF_CONF}/.master-ready" ]; then
        IMAGE_HOST=$(< ${LSF_CONF}/.master-ready)
    else
	# the host name from base image
	log_info "    config_lsfs: Removing $IMAGE_HOST from work directory"
	IMAGE_HOST=`awk -F'"' '/MASTER_LIST/ {print $(NF-1)}' $LSF_TOP/.conf_tmpl/lsf.conf`
        find $LSF_TOP/work/${CLUSTERNAME}/logdir \
            ${LSF_CONF} \
            -type f -print0 | xargs -0 sed -i "s/$IMAGE_HOST/$MYHOST/g"    
    fi
    log_info "Finished:  config_lsfs: Fixing LSF config.  Old host = $IMAGE_HOST.  New host = $MYHOST"
}



# init_compute_share_dir - Prepares the LSF Compute node to run LSF
function init_compute_share_dir()
{
    log_info "Running:  init_compute_share_dir()"
    local HOST=$(hostname)
    local CONF=$LSF_TOP/conf
    cp -r $LSF_TOP/.conf_tmpl/* $LSF_TOP/conf
    #IMAGE_HOST=`awk -F'"' '/MASTER_LIST/ {print $(NF-1)}' $LSF_TOP/.conf_tmpl/lsf.conf`
    local master_name
    local master_ip=$(grep master /tmp/kubepod-data |awk '{ print $2 }')
    local master_hip=$(grep master /tmp/kubepod-data |awk '{ print $1 }')
    local master_host=""
    if [ "$master_ip" = "$master_hip" ]; then
        master_name=$(grep master /tmp/kubepod-data |awk '{ print $8 }')
    else
        master_name=$(grep master /tmp/kubepod-data |awk '{ print $3 }')
    fi
    log_info "    LSF Master = ${master_name}"

    log_info "    Setting Clustername to: ${CLUSTERNAME}"
    cp -nar $LSF_TOP/.conf_tmpl/* ${CONF}
    mv ${CONF}/lsf.cluster.myCluster ${CONF}/lsf.cluster.${CLUSTERNAME}
    mv ${CONF}/ego/myCluster ${CONF}/ego/${CLUSTERNAME}
    mv ${CONF}/lsbatch/myCluster ${CONF}/lsbatch/${CLUSTERNAME}
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/profile.lsf
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/lsf.shared
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/lsf.conf
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/cshrc.lsf
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/trigger-reconfig.sh
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/ego/myCluster/eservice/esc/conf/services/named.xml
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/ego/myCluster/eservice/esd/conf/named/conf/named.conf
    sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${CONF}/ego/myCluster/kernel/ego.conf

    sed -i -e s:^MASTER_LIST=.*:MASTER_LIST=\"$master_name\":g ${CONF}/lsf.conf
    sed -i -e s:^LSF_SERVER_HOSTS=.*:LSF_SERVER_HOSTS=\"$master_name\":g ${CONF}/lsf.conf

    local LSFCONF=${LSF_TOP}/conf/lsf.conf
    # Enable GPU features
    grep "LSB_GPU_NEW_SYNTAX=extend" ${LSFCONF} || echo "LSB_GPU_NEW_SYNTAX=extend" >> ${LSFCONF}
    grep "LSF_GPU_AUTOCONFIG=Y" ${LSFCONF} || echo "LSF_GPU_AUTOCONFIG=Y" >> ${LSFCONF}

    # Switch to TCP transport for LIM
    grep "LSF_CALL_LIM_WITH_TCP=Y" ${LSFCONF} || echo "LSF_CALL_LIM_WITH_TCP=Y" >> ${LSFCONF}
    grep "LSF_ANNOUNCE_MASTER_TCP_WAITTIME=0" ${LSFCONF} || echo "LSF_ANNOUNCE_MASTER_TCP_WAITTIME=0" >> ${LSFCONF}

    # Get config from Master LIM
    grep "LSF_GET_CONF=lim" ${LSFCONF} || echo "LSF_GET_CONF=lim" >> ${LSFCONF}
    if [ "${DEPLOYMENT_TYPE}" = "lsf" ]; then
        sed -i -e 's:LSF_ENABLE_EGO.*:LSF_ENABLE_EGO=Y:g' ${LSFCONF}
    fi
}

# sort_jq_output  - Process the output of jq and extract the data we need
#                   Output result to /tmp/kubepod-data
function sort_jq_output()
{
    log_info "Running: sort_jq_output()"
    # Different versions of jq output the dictionary in different order.
    local CURR_IFS=$IFS
    local DATA_OUT=$(</tmp/kubepod-data.tmp)
    local DATA_LINES=( )
    local THIS_LINE=( )
    # Data in the output
    local THIS_ENTRY=""
    local THIS_PIP=""
    local THIS_HIP=""
    local THIS_HNAME=""
    local THIS_NAME=""
    local THIS_PHASE=""
    local THIS_ROLE=""
    local THIS_APP=""
    IFS=$'\n'
    DATA_LINES=( $DATA_OUT )
    cat /dev/null > /tmp/kubepod-data
    for ((i=0; i < ${#DATA_LINES[*]}; i++)); do
        IFS=$' \t'
        THIS_LINE=( ${DATA_LINES[$i]} )
        if [ -z "$THIS_LINE" ]; then
            continue
        fi
        # THIS_LINE is a list of the data e.g.
        # hname: ma1hyper8  phase: Running  role: master  pip: 10.129.1.62  hip: 9.21.52.88 name: ibm-spectrum-lsf-master-6f
        # or
        # name: ibm-lsf-operator-794d95748f-kw8kd  hip: 9.21.52.86  pip: 10.130.0.19  role: null   phase: Running   hname: ma1hyper6

        for ((j=0; j < ${#THIS_LINE[*]}; j++)); do
            THIS_ENTRY="${THIS_LINE[$j]}"
            j=$(( $j + 1 ))
            # log_info "Looking at: ${THIS_ENTRY} data is: ${THIS_LINE[$j]}  j=$j"
            case "${THIS_ENTRY}" in
                "hname:")
                    THIS_HNAME="${THIS_LINE[$j]}"
                    ;;
                "phase:")
                    THIS_PHASE="${THIS_LINE[$j]}" 
                    ;;
                "role:")
                    THIS_ROLE="${THIS_LINE[$j]}"
                    ;;
                "pip:")
                    THIS_PIP="${THIS_LINE[$j]}"
                    ;;
                "hip:")
                    THIS_HIP="${THIS_LINE[$j]}"
                    ;;
                "name:")
                    THIS_NAME="${THIS_LINE[$j]}"
                    ;;
                "lsftype:")
                    THIS_APP="${THIS_LINE[$j]}"
                    ;;
                *)
                    log_error "Cannot parse: ${THIS_ENTRY}"
                    log_info "   Line contains:  ${DATA_LINES[$i]}"
                    ;;
            esac
        done

        # Validate data
        if [ -n ${THIS_HNAME} -a -n ${THIS_PHASE} -a -n ${THIS_ROLE} -a -n ${THIS_PIP} -a -n ${THIS_HIP} -a -n ${THIS_NAME} ]; then
            # name: ibm-lsf-operator-794d95748f-kw8kd  hip: 9.21.52.86  pip: 10.130.0.19  role: null   phase: Running   hname: ma1hyper6
            #|awk '{ print $6 " " $4 " " $2 "  # " $8 " " $10 " on " $12 }' | sort > /tmp/kubepod-data
            if [ ${THIS_ROLE} = "null" -o ${THIS_PHASE} = "Failed" -o ${THIS_PHASE} = "Pending" -o ${THIS_PHASE} = "null" -o ${THIS_PHASE} = "Terminating" ]; then
                log_info "   Ignoring: ${THIS_PIP} ${THIS_HIP} ${THIS_NAME}  # ${THIS_ROLE} ${THIS_PHASE} on ${THIS_HNAME}"
            else  
                echo "${THIS_PIP} ${THIS_HIP} ${THIS_NAME}  # ${THIS_ROLE} ${THIS_PHASE} on ${THIS_HNAME}" >> /tmp/kubepod-data
            fi
        else
            log_error "Incomplete parse of: ${DATA_LINES[$i]}"
            log_error "Got: ${THIS_PIP} ${THIS_HIP} ${THIS_NAME}  # ${THIS_ROLE} ${THIS_PHASE} on ${THIS_HNAME}"
        fi
        THIS_HNAME=""
        THIS_PHASE=""
        THIS_ROLE=""
        THIS_PIP=""
        THIS_HIP=""
        THIS_NAME=""
        THIS_APP=""
    done
    IFS=$CURR_IFS
    log_info "Finished: sort_jq_output()"
}


# get_k8s_pods  - Query the API server to get a list of all the pods in this namespace
function get_k8s_pods()
{
    log_info "Running: get_k8s_pods()"
    local KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
    local KUBE_NS=$(</var/run/secrets/kubernetes.io/serviceaccount/namespace)
    log_info "    get_k8s_pods: URL=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/$KUBE_NS/pods"

    curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/$KUBE_NS/pods > /tmp/kubepods
   
    # For OpenSHift we need to use the nodename as provided by the api server and not the IP.  Get from .spec.nodeName 
    # jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' | grep "${PRODUCT}" | tr -d '{",' |awk '{ print $6 " " $4 " " $2 "  # " $8 " " $10 " on " $12 }' | sort > /tmp/kubepod-data
    jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName, lsftype: .metadata.labels.lsftype }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' | grep "${PRODUCT}" | tr -d '{",' > /tmp/kubepod-data.tmp
    #|awk '{ print $6 " " $4 " " $2 "  # " $8 " " $10 " on " $12 }' | sort > /tmp/kubepod-data

    if [ -s /tmp/kubepod-data.tmp ]; then
        log_info "    get_k8s_pods:  kubepod-data contains:"
        local KDATA=$(</tmp/kubepod-data.tmp)
        log_info "${KDATA}"
        # Different versions of jq output the dictionary in different order.  
        sort_jq_output

        jq '.items[] | {name: .metadata.name, resource: .metadata.annotations.providesResource }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' | tr -d '{,' | grep -v null | sed -e 's~^.*"name":\ "~~g' |sed -e 's~".*"resource":~~g' > /tmp/host-resource.map

    else
        log_info "    get_k8s_pods: ERROR: failed to get hosts.  Logging more data to /tmp/kubepod-data.___"
        log_info "    get_k8s_pods: kubepods contains:"
        local KDATA=$(</tmp/kubepods)
        log_info "${KDATA}"
        jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName, lsftype: .metadata.labels.lsftype }' /tmp/kubepods > /tmp/kubepod-data.step1 

        jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName, lsftype: .metadata.labels.lsftype }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' > /tmp/kubepod-data.step2
        jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName, lsftype: .metadata.labels.lsftype }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' | grep "${PRODUCT}" > /tmp/kubepod-data.step3
        jq '.items[] | {name: .metadata.name, hip: .status.hostIP, pip: .status.podIP, role: .metadata.labels.role, phase: .status.phase, hname: .spec.nodeName, lsftype: .metadata.labels.lsftype }' /tmp/kubepods |tr '\n' ' ' |tr '}' '\n' | grep "${PRODUCT}" | tr -d '{",' > /tmp/kubepod-data.step4
    fi
    log_info "Finished: get_k8s_pods()"
}


# gen_pod_hosts  - Generate a hosts file from the pod data
function gen_pod_hosts()
{
    log_info "Running: gen_pod_hosts()"
    if [ ! -s /tmp/kubepod-data ]; then
        log_info "    gen_pod_hosts:  /tmp/kubepod-data is 0 bytes!"
        return
    fi
    local HOST=$(hostname)
    local CURR_IFS=$IFS
    local POD_OUT=$(</tmp/kubepod-data)
    local POD_LINES=( )
    local THIS_LINE=( )
    local THIS_PIP=""
    local THIS_HIP=""
    local THIS_HNAME=""
    local THIS_POD=""
    local THIS_PHASE=""
    local IP_BITS=( )
    local THIS_IP=""
    local THIS_NAME=""
    local THIS_ROLE=""
    IFS=$'\n'
    POD_LINES=( $POD_OUT )
    cat /dev/null > /tmp/hosts.m2
    for ((i=0; i < ${#POD_LINES[*]}; i++)); do
        IFS=$' \t'
        THIS_LINE=( ${POD_LINES[$i]} )
        if [ -z "$THIS_LINE" ]; then
	        continue
	    fi
        THIS_PIP="${THIS_LINE[0]}"
        if [ "$THIS_PIP" = "null" -o "$THIS_PIP" = "#" ]; then
            log_info "    Ignoring line: $THIS_LINE"
            continue
        fi
        THIS_HIP="${THIS_LINE[1]}"
        THIS_POD="${THIS_LINE[2]}"
        THIS_ROLE="${THIS_LINE[4]}"
        THIS_PHASE="${THIS_LINE[5]}"
        THIS_HNAME="${THIS_LINE[7]}"
        if [ -z "$THIS_HNAME" -o -z "$THIS_ROLE" -o "$THIS_ROLE" = "null" -o "$THIS_PHASE" = "Terminating" ]; then
            log_info "    Ignoring line: $THIS_LINE"
            continue
        fi
        IFS='.'
        IP_BITS=( ${THIS_HIP} )
        if [ "$THIS_ROLE" = "master" ]; then
	    THIS_NAME="master-${IP_BITS[0]}-${IP_BITS[1]}-${IP_BITS[2]}-${IP_BITS[3]}"
            # Deal with hostnetworking
            if [ "${THIS_PIP}" = "${THIS_HIP}" ]; then
                log_info "    Appears hostnetworking is used"
                echo "${THIS_PIP} ${THIS_HNAME} lsfmaster # master on ${THIS_HNAME}" >> /tmp/hosts.m2
            else
                echo "${THIS_PIP}   lsfmaster  ${THIS_NAME}  ${THIS_POD}  # master on ${THIS_HNAME}" >> /tmp/hosts.m2
            fi
        else
            if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
                THIS_NAME="worker-${IP_BITS[0]}-${IP_BITS[1]}-${IP_BITS[2]}-${IP_BITS[3]}"
                echo "${THIS_PIP}   ${THIS_NAME}  ${THIS_POD}  # agent on ${THIS_HNAME}" >> /tmp/hosts.m2
            else
                THIS_NAME="${THIS_POD}"
                if [ ${THIS_ROLE} = "gui" ]; then
                    if [ "${THIS_PIP}" = "${THIS_HIP}" ]; then
                        echo "${THIS_PIP} ${THIS_HNAME} gui ${THIS_POD}  # ${THIS_ROLE} on ${THIS_HNAME}" >> /tmp/hosts.m2
                    else
                        echo "${THIS_PIP}   gui ${THIS_POD}  # ${THIS_ROLE} on ${THIS_HNAME}" >> /tmp/hosts.m2
                    fi
                    if [ "${NETWORKING}" != "k8s" ]; then
                        # Master is using hostnetworking
                        echo "${THIS_HIP}   gui  # hostNetwork workaround" >> /tmp/hosts.m2
                    fi

                else
                    if [ "${THIS_PIP}" = "${THIS_HIP}" ]; then
                        echo "${THIS_PIP} ${THIS_HNAME}  # ${THIS_ROLE} on ${THIS_HNAME}" >> /tmp/hosts.m2
                    else
                        echo "${THIS_PIP}   ${THIS_POD}  # ${THIS_ROLE} on ${THIS_HNAME}" >> /tmp/hosts.m2
                        if [ "${NETWORKING}" != "k8s" ]; then
                            # Master is using hostnetworking
                            echo "${THIS_HIP}   ${THIS_POD}  # hostNetwork workaround" >> /tmp/hosts.m2  
                        fi
                    fi
                fi
            fi
        fi
        log_info "    THIS_PIP=$THIS_PIP  THIS_HIP=$THIS_HIP  THIS_NAME=$THIS_NAME  THIS_POD=$THIS_POD  THIS_ROLE=${THIS_ROLE}  THIS_HNAME=${THIS_HNAME}"
    done
    IFS=$CURR_IFS
    log_info "    Hosts file will contain:"
    cat /tmp/hosts.m2 >> ${LOGFILE}
    mkdir -p ${LSF_CONF}
    cp /tmp/hosts.m2 ${LSF_CONF}/hosts
    log_info "Finished: gen_pod_hosts"
}


# validate_hosts - Check the generated hosts file to see if we have the
#                  masters IP, and the IP for this host
function validate_hosts()
{
    log_info "Running: validate_hosts()"
    READY4LSF=no
    if [ ! -s /tmp/hosts.m2 ]; then
        log_info "Exiting: validate_hosts() No /tmp/hosts.m2 found!"
        cat /tmp/kubepods
        return
    fi
    grep lsfmaster /tmp/hosts.m2
    if [ $? -ne 0 ]; then
	# No master yet
	log_info "Exiting: validate_hosts()  READY4LSF=${READY4LSF}"
	return
    fi	
    local HOST=$(hostname)
    if [ "$HOST" != "lsfmaster" ]; then
	READY4LSF=yes
    else
	# Need to see if this host has an IP assigned
	grep "$HOST" /tmp/hosts.m2 |grep null > /dev/null 2>&1
	if [ $? -ne 0 ]; then
	    READY4LSF=yes
	fi
    fi
    log_info "Finished: validate_hosts()  READY4LSF=${READY4LSF}"
}


# add_host_resource - Add he Host resource entry for this machine.
#                     This is for dynamic hosts
function add_host_resource()
{
    log_info "Running: add_host_resource()"
    if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
        local POD=$(hostname)
        local HOST=$(grep $POD /tmp/kubepod-data |awk '{ print $2 }')
        if [ "${HOST}" != "" ]; then
	    echo "LSF_LOCAL_RESOURCES=\"[resourcemap ${HOST}*kube_name]\"" >> ${LSF_TOP}/conf/lsf.conf
	    log_info "    Added: LSF_LOCAL_RESOURCES=\"[resourcemap ${HOST}*kube_name]\"  to ${LSF_TOP}/conf/lsf.conf"
        fi
    else
        # The resource lisrt will come from the pods PROVIDESRESOURCE environment variable
        if [ "${PROVIDESRESOURCE}" != "" ]; then
            local RESSTR=""
            local CURR_IFS=$IFS
            local RESLIST=( )
            local THIS_RES=""
            IFS=$' '
            RESLIST=( $PROVIDESRESOURCE )
            IFS=$CURR_IFS
            for ((i=0; i < ${#RESLIST[*]}; i++)); do
                THIS_RES=${RESLIST[$i]}
       		if [ -z ${RESSTR} ]; then
                    RESSTR="[resource ${THIS_RES}]"
                else
                    RESSTR="${RESSTR} [resource ${THIS_RES}]"
                fi
            done
            if [ -n "${RESSTR}" ]; then
                echo "LSF_LOCAL_RESOURCES=\"${RESSTR}\"" >> ${LSF_TOP}/conf/lsf.conf
                log_info "     Added: LSF_LOCAL_RESOURCES=\"${RESSTR}\""
            fi
        fi
    fi
    log_info "Finished: add_host_resource"
}


# change_hostname  - Change the name of the host for the workers
#                    This is needed so LSF is not confused should a pod be killed
function change_hostname()
{
    log_info "Running: change_hostname()"
    local POD=$(hostname)
    local HOST=""
    if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
        HOST=$(grep $POD /tmp/hosts.m2 |awk '{ print $2 }')
        log_info "     change_hostname: Changing name from: ${POD} to ${HOST}"
    else
        log_info "     change_hostname: Not changing name: ${POD}"
        return  
    fi
    if [ "${HOST}" != "" ]; then
        hostname ${HOST}
    else
        log_info "ERROR:  Can't find this pod name in /tmp/hosts.m2"
    fi
}


# check_ports - Check that the needed ports are free
function check_ports()
{
    log_info "Running: check_ports()"

    local fail="no"
    local CURR_IFS=$IFS
    local NET_LINES=( )
    local NET_OUT=$(netstat -anp |grep LISTEN |grep tcp |grep -v tcp6 )
    local THIS_LINE=( )
    local THIS_LISTEN=""
    local MY_PORTS=( 7869 6878 6881 6882 6891 )

    # Scan the IP's to see if this is the master
    IFS=$'\n'
    NET_LINES=( $NET_OUT )
    for ((i=0; i < ${#NET_LINES[*]}; i++)); do
        IFS=$' \t'
        THIS_LINE=( ${NET_LINES[$i]} )
        THIS_LISTEN="${THIS_LINE[3]}"
        # log_info "    checking against ${THIS_LISTEN}"
        for ((j=0; j < ${#MY_PORTS[*]}; j++)); do
            # log_info "    check port ${MY_PORTS[$j]}"
            if [ "${THIS_LISTEN}" = "0.0.0.0:${MY_PORTS[$j]}" ]; then
                log_info "    PORT Conflict on port ${MY_PORTS[$j]}"
                fail="yes"
            fi
        done
    done
    if [ $fail = "yes" ]; then
        log_info "FATAL ERROR!!!   Are you running LSF on the host?"
        sleep 60
        exit 1
    fi
    log_info "Finished: check_ports()"
    IFS="$CURR_IFS"
}



# should_reconfig - This function will restart the LSF daemons if there is
#                   a reconfig flag file for that host
function should_reconfig()
{
    if [ -e ${LSF_CONF}/.reconfighosts/${MYHOST} ]; then
	log_info "should_reconfig:  Reconfiguring now"
	rm -rf ${LSF_CONF}/.reconfighosts/${MYHOST}
	local NEWMaster=$(grep LSF_MASTER_LIST ${LSF_CONF}/lsf.conf)
	log_info "    Now have: $NEWMaster"
	stop_lsf
	sleep 5
	start_lsf
    fi
}


# chk_hosts  - Check to see if there is a change to the hosts
#              If this is the master we will also need to reconfigure
function chk_hosts()
{
    log_stop
    log_info "Running:  chk_hosts()"
    mv /tmp/kubepod-data /tmp/kubepod-data.OLD
    get_k8s_pods
    if [ ! -s /tmp/kubepod-data ]; then
        log_start
        log_info "ERROR:    chk_hosts() /tmp/kubepod-data is bad.  Can't update"
        return
    fi 
    diff -q /tmp/kubepod-data /tmp/kubepod-data.OLD
    if [ $? -eq 0 ]; then
        log_start
        return
    fi
    # The hosts file has changed.  We need to see that the change is
    # If the lsfmaster has changed it's IP, then we need to restart
    log_start
    local NUM_MASTERS=$(grep '# master' /tmp/kubepod-data |wc -l)
    while [ ${NUM_MASTERS} -ne 1 ]; do
	log_info "   chk_hosts()  There is more than one LSF master.  Waiting for resolution"
        sleep 30
        rm /tmp/kubepod-data        
        get_k8s_pods
        if [ -s /tmp/kubepod-data ]; then
            NUM_MASTERS=$(grep '# master' /tmp/kubepod-data |wc -l)
        fi
    done

    # Regenerate the host file fragment
    touch /tmp/hosts.m2
    cp /tmp/hosts.m2 /tmp/hosts.m3
    gen_pod_hosts
    diff -q /tmp/hosts.m2 /tmp/hosts.m3
    if [ $? -eq 0 ]; then
        log_info "   chk_hosts()  One or more worker nodes may be restarting rapidly."
        return
    fi
    log_info "   chk_hosts()  There is a valid change to process"
    diff -Nup /tmp/hosts.m3 /tmp/hosts.m2 >>$LOGFILE

    # Regenerate /etc/host
    update_etc_hosts

    if [ "$ROLE" != "master" ]; then
	# TODO:  Check to see if the masters IP has changed and reconfigure
	local OLDMASTERIP=$( grep master /tmp/kubepod-data.OLD |awk '{ print $1 }' )
	local NEWMASTERIP=$( grep master /tmp/kubepod-data |awk '{ print $1 }' )
        log_info "   chk_hosts()  New master IP ${NEWMASTERIP}"
        if [ "${OLDMASTERIP}" != "${NEWMASTERIP}" ]; then
 	    # Master IP has changed
            stop_lsf
            sleep 5
            start_lsf
        fi
        return
    fi

    # Add any new hosts
    add_exechosts
    # Reconfig LSF
    lsadmin reconfig -f
    badmin mbdrestart -f -C "Adding hosts"

    log_info "Finished:  chk_hosts()"
}



######################################################################################
###########################   Master Only Functions  #################################
######################################################################################

# add_gpu_elim_conf - Add configuration for ELIM based GPU detection
#                     This will generate the config file fragments
#                     NOTE:  Assumed 8 GPUs
function add_gpu_elim_conf()
{
    log_info "Running: add_gpu_elim_conf()"
    local resourceFile="$HOME_DIR/lsf/conf/lsf.shared.gpu"
    local mapFile="$HOME_DIR/lsf/conf/lsf.cluster.gpu"
    local gpu_number=8

    cat<<EOF > $resourceFile
Begin Resource
RESOURCENAME     TYPE      INTERVAL  INCREASING  CONSUMABLE  DESCRIPTION
ngpus            Numeric   60        N           N       (Number of GPUs)
ngpus_physical   Numeric   60        N           Y       (Total GPU)
gpu_topology     String    60        ()          ()      (GPU Topology)
gpu_shared_avg_mut Numeric   60       Y          ()      (Average memory of all shared mode GPUs)
gpu_shared_avg_ut  Numeric   60       Y          ()      (Average memory of all shared mode GPUs)
gpu_driver         String    60       ()         ()      (GPU driver version)
gpu_maxfactor   Numeric   60       N          N       (Max GPU factor on a host)
gpu_matrix       String    60        ()          ()    (GPU matrix between GPUs)
EOF

    cat<<EOF > $mapFile
Begin ResourceMap
RESOURCENAME  LOCATION
ngpus [default]
ngpus_physical [default]
gpu_topology [default]
gpu_shared_avg_mut  [default]
gpu_shared_avg_ut  [default]
gpu_driver [default]
gpu_maxfactor [default]
gpu_matrix [default]
EOF

    for ((i=0;i<$gpu_number;i++))
    do
        echo "gpu_mode$i        String    60        ()          ()      (Mode of GPU$i)" >> $resourceFile
        echo "gpu_mode$i [default]" >> $mapFile
        echo "gpu_temp$i        Numeric   60        Y           ()      (Temperature of GPU$i)" >> $resourceFile
        echo "gpu_temp$i [default]" >> $mapFile
        echo "gpu_ecc$i         Numeric   60        N           ()      (ECC errors on GPU$i)" >> $resourceFile
        echo "gpu_ecc$i [default]" >> $mapFile
        echo "gpu_model$i       String    60        ()          ()      (Model name of GPU$i)" >> $resourceFile
        echo "gpu_model$i [default]" >> $mapFile
        echo "gpu_ut$i          Numeric   60        Y           ()      (GPU memory utilization of GPU$i)" >> $resourceFile
        echo "gpu_ut$i [default]" >> $mapFile
        echo "gpu_mut$i         Numeric   60        Y           ()      (GPU memory utilization of GPU$i)" >> $resourceFile
        echo "gpu_mut$i [default]" >> $mapFile
        echo "gpu_mtotal$i      Numeric   60        Y           ()      (Memory total of GPU$i)" >> $resourceFile
        echo "gpu_mtotal$i [default]" >> $mapFile
        echo "gpu_mused$i       Numeric   60        Y           ()      (Memory used of GPU$i)" >> $resourceFile
        echo "gpu_mused$i [default]" >> $mapFile
        echo "gpu_status$i      String    60        ()          ()      (GPU status of GPU$i)" >> $resourceFile
        echo "gpu_status$i [default]" >> $mapFile
        echo "gpu_error$i       String    60        ()          ()      (GPU error of GPU$i)" >> $resourceFile
        echo "gpu_error$i [default]" >> $mapFile
        echo "gpu_pstate$i      Numeric   60        Y          ()      (Performance state of GPU$i)" >> $resourceFile
        echo "gpu_pstate$i [default]" >> $mapFile
        echo "gpu_busid$i       String    60        ()          ()      (Bus id of GPU$i)" >> $resourceFile
        echo "gpu_busid$i [default]" >> $mapFile
        echo "gpu_factor$i       String    60        ()          ()      (GPU factor of GPU$i)" >> $resourceFile
        echo "gpu_factor$i [default]" >> $mapFile
    done

    echo "End Resource" >> $resourceFile
    echo "End ResourceMap" >> $mapFile

}


# add_resources   - Add boolean resources to the lsf.shared file
#                 The images will provide support for different 
#                 applications.  That will be exposed as different 
#                 resources that the user can select.  This function
#                 adds the resources to LSF.
#                 The list of resources to add is provided by the
#                 IMAGERESOURCE environment variable.
function add_resources()
{
    if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
        log_info "add_resources:  Skipping"
        return
    fi
    log_info "add_resources:  Entered"
    if [ "${IMAGERESOURCE}" != "" ]; then
        log_info "     add_resources:  Adding resources: ${IMAGERESOURCE}"
    fi

    local resourceFile="$HOME_DIR/lsf/conf/lsf.shared"
    local RES_LIST=( )
    local RES_NAME=""
    local HAVE=""
    local CURR_IFS=$IFS
    IFS=$' '
    RES_LIST=( $IMAGERESOURCE )
    for ((i=0; i < ${#RES_LIST[*]}; i++)); do
        RES_NAME=${RES_LIST[$i]}
   	# Skip resources that are there already
        HAVE=$( grep -c "${RES_NAME}.*Boolean" $resourceFile )
        if [ $HAVE -gt 0 ]; then
            log_info "    add_resources: Already have >${RES_NAME}<"
            continue
        fi
        log_info "    add_resources: Adding Resource >${RES_NAME}<"
        sed -i -e "s:End\ Resource:   ${RES_NAME}  Boolean ()       ()          (Compute Pod resource ${RES_NAME})\nEnd\ Resource\n:g" $resourceFile
    done
    IFS=$CURR_IFS
    log_info "add_resources: Finished"
}

# mk_kube_conf - Generate the kube config file for the LSF scheduler plugin
#
function mk_kube_conf()
{
    if [ ${DEPLOYMENT_TYPE} != "podscheduler" ]; then
        return
    fi

    # https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT
    # https://kubernetes.default.svc.cluster.local:8001
    local TOKEN=$(< /run/secrets/kubernetes.io/serviceaccount/token)
    (
cat << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    server: https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_PORT_443_TCP_PORT}
  name: mycluster
contexts:
- context:
    cluster: mycluster
    namespace: default
    user: default
  name: mycluster-context
current-context: mycluster-context
kind: Config
preferences: {}
users:
- name: default
  user:
    token: ${TOKEN}
EOF
    ) > /opt/ibm/lsfsuite/lsf/conf/kube_config

}


# chk_lsb_config()  - Check for new versions of the lsb.users and lsb.queues
#                   config man files.  If there is a different sync up and reconfig
#                   An optional arguemnt controls when a reconfig is done
function chk_lsb_config()
{
    if [ ${DEPLOYMENT_TYPE} != "podscheduler" ]; then
        return
    fi

    local NORECONFIG=$1
    local LSFCONF=/opt/ibm/lsfsuite/lsf/conf 
    local LSBDIR=/opt/ibm/lsfsuite/lsf/conf/lsbatch/${CLUSTERNAME}/configdir
    local DORECONFIG=0

    diff -q /opt/ibm/lsfsuite/configmap/lsf.conf/lsf.conf ${LSFCONF}/lsf.conf >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsf.conf detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsf.conf/lsf.conf ${LSFCONF}/lsf.conf 
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.applications/lsb.applications ${LSBDIR}/lsb.applications >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.applications detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.applications/lsb.applications ${LSBDIR}/lsb.applications
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.hosts/lsb.hosts ${LSBDIR}/lsb.hosts >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.hosts detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.hosts/lsb.hosts ${LSBDIR}/lsb.hosts
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.queues/lsb.queues ${LSBDIR}/lsb.queues >/dev/null 2>&1
    if [ $? -ne 0 ]; then
	log_info "chk_lsb_config:  New lsb.queues detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.queues/lsb.queues ${LSBDIR}/lsb.queues
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.resources/lsb.resources ${LSBDIR}/lsb.resources >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.resources detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.resources/lsb.resources ${LSBDIR}/lsb.resources 
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.users/lsb.users ${LSBDIR}/lsb.users >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.users detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.users/lsb.users ${LSBDIR}/lsb.users
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.paralleljobs/lsb.paralleljobs ${LSBDIR}/lsb.paralleljobs >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.paralleljobs detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.paralleljobs/lsb.paralleljobs ${LSBDIR}/lsb.paralleljobs
    fi
    diff -q /opt/ibm/lsfsuite/configmap/lsb.params/lsb.params ${LSBDIR}/lsb.params >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_info "chk_lsb_config:  New lsb.params detected"
        DORECONFIG=1
        cp /opt/ibm/lsfsuite/configmap/lsb.params/lsb.params ${LSBDIR}/lsb.params
    fi
    if [ -z "$NORECONFIG" ]; then
        if [ "$DORECONFIG" = "1" ]; then
	        log_info "    chk_lsb_config:  Reconfiguring"
            badmin mbdrestart -f -C "New config"
        fi
    fi
}


# reconfig_master - This function will remove the old masters entries
#                   from the lsf.conf, lsb.hosts, lsf.cluster.__ and
#                   hosts files.  I will then update them with the 
#                   new hostname and IP(s).  It will then restart 
#                   the LSF master processes, and create the flag file
#                   to trigger the slave compute nodes to restart.
function reconfig_master()
{
    log_info "Entered:  reconfig_master"
    log_info "    Stopping LSF master"
    stop_lsf
    log_info "    updating ${IMAGE_HOST} in lsf.cluster.__ to ${NEWHOST}"
    sed -i -e "s:^${IMAGE_HOST}:${NEWHOST}:g" $HOME_DIR/lsf/conf/lsf.cluster.${CLUSTERNAME}    
    log_info "    updating lsf.conf and ego.conf"
    # sed -i -e s:^LSF_MASTER_LIST=.*:LSF_MASTER_LIST=\"$NEWHOST\":g ${LSF_CONF}/lsf.conf
    sed -i -e s:^EGO_MASTER_LIST=.*:EGO_MASTER_LIST=\"$NEWHOST\":g ${LSF_CONF}/ego/${CLUSTERNAME}/kernel/ego.conf
    sed -i -e s:^MASTER_LIST=.*:MASTER_LIST=\"$NEWHOST\":g ${LSF_CONF}/lsf.conf
    log_info "    updating lsb.hosts"
    sed -i -e "s:^master_hosts.*:master_hosts   (${NEWHOST}):g" ${LSF_CONF}/lsbatch/${CLUSTERNAME}/configdir/lsb.hosts
    grep -v "${IMAGE_HOST}" ${LSF_CONF}/hosts > ${LSF_CONF}/hosts.BAK
    mv ${LSF_CONF}/hosts.BAK ${LSF_CONF}/hosts
    log_info "    regenerating lock"
    generate_lock    
    log_info "    starting LSF master"
    start_lsf
    log_info "Finished:  reconfig_master"
}


#
# prep_master  - Prepare the LSF conf and other directories with initial contents
#
function prep_master()
{
    log_info "Running:  prep_master()"
    log_info "    prep_master:  HOME_DIR=$HOME_DIR"
    log_info "    prep_master:  LSF_TOP=$LSF_TOP"
    
    if [ ! -d "$LSF_TOP" ]; then
        log_info "    prep_master: Can't find $LSF_TOP.  Is this an LSF image"
    fi

    local HOMECONF=$HOME_DIR/lsf/conf
    local HOMELSBC=$HOME_DIR/lsf/conf/lsbatch/${CLUSTERNAME}/configdir

    # Fix the shared directories since we have mounted over them
    if [ ! -d /opt/ibm/lsfsuite/lsfadmin ]; then
        mkdir -p /opt/ibm/lsfsuite/lsfadmin
        cp /etc/skel/.* /opt/ibm/lsfsuite/lsfadmin/
        chown -R lsfadmin /opt/ibm/lsfsuite/lsfadmin
    fi

    # Make directories as needed
    test -d ${HOMECONF} || mkdir -p ${HOMECONF}
    test -d $HOME_DIR/lsf/work || mkdir -p $HOME_DIR/lsf/work
    test -d ${HOMECONF}/.reconfighosts || mkdir -p ${HOMECONF}/.reconfighosts

    # Log an error if the PV is bad
    if [ ! -d ${HOMECONF} ]; then
        log_error "The Persistent Volume (PV) used by the cluster does not appear to be correct."
        log_error "It needs to be writable, and for NFS PVs should have UID 495."
        log_error "Pod will die in 60 seconds"
        sleep 60
        exit 9
    fi

    log_info "    prep_master: Check Persistent Volume can be written to.."
    touch ${HOMECONF}/hosts
    log_info "    prep_master: The persistent volume is writable"

    # Make the conf dir in the correct location if needed
    if [ ! -e ${HOMECONF}/lsf.conf ]; then
        # Create initial contents
        log_info "    prep_master: Create initial contents"
        cp -nar $LSF_TOP/.conf_tmpl/* ${HOMECONF}
        mv ${HOMECONF}/lsf.cluster.myCluster ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
        mv ${HOMECONF}/ego/myCluster ${HOMECONF}/ego/${CLUSTERNAME}
        mv ${HOMECONF}/lsbatch/myCluster ${HOMECONF}/lsbatch/${CLUSTERNAME}
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/profile.lsf
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/lsf.shared
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/lsf.conf
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/cshrc.lsf
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/trigger-reconfig.sh
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/ego/myCluster/eservice/esc/conf/services/named.xml
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/ego/myCluster/eservice/esd/conf/named/conf/named.conf
        sed -i -e "s^myCluster^${CLUSTERNAME}^g" ${HOMECONF}/ego/myCluster/kernel/ego.conf
        cp -nar $LSF_TOP/.work/* $HOME_DIR/lsf/work
        mv $HOME_DIR/lsf/work/myCluster $HOME_DIR/lsf/work/${CLUSTERNAME}

        # Change ownership for Gluster
	    log_info "    prep_master: Setting root as owner"
        local HERE=$(pwd)
	    cd ${HOMECONF}
	    chown -R root *
        find . -type f -exec chmod 664 {} \;
        find . -type d -exec chmod 755 {} \;
        chmod a+x ./profile.lsf ./cshrc.lsf ./trigger-reconfig.sh	
        cd ${HERE}

        if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
            # Move off the lsb.users and lsb.queues.  They are in a configmap
            mv ${HOMELSBC}/lsb.applications ${HOMELSBC}/lsb.applications.ORIG
            mv ${HOMELSBC}/lsb.hosts ${HOMELSBC}/lsb.hosts.ORIG
            mv ${HOMELSBC}/lsb.queues ${HOMELSBC}/lsb.queues.ORIG
            mv ${HOMELSBC}/lsb.users ${HOMELSBC}/lsb.users.ORIG
        fi

        # Clean the hostcache
        mkdir -p $HOME_DIR/lsf/work/${CLUSTERNAME}/ego/lim
        cat /dev/null > $HOME_DIR/lsf/work/${CLUSTERNAME}/ego/lim/hostcache

        # Change permissions
        # chown -R lsfadmin $HOME_DIR/lsf
    else
        log_info "    prep_master: Existing contents!!!  Failover?"
    fi

    # Make the links to the proper location
    if [ ! -e $LSF_TOP/conf/lsbatch ]; then
        log_info "    prep_master: Setting up symbolic link for LSF conf"
        ln -s ${HOMECONF}/ /$LSF_TOP/
    else
        log_info "    prep_master: link to $LSF_TOP/conf already exists.  Master failover!"
    fi
    if [ ! -e $LSF_TOP/work ]; then
        log_info "    prep_master: Setting up symbolic link for LSF work"
        ln -s $HOME_DIR/lsf/work/ /$LSF_TOP/
    fi

    # Create the hosts file
    #cat /etc/hosts |grep $MYHOST > ${HOMECONF}/hosts
    cp /etc/hosts /etc/hosts.ORIG
    touch ${HOMECONF}/hosts

    # Maybe using existing conf so update the MASTER host
    # sed -i -e s:^LSF_MASTER_LIST=.*:LSF_MASTER_LIST=\"$MYHOST\":g ${HOMECONF}/lsf.conf
    sed -i -e s:^EGO_MASTER_LIST=.*:EGO_MASTER_LIST=\"$MYHOST\":g ${HOMECONF}/ego/${CLUSTERNAME}/kernel/ego.conf
    sed -i -e s:^MASTER_LIST=.*:MASTER_LIST=\"$MYHOST\":g ${HOMECONF}/lsf.conf
    sed -i -e s:^LSF_SERVER_HOSTS=.*:LSF_SERVER_HOSTS=\"$MYHOST\":g ${HOMECONF}/lsf.conf

    if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
        # Enable Kubernetes scheduling module
        log_info "    prep_master:  Enabling Kubernetes"
        local HAVECCFG=$(grep -c LSF_GET_CPU_MEM_FROM_CONTAINER ${HOMECONF}/lsf.conf)
        if [ "${HAVECCFG}" = "0" ]; then
            echo "LSF_GET_CPU_MEM_FROM_CONTAINER=N" >> ${HOMECONF}/lsf.conf
        else
            sed -i -e s:LSF_GET_CPU_MEM_FROM_CONTAINER.*:LSF_GET_CPU_MEM_FROM_CONTAINER=N:g ${HOMECONF}/lsf.conf
        fi

        log_info "    prep_master:  Modifing lsbatch/${CLUSTERNAME}/configdir/lsb.modules"
        grep "^schmod_kubernetes" ${HOMELSBC}/lsb.modules ||sed -i -e "s:^End\ PluginModule.*:schmod_kubernetes\ \ \ \ \(\)\ \ \ \ \(\)\nEnd\ PluginModule:g" ${HOMELSBC}/lsb.modules
        grep "^schmod_resourceplan" ${HOMELSBC}/lsb.modules ||sed -i -e "s:^End\ PluginModule.*:schmod_resourceplan\ \ \ \ \(\)\ \ \ \ \(\)\nEnd\ PluginModule:g" ${HOMELSBC}/lsb.modules

        local HAVERESOURSE=$(grep -c kube_name ${HOMECONF}/lsf.shared)
        if [ "$HAVERESOURSE" = "0" ]; then
            # Config for ICP integration
            log_info "    prep_master:  Configuring resource map"
            sed -i -e "s:End\ Resource:   kube_name  String  ()       ()          (Kubernetes node name)\nEnd\ Resource\n:g" ${HOMECONF}/lsf.shared
            sed -i -e "s:End\ Resource:   kubernetes Boolean ()       ()          (kubernetes node)\n   icpcpu     Numeric ()       N           (CPU metric for ICP)\nEnd\ Resource\n:g" ${HOMECONF}/lsf.shared
            sed -i -e "s:End\ Resource:   servicepod Numeric ()       Y           (Counter for running service pods)\n   computepod Numeric ()       Y           (Counter for running compute pods)\nEnd\ Resource\n:g" ${HOMECONF}/lsf.shared
        fi

        local HAVERESOURSE=$(grep -c rack_name ${HOMECONF}/lsf.shared)
        if [ "$HAVERESOURSE" = "0" ]; then
            # Config for ICP integration
            log_info "    prep_master:  Configuring resource map 2"
            sed -i -e "s:End\ Resource:   rack_name  String  ()       ()          (The rack of each host belongs to)\n   zone_name  String  ()       ()          (The zone of each host belongs to)\nEnd\ Resource\n:g" ${HOMECONF}/lsf.shared
        fi

        # Add resource map entries
        HAVERESOURCE=$(grep -c servicepod ${HOMECONF}/lsf.cluster.${CLUSTERNAME})
        if [ "$HAVERESOURCE" = "0" ]; then
            # Config for app profile demos
            log_info "    prep_master:  Configuring lsf.cluster.${CLUSTERNAME}"
            echo "" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
            echo "Begin ResourceMap" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
            echo "RESOURCENAME  LOCATION" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
            echo "servicepod      (0@[default])" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
            echo "computepod      (0@[default])" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
            echo "End ResourceMap" >> ${HOMECONF}/lsf.cluster.${CLUSTERNAME}
        fi

        chk_lsb_config NORECONFIG
    else
        log_info "    prep_master:  LSF cluster type"
        # Add config that is usually provided by the configMap
        local LSFCONF=${HOMECONF}/lsf.conf
        # Enable GPU features
        grep "LSB_GPU_NEW_SYNTAX=extend" ${LSFCONF} || echo "LSB_GPU_NEW_SYNTAX=extend" >> ${LSFCONF}
        grep "LSF_GPU_AUTOCONFIG=Y" ${LSFCONF} || echo "LSF_GPU_AUTOCONFIG=Y" >> ${LSFCONF}

        # Switch to TCP transport for LIM
        grep "LSF_CALL_LIM_WITH_TCP=Y" ${LSFCONF} || echo "LSF_CALL_LIM_WITH_TCP=Y" >> ${LSFCONF}
        grep "LSF_ANNOUNCE_MASTER_TCP_WAITTIME=0" ${LSFCONF} || echo "LSF_ANNOUNCE_MASTER_TCP_WAITTIME=0" >> ${LSFCONF}

        # Enable EGO
        log_info "    Enabling EGO"
        sed -i -e 's:LSF_ENABLE_EGO.*:LSF_ENABLE_EGO=Y:g' ${LSFCONF}
    fi
 
    add_gpu_elim_conf

    log_info "Finished:  prep_master()"
}


# add_exechosts - This function will add nodes to the LSF masters config
#                 It will read the contents of the tmp/hosts.m2
#                 It will ignore hosts that have a null Pod IP, and
#                 add the others to the lsf.cluster file, provided it is
#                 not there already.
function add_exechosts()
{
    log_info "Running:  add_exechosts"
    LSF_TOP="/opt/ibm/lsfsuite/lsf"    # Something clobbered the LSF_TOP!!!
    local CURR_IFS=$IFS
    local HOSTS_OUT=$(</tmp/hosts.m2)
    local HOSTS_LINES=( )
    local THIS_LINE=( )
    local THIS_IP=""
    local THIS_HNAME=""
    local THIS_ALT_HNAME=""
    local THIS_RES=""
    local THIS_ROLE=""
    IFS=$'\n'
    HOSTS_LINES=( $HOSTS_OUT )
    for ((i=0; i < ${#HOSTS_LINES[*]}; i++)); do
        log_info "    add_exechosts: line: ${HOSTS_LINES[$i]}"
        IFS=$' \t'
        THIS_LINE=( ${HOSTS_LINES[$i]} )
        log_info "    add_exechosts: THIS_LINE[0]=${THIS_LINE[0]}  THIS_LINE[1]=${THIS_LINE[1]}"
	    if [ -z "${THIS_LINE[0]}" ]; then
            continue
        fi
        if [ "${THIS_LINE[0]}" = "null" ]; then
            log_info "    Ignoring line: $THIS_LINE"
            continue
        fi
        THIS_HNAME="${THIS_LINE[1]}"
        THIS_ALT_HNAME="${THIS_LINE[6]}"
	    log_info "    add_exechosts: Checking for lsfmaster.  Have: ${THIS_HNAME}"
        if [ "${THIS_HNAME}" = "lsfmaster" ]; then
            log_info "    add_exechosts: ignoring lsfmaster"
            continue
        fi        

        # Ignore this entry if we have it already
        grep -c "${THIS_HNAME}" $LSF_CONF/lsf.cluster.${CLUSTERNAME} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "    add_exechosts: Have entry for ${THIS_HNAME}"
            continue
        fi

        if [ ${DEPLOYMENT_TYPE} = "podscheduler" ]; then
            # We need the IP address for LSF.  Get it from the names
            # OpenShift uses a different naming convention than ICP.  Have to deal with it here
            log_info "    add_exechosts:  THIS_ALT_HNAME=${THIS_ALT_HNAME}"
            if [ "${THIS_ALT_HNAME}" != "null" ]; then
                THIS_IP=${THIS_ALT_HNAME}
                log_info "    add_exechosts: OpenShift host naming"
            else
                # NOTE:  If you change the host name this as to change too
                THIS_IP=$( echo "$THIS_HNAME" |tr '-' '.' |sed -e s:worker\.::g)
                log_info "    add_exechosts: ICP host naming"
            fi
            sed -i -e "s:^End.*Host:${THIS_HNAME} ! ! 1 (kubernetes kube_name=${THIS_IP})\nEnd    Host:g" $HOME_DIR/lsf/conf/lsf.cluster.${CLUSTERNAME}
            log_info "    add_exechosts:  Adding to cluster file: ${THIS_HNAME} ! ! 1 (kubernetes kube_name=${THIS_IP})"
        else
            THIS_RES=$( grep ${THIS_HNAME} /tmp/host-resource.map |cut -d' ' -f2- |tr -d '"' )
            THIS_ROLE="${THIS_LINE[3]}"
#            if [ "${THIS_ROLE}" = "gui" ]; then
#                sed -i -e "s:^End.*Host:${THIS_HNAME} ! ! 0 (${THIS_RES})\nEnd    Host:g" $HOME_DIR/lsf/conf/lsf.cluster.${CLUSTERNAME}
#                log_info "    add_exechosts:  Adding to cluster file: ${THIS_HNAME} ! ! 0 (${THIS_RES})"
#            else
                sed -i -e "s:^End.*Host:${THIS_HNAME} ! ! 1 (${THIS_RES})\nEnd    Host:g" $HOME_DIR/lsf/conf/lsf.cluster.${CLUSTERNAME}
                log_info "    add_exechosts:  Adding to cluster file: ${THIS_HNAME} ! ! 1 (${THIS_RES})"
#            fi
        fi

    done
    IFS=$CURR_IFS
    log_info "Finished: add_exechosts"
}


# MASTER ONLY: Read Environment Variable "ENV_ADD_ADMIN_LIST" & if set, then add admins to files:
#     /opt/ibm/lsfsuite/lsf/conf/lsf.cluster.${CLUSTERNAME}
#     /opt/ibm/lsfsuite/lsf/conf/lsbatch/${CLUSTERNAME}/configdir/lsb.users
# This function adds only new unique admins (avoiding duplicates)
# [https://github.ibm.com/platformcomputing/k8s-batch-driver/issues/169]
function add_new_unique_admins () {
    log_info "Running:  add_new_unique_admins()"
    new_admins="$(echo ${ENV_ADD_ADMIN_LIST})"
    if [ "${new_admins}" = "" ]; then
        log_info "    add_new_unique_admins: Environment Variable is blank. No admins to add. Returning ..."
        log_info "Finished:  add_new_unique_admins()"
        return
    else
        log_info "    add_new_unique_admins: Environment Variable is SET: >>${new_admins}<< ... Proceeding ..."
    fi

    cluster_file="/opt/ibm/lsfsuite/lsf/conf/lsf.cluster.${CLUSTERNAME}"
    lsb_users_file="/opt/ibm/lsfsuite/lsf/conf/lsbatch/${CLUSTERNAME}/configdir/lsb.users"

    cluster_existing_line="$(cat ${cluster_file} | grep 'Administrators\s*=')"
    cluster_split_str_eq="$(echo $cluster_existing_line | tr "=" " ")"
    cluster_existing_admins="$(echo $cluster_split_str_eq | awk '{ for(i=2;i<=NF;++i) { if( i==NF ) { printf $i } else { printf $i""FS } } ; print "" }')"

    lsb_existing_line="$(cat ${lsb_users_file} | grep 'lsfadmins\s*(')"
    lsb_existing_line_awk="$(cat ${lsb_users_file} | grep 'lsfadmins\s*(' | awk '{ for(i=1;i<NF;++i) { if( i==NF-1 ) { printf $i } else { printf $i""FS } } ; print "" }')"
    lsb_split_str_op="$(echo $lsb_existing_line | tr "(" " ")"
    lsb_existing_admins="$(echo $lsb_split_str_op | awk '{ for(i=2;i<NF;++i) { if( i==NF-1 ) { printf $i } else { printf $i""FS } } ; print "" }')"

    log_info "    add_new_unique_admins: >>${cluster_file}<< | >>${lsb_users_file}<<"
    log_info "    add_new_unique_admins: cluster exist line/users: >>${cluster_existing_line}<< | >>${cluster_existing_admins}<<"
    log_info "    add_new_unique_admins: lsb exist line/users: >>${lsb_existing_line}<< | >>${lsb_existing_line_awk}<< | >>${lsb_existing_admins}<<"

    cluster_unique_new_admins=""
    if [ "${cluster_existing_line}" = "" ]; then
        # Cluster file does not contain any admins.
        # So all new-admins are unique admins
        cluster_unique_new_admins=${new_admins}
    else
        # Cluster file already contain some Admins.
        # Looping through New-Admins & Cross-Referencing with Existing Cluster Admins
        # to eliminate duplicates, and only add Unique New Admins
        for cur_new_admin in $new_admins
        do
            elimdup_newadmin_forcluster="no"
            for cluster_cur_exist_admin in $cluster_existing_admins
            do
                if [ "${cur_new_admin}" = "${cluster_cur_exist_admin}" ]; then
                    elimdup_newadmin_forcluster="yes"
                    break
                fi
            done

            if [ "${elimdup_newadmin_forcluster}" = "no" ]; then
                if [ "${cluster_unique_new_admins}" = "" ]; then
                    cluster_unique_new_admins="${cur_new_admin}"
                else
                    cluster_unique_new_admins="${cluster_unique_new_admins} ${cur_new_admin}"
                fi
            fi
        done
    fi

    lsb_unique_new_admins=""
    if [ "${lsb_existing_line}" = "" ]; then
        # Cluster file does not contain any admins.
        # So all new-admins are unique admins
        lsb_unique_new_admins=${new_admins}
    else
        # LSB file already contain some Admins.
        # Looping through New-Admins & Cross-Referencing with Existing LSB Admins
        # to eliminate duplicates, and only add Unique New Admins
        for cur_new_admin in $new_admins
        do
            elimdup_newadmin_forlsb="no"
            for lsb_cur_exist_admin in $lsb_existing_admins
            do
                if [ "${cur_new_admin}" = "${lsb_cur_exist_admin}" ]; then
                    elimdup_newadmin_forlsb="yes"
                    break
                fi
            done

            if [ "${elimdup_newadmin_forlsb}" = "no" ]; then
                if [ "${lsb_unique_new_admins}" = "" ]; then
                    lsb_unique_new_admins="${cur_new_admin}"
                else
                    lsb_unique_new_admins="${lsb_unique_new_admins} ${cur_new_admin}"
                fi
            fi
        done
    fi

    log_info "    add_new_unique_admins: cluster_unique_new_admins: >>${cluster_unique_new_admins}<< ... lsb_unique_new_admins: >>${lsb_unique_new_admins}<<"

    # Adding admins to Cluster file
    insert_line_cluster_file="Administrators = lsfadmin mblack ${new_admins}"
    if [ "${cluster_existing_line}" = "" ]; then
        log_info "    add_new_unique_admins: Inserting line: >>${insert_line_cluster_file}<< into file: >>${cluster_file}<<"
        echo "${insert_line_cluster_file}" >> ${cluster_file}
    else
        log_info "    add_new_unique_admins: Cluster file >>${cluster_file}<< already contains a line with Admins: >>${cluster_existing_line}<<"
        if [ "${cluster_unique_new_admins}" = "" ]; then
            log_info "    add_new_unique_admins: NO unique new cluster admins found. All new-admins are already present in existing cluster admins."
        else
            log_info "    add_new_unique_admins: Appending new-unique-admin-users to existing admin-users in Cluster file ..."
            insert_line_cluster_file="${cluster_existing_line} ${cluster_unique_new_admins}"
            sed -i -e s:"${cluster_existing_line}":"${insert_line_cluster_file}":g ${cluster_file}
        fi
    fi

    # Adding admins to lsb.users file
    insert_line_lsb_users_file="lsfadmins (lsfadmin mblack ${new_admins} )"
    if [ "${lsb_existing_line_awk}" = "" ]; then
        log_info "    add_new_unique_admins: Inserting line: >>${insert_line_lsb_users_file}<< into file: >>${lsb_users_file}<<"
        echo "${insert_line_lsb_users_file}" >> ${lsb_users_file}
    else
        log_info "    add_new_unique_admins: LSB Users file >>${lsb_users_file}<< already contains a line with Admins: >>${lsb_existing_line_awk}<<"
        if [ "${lsb_unique_new_admins}" = "" ]; then
            log_info "    add_new_unique_admins: NO unique new LSB user admins found. All new-admins are already present in existing LSB user admins."
        else
            log_info "    add_new_unique_admins: Appending new-unique-admin-users to existing admin-users in LSB users file..."
            insert_line_lsb_users_file="${lsb_existing_line_awk} ${lsb_unique_new_admins} )"
            sed -i -e s:"${lsb_existing_line}":"${insert_line_lsb_users_file}":g ${lsb_users_file}
        fi
    fi

    log_info "    add_new_unique_admins: Displaying resulting Cluster & LSB Users files (with grep)"
    log_info "    add_new_unique_admins: >>$(cat ${cluster_file} | grep 'Administrators\s*=')<<"
    log_info "    add_new_unique_admins: >>$(cat ${lsb_users_file} | grep 'lsfadmins\s*(')<<"

    log_info "    add_new_unique_admins: Un-setting environment variable >>${ENV_ADD_ADMIN_LIST}<< ... >>$(env | grep ENV_ADD_ADMIN_LIST)<<"
    unset ENV_ADD_ADMIN_LIST
    log_info "    add_new_unique_admins: Environment variable unset: >>${ENV_ADD_ADMIN_LIST}<< ... >>$(env | grep ENV_ADD_ADMIN_LIST)<<"
    log_info "Finished:  add_new_unique_admins()"
}


###################################################################################
###############################  main  ############################################
###################################################################################

############## CMD parameter from docker run ##########

ROLE=$1
DIE_ON_FAIL=$2
if [ -z "$ROLE" -o "$ROLE" = "" ]; then
    # Looks like we are debugging
    ROLE=debug
    DIE_ON_FAIL=no
fi

# Override PRODUCT name
if [ "$3" != "" ]; then
    PRODUCT=$3
fi
# Set the deployment type to turn on/off the K8s integration and related config
DEPLOYMENT_TYPE="podscheduler"
if [ "$4" != "" ]; then
    DEPLOYMENT_TYPE=$4
fi

#if [ -e /alt-lsf-start.sh ]; then
#    /alt-lsf-start.sh $1 $2 $3
#    RVAL=$?
#    exit $RVAL
#    log_info "Skipping"
#fi

#######################################

MYHOST=$(hostname)
NEWHOST="${MYHOST}"
HOME_DIR="/opt/ibm/lsfsuite/lsfadmin"
LSF_TOP="/opt/ibm/lsfsuite/lsf"
LSF_CONF="${LSF_TOP}/conf"
LOGFILE="/tmp/start_lsf.log"
LOCKFILE="$LSF_TOP/lsf.lock"
LIVEFILE="/tmp/lsf-alive"
READYFILE="/tmp/lsf-ready"
PAC_TOP="/opt/ibm/lsfsuite/ext"
DB_NAME="pac"
READY4LSF=no

init_log $LOGFILE
log_info "Start args: ROLE=$ROLE"
log_info "            DIE_ON_FAIL=$DIE_ON_FAIL"
log_info "            PRODUCT=$PRODUCT"
log_info "            DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE"
log_info "            CLUSTER=${CLUSTERNAME}"
log_info "            NETWORKING=${NETWORKING}"

# Make sure the ports are clear before continuing
check_ports

# Prepare the directory structure for a master, or debug host
if [ "$ROLE" = "master" -o "$ROLE" = "debug"  ]; then
    # Setup the links to the NFS directory
    prep_master

    # For MASTER, on startup, we must check the "ENV_ADD_ADMIN_LIST" environment variable
    # And if set, then we must add new admins to the lsf.cluster.${CLUSTERNAME} & lsb.users files.
    # [https://github.ibm.com/platformcomputing/k8s-batch-driver/issues/169]
    add_new_unique_admins
fi

# Get the pod list and generate a hosts file
# We can be too fast, so we need to wait
sleep 10
get_k8s_pods
gen_pod_hosts
validate_hosts
while [ ${READY4LSF} = "no" ]; do
    sleep 7
    get_k8s_pods
    gen_pod_hosts
    validate_hosts
done

update_etc_hosts

# Enable user authentication
run_authconfig
add_authconfig
start_authdaemons

if [ "$ROLE" = "master" ]; then
    # Make the kube_conf if needed
    mk_kube_conf

    # Add pod resources if needed
    add_resources

    # Check for the ${LSF_CONF}/.master-ready file.  If it exists this means
    # failover has happened.  We only need to reconfigure
    if [ -e "${LSF_CONF}/.master-ready" ]; then
        log_info "pre main loop:  This is an existing cluster!!"
        IMAGE_HOST=$(< ${LSF_CONF}/.master-ready)
        if [ "${IMAGE_HOST}" != "${MYHOST}" ]; then
            log_info "pre main loop:  EEEK!  LSF Masters hostname, and IP(s) have changed"
            log_info "pre main loop:  Old Name = $IMAGE_HOST    New Name = ${NEWHOST}"
        fi
    else
        # This is the initial startup of the LSF Master
        # The Primary master will need to setup the directory structures
        log_info "pre main loop: Setting up initial Primary Master"
        config_lsfs
    fi

    if [ "${NETWORKING}" != "k8s" ]; then
        # We need to give the pods more time to start
        sleep 60
        get_k8s_pods
        gen_pod_hosts
    fi

    # Add the discovered nodes to LSF config
    add_exechosts
    update_etc_hosts
    generate_lock
    start_lsf

elif [ "$ROLE" = "gui" ]; then
    # Configure the GUI and run
    touch "$LIVEFILE"
    init_gui_share_dir
    fix_gui_conf
    init_database
    start_pac

    touch ${READYFILE}
    start_lsf
    while true; do
        monitor_webgui
        sleep 60
    done
elif [ "$ROLE" = "test" ]; then
    # Run some tests on the image and exit
    test_image
    exit 0
elif [ "$ROLE" = "debug" ]; then
    # Do some minimal config if the prerequisites are there, but do not fail
    log_info "+++++  DEBUG MODE  +++++"
    log_info "Going to sleep"
    sleep 6000000
else
    # This is the startup of a compute node
    init_compute_share_dir
    # add_host_resource
    change_hostname
    start_lsf
fi

# Signal Kubernetes
touch $LIVEFILE
log_info "pre main loop:  LSF_TOP=${LSF_TOP}"

LPCNT=0
LSIDCNT=0
# Can't exit or container stops.  Output state and update hosts if needed
while true; do
    if test $(pgrep -f lim | wc -l) -eq 0
    then
        log_error "LIM process has exited due to a fatal error."
        log_error `tail -n 20 /opt/ibm/lsfsuite/lsf/log/lim.log.*`
        rm -f "$READYFILE"
        if [ "$DIE_ON_FAIL" = "no" ]; then
            sleep 36000
        fi
        rm -f "$LIVEFILE"
        dump_logs_stdout
        exit 9
    else
        touch "$READYFILE"
    fi

    # Will try every minute to get new hosts for 10 minutes
    # After that will switch to every 5 minutes
    LPCNT=$((${LPCNT} + 1))
    if [ ${LPCNT} -eq 6 ]; then
        LPCNT=0
        chk_hosts
        # Try lsid on the master to see if it is stuck
        if [ "$ROLE" = "master" ]; then
            lsid > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                log_error "Lsid failed! LSIDCNT=${LSIDCNT}"
                LSIDCNT=$((${LSIDCNT} + 1))
                if [ ${LSIDCNT} -eq 3 ]; then
                    rm -f "$LIVEFILE"
                    log_error "Fatal error LSF did not re-start.  Configuration may be corrupt!"
                    dump_logs_stdout
                    exit 10
                fi
            else
                LSIDCNT=0
            fi        
        fi
    fi

    if [ "$ROLE" = "master" ]; then
        # Check for new lsb.users lsb.queues lsb.hosts lsb.paralleljobs or lsb.applications
        chk_lsb_config

        # Check for the "reconfig" flag
        should_reconfig
    fi

    sleep 10
    dump_logs_stdout
done
