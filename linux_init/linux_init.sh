#!/bin/bash
file_dir='/opt/liangbo/folder'
#####################公共函数，程序执行提示信息############################
#1 步骤输出 紫色
#2 正确输出 绿色
#3 错误输出 红色
#4 提示输出 蓝色
#5 警告输出 黄色
############################################################################
function echo_fun(){
  if [ $# -ge 2 ];then
     params_num=$1
     shift 1
     params_mes=$@
  else
    echo_fun 3 请至少输入两个参数 echo_fun ...
    exit
  fi
  case $params_num in
        1)
        echo -e "\033[35;40;1m  ***************************** ${params_mes} *****************************\033[0m\r\n"
        ;;
        2)
        echo -e "\033[32;40;1m ${params_mes}\033[0m\r\n"
        ;;
        3)
        echo -e "\033[31;40;1m ${params_mes}\033[0m\r\n"
        ;;
        4)
        echo -e "\033[36;40;1m ${params_mes}\033[0m\r\n"
        ;;
        5)
        echo -e "\033[33;40;1m ${params_mes} \033[0m\r\n"
        ;;
        *)
        echo_fun 3 参数异常第一个参数应为1,2,3,4,5
        ;;
   esac
}
#####################公共函数，免密配置提示信息#################################
# 9 --> 密码错误
# 8 --> ip/hostname 错误
# 7 --> passwd
# 6 --> Connection timed out
# 2 --> 已经做过的ssh-keygen 不在做了
# 1 --> 新做的ssh-keygen
################################################################################
function show_result(){ 
  if [ $# -ge 2 ];then
     params_num=$1
     shift 1
     params_mes=$@
  else
    echo_fun 3 请至少输入两个参数 show_result ..
    exit
  fi
 
  case $params_num in
    0)
        echo_fun 2  "${params_mes[*]} [ success ]"
    ;;
 
    1)
        echo_fun 2  "${params_mes[*]} [ success ]"
    ;;
 
    2)
        echo_fun 2  "${params_mes[*]} [ success ]"
     ;;
    6)
        echo_fun 3  "${params_mes[*]}  [ failed ] : Connection timed out"
        return 6
    ;;
    7)
        echo_fun 3  "${params_mes[*]}  [ failed ] : Connection refused(ssh 端口是否正确)"
        return 7
    ;;
    8)
        echo_fun 3  "${params_mes[*]}   [ failed ] : No route to host(ip地址是否正确)"
        return 8
    ;;
    9)
        echo_fun 3  "${params_mes[*]}  [ failed ] : Permission denied(密码错误)"
        return 9
    ;;
    *)
        echo_fun 3  "${params_mes[*]} [ failed ] : 未知的错误"
        return 9
    ;;
  esac
}
#####################第一步：遍历host文件，生成秘钥#############################################
#1，定义list_ssh_keygen函数，实现遍历hosts文件
#2，执行step_fun_1函数，执行批量登录以及秘钥生成
#################################################################################################

############遍历hosts文件###############
function list_ssh_keygen(){
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`ssh_keygen_exec $IP $PASSWD`           #批量登录，生成秘钥
      RES=$?
      MESSAGE="keygen-->root@$IP"
      show_result  $RES  $MESSAGE            #返回单次循环结果   
      if [ $RES != "0" ];then
        return "$RES"
        break
      fi
    done < /opt/liangbo/hosts
}
############远程登录函数#############
function ssh_keygen_exec(){
  expect -c"
    spawn ssh -l root@$IP ssh-keygen
      set timeout 30
      expect {
        \"*Permission denied, please try again*\" {puts \"fail\";exit 9 }
        \"*Connection refused*\" {puts \"fail\";exit 7 }
        \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
        \"*password*\" {send \"$PASSWD\r\";exp_continue}
        \"Enter file in which to save the key*\" {send \"\r\";exp_continue}
        \"Enter passphrase*\" {send \"\r\";exp_continue}
        \"Enter same passphrase again*\" {send \"\r\";puts \"success\";exit 1}
        \"Overwrite (y/n)*\" {send \"n\r\";puts \"success\";exit 2}
        \"*No route to host*\" {puts \"fail\";exit 8}
        \"*Connection timed out*\" {puts \"fail\";exit 6}
      }
  "
}
########开始配置免密################
function step_fun_1(){
echo_fun 1 第一步,生成秘钥对
if [ "`rpm -qa |grep expect`" = "" ];then
  echo_fun 4 yum安装expect...
  yum clean all;yum repolist >/dev/null 2>&1
  yum install expect -y  >/dev/null 2>&1
  if [ `echo $?` != 0 ];then
    echo_fun 5 expect安装失败请检查yum源
    exit
  fi
fi
  list_ssh_keygen        # 公共函数 遍历hosts
  RES=$?
  if [ $RES != 0 ];then
     echo -e "\033[33;40;1m>>Please check '/opt/liangbo/hosts' file<<   Retry(yes/no)?\033[0m"
     read  name
     if [ $name = "no" ];then
       echo_fun 5 "当前执行第 1 步,如果继续执行请重新运行脚本 bash linux_init.sh "
       exit
     elif [ $name = "yes" ];then
       step_fun_1
     else
      step_fun_1
    fi
  fi
  echo -e "\r\n"
}
#####################第二步：配置免密########################################################
#
#############################################################################################
function step_fun_2(){
  echo_fun 1 第二步,配置免密
  echo_fun 4 "当前机器`hostname`"
  ssh_copyid_fun
}
 
