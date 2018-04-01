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

function get_target_java_pid()
{
    for arg in $(echo $@)
    do
        # 分析了jdk的工具集，第一个数字参数即为java的pid。##
        (echo $arg | grep -w '^[0-9][0-9]*$' >/dev/null 2>&1) && echo $arg && return 0
    done
}

function check_target_java_pid()
{
    local target_java_pid=$1

    # 如果target_java_pid为空，则不进行检查。正常的jdk工具使用过程中是有不输入参数的场景的，例如使用无参数的jps查询当前运行的所有java进程。##
    [ -z "$target_java_pid" ] && return 0

    # 检查pid是否合法。##
    ps -ww -o pid,user:20,cmd -p $target_java_pid | sed '1d' | awk '{print $3}' | grep -w java >/dev/null 2>&1
    [ $? -ne 0 ] && echo "Pid [ $target_java_pid ] is not a valid java pid." && exit 1

    # jdk提供的工具执行时，要求当前操作系统用户和java进程用户一致，否则会报错。##
    local cur_user=$(whoami)
    local java_user=$(ps -ww -o pid,user:20,cmd -p $target_java_pid | sed '1d' | awk '{print $2}')
    [ "$cur_user" != "$java_user" ] && echo "Current os user [ $cur_user ] and java process user [ $java_user ] don't match. Please switch the user to [ $java_user ]." && exit 1
}

function set_java_env_var()
{
    local target_java_pid=$1

    # 获取JAVA_CMD_FOR_TOOLS的逻辑：##
    # 1. 如果target_java_pid不空，则使用target_java_pid获取java执行程序路径，进而设置JAVA_CMD_FOR_TOOLS。##
    # 2. 如果target_java_pid为空，且环境变量JAVA_CMD_FOR_TOOLS已设置，则以环境变量为准。##
    # 3. 如果target_java_pid为空，且环境变量JAVA_CMD_FOR_TOOLS未设置，则提示设置环境变量，并退出。##
    [ -n "$target_java_pid" ] && JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$target_java_pid/exe)

    # 如果JAVA_CMD_FOR_TOOLS仍为空，则提示设置环境变量，并退出。##
    if [ -z "$JAVA_CMD_FOR_TOOLS" ]; then
        # 查找正在运行的java进程。##
        local java_processes=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java)
        [ -z "$java_processes" ] && echo "Find no running java process." && exit 1

        # 提示设置JAVA_CMD_FOR_TOOLS。##
        echo "Env var [ JAVA_CMD_FOR_TOOLS ] not set. Please set env var first by using one of the following commands: "
        printf "%-10s %-20s %s\n" "PID" "USER" "SET_JAVA_ENV_COMMAND"
        echo "$java_processes" | while read java_process
        do
            java_process_id=$(echo $java_process | awk '{print $1}')
            java_process_user=$(echo $java_process | awk '{print $2}')
            java_process_executable=$(readlink -m /proc/$java_process_id/exe)
            printf "%-10s %-20s [ export JAVA_CMD_FOR_TOOLS=%s ]\n" "$java_process_id" "$java_process_user" "$java_process_executable"
        done
        exit 1
    fi

    if [ -f "$(dirname $JAVA_CMD_FOR_TOOLS)/../lib/tools.jar" ]; then
        # JAVA_CMD_FOR_TOOLS是jdk，使用此jdk的类库，这样可以减小发生类库版本不匹配的可能性。##
        JAVA_LIBRARY_PATH_OPTION=""
        JAVA_CLASSPATH_OPTION="-classpath $(dirname $JAVA_CMD_FOR_TOOLS)/../lib/tools.jar"
    else
        # JAVA_CMD_FOR_TOOLS是jre，使用本工具中的类库。##

        # 检查对应版本的jdk类库是否存在。##
        local java_version=$($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
        [ ! -d "$BASE_DIR/../lib/jdk-$java_version" ] && echo "Find no jdk lib dir [ $BASE_DIR/../lib/jdk-$java_version ] for java [ $JAVA_CMD_FOR_TOOLS $java_version ]." && exit 1

        # 使用对应版本的jdk类库建立链接。##
        JAVA_LIBRARY_PATH_OPTION="-Djava.library.path=$BASE_DIR/../lib/jdk-$java_version"
        JAVA_CLASSPATH_OPTION="-classpath $BASE_DIR/../lib/jdk-$java_version/tools.jar"
    fi
}

# 获取pid。##
target_java_pid=$(get_target_java_pid $@)

# 校验pid。##
check_target_java_pid $target_java_pid

# 设置java环境变量。##
set_java_env_var $target_java_pid

# 执行命令。##
$JAVA_CMD_FOR_TOOLS $JAVA_LIBRARY_PATH_OPTION $JAVA_CLASSPATH_OPTION sun.tools.jcmd.JCmd $@
