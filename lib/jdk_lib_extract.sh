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

if [ $# -eq 1 ]; then
    jdk_path=$1
else
    echo "Usage: sh $0 <jdk_path>"
    exit 1
fi

echo "Extract jdk lib start."

# 参数校验。##
[ ! -f "$jdk_path/bin/java" ] && echo "Extract jdk fail. Dir [ $jdk_path ] is not a valid jdk path. Beacuse file [ $jdk_path/bin/java ] not found." && exit 1
[ ! -f "$jdk_path/lib/tools.jar" ] && echo "Extract jdk fail. Dir [ $jdk_path ] is not a valid jdk path. Beacuse file [ $jdk_path/lib/tools.jar ] not found." && exit 1

# 获取jdk版本。##
jdk_version=$($jdk_path/bin/java -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')

# 存在性校验。#
[ -d "$BASE_DIR/jdk-$jdk_version" ] && echo "Extract jdk lib fail. Dir [ $BASE_DIR/jdk-$jdk_version ] already exists." && exit 1

# 创建目录。##
output_dir=$BASE_DIR/jdk-$jdk_version
mkdir -p $output_dir

# 复制tools.jar。##
tools_jar_path=$jdk_path/lib/tools.jar
cp $tools_jar_path $output_dir

# 复制libattach.so。##
libattach_so_path=$(find $jdk_path -type f -name "libattach.so")
[ ! -f "$libattach_so_path" ] && echo "Extract jdk lib fail. File [ libattach.so ] not found in dir [ $jdk_path ]." && exit 1
cp $libattach_so_path $output_dir

# 生成版本信息。##
$jdk_path/bin/java -version >$output_dir/jdk-version.txt 2>&1

echo "Extract jdk lib finish."
