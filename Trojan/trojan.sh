#!/bin/bash
# Author: Jrohy
# github: https://github.com/Jrohy/trojan

#�����������, 0Ϊ��, 1Ϊ��
HELP=0

REMOVE=0

UPDATE=0

DOWNLAOD_URL="https://zgcwkj.github.io/LinuxScript/Trojan/"

SERVICE_URL="https://zgcwkj.github.io/LinuxScript/Trojan/trojan-web.service"

[[ -e /var/lib/trojan-manager ]] && UPDATE=1

#Centos ��ʱȡ������
[[ -f /etc/redhat-release && -z $(echo $SHELL|grep zsh) ]] && unalias -a

[[ -z $(echo $SHELL|grep zsh) ]] && SHELL_WAY="bash" || SHELL_WAY="zsh"

#######color code########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"
FUCHSIA="35m"

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

#######get params#########
while [[ $# > 0 ]];do
    KEY="$1"
    case $KEY in
        --remove)
        REMOVE=1
        ;;
        -h|--help)
        HELP=1
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
#############################

help(){
    echo "bash $0 [-h|--help] [--remove]"
    echo "  -h, --help           Show help"
    echo "      --remove         remove trojan"
    return 0
}

removeTrojan() {
    #�Ƴ�trojan
    rm -rf /usr/bin/trojan >/dev/null 2>&1
    rm -rf /usr/local/etc/trojan >/dev/null 2>&1
    rm -f /etc/systemd/system/trojan.service >/dev/null 2>&1

    #�Ƴ�trojan�������
    rm -f /usr/local/bin/trojan >/dev/null 2>&1
    rm -rf /var/lib/trojan-manager >/dev/null 2>&1
    rm -f /etc/systemd/system/trojan-web.service >/dev/null 2>&1

    systemctl daemon-reload

    #�Ƴ�trojan��ר��mysql
    docker rm -f trojan-mysql
    rm -rf /home/mysql >/dev/null 2>&1

    #�Ƴ���������
    sed -i '/trojan/d' ~/.${SHELL_WAY}rc
    source ~/.${SHELL_WAY}rc

    colorEcho ${GREEN} "uninstall success!"
}

checkSys() {
    #����Ƿ�ΪRoot
    [ $(id -u) != "0" ] && { colorEcho ${RED} "Error: You must be root to run this script"; exit 1; }
    if [[ $(uname -m 2> /dev/null) != x86_64 ]]; then
        colorEcho $YELLOW "Please run this script on x86_64 machine."
        exit 1
    fi

    if [[ `command -v apt-get` ]];then
        PACKAGE_MANAGER='apt-get'
    elif [[ `command -v dnf` ]];then
        PACKAGE_MANAGER='dnf'
    elif [[ `command -v yum` ]];then
        PACKAGE_MANAGER='yum'
    else
        colorEcho $RED "Not support OS!"
        exit 1
    fi
}

#��װ����
installDependent(){
    if [[ ${PACKAGE_MANAGER} == 'dnf' || ${PACKAGE_MANAGER} == 'yum' ]];then
        ${PACKAGE_MANAGER} install socat bash-completion -y
    else
        ${PACKAGE_MANAGER} update
        ${PACKAGE_MANAGER} install socat bash-completion -y
    fi
}

setupCron() {
    if [[ `crontab -l 2>/dev/null|grep acme` && -z `crontab -l 2>/dev/null|grep trojan-web` ]]; then
        #���㱱��ʱ������3��ʱVPS��ʵ��ʱ��
        ORIGIN_TIME_ZONE=$(date -R|awk '{printf"%d",$6}')
        LOCAL_TIME_ZONE=${ORIGIN_TIME_ZONE%00}
        BEIJING_ZONE=8
        BEIJING_UPDATE_TIME=3
        DIFF_ZONE=$[$BEIJING_ZONE-$LOCAL_TIME_ZONE]
        LOCAL_TIME=$[$BEIJING_UPDATE_TIME-$DIFF_ZONE]
        if [ $LOCAL_TIME -lt 0 ];then
            LOCAL_TIME=$[24+$LOCAL_TIME]
        elif [ $LOCAL_TIME -ge 24 ];then
            LOCAL_TIME=$[$LOCAL_TIME-24]
        fi
        crontab -l 2>/dev/null|sed '/acme.sh/d' > crontab.txt
        echo "0 ${LOCAL_TIME}"' * * * systemctl stop trojan-web && "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null && systemctl start trojan-web' >> crontab.txt
        crontab crontab.txt
        rm -f crontab.txt
    fi
}

installTrojan(){
    local SHOW_TIP=0
    if [[ $UPDATE == 1 ]];then
        systemctl stop trojan-web >/dev/null 2>&1
        rm -f /usr/local/bin/trojan
    fi
    echo "�������ع������..."
    curl -L "$DOWNLAOD_URL/trojan" -o /usr/local/bin/trojan
    chmod +x /usr/local/bin/trojan
    if [[ ! -e /etc/systemd/system/trojan-web.service ]];then
        SHOW_TIP=1
        curl -L $SERVICE_URL -o /etc/systemd/system/trojan-web.service
        systemctl daemon-reload
        systemctl enable trojan-web
    fi
    #���ȫ��������
    [[ -z $(grep trojan ~/.${SHELL_WAY}rc) ]] && echo "source <(trojan completion ${SHELL_WAY})" >> ~/.${SHELL_WAY}rc
    source ~/.${SHELL_WAY}rc
    if [[ $UPDATE == 0 ]];then
        colorEcho $GREEN "��װtrojan�������ɹ�!\n"
        echo -e "��������`colorEcho $BLUE trojan`�ɽ���trojan����\n"
        /usr/local/bin/trojan
    else
        if [[ `cat /usr/local/etc/trojan/config.json|grep -w "\"db\""` ]];then
            sed -i "s/\"db\"/\"database\"/g" /usr/local/etc/trojan/config.json
            systemctl restart trojan
        fi
        colorEcho $GREEN "����trojan�������ɹ�!\n"
    fi
    setupCron
    systemctl restart trojan-web
    [[ $SHOW_TIP == 1 ]] && echo "���������'`colorEcho $BLUE https://����`'������trojan���û�����"
}

main(){
    [[ ${HELP} == 1 ]] && help && return
    [[ ${REMOVE} == 1 ]] && removeTrojan && return
    [[ $UPDATE == 0 ]] && echo "���ڰ�װtrojan�������.." || echo "���ڸ���trojan�������.."
    checkSys
    [[ $UPDATE == 0 ]] && installDependent
    installTrojan
}