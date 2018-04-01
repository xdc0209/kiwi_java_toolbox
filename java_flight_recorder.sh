#!/bin/bash

# ----------------------------- kiwi bash lib start -------------------------------------

# Make sure to execute this script with bash. Bash works well on suse, redhat, aix.##
# 确保以bash执行此脚本。Bash在suse、redhat、aix上表现很出色。##
[ -z "$BASH" ] && echo "Please use bash to run this script [ bash $0 ] or make sure the first line of this script [ $0 ] is [ #!/bin/bash ]." && exit 1

# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
[ -c /dev/stdout ] && export PS4_COLOR="32"
[ ! -c /dev/stdout ] && export PS4_COLOR=""
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $(cd $(dirname ${BASH_SOURCE[0]}) && pwd))/$(basename ${BASH_SOURCE[0]})" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") ; [ -z "$PS4_COLOR" ] && echo ${debug_info:0:94} ; [ -n "$PS4_COLOR" ] && echo -e "\e[${PS4_COLOR}m${debug_info:0:80}\e[0m")]: '

# 保存调试状态，用于调用子脚本。调用子脚本样例：bash $DEBUG_SWITCH subscript.sh##
# Save the debug state to invoke the subscript. Invoke the subscript example: bash $DEBUG_SWITCH subscript.sh##
(echo "${SHELLOPTS}" | grep -q "xtrace") && export DEBUG_SWITCH=-x

# Get the absolute path of this script.##
# 获取脚本的绝对路径。##
BASE_DIR=$(cd $(dirname $0) && pwd)
BASE_NAME=$(basename $0 .sh)

# 设置日志文件。##
# Set the log file.##
log=$BASE_DIR/$BASE_NAME.log

function print_error()
{
    echo "[$(date "+%F %T")] ERROR: $*" | tee -a $log 1>&2
}

function print_info()
{
    echo "[$(date "+%F %T")] INFO: $*" | tee -a $log
}

function log_error()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] ERROR: $*" >>$log
}

function log_info()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] INFO: $*" >>$log
}

function die()
{
    print_error "$*"
    print_error "See log [ $log ] for details."
    exit 1
}

# ----------------------------- kiwi bash lib end ---------------------------------------

# java线程堆栈中的本地线程显示为16进制，而top命令中的线程为10进制，为了方便比对，在top文件中添加16进制的线程ID##
function add_pid16_to_top_file()
{
    local top_file=$1
    # 若第一列为数字，则在前面添加16进制的数字。若第一列为PID，则在前面添加PID-16。其他情况原样输出##
    awk '{if($1~/^[0-9]+$/) {printf("0x%x %s\n",$1,$0)} else if($1~/^PID$/) {printf("PID-16 %s\n",$0)} else {printf("%s\n",$0)}}' $top_file >$top_file.tmp
    mv $top_file.tmp $top_file
}

# 以java进程用户执行命令。jdk提供的工具执行时，要求当前操作系统用户和java进程用户一致，否则会报错。##
function exec_cmd_with_java_user()
{
    local java_pid=$1
    shift 1
    local exec_cmd=$@

    local java_user=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java | grep -w $java_pid | awk '{print $2}')
    local cur_user=$(whoami)

    if [ "$cur_user" = "$java_user" ]; then
        $exec_cmd
    elif [ "$cur_user" = "root" ]; then
        su - $java_user -c "$exec_cmd"
    else
        echo "Current os user [ $cur_user ] must be [ root ] or java process user [ $java_user ]." && exit 1
    fi
}

