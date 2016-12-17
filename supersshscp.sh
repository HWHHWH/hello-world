#!/bin/bash
# by liusf@ + huwh@


srcfile=
rstDir=
#modeFlag=0 default files transfer mode
#modeFlag=1 is running cmds mode
#modeFlag=2 is mis mode
#modeFlag=999 is initial number
modeFlag=9999
cmd=
timeout=
hostip=
passwd=
mixContent=
backscp=0
user=root
port=57891
dstip=
ptpmodeFlag=

function usage(){
	shellname="`echo ${0##*/}`"

	echo -e "usage:
	-h             显示帮助
	-r [ip]        指定ip地址或主机名,点对点文件传输模式时指定原始IP地址(多目标模式下用空格分隔)
	-s [number]    设置超时时间
	-b             文件回传模式
	-p [port]      指定端口
	-u [user]      指定用户(不加此参数默认为root用户)
	-w [password]  指定密码(普通服务器不需要此参数)
	-c [commmand]  在远程服务器上执行命令
	-f [localfile] 本地文件或目录(回传模式下为远程服务器上的绝对路径文件)(多文件模式下用空格分隔)
	-d [remoteDir] 目标目录或文件(回传模式下为本地目录或文件,点对点模式时不能为目录)
	-M [mixed command] 混合执行文件传输或远程命令
		[mixed command]详细说明:
		传输模式、回传模式、远程命令模式和本地命令模式这四种模式的命令内容以"~"为分隔符,统一写在一条语句上.
		传输模式格式: L::本地文件::目标目录 (其中L::为模式标记,双冒号::为命令分隔符)(多文件模式下用空格分隔)
		回传模式格式: R::目标文件::本地目录 (其中R::为模式标记,双冒号::为命令分隔符)(多文件模式下用空格分隔)
		远程命令模式: C::远程执行的命令内容
		本地命令模式：命令内容(该模式全部内容视为要执行的命令)
	-R [ip]         点对点文件传输模式时指定目标IP地址
	-P              点对点文件传输模式,需要与-f和-d、-r、-R结合使用

"

	echo "eg: 1、远程命令模式(支持多远程的命令执行)："
	echo "    	${shellname} -r \"192.168.0.1 192.168.0.2\" -c w -s 60"
	echo "    2、本地传远程(支持多远程的单文件或多文件传输)："
	echo "    	${shellname} -r \"192.168.0.1 192.168.0.2\" -f \"/tmp/a /tmp/b\" -d /tmp/"
        echo "    3、远程传本地(支持多远程的单文件传输[文件名以IP后缀区别]或单远程的多文件传输)："
	echo "    	${shellname} -r \"192.168.0.1 192.168.0.2\" -f \"/tmp/a\" -d /tmp/ -b"
	echo "    4、混合模式(支持本地传远程，远程传本地，远程命令模式，本地命令模式的混合)："
	echo "    	${shellname} -r \"192.168.0.1 192.168.0.2\" -M \"L::/tmp/a /tmp/b::/tmp/remotedir~C::w>/tmp/filelist~R::/tmp/filelist::/tmp/local/filelist~cat /tmp/local/filelist\""
	echo "    5、P2P模式(支持点对点远程机器的文件传输)："
        echo "    	${shellname} -P -r 113.107.236.5 -R 113.107.236.6 -f /root/rpm.log -d /tmp/60test2"
	exit
}

function checkResultStatus(){
	resultStatus="$1"
	if [ "${resultStatus}" -eq 0 ]
	then
		echo  "------supersshscp_success------"
		#echo -e "\\033[32m\\033[1m------supersshscp_success------\\033[m"
	else
		echo  "------supersshscp_failure:${resultStatus}------"
		#echo -e "\\033[31m\\033[1m------supersshscp_failure:${resultStatus}------\\033[m"
	fi
}



function scpProcess(){
	scpCMD="$@"
	#scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=${timeout} -P "${port}" ${scpCMD}

	if [ -z ${timeout} ]
	then
		timeout=3600
	fi

	if [ ! -z "${passwd}" ]
	then
		/tmp/.autologin.exp "${user}" "${passwd}" "${hostip}" "${port}" ${timeout} scp ${scpCMD}
		checkResultStatus $?
	else
		if [ "$backscp" -eq 0 ];then
                        #scp_L2R
			scp -r -o ConnectTimeout=${timeout} -P "${port}" ${scpCMD}
                else
                        #scp_R2L
			scp -r -o ConnectTimeout=${timeout} -P "${port}" "$1""$2" "$3"
                fi


		checkResultStatus $?
	fi
}

function sshProcess(){
# run on the remote
	sshCMD="$@"

	if [ -z ${timeout} ]
	then
		timeout=120
	fi

	if [ ! -z "${passwd}" ]
	then
		/tmp/.autologin.exp "${user}" "${passwd}" "${hostip}" "${port}" ${timeout} ssh "${sshCMD}"
		checkResultStatus $?
	else

	#ssh  ${user}@$hostip -j -p "${port}" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=$timeout  "${sshCMD}"
	#ssh -j ---not retry to enter the password
		for ip in $(echo "${hostip}")
		do
			ssh  ${user}@${ip} -j -p "${port}" -o ConnectTimeout=${timeout}  "${sshCMD}"
			checkResultStatus $?
		done
	fi
}

