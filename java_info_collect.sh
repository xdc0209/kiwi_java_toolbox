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

function java_info_collect()
{
    local java_pid=$1
    local java_cmd=$(readlink -m /proc/$java_pid/exe)

    print_info "============================================================================================"
    print_info "查询java版本："
    print_info "$java_cmd -version"
    print_info "============================================================================================"
    $java_cmd -version 2>&1 | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "查询java进程运行时间："
    print_info "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.uptime"
    print_info "============================================================================================"
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.uptime" | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "查询java虚拟机系统属性："
    print_info "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.system_properties"
    print_info "============================================================================================"
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.system_properties" | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "查询java虚拟机启动参数："
    print_info "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.command_line"
    print_info "============================================================================================"
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.command_line" | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "显示java虚拟机GC信息(按大小显示)："
    print_info "sh $BASE_DIR/bin/jstat.sh -gc $java_pid 1000 3"
    print_info "============================================================================================"
    # 此操作要放在"获取java虚拟机堆转储"和"显示堆中存活对象统计信息的直方图"的前面，以免这个两个操作触发的GC影响显示GC信息的结果。##
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jstat.sh -gc $java_pid 1000 3" | tee -a $log
    {
        echo "输出内容含义如下：                                                   "
        echo "  S0C  新生代存活区Survivor0区容量(单位KB)。                         "
        echo "  S1C  新生代存活区Survivor1区容量(单位KB)。                         "
        echo "  S0U  新生代存活区Survivor0区占用(单位KB)。                         "
        echo "  S1U  新生代存活区Survivor1区占用(单位KB)。                         "
        echo "  EC   新生代伊甸园区Eden区容量(单位KB)。                            "
        echo "  EU   新生代伊甸园区Eden区占用(单位KB)。                            "
        echo "  OC   老年代Old区占用容量(单位KB)。                                 "
        echo "  OU   老年代Old区占用占用(单位KB)。                                 "
        echo "  PC   永久代Permanent区容量(单位KB)。(注：before java 1.8)          "
        echo "  PU   永久代Permanent区占用(单位KB)。(注：before java 1.8)          "
        echo "  MC   元数据空间容量(单位KB)。       (注：java 1.8)                 "
        echo "  MU   元数据空间占用(单位KB)。       (注：java 1.8)                 "
        echo "  CCSC 压缩类空间容量(单位KB)。       (注：java 1.8)                 "
        echo "  CCSU 压缩类空间占用(单位KB)。       (注：java 1.8)                 "
        echo "  YGC  应用程序启动后发生Young GC的次数。                            "
        echo "  YGCT 应用程序启动后发生Young GC所用的时间(单位秒)。                "
        echo "  FGC  应用程序启动后发生Full GC的次数。                             "
        echo "  FGCT 应用程序启动后发生Full GC所用的时间(单位秒)。                 "
        echo "  GCT  应用程序启动后发生Young GC和Full GC所用的时间(单位秒)。       "
        echo "The meaning of the output is as follows:                             "
        echo "  S0C  Current survivor space 0 capacity (KB).                       "
        echo "  S1C  Current survivor space 1 capacity (KB).                       "
        echo "  S0U  Current survivor space 0 utilization (KB).                    "
        echo "  S1U  Current survivor space 1 utilization (KB).                    "
        echo "  EC   Current eden space capacity (KB).                             "
        echo "  EU   Eden space utilization (KB).                                  "
        echo "  OC   Current old space capacity (KB).                              "
        echo "  OU   Old space utilization (KB).                                   "
        echo "  PC   Current permanent space capacity (KB). (Tips: before java 1.8)"
        echo "  PU   Permanent space utilization (KB).      (Tips: before java 1.8)"
        echo "  MC   Metaspace capacity (kB).               (Tips: java 1.8)       "
        echo "  MU   Metacspace utilization (kB).           (Tips: java 1.8)       "
        echo "  CCSC Compressed class space capacity (kB).  (Tips: java 1.8)       "
        echo "  CCSU Compressed class space used (kB).      (Tips: java 1.8)       "
        echo "  YGC  Number of young generation GC Events.                         "
        echo "  YGCT Young generation garbage collection time.                     "
        echo "  FGC  Number of full GC events.                                     "
        echo "  FGCT Full garbage collection time.                                 "
        echo "  GCT  Total garbage collection time.                                "
        echo
        echo
    } | tee -a $log

    print_info "============================================================================================"
    print_info "显示java虚拟机GC信息(按百分比显示)："
    print_info "sh $BASE_DIR/bin/jstat.sh -gccause $java_pid 1000 3"
    print_info "============================================================================================"
    # 此操作要放在"获取java虚拟机堆转储"和"显示堆中存活对象统计信息的直方图"的前面，以免这个两个操作触发的GC影响显示GC信息的结果。##
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jstat.sh -gccause $java_pid 1000 3" | tee -a $log
    {
        echo "输出内容含义如下：                                                                                                "
        echo "  S0   新生代存活区Survivor0区占用百分比。                                                                        "
        echo "  S1   新生代存活区Survivor1区占用百分比。                                                                        "
        echo "  E    新生代伊甸园区Eden区占用百分比。                                                                           "
        echo "  O    老年代Old区占用百分比。                                                                                    "
        echo "  P    永久代Permanent区占用百分比。(注：before java 1.8)                                                         "
        echo "  M    元数据空间占用百分比。       (注：java 1.8)                                                                "
        echo "  CCS  压缩类空间占用百分比。       (注：java 1.8)                                                                "
        echo "  YGC  应用程序启动后发生Young GC的次数。                                                                         "
        echo "  YGCT 应用程序启动后发生Young GC所用的时间(单位秒)。                                                             "
        echo "  FGC  应用程序启动后发生Full GC的次数。                                                                          "
        echo "  FGCT 应用程序启动后发生Full GC所用的时间(单位秒)。                                                              "
        echo "  GCT  应用程序启动后发生Young GC和Full GC所用的时间(单位秒)。                                                    "
        echo "  LGCC 上次GC的原因。                                                                                             "
        echo "  GCC  当前GC的原因。                                                                                             "
        echo "The meaning of the output is as follows:                                                                          "
        echo "  S0   Survivor space 0 utilization as a percentage of the space's current capacity.                              "
        echo "  S1   Survivor space 1 utilization as a percentage of the space's current capacity.                              "
        echo "  E    Eden space utilization as a percentage of the space's current capacity.                                    "
        echo "  O    Old space utilization as a percentage of the space's current capacity.                                     "
        echo "  P    Permanent space utilization as a percentage of the space's current capacity.        (Tips: before java 1.8)"
        echo "  M    Metaspace utilization as a percentage of the space's current capacity.              (Tips: java 1.8)       "
        echo "  CCS  Compressed class space utilization as a percentage of the space's current capacity. (Tips: java 1.8)       "
        echo "  YGC  Number of young generation GC events.                                                                      "
        echo "  YGCT Young generation garbage collection time.                                                                  "
        echo "  FGC  Number of full GC events.                                                                                  "
        echo "  FGCT Full garbage collection time.                                                                              "
        echo "  GCT  Total garbage collection time.                                                                             "
        echo "  LGCC Cause of last Garbage Collection.                                                                          "
        echo "  GCC  Cause of current Garbage Collection.                                                                       "
        echo
        echo
    } | tee -a $log

    print_info "============================================================================================"
    print_info "获取java虚拟机线程转储："
    print_info "Get stack info."
    print_info "============================================================================================"
    # 获取线程堆栈的次数，一次性的连续获取多次线程堆栈，供分析比较，推荐3次##
    stack_times=3
    # 获取线程堆栈的间隔，建议不要小于2s##
    stack_interval=2s
    for stack_time in $(seq 1 $stack_times)
    do
        print_info "Get stack time $stack_time of $(seq 1 $stack_times | tail -1)."

        print_info "Exec cmd [ sh $BASE_DIR/bin/jstack.sh -l $java_pid ]."
        exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jstack.sh -l $java_pid" >$output_dir/cpu_jstack-$stack_time.txt

        print_info "Exec cmd [ gstack $java_pid ]."
        gstack $java_pid                                                            >$output_dir/cpu_pstack-$stack_time.txt

        print_info "Exec cmd [ top -bcH -n 1 -p $java_pid ]."
        top -bcH -n 1 -p $java_pid                                                  >$output_dir/cpu_top-$stack_time.txt

        print_info "Add PID-16 column to top file."
        add_pid16_to_top_file                                                        $output_dir/cpu_top-$stack_time.txt

        print_info "Sleep $stack_interval ..."
        sleep $stack_interval
        echo | tee -a $log
    done
    echo | tee -a $log
    echo | tee -a $log

    # print_info "============================================================================================"
    # print_info "显示java进程中cpu最高的top5线程："
    # print_info "$java_cmd -Djava.library.path=$BASE_DIR/lib/jdk1.8.0_111 -classpath $BASE_DIR/lib/jdk1.8.0_111/tools.jar:$BASE_DIR/bin/jtop.jar jtop -size H -thread 5 -stack 100 --color $java_pid 1000 10"
    # print_info "============================================================================================"
    # # 显示java进程中cpu最高的top5线程，间隔2秒，打印10次##
    # $java_cmd -Djava.library.path=$BASE_DIR/lib/jdk1.8.0_111 -classpath $BASE_DIR/lib/jdk1.8.0_111/tools.jar:$BASE_DIR/bin/jtop.jar jtop -size H -thread 5 -stack 100 --color $java_pid 1000 10 | tee -a $log
    # echo | tee -a $log
    # echo | tee -a $log

    print_info "============================================================================================"
    print_info "查询进程的地址空间和内存状态信息："
    print_info "pmap $java_pid"
    print_info "============================================================================================"
    echo "Dump pmap to $output_dir/mem_pmap.txt ..." | tee -a $log
    pmap $java_pid >$output_dir/mem_pmap.txt
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "显示堆中对象统计信息的直方图："
    print_info "sh $BASE_DIR/bin/jmap.sh -histo $java_pid"
    print_info "============================================================================================"
    echo "Dump objects histogram to $output_dir/mem_objects_histogram.txt ..." | tee -a $log
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jmap.sh -histo $java_pid" >$output_dir/mem_objects_histogram.txt
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "显示堆中对象统计信息的直方图(仅包含存活对象)："
    print_info "sh $BASE_DIR/bin/jmap.sh -histo:live $java_pid"
    print_info "============================================================================================"
    echo "Dump live objects histogram to $output_dir/mem_objects_histogram_live.txt ..." | tee -a $log
    # To print histogram of java object heap; if the "live" suboption is specified, only count live objects.##
    # 注意：带有live参数时，JVM会先触发Young GC，再触发Full GC，然后再统计信息。因为Full GC会暂停应用，请权衡后用。##
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jmap.sh -histo:live $java_pid" >$output_dir/mem_objects_histogram_live.txt
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "获取java虚拟机堆转储："
    print_info "sh $BASE_DIR/bin/jmap.sh -dump:live,format=b,file=$output_dir/mem_heap_dump.hprof $java_pid"
    print_info "============================================================================================"
    # To dump java heap in hprof binary format.##
    # 注意1：同histo，带有live参数时，JVM会先触发Young GC，再触发Full GC，在生成文件。##
    # 注意2：JVM会将整个heap的信息dump写入到一个文件，heap如果比较大的话，就会导致这个过程比较耗时，并且执行的过程中为了保证dump的信息是可靠的，所以会暂停应用。##
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jmap.sh -dump:live,format=b,file=$output_dir/mem_heap_dump.hprof $java_pid" | tee -a $log
    echo | tee -a $log
    echo | tee -a $log
}