###########循环遍历 做单项免密###############
function ssh_copyid_fun(){
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      # 免秘钥  ~/.ssh/id_rsa.pub
      res=`expect -c " 
        spawn ssh-copy-id  root@$IP 
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";exp_continue}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
   RESULT=$?
   MESSAGE="免密-->root@$IP"
   show_result  $RESULT $MESSAGE
  if [ $RESULT -ne 0 ];then
     echo_fun 5 "当前执行第 2 步,如果继续执行请重新运行脚本 bash linux_init.sh "
     exit
  fi
done < /opt/liangbo/hosts
}
#####################第三步：文件下发########################################################
#
#############################################################################################

function step_fun_3(){
  echo_fun 1 第三步,文件下发
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
    ##########文件下发###############
	    scp $file_dir/*  $IP:/root > /dev/null
	    RESULT=$?
	    MESSAGE="文件下发-->$IP "
	    show_result  $RESULT $MESSAGE
	    if [ $RESULT -ne 0 ];then
	        echo_fun 5 "当前执行第 3 步,如果继续执行请重新运行脚本 bash linux_init.sh "
	        exit
	    fi
  done < /opt/liangbo/hosts 
}

#####################第四步：基线加固########################################################
#
#############################################################################################

function step_fun_4(){
  echo_fun 1 第四步：基线加固
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`expect -c " 
        spawn ssh root@$IP  bash func_scripts.sh safety
        set timeout 30
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";puts \"success\";exit 1}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
	    RESULT=$?
	    MESSAGE="基线加固-->$IP"
	    show_result  $RESULT $MESSAGE
	    if [ $RESULT -ne 0 ];then
	        echo_fun 5 "当前执行第 4 步,如果继续执行请重新运行脚本 bash linux_init.sh "
	        exit
	    fi
  done < /opt/liangbo/hosts 
}
#####################第五步：主机yum配置########################################################
#
#############################################################################################

function step_fun_5(){
  echo_fun 1 第五步：主机Yum配置
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`expect -c " 
        spawn ssh root@$IP  bash func_scripts.sh yum
        set timeout 30
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";puts \"success\";exit 1}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
      RESULT=$?
      MESSAGE="主机Yum配置-->$IP"
      show_result  $RESULT $MESSAGE
      if [ $RESULT -ne 0 ];then
          echo_fun 5 "当前执行第 5 步,如果继续执行请重新运行脚本 bash linux_init.sh "
          exit
      fi
  done < /opt/liangbo/hosts 
}
#####################第六步：openssh升级########################################################
#
#############################################################################################
function step_fun_6(){
  echo_fun 1 第六步：OpenSSH漏洞升级
  OLD_IS="$IFS"
  IFS=" "
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`expect -c " 
        spawn ssh root@$IP  bash func_scripts.sh update
        set timeout 30
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";puts \"success\";exit 1}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
      RESULT=$?
      MESSAGE="OpenSSH漏洞升级-->$IP"
      show_result  $RESULT $MESSAGE
      if [ $RESULT -ne 0 ];then
          echo_fun 5 "当前执行第 6 步,如果继续执行请重新运行脚本 bash linux_init.sh "
          exit
      fi
  done < /opt/liangbo/hosts 
}