function init_env()
{
    chmod -R 755 $BASE_DIR >/dev/null 2>&1

    local hostname=$(hostname)
    local ips=$(ifconfig -a 2>/dev/null | grep -w 'inet' | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1' | tr '\n' '-' | sed 's/-$//g')
    [ -z "$ips" ] && local ips=$(ip addr 2>/dev/null | grep -w 'inet' | awk -F/ '{print $1}' | awk '{print $2}' | grep -v '127.0.0.1' | tr '\n' '-' | sed 's/-$//g')
    local date=$(date "+%Y%m%dT%H%M%S%z")

    jfr_name=$BASE_NAME
    jfr_file=/tmp/${BASE_NAME}_${hostname}_${ips}_${date}.jfr
}

function check_java_pid()
{
    local java_pid=$1

    # 检查输入的JAVA进程ID是否为空。##
    [ -z "$java_pid" ] && echo "Pid can not be empty." | tee -a $log && exit 1

    # 检查输入的JAVA进程ID是否合法。##
    ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java | awk '{print $1}' | grep -w $java_pid >/dev/null 2>&1
    [ $? -ne 0 ] && echo "Pid [ $java_pid ] is not a valid java pid." | tee -a $log && exit 1
}

function check_java_lib()
{
    local java_pid=$1
    local java_cmd=$(readlink -m /proc/$java_pid/exe)

    if [ -f "$(dirname $java_cmd)/../lib/tools.jar" ]; then
        # java_cmd是jdk，使用此jdk的类库，这样可以减小发生类库版本不匹配的可能性。##
        # 空命令，什么也不做。##
        :
    else
        # java_cmd是jre，使用本工具中的类库。##
        # 检查对应版本的jdk类库是否存在。##
        local java_version=$($java_cmd -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
        [ ! -d "$BASE_DIR/lib/jdk-$java_version" ] && echo "Find no jdk lib dir [ $BASE_DIR/lib/jdk-$java_version ] for java [ $java_cmd $java_version ]." | tee -a $log && exit 1
    fi
}

function check_cur_user()
{
    local java_pid=$1

    local java_user=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java | grep -w $java_pid | awk '{print $2}')
    local cur_user=$(whoami)

    if [ "$cur_user" = "$java_user" ]; then
        # 空命令，什么也不做。##
        :
    elif [ "$cur_user" = "root" ]; then
        # 检查java用户是否对此工具目录有访问权限。##
        su - $java_user -c "cd $BASE_DIR" >/dev/null 2>&1
        [ $? -ne 0 ] && echo "User [ $java_user ] has no access to dir [ $BASE_DIR ]." | tee -a $log && exit 1
    else
        echo "Current os user [ $cur_user ] must be [ root ] or java process user [ $java_user ]." && exit 1
    fi
}

function java_flight_recorder()
{
    # Tips:##
    # Java Flight Recorder is available in JDK 7u4 and later.##
    # Prior to JDK 8u40 release, the JVM must also have been started with the flag: -XX:+UnlockCommercialFeatures -XX:FlightRecorder.##
    # Since the JDK 8u40 release, the Java Flight Recorder can be enabled during runtime.##

    local java_pid=$1
    local jfr_operation=$2

    case "$jfr_operation" in
        "start")
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features" >/dev/null 2>&1

            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check" | grep -q -w $jfr_name
            [ $? -eq 0 ] && echo "Java flight recorder [ $jfr_name ] is running. No need to start." && exit 0

            echo "Exec cmd [ sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.start name=$jfr_name settings=profile maxsize=100m maxage=24h ]." | tee -a $log
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.start name=$jfr_name settings=profile maxsize=100m maxage=24h" | tee -a $log
            ;;

        "check")
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features" >/dev/null 2>&1

            echo "Exec cmd [ sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check ]." | tee -a $log
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check" | tee -a $log
            ;;

        "dump")
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features" >/dev/null 2>&1

            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check" | grep -q -w $jfr_name
            [ $? -ne 0 ] && echo "Java flight recorder [ $jfr_name ] is not running. Please start first." && exit 0

            echo "Exec cmd [ sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.dump name=$jfr_name filename=$jfr_file compress=true ]." | tee -a $log
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.dump name=$jfr_name filename=$jfr_file compress=true" | tee -a $log
            ;;

        "stop")
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features" >/dev/null 2>&1

            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check" | grep -q -w $jfr_name
            [ $? -ne 0 ] && echo "Java flight recorder [ $jfr_name ] is not running. No need to stop." && exit 0

            echo "Exec cmd [ sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.stop name=$jfr_name ]." | tee -a $log
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.stop name=$jfr_name" | tee -a $log
            ;;

        *)
            help
            ;;
    esac
}

function help()
{
    echo "Usage:"
    echo "--------------------------------------------------"
    echo "  sh $0 start [java_pid]"
    echo "  sh $0 check [java_pid]"
    echo "  sh $0 dump  [java_pid]"
    echo "  sh $0 stop  [java_pid]"
    echo

    echo "Java Progress:"
    echo "--------------------------------------------------"
    ps -eww -o pid,user:20,cmd | head -n1
    ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
    echo

    exit 1
}

# 参数检查。##
[ $# -ne 2 ] && help
jfr_operation=$1
java_pid=$2

# 初始化和检查。##
init_env
check_java_pid $java_pid
check_java_lib $java_pid
check_cur_user $java_pid

# 操作飞行记录。##
java_flight_recorder $java_pid $jfr_operation
