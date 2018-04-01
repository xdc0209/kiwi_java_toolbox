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

    output_dir=/tmp/${BASE_NAME}_${hostname}_${ips}_${date}
    log=$output_dir/${BASE_NAME}.log

    mkdir -p $output_dir
    chmod -R 777 $output_dir
}

function input_java_pid()
{
    print_info "============================================================================================"
    print_info "查询java进程："
    print_info "ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java"
    print_info "============================================================================================"
    # 查询java进程。##
    ps -eww -o pid,user:20,cmd | head -n1                                                       | tee -a $log
    ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java | grep -v tee | grep -v $BASE_NAME | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    # 选择java进程。##
    read -p "Enter java pid: " java_pid
    echo "You enter: $java_pid" | tee -a $log
    echo | tee -a $log
    echo | tee -a $log
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

function java_cpu_monitor()
{
    local java_pid=$1

    print_info "============================================================================================"
    print_info "获取java虚拟机线程转储："
    print_info "Get stack info."
    print_info "============================================================================================"

    # 加载配置。其中的配置项可以酌情更改。##
    source $BASE_DIR/$BASE_NAME.conf

    local cpu_high_continuous_times=0
    for check_cpu_time in $(seq -f "%05g" 1 $check_cpu_times)
    do
        print_info "Check cpu time $check_cpu_time of $(seq -f "%05g" 1 $check_cpu_times | tail -1)."

        # 风险：top命令执行时间过长，一般需要0.5秒，所有获取线程堆栈的间隔不要太小，以免对检查周期产生较大影响。##
        local cpu_usage=$(top -b -n 1 -p $java_pid | grep -w $java_pid | awk '{print $9}')
        if [ $(echo "$cpu_usage < $cpu_threshold_usage" | bc) -eq 1 ]; then
            local cpu_high_continuous_times=0
            print_info "Beacuse {cpu_usage} [$cpu_usage%] < {cpu_threshold_usage} [$cpu_threshold_usage%], reset {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
            print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] < {cpu_threshold_times} [$cpu_threshold_times], skip to get stack this time."
            print_info "Sleep $check_cpu_interval ..."
            sleep $check_cpu_interval
            echo | tee -a $log
            continue
        fi

        ((cpu_high_continuous_times++))
        print_info "Beacuse {cpu_usage} [$cpu_usage%] >= {cpu_threshold_usage} [$cpu_threshold_usage%], increase {cpu_high_continuous_times} to [$cpu_high_continuous_times]."

        if [ $cpu_high_continuous_times -lt $cpu_threshold_times ]; then
            print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] < {cpu_threshold_times} [$cpu_threshold_times], skip to get stack this time."
            print_info "Sleep $check_cpu_interval ..."
            sleep $check_cpu_interval
            echo | tee -a $log
            continue
        fi

        print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] >= {cpu_threshold_times} [$cpu_threshold_times], start to get stack this time."
        for stack_time in $(seq 1 $stack_times)
        do
            print_info "Get stack time $stack_time of $(seq 1 $stack_times | tail -1)."

            print_info "Exec cmd [ sh $BASE_DIR/bin/jstack.sh -l $java_pid ]."
            exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jstack.sh -l $java_pid" >$output_dir/$check_cpu_time-cpu_jstack-$stack_time.txt

            print_info "Exec cmd [ gstack $java_pid ]."
            gstack $java_pid                                                            >$output_dir/$check_cpu_time-cpu_pstack-$stack_time.txt

            print_info "Exec cmd [ top -bcH -n 1 -p $java_pid ]."
            top -bcH -n 1 -p $java_pid                                                  >$output_dir/$check_cpu_time-cpu_top-$stack_time.txt

            print_info "Add PID-16 column to top file."
            add_pid16_to_top_file                                                        $output_dir/$check_cpu_time-cpu_top-$stack_time.txt

            print_info "Sleep $stack_interval ..."
            sleep $stack_interval
            echo | tee -a $log
        done

        local cpu_high_continuous_times=0
        print_info "Finish to get stack, reset {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
        print_info "Sleep $check_cpu_interval ..."
        sleep $check_cpu_interval
        echo | tee -a $log
    done
    echo | tee -a $log
    echo | tee -a $log
}

function exit_gracefully()
{
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "压缩目录："
    print_info "zip -r $output_dir.zip $output_dir"
    print_info "============================================================================================"
    zip -r $output_dir.zip $output_dir | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "显示目录大小："
    print_info "du -ah $output_dir* | sort -k 2 | column -t"
    print_info "============================================================================================"
    du -ah $output_dir* | sort -k 2 | column -t | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    echo "The target file is [ $output_dir.zip ]." | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    exit 0
}

# 初始化和检查。##
init_env
input_java_pid
check_java_pid $java_pid
check_java_lib $java_pid
check_cur_user $java_pid

# 响应中断(Ctrl+C)并优雅地退出。##
trap "exit_gracefully" INT

# 监控CPU。##
java_cpu_monitor $java_pid

# 退出。#
exit_gracefully