#####################第七步：设备信息采集########################################################
#
#############################################################################################
function step_fun_7(){
  echo_fun 1 第七步：设备信息采集
  OLD_IS="$IFS"
  IFS=" "
  printf "%-20s%-20s%-15s%-30s%-15s%-10s%-10s%-10s\n" HostName Sys_Version Sys_Sda Product SN Mem CPU Cores >> output_info
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`expect -c " 
        spawn ssh root@$IP  bash func_scripts.sh info
        set timeout 30
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";puts \"success\";exit 1}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
      out=`echo $res |tail -1`
      printf "%-20s%-20s%-15s%-30s%-15s%-10s%-10s%-10s\n" ${out} >> output_info
      RESULT=$?
      MESSAGE="$IP-->设备信息采集"
      show_result  $RESULT $MESSAGE
      if [ $RESULT -ne 0 ];then
          echo_fun 5 "当前执行第 7 步,如果继续执行请重新运行脚本 bash linux_init.sh "
          exit
      fi
  done < /opt/liangbo/hosts 
}


function step_fun_8(){
  echo_fun 1 第八步：资源使用率
  OLD_IS="$IFS"
  IFS=" "
  printf "%-15s%-15s%-15s%-15s%-15s%-15s\n" CPU CPUUSED MEM MEMUED FILE FILEUSED >> output_used
  while read LINE
    do
      arr=($LINE)
      IP=${arr[0]}
      PASSWD=${arr[1]}
      res=`expect -c " 
        spawn ssh root@$IP  bash func_scripts.sh used
        set timeout 30
        expect {
          \"*continue connecting (yes/no)*\" {send \"yes\r\";exp_continue}
          \"*Permission denied*\" {puts \"fail\";exit 9 }
          \"*password*\" {send \"$PASSWD\r\";puts \"success\";exit 1}
          \"*No route to host*\" {puts \"fail\r\";exit 8}
          \"*Connection timed out*\" {puts \"fail\r\";exit 6}
        }
    "`
      out=`echo $res |tail -1`
      printf "%-15s%-15s%-15s%-15s%-15s%-15s\n" ${out} >> output_used
      RESULT=$?
      MESSAGE="$IP-->资源使用率"
      show_result  $RESULT $MESSAGE
      if [ $RESULT -ne 0 ];then
          echo_fun 5 "当前执行第 8 步,如果继续执行请重新运行脚本 bash linux_init.sh "
          exit
      fi
  done < /opt/liangbo/hosts
}

#############主程序执行########################################
function list_init_info() {
	  echo -e "\033[33;40;1m<------#######请依序选择需要执行的操作#######------->\033[0m"
    echo -e "\033[33;40;1m<------          生成秘钥   请输入 1         ------->\033[0m"
    echo -e "\033[33;40;1m<------          配置免密   请输入 2         ------->\033[0m"
    echo -e "\033[33;40;1m<------          文件下发   请输入 3         ------->\033[0m"
    echo -e "\033[33;40;1m<------          基线加固   请输入 4         ------->\033[0m"
    echo -e "\033[33;40;1m<------       主机Yum配置   请输入 5         ------->\033[0m"
    echo -e "\033[33;40;1m<------   OpenSSH漏洞升级   请输入 6         ------->\033[0m"
    echo -e "\033[33;40;1m<------      设备信息采集   请输入 7         ------->\033[0m"
    echo -e "\033[33;40;1m<------    资源使用率采集   请输入 8         ------->\033[0m"
}

function step_fun(){
	  echo -e "\033[35;40;1m<-------请选择初始化开始的步数，请输入start_step：----------->\033[0m"
    read  STEP
    echo -e "\033[35;40;1m<-------请选择初始化结束的步数，请输入end_step：  ----------->\033[0m"
    read  ENDSTEP
    if [ $STEP -gt $ENDSTEP ];then
      echo_fun 3 请确保start_step不小于end_step
      echo_fun 4 请重新输入start_step和end_step
      step_fun
    else
      return 10
      exit 
    fi
    
}
function linux_init_fun(){
	list_init_info
	step_fun
    RES=$?
    if [ $RES -eq 10 ];then
	    while (($STEP <= $ENDSTEP))
            do
                step_fun_$STEP
                ((STEP++))
            done
    fi
}
linux_init_fun