function os_info_collect()
{
    print_info "============================================================================================"
    print_info "获取OS信息："
    print_info "Get os info."
    print_info "============================================================================================"
    echo "Dump os info to $output_dir ..." | tee -a $log
    date         >$output_dir/os_date.txt     2>&1
    ifconfig     >$output_dir/os_ifconfig.txt 2>&1
    ip addr      >$output_dir/os_ip.txt       2>&1
    netstat -anp >$output_dir/os_netstat.txt  2>&1
    ps -eflww    >$output_dir/os_ps.txt       2>&1
    top -bc -n 5 >$output_dir/os_top.txt      2>&1
    df -h        >$output_dir/os_df.txt       2>&1
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

    print_info "============================================================================================"
    print_info "压缩目录(已删除heapdump)："
    print_info "zip -r $output_dir.without.heapdump.zip $output_dir"
    print_info "============================================================================================"
    [ -n "$output_dir" ] && [ -f "$output_dir/mem_heap_dump.hprof" ] && rm $output_dir/mem_heap_dump.hprof
    zip -r $output_dir.without.heapdump.zip $output_dir | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    print_info "============================================================================================"
    print_info "显示目录大小(已删除heapdump)："
    print_info "du -ah $output_dir* | sort -k 2 | column -t"
    print_info "============================================================================================"
    du -ah $output_dir* | sort -k 2 | column -t | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    echo "The target file is [ $output_dir.zip ] and [ $output_dir.without.heapdump.zip ]." | tee -a $log
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

# 搜集信息。##
java_info_collect $java_pid
os_info_collect

# 退出。#
exit_gracefully
