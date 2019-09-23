#!/bin/bash
  operation=$1
  kernel_version=`uname -r | awk -F '-' '{print $1}'`
  linux_class=`cat /etc/redhat-release | awk '{print $1}'`
  linux_red=`cat /etc/redhat-release | awk '{print $1$2}'`
  linux_version=`cat /etc/redhat-release | awk '{print $(NF-1)}' | awk -F '.' '{print $1$2}'`
###########################基线加固函数#######################
  function scripts_safety(){
    case $kernel_version  in  
       2.6.32 )
       version='Linux-6'
       bash safety-scripts-6.v7.5.sh
       ;;
       3.10.0 )
       version='Linux-7'
       bash safety-scripts-7.v7.5.sh
       ;;
       * )
       echo "系统版本获取失败，该主机未做基线加固"
       ;;
  esac
  echo "[$version]版本基线加固完成"
  }
###########################漏洞升级函数#######################
  function scripts_update(){
    case $kernel_version  in  
       2.6.32 )
       version='OpenSSH-6'
       yum update openssh -y > /dev/null
       ;;
       3.10.0 )
       version='OpenSSH-7'
       yum update openssh -y > /dev/null
       ;;
       * )
       echo "系统版本获取失败，该主机未做漏洞升级"
       ;;
  esac
  echo "[$version]版本漏洞升级完成"
  }
###########################yum文件配置函数########################
  function file_cp_repo(){
    class=$1
    cp /root/$class$linux_version.repo   /etc/yum.repos.d/ > /dev/null
    if [ $kernel_version = 2.6.32 ]; then
      cp /root/openssh69.repo /etc/yum.repos.d/ > /dev/null
    elif [ $kernel_version = 3.10.0 ]; then
      cp /root/openssh75.repo /etc/yum.repos.d/ > /dev/null
    else
      echo "系统内核版本获取有误"  
    fi   
    yum clean all;yum repolist > /dev/null
  }
  function scripts_yum(){
    case $linux_class  in  
       CentOS )
          case $linux_version in
            66 )
            file_cp_repo $linux_class
            ;;
            69 )
            file_cp_repo $linux_class
            ;;
            70 )
            file_cp_repo $linux_class
            ;;
            71 )
            file_cp_repo $linux_class
            ;;
            72 )
            file_cp_repo $linux_class
            ;;
            73 )
            file_cp_repo $linux_class
            ;;
            74 )
            file_cp_repo $linux_class
            ;;
            * )
            echo "系统版本获取失败，未进行yum配置"
            ;;
          esac
         ;;
      Red )
          case $linux_version in
            66 )
            file_cp_repo $linux_red
            ;;
            69 )
            file_cp_repo $linux_red
            ;;
            70 )
            file_cp_repo $linux_red
            ;;
            71 )
            file_cp_repo $linux_red
            ;;
            72 )
            file_cp_repo $linux_red
            ;;
            73 )
            file_cp_repo $linux_red
            ;;
            74 )
            file_cp_repo $linux_red
            ;;
            * )
            echo "系统版本获取失败，未进行yum配置"
            ;;
          esac
         ;;
       * )
       echo "操作系统类型[CentOS or Redhat]获取失败"
       ;;
  esac
  echo "[$linux_class $linux_version]版本yum配置完成"
  }
######################################主机信息收集################################
function scripts_info(){
#主机名
	hostname=`hostname |awk -F '.' '{print $1}'`
#操作系统类型&版本
	linux_class=`cat /etc/redhat-release | awk '{print $1}'`
	linux_version=`cat /etc/redhat-release | awk '{print $(NF-1)}' | awk -F '.' '{print $1$2}'`
	sys_version=$linux_class$linux_version
#系统盘的大小
	sys_sda=$(lsblk |grep sda | awk 'NR==1{print $4}')
#设备型号
	pro_tmp=$(dmidecode -t system |grep Product |awk -F ':' '{print $2}')
	hw_product=`echo $pro_tmp | awk '{print $1$2$3}'`
#序列号
	hw_sn=$(dmidecode -t system |grep Serial  |awk '{print $NF}')
#内存容量
	mem_tmp=$(free -g |awk 'NR==2{print $2}')
	hw_mem=$(($mem_tmp + 1))
#cpu个数
	hw_cpu=`cat /proc/cpuinfo |grep 'physical id'|sort |uniq|wc -l`
#cpu核数
	logic_cpu=`cat /proc/cpuinfo |grep 'processor'|wc -l`
#结果输出
	printf "%s %s %s %s %s %s %s %s" $hostname $sys_version $sys_sda $hw_product $hw_sn $hw_mem $hw_cpu $logic_cpu
}
function scripts_used(){
	MEMUSED=`free | awk '/Mem:/ {print 100*$3/$2}'`
        CPUUSED=`sar -u 3 1 | tail -n 1 | awk '{print $2+$3+$4}'`
        FILEUSED=`df -P |grep /dev/mapper/vgroot-lv_app |awk '{print $(NF-1)}'`
        sys_sda=$(lsblk |grep sda | awk 'NR==1{print $4}')
	logic_cpu=`cat /proc/cpuinfo |grep 'processor'|wc -l`
	mem_tmp=$(free -g |awk 'NR==2{print $2}')
	hw_mem=$(($mem_tmp + 1))
        printf "%s %s %s %s %s %s" $logic_cpu $CPUUSED $hw_mem $MEMUSED $sys_sda $FILEUSED
} 
scripts_$operation