function checkMixedContent(){
	if [ "`echo "$@" |awk -F'::' '{print NF}'`" -ne 3 ]
	then
		echo "ERROR! MixedContent don't have 2 items!"
		usage
	fi
}

while getopts "hf:d:c:s:r:p:w:M:bu:PR:" opt
do
        case "$opt" in
		f) modeFlag=0;srcfile=$OPTARG;;
		d) rstDir=$OPTARG;;
		c) modeFlag=1;cmd=$OPTARG;;
		s) timeout=$OPTARG;;
		r) hostip=$OPTARG;;
		b) backscp=1;;
		p) port=$OPTARG;;
		w) passwd=$OPTARG;;
		M) modeFlag=2;mixedContent="$OPTARG";;
		u) user=$OPTARG;;
		P) ptpmodeFlag=0;;
		R) dstip=$OPTARG;;
		h) usage;;
		*) usage;;
        esac
done

if [  "${modeFlag}" -eq 0 ];then
# files mode
	if [ -z "$srcfile" -o -z "$rstDir" ];then
		usage
	fi
elif [ "${modeFlag}" -eq 1 ];then
# cmds mode
	if [ "$srcfile" -o "$rstDir" ];then
		usage
	fi
fi

if [ -z "${hostip}" ];then
	usage
fi


if [ "${modeFlag}" -eq 0 ];then
# files mode
	if [ -z ${ptpmodeFlag} ]
	then
	ipcount=$(echo "${hostip}" | awk '{print NF}')
		for ip in $(echo "${hostip}")
		do
		if [ "$backscp" -eq 0 ];then
			#scp_L2R
			scpCMDStr="${srcfile} ${user}@${ip}:${rstDir}"
			scpProcess ${scpCMDStr}
		else
			#scp_R2L
			scpIp="${user}@${ip}:"
			filename=$(echo ${srcfile} | sed 's/.*\///')
			if [ ${ipcount} -gt 1 ]
				then
   				scpDirFile="${rstDir}${filename}_${ip}"
				else
				scpDirFile="${rstDir}"
			fi
			scpProcess ${scpIp} "${srcfile}" ${scpDirFile}
		fi
		done
	else
	#ptpmode
	if [ -z ${dstip} ]
	then
		usage
	fi
        for ip in $(echo "${dstip}")
	do
		supersshscp.sh -r ${ip} -c "nc -dl 60606 >  ${rstDir}   &"  && echo "==> ${ip} nc listening..."
		echo "======================================================"
		supersshscp.sh -r ${hostip} -c "md5sum ${srcfile};nc ${ip} 60606 <  ${srcfile}"  && echo "==> ${hostip} nc sended..."
		echo "======================================================"
		supersshscp.sh -r ${ip} -c "md5sum ${rstDir}"
	done
	fi
elif [ "${modeFlag}" -eq 1 ];then
# cmds mode
	sshProcess	${cmd}
elif [ "${modeFlag}" -eq 2 ];then
# mix mode
	for((i=1;i<=`echo "${mixedContent}"|awk -F'~' '{print NF}'`;i++))
	{
           for ip in $(echo "${hostip}")
	   do
		subCmd="`echo "${mixedContent}"|awk -F'~' '{print $'$i'}'`"
		if [ "`echo "${subCmd}"|grep  '^L::'|wc -l`" -eq 1 ]
		then
			checkMixedContent ${subCmd}
			srcfile="`echo "${subCmd}"|awk -F'::' '{print $2}'`"
			rstDir="`echo "${subCmd}"|awk -F'::' '{print $3}'`"
			scpCMDStr="${srcfile} ${user}@${ip}:${rstDir}"
			scpProcess ${scpCMDStr}

		elif [ "`echo "${subCmd}"|grep  '^R::'|wc -l`" -eq 1 ]
		then
			backscp=1
			ipcount=$(echo "${hostip}" | awk '{print NF}')
			checkMixedContent ${subCmd}
			srcfile="`echo "${subCmd}"|awk -F'::' '{print $2}'`"
			rstDir="`echo "${subCmd}"|awk -F'::' '{print $3}'`"
			#scpCMDStr="${user}@${hostip}:"${srcfile}" ${rstDir}"
			#scp_R2L
			filename=$(echo ${srcfile} | sed 's/.*\///')
			if [ ${ipcount} -gt 1 ]
                                then
                                scpDirFile="${rstDir}${filename}_${ip}"
                                else
                                scpDirFile="${rstDir}"
                        fi
                        #scpDirFile="${rstDir}${filename}_${ip}"
			scpIp="${user}@${ip}:"
                        scpProcess ${scpIp} "${srcfile}" ${scpDirFile}
		elif [ "`echo "${subCmd}"|grep  '^C::'|wc -l`" -eq 1 ]
		then
			sshCMDStr="`echo "${subCmd}"|awk -F'::' '{print $2}'`"
			sshProcess ${sshCMDStr}
		else
			countSubCmd="`echo "${subCmd}"|awk -F';' '{print NF}'`"
			for((n=1;n<=${countSubCmd};n++))
			{

				localCMDStr="`echo "${subCmd}"|awk -F';' '{print $'$n'}'`"
				${localCMDStr}
			}
		fi
            done
	}
fi
