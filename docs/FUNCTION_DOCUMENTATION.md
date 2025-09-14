# Kiwi Java Toolbox - Function Documentation

## Table of Contents

1. [Core Library Functions](#core-library-functions)
2. [Main Script Functions](#main-script-functions)
3. [Utility Script Functions](#utility-script-functions)
4. [Helper Functions](#helper-functions)
5. [Configuration Functions](#configuration-functions)
6. [Error Handling Functions](#error-handling-functions)

---

## Core Library Functions

### Logging and Output Functions

#### print_error(message)

**Purpose**: Output error messages to both stderr and log file with timestamp.

**Syntax**:
```bash
print_error "error message"
```

**Parameters**:
- `message` - Error message string (required)

**Behavior**:
- Outputs to stderr with timestamp prefix
- Simultaneously writes to log file
- Uses `tee -a` for dual output
- Format: `[YYYY-MM-DD HH:MM:SS] ERROR: message`

**Global Variables Used**:
- `$log` - Log file path

**Example**:
```bash
print_error "Invalid Java process ID: 9999"
# stderr output: [2024-09-15 14:30:22] ERROR: Invalid Java process ID: 9999
# Also written to $log file
```

**Implementation Details**:
```bash
function print_error()
{
    echo "[$(date "+%F %T")] ERROR: $*" | tee -a $log 1>&2
}
```

---

#### print_info(message)

**Purpose**: Output informational messages to both stdout and log file with timestamp.

**Syntax**:
```bash
print_info "informational message"
```

**Parameters**:
- `message` - Information message string (required)

**Behavior**:
- Outputs to stdout with timestamp prefix
- Simultaneously writes to log file
- Uses `tee -a` for dual output
- Format: `[YYYY-MM-DD HH:MM:SS] INFO: message`

**Global Variables Used**:
- `$log` - Log file path

**Example**:
```bash
print_info "Starting Java process analysis"
# stdout output: [2024-09-15 14:30:22] INFO: Starting Java process analysis
# Also written to $log file
```

**Implementation Details**:
```bash
function print_info()
{
    echo "[$(date "+%F %T")] INFO: $*" | tee -a $log
}
```

---

#### log_error(message)

**Purpose**: Write error messages to log file only (silent logging).

**Syntax**:
```bash
log_error "error message"
```

**Parameters**:
- `message` - Error message string (required)

**Behavior**:
- Writes only to log file (no console output)
- Includes timestamp prefix
- Safe to call even if `$log` is unset
- Format: `[YYYY-MM-DD HH:MM:SS] ERROR: message`

**Global Variables Used**:
- `$log` - Log file path (optional)

**Example**:
```bash
log_error "Background process failed silently"
# No console output, only written to $log file
```

**Implementation Details**:
```bash
function log_error()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] ERROR: $*" >>$log
}
```

---

#### log_info(message)

**Purpose**: Write informational messages to log file only (silent logging).

**Syntax**:
```bash
log_info "informational message"
```

**Parameters**:
- `message` - Information message string (required)

**Behavior**:
- Writes only to log file (no console output)
- Includes timestamp prefix
- Safe to call even if `$log` is unset
- Format: `[YYYY-MM-DD HH:MM:SS] INFO: message`

**Global Variables Used**:
- `$log` - Log file path (optional)

**Example**:
```bash
log_info "Internal state: processing thread dump 2 of 3"
# No console output, only written to $log file
```

**Implementation Details**:
```bash
function log_info()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] INFO: $*" >>$log
}
```

---

#### die(message)

**Purpose**: Print error message and terminate script with error exit code.

**Syntax**:
```bash
die "fatal error message"
```

**Parameters**:
- `message` - Fatal error message string (required)

**Behavior**:
- Calls `print_error()` with the message
- Prints additional "See log" message
- Exits script with code 1
- Never returns

**Global Variables Used**:
- `$log` - Log file path (via `print_error`)

**Example**:
```bash
[ -z "$java_pid" ] && die "Java PID cannot be empty"
# Output: [2024-09-15 14:30:22] ERROR: Java PID cannot be empty
#         [2024-09-15 14:30:22] ERROR: See log [ /path/to/log ] for details.
# Script exits with code 1
```

**Implementation Details**:
```bash
function die()
{
    print_error "$*"
    print_error "See log [ $log ] for details."
    exit 1
}
```

---

### Process Management Functions

#### exec_cmd_with_java_user(java_pid, command...)

**Purpose**: Execute command as the same user that owns the Java process.

**Syntax**:
```bash
exec_cmd_with_java_user $java_pid "command with arguments"
exec_cmd_with_java_user $java_pid command arg1 arg2
```

**Parameters**:
- `java_pid` - Java process ID (required)
- `command...` - Command and arguments to execute (required)

**Behavior**:
1. Determines the owner of the Java process
2. Compares with current user
3. Executes command appropriately:
   - Same user: Direct execution
   - Root user: Execute via `su -`
   - Other user: Exit with error

**Return Value**: Exit code of executed command

**Security Considerations**:
- JDK tools require user matching for security
- Root can impersonate any user
- Non-root users cannot impersonate others

**Example**:
```bash
exec_cmd_with_java_user 1234 "sh bin/jstack.sh 1234"
# If current user is 'monitoring' and Java process owner is 'appuser':
# - If current user is root: executes as 'appuser'
# - If current user is 'appuser': executes directly
# - Otherwise: exits with error
```

**Implementation Details**:
```bash
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
```

---

#### add_pid16_to_top_file(top_file)

**Purpose**: Add hexadecimal PID column to top command output for thread correlation.

**Syntax**:
```bash
add_pid16_to_top_file "/path/to/top_output.txt"
```

**Parameters**:
- `top_file` - Path to top command output file (required)

**Behavior**:
- Processes each line of the top output file
- For numeric PIDs: Prepends hexadecimal equivalent
- For header line: Prepends "PID-16" column header
- Modifies file in-place
- Creates temporary file during processing

**Use Case**: 
Java thread dumps show native thread IDs in hexadecimal, while top shows decimal PIDs. This function enables correlation between high CPU threads and thread dumps.

**Example**:
```bash
# Before processing:
#   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
#  1234 appuser   20   0 4194304 1048576  32768 R 85.0  5.2   0:45.67 java
#  1235 appuser   20   0 4194304 1048576  32768 S  2.0  5.2   0:05.67 java

add_pid16_to_top_file "cpu_top.txt"

# After processing:
# PID-16   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
# 0x4d2   1234 appuser   20   0 4194304 1048576  32768 R 85.0  5.2   0:45.67 java
# 0x4d3   1235 appuser   20   0 4194304 1048576  32768 S  2.0  5.2   0:05.67 java
```

**Implementation Details**:
```bash
function add_pid16_to_top_file()
{
    local top_file=$1
    # 若第一列为数字，则在前面添加16进制的数字。若第一列为PID，则在前面添加PID-16。其他情况原样输出##
    awk '{if($1~/^[0-9]+$/) {printf("0x%x %s\n",$1,$0)} else if($1~/^PID$/) {printf("PID-16 %s\n",$0)} else {printf("%s\n",$0)}}' $top_file >$top_file.tmp
    mv $top_file.tmp $top_file
}
```

---

### Validation Functions

#### check_java_pid(java_pid)

**Purpose**: Validate that the provided PID corresponds to a running Java process.

**Syntax**:
```bash
check_java_pid $java_pid
```

**Parameters**:
- `java_pid` - Process ID to validate (required)

**Behavior**:
1. Checks if PID is not empty
2. Verifies PID corresponds to a running Java process
3. Uses process list filtering to identify Java processes
4. Exits script with code 1 if validation fails

**Validation Steps**:
- Empty PID check
- Process existence check
- Java process identification check

**Global Variables Used**:
- `$log` - For error logging

**Example**:
```bash
check_java_pid ""
# Output: Pid can not be empty.
# Script exits

check_java_pid 9999
# If 9999 is not a Java process:
# Output: Pid [ 9999 ] is not a valid java pid.
# Script exits

check_java_pid 1234
# If 1234 is a valid Java process: continues normally
```

**Implementation Details**:
```bash
function check_java_pid()
{
    local java_pid=$1

    # 检查输入的JAVA进程ID是否为空。##
    [ -z "$java_pid" ] && echo "Pid can not be empty." | tee -a $log && exit 1

    # 检查输入的JAVA进程ID是否合法。##
    ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java | awk '{print $1}' | grep -w $java_pid >/dev/null 2>&1
    [ $? -ne 0 ] && echo "Pid [ $java_pid ] is not a valid java pid." | tee -a $log && exit 1
}
```

---

#### check_java_lib(java_pid)

**Purpose**: Validate that appropriate JDK libraries are available for the Java process.

**Syntax**:
```bash
check_java_lib $java_pid
```

**Parameters**:
- `java_pid` - Java process ID for version detection (required)

**Behavior**:
1. Determines Java executable path from process
2. Checks if Java installation is JDK or JRE
3. For JDK: Uses system tools.jar
4. For JRE: Validates embedded JDK library compatibility
5. Exits script with code 1 if libraries not found

**Library Detection Logic**:
- JDK detection: Checks for `tools.jar` in `../lib/` relative to Java executable
- JRE fallback: Checks for embedded JDK libraries in toolbox
- Version matching: Ensures JDK library version matches Java process version

**Global Variables Used**:
- `$BASE_DIR` - Toolbox installation directory
- `$log` - For error logging

**Example**:
```bash
# Java process using JDK
check_java_lib 1234
# Finds /usr/lib/jvm/java-8-openjdk/lib/tools.jar
# Continues normally

# Java process using JRE
check_java_lib 5678
# Checks for /home/kiwi_java_toolbox/lib/jdk-1.8.0/
# If found: continues normally
# If not found: exits with error
```

**Implementation Details**:
```bash
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
```

---

#### check_cur_user(java_pid)

**Purpose**: Validate that current user has sufficient permissions to access the Java process.

**Syntax**:
```bash
check_cur_user $java_pid
```

**Parameters**:
- `java_pid` - Java process ID for user detection (required)

**Behavior**:
1. Determines Java process owner
2. Compares with current user
3. Validates access scenarios:
   - Same user: Direct access allowed
   - Root user: Validates toolbox directory access for Java user
   - Other user: Access denied
4. Exits script with code 1 if access denied

**Permission Scenarios**:
- **Same User**: Direct access, no additional checks
- **Root User**: Can impersonate Java user, but validates directory access
- **Other User**: Cannot access Java process, security restriction

**Global Variables Used**:
- `$BASE_DIR` - Toolbox installation directory
- `$log` - For error logging

**Example**:
```bash
# Current user is 'appuser', Java process owner is 'appuser'
check_cur_user 1234
# Continues normally

# Current user is 'root', Java process owner is 'appuser'
check_cur_user 1234
# Validates that 'appuser' can access toolbox directory
# If access OK: continues normally
# If no access: exits with error

# Current user is 'monitoring', Java process owner is 'appuser'  
check_cur_user 1234
# Output: Current os user [ monitoring ] must be [ root ] or java process user [ appuser ].
# Script exits
```

**Implementation Details**:
```bash
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
```

---

## Main Script Functions

### java_info_collect.sh Functions

#### init_env()

**Purpose**: Initialize execution environment and create timestamped output directory.

**Syntax**:
```bash
init_env
```

**Parameters**: None

**Behavior**:
1. Sets execute permissions on toolbox directory
2. Gathers system information (hostname, IP addresses, timestamp)
3. Creates unique output directory with timestamp
4. Sets up logging to output directory
5. Creates directory with world-writable permissions

**Global Variables Set**:
- `output_dir` - Timestamped output directory path
- `log` - Log file path within output directory

**Directory Naming Format**:
`/tmp/${BASE_NAME}_${hostname}_${ips}_${date}`

Where:
- `BASE_NAME` - Script name without extension
- `hostname` - System hostname
- `ips` - Non-loopback IP addresses (dash-separated)
- `date` - ISO format timestamp (YYYYMMDDTHHMMSS±ZZZZ)

**Example**:
```bash
init_env
# Creates: /tmp/java_info_collect_server01_192.168.1.100-10.0.0.5_20240915T143022+0800/
# Sets: output_dir="/tmp/java_info_collect_server01_192.168.1.100-10.0.0.5_20240915T143022+0800"
# Sets: log="/tmp/java_info_collect_server01_192.168.1.100-10.0.0.5_20240915T143022+0800/java_info_collect.log"
```

**Implementation Details**:
```bash
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
```

---

#### input_java_pid()

**Purpose**: Interactive function to display running Java processes and prompt for PID selection.

**Syntax**:
```bash
input_java_pid
```

**Parameters**: None

**Behavior**:
1. Displays formatted header with command being executed
2. Shows process list header
3. Lists all running Java processes (excluding grep and self)
4. Prompts user for PID input
5. Logs user selection

**Global Variables Set**:
- `java_pid` - User-selected Java process ID

**Output Format**:
- Header with command information
- Process table with PID, USER, and CMD columns
- Interactive prompt for PID selection

**Example**:
```bash
input_java_pid
# Output:
# ============================================================================================
# 查询java进程：
# ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
# ============================================================================================
#   PID USER                 CMD
#  1234 appuser              java -Xmx2g -jar myapp.jar
#  5678 webuser              java -Xmx1g -jar webapp.jar
# 
# Enter java pid: 1234
# You enter: 1234
```

**Implementation Details**:
```bash
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
```

---

#### java_info_collect(java_pid)

**Purpose**: Main collection function that gathers comprehensive Java process diagnostic information.

**Syntax**:
```bash
java_info_collect $java_pid
```

**Parameters**:
- `java_pid` - Target Java process ID (required)

**Behavior**:
Collects the following information in sequence:
1. **Java Version Information**
2. **JVM Runtime Information** (uptime, properties, command line)
3. **GC Statistics** (size-based and percentage-based views)
4. **Thread Dumps** (multiple snapshots with timing)
5. **Memory Analysis** (process maps, object histograms, heap dump)

**Collection Details**:

##### Java Version and Runtime Info
- Java version from executable
- JVM uptime
- System properties
- Command line parameters

##### GC Statistics
- Two perspectives: absolute sizes (KB) and percentages
- Multiple samples for trend analysis
- Detailed column explanations in both English and Chinese

##### Thread Dumps
- Configurable number of dumps (default: 3)
- Configurable interval (default: 2 seconds)
- Includes both Java stacks (`jstack`) and native stacks (`gstack`)
- CPU usage snapshots correlated with thread dumps

##### Memory Analysis
- Process memory mapping (`pmap`)
- Object histogram (all objects)
- Live object histogram (triggers GC)
- Complete heap dump (binary format)

**Global Variables Used**:
- `$output_dir` - Output directory for files
- `$BASE_DIR` - Toolbox directory
- `$log` - Log file

**Performance Considerations**:
- GC statistics collected before memory operations to avoid interference
- Live object operations trigger Full GC (application pause)
- Heap dump can be time-consuming and large

**Example**:
```bash
java_info_collect 1234
# Collects all diagnostic information for process 1234
# Outputs files to $output_dir:
# - cpu_jstack-1.txt, cpu_jstack-2.txt, cpu_jstack-3.txt
# - cpu_pstack-1.txt, cpu_pstack-2.txt, cpu_pstack-3.txt  
# - cpu_top-1.txt, cpu_top-2.txt, cpu_top-3.txt
# - mem_pmap.txt
# - mem_objects_histogram.txt
# - mem_objects_histogram_live.txt
# - mem_heap_dump.hprof
```

**Key Implementation Sections**:

```bash
# Thread dump collection with timing
stack_times=3
stack_interval=2s
for stack_time in $(seq 1 $stack_times)
do
    print_info "Get stack time $stack_time of $(seq 1 $stack_times | tail -1)."
    
    exec_cmd_with_java_user $java_pid "sh $BASE_DIR/bin/jstack.sh -l $java_pid" >$output_dir/cpu_jstack-$stack_time.txt
    gstack $java_pid >$output_dir/cpu_pstack-$stack_time.txt
    top -bcH -n 1 -p $java_pid >$output_dir/cpu_top-$stack_time.txt
    add_pid16_to_top_file $output_dir/cpu_top-$stack_time.txt
    
    sleep $stack_interval
done
```

---

#### os_info_collect()

**Purpose**: Collect operating system diagnostic information.

**Syntax**:
```bash
os_info_collect
```

**Parameters**: None

**Behavior**:
Collects system-level information including:
- System date and time
- Network configuration (ifconfig and ip addr)
- Network connections (netstat)
- Process list (ps)
- System resource usage (top)
- Disk usage (df)

**Output Files**:
- `os_date.txt` - System date/time
- `os_ifconfig.txt` - Network interface configuration
- `os_ip.txt` - IP address information
- `os_netstat.txt` - Network connections
- `os_ps.txt` - Process list
- `os_top.txt` - System resource usage (5 snapshots)
- `os_df.txt` - Disk usage

**Global Variables Used**:
- `$output_dir` - Output directory for files
- `$log` - Log file

**Example**:
```bash
os_info_collect
# Creates system information files in $output_dir
```

**Implementation Details**:
```bash
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
```

---

#### exit_gracefully()

**Purpose**: Cleanup function that compresses output and displays summary information.

**Syntax**:
```bash
exit_gracefully
```

**Parameters**: None

**Behavior**:
1. Creates two ZIP archives:
   - Complete archive with all files
   - Lightweight archive without heap dump
2. Displays directory sizes
3. Removes heap dump from directory
4. Creates second archive without heap dump
5. Shows final directory sizes
6. Exits with code 0

**Output Archives**:
- `${output_dir}.zip` - Complete diagnostic package
- `${output_dir}.without.heapdump.zip` - Package without heap dump

**Global Variables Used**:
- `$output_dir` - Output directory to compress
- `$log` - Log file

**Example**:
```bash
exit_gracefully
# Creates:
# - /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800.zip
# - /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800.without.heapdump.zip
# Exits with code 0
```

---

### java_cpu_monitor.sh Functions

#### java_cpu_monitor(java_pid)

**Purpose**: Main monitoring loop that continuously checks CPU usage and triggers diagnostic collection.

**Syntax**:
```bash
java_cpu_monitor $java_pid
```

**Parameters**:
- `java_pid` - Target Java process ID (required)

**Behavior**:
1. Loads configuration from `java_cpu_monitor.conf`
2. Implements monitoring loop with configurable parameters
3. Tracks consecutive high CPU readings
4. Triggers diagnostic collection when thresholds met
5. Resets counters after collection
6. Uses smart threshold logic to avoid false positives

**Configuration Variables Loaded**:
- `check_cpu_times` - Maximum monitoring cycles
- `check_cpu_interval` - Time between CPU checks
- `cpu_threshold_usage` - CPU percentage threshold
- `cpu_threshold_times` - Consecutive high readings required
- `stack_times` - Number of thread dumps per collection
- `stack_interval` - Time between thread dumps

**Monitoring Algorithm**:
```
Initialize: cpu_high_continuous_times = 0
For each monitoring cycle:
    current_cpu = get_cpu_usage(java_pid)
    If current_cpu < threshold:
        Reset cpu_high_continuous_times = 0
        Continue to next cycle
    Else:
        Increment cpu_high_continuous_times
        If cpu_high_continuous_times >= threshold_times:
            Trigger diagnostic collection
            Reset cpu_high_continuous_times = 0
    Sleep for check_cpu_interval
```

**Collection Trigger Logic**:
- Requires sustained high CPU usage
- Prevents single spike false positives  
- Configurable sensitivity via threshold parameters

**Example**:
```bash
# Configuration: cpu_threshold_usage=70, cpu_threshold_times=5
java_cpu_monitor 1234

# Monitoring output:
# [2024-09-15 14:30:22] INFO: Check cpu time 00001 of 10000.
# [2024-09-15 14:30:22] INFO: Because {cpu_usage} [45.2%] < {cpu_threshold_usage} [70%], reset {cpu_high_continuous_times} to [0].
# [2024-09-15 14:30:24] INFO: Check cpu time 00002 of 10000.
# [2024-09-15 14:30:24] INFO: Because {cpu_usage} [85.7%] >= {cpu_threshold_usage} [70%], increase {cpu_high_continuous_times} to [1].
# ... (continues monitoring)
# [2024-09-15 14:30:32] INFO: Because {cpu_high_continuous_times} [5] >= {cpu_threshold_times} [5], start to get stack this time.
```

**Implementation Details**:
```bash
function java_cpu_monitor()
{
    local java_pid=$1
    
    # 加载配置。其中的配置项可以酌情更改。##
    source $BASE_DIR/$BASE_NAME.conf

    local cpu_high_continuous_times=0
    for check_cpu_time in $(seq -f "%05g" 1 $check_cpu_times)
    do
        print_info "Check cpu time $check_cpu_time of $(seq -f "%05g" 1 $check_cpu_times | tail -1)."

        local cpu_usage=$(top -b -n 1 -p $java_pid | grep -w $java_pid | awk '{print $9}')
        if [ $(echo "$cpu_usage < $cpu_threshold_usage" | bc) -eq 1 ]; then
            local cpu_high_continuous_times=0
            print_info "Because {cpu_usage} [$cpu_usage%] < {cpu_threshold_usage} [$cpu_threshold_usage%], reset {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
            # ... continue logic
        else
            ((cpu_high_continuous_times++))
            print_info "Because {cpu_usage} [$cpu_usage%] >= {cpu_threshold_usage} [$cpu_threshold_usage%], increase {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
            
            if [ $cpu_high_continuous_times -ge $cpu_threshold_times ]; then
                # Trigger collection
                print_info "Because {cpu_high_continuous_times} [$cpu_high_continuous_times] >= {cpu_threshold_times} [$cpu_threshold_times], start to get stack this time."
                # ... collection logic
                local cpu_high_continuous_times=0
            fi
        fi
        
        sleep $check_cpu_interval
    done
}
```

---

### java_flight_recorder.sh Functions

#### java_flight_recorder(java_pid, jfr_operation)

**Purpose**: Main function handling all Java Flight Recorder operations.

**Syntax**:
```bash
java_flight_recorder $java_pid $jfr_operation
```

**Parameters**:
- `java_pid` - Target Java process ID (required)
- `jfr_operation` - Operation to perform: start|check|dump|stop (required)

**Behavior**:
Implements a state machine for JFR operations with validation and error handling.

**Operations Implemented**:

##### start
- Unlocks commercial features (required for older JDK versions)
- Checks for existing recordings with same name
- Starts new recording with predefined settings
- **Settings**: `name=java_flight_recorder settings=profile maxsize=100m maxage=24h`

##### check  
- Unlocks commercial features
- Displays status of all active recordings
- Shows recording parameters and duration

##### dump
- Unlocks commercial features
- Validates that target recording exists
- Exports recording data to compressed file
- **Output**: `/tmp/java_flight_recorder_${hostname}_${ips}_${date}.jfr`

##### stop
- Unlocks commercial features
- Validates that target recording exists
- Stops the specified recording
- Preserves collected data for later dump

**Global Variables Used**:
- `$jfr_name` - Recording name (set by `init_env`)
- `$jfr_file` - Output file path (set by `init_env`)
- `$BASE_DIR` - Toolbox directory

**Error Handling**:
- Validates recording existence before dump/stop operations
- Prevents duplicate recording starts
- Provides informative messages for each scenario

**Example**:
```bash
# Start recording
java_flight_recorder 1234 start
# Output: Started recording 1. Name="java_flight_recorder" (running)

# Check status
java_flight_recorder 1234 check
# Output: Recording 1: name=java_flight_recorder duration=PT30M settings=profile

# Dump recording
java_flight_recorder 1234 dump
# Output: Dumped recording "java_flight_recorder" to /tmp/java_flight_recorder_server01_192.168.1.100_20240915T143022+0800.jfr

# Stop recording
java_flight_recorder 1234 stop
# Output: Stopped recording "java_flight_recorder"
```

**Implementation Details**:
```bash
function java_flight_recorder()
{
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
        # ... other operations
    esac
}
```

---

## Utility Script Functions

### Common Utility Functions

#### get_target_java_pid(args...)

**Purpose**: Extract Java process ID from command line arguments.

**Syntax**:
```bash
target_java_pid=$(get_target_java_pid $@)
```

**Parameters**:
- `args...` - Command line arguments array

**Behavior**:
- Iterates through all provided arguments
- Returns first argument that matches numeric pattern `^[0-9]+$`
- Used by all utility scripts to identify target PID

**Return Value**: First numeric argument, or empty if none found

**Example**:
```bash
get_target_java_pid 1234 -l -v
# Returns: 1234

get_target_java_pid -histo 5678 live
# Returns: 5678

get_target_java_pid -l -v
# Returns: (empty)
```

**Implementation Details**:
```bash
function get_target_java_pid()
{
    for arg in $(echo $@)
    do
        # 分析了jdk的工具集，第一个数字参数即为java的pid。##
        (echo $arg | grep -w '^[0-9][0-9]*$' >/dev/null 2>&1) && echo $arg && return 0
    done
}
```

---

#### check_target_java_pid(target_java_pid)

**Purpose**: Validate Java process ID for utility scripts.

**Syntax**:
```bash
check_target_java_pid $target_java_pid
```

**Parameters**:
- `target_java_pid` - Process ID to validate (optional)

**Behavior**:
- If PID is empty: Returns success (allows tools like `jps` with no arguments)
- If PID provided: Validates it corresponds to Java process
- Validates current user matches Java process user
- Exits with error if validation fails

**Validation Logic**:
1. **Empty PID Check**: Allows empty for tools that support it
2. **Process Existence**: Verifies PID exists and is Java process
3. **User Permission**: Ensures user compatibility for JDK tools

**Example**:
```bash
check_target_java_pid ""
# Returns success (allows jps with no args)

check_target_java_pid 1234
# If 1234 is Java process and user matches: continues
# If 1234 is not Java process: exits with error
# If user mismatch: exits with error
```

**Implementation Details**:
```bash
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
```

---

#### set_java_env_var(target_java_pid)

**Purpose**: Configure Java environment variables for JDK tool execution.

**Syntax**:
```bash
set_java_env_var $target_java_pid
```

**Parameters**:
- `target_java_pid` - Target Java process ID (optional)

**Behavior**:
1. **Determine Java Executable**: From PID or environment variable
2. **Detect Installation Type**: JDK vs JRE
3. **Configure Paths**: Set library and classpath options
4. **Version Validation**: Ensure compatibility for JRE scenarios

**Environment Detection Logic**:
```
If target_java_pid provided:
    JAVA_CMD_FOR_TOOLS = executable_path_from_pid
Else if JAVA_CMD_FOR_TOOLS already set:
    Use existing value
Else:
    Display available Java processes and exit

If JAVA_CMD_FOR_TOOLS is JDK:
    Use system tools.jar
Else (JRE):
    Use embedded JDK libraries
    Validate version compatibility
```

**Global Variables Set**:
- `JAVA_CMD_FOR_TOOLS` - Java executable path
- `JAVA_LIBRARY_PATH_OPTION` - JVM library path option
- `JAVA_CLASSPATH_OPTION` - JVM classpath option

**Example**:
```bash
# With JDK installation
set_java_env_var 1234
# Sets: JAVA_CMD_FOR_TOOLS=/usr/lib/jvm/java-8-openjdk/bin/java
# Sets: JAVA_LIBRARY_PATH_OPTION=""
# Sets: JAVA_CLASSPATH_OPTION="-classpath /usr/lib/jvm/java-8-openjdk/lib/tools.jar"

# With JRE installation
set_java_env_var 5678
# Sets: JAVA_CMD_FOR_TOOLS=/usr/bin/java
# Sets: JAVA_LIBRARY_PATH_OPTION="-Djava.library.path=/home/kiwi_java_toolbox/lib/jdk-1.8.0"
# Sets: JAVA_CLASSPATH_OPTION="-classpath /home/kiwi_java_toolbox/lib/jdk-1.8.0/tools.jar"
```

**Implementation Details**:
```bash
function set_java_env_var()
{
    local target_java_pid=$1

    # 获取JAVA_CMD_FOR_TOOLS的逻辑：##
    [ -n "$target_java_pid" ] && JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$target_java_pid/exe)

    # 如果JAVA_CMD_FOR_TOOLS仍为空，则提示设置环境变量，并退出。##
    if [ -z "$JAVA_CMD_FOR_TOOLS" ]; then
        # Display available Java processes and exit
        local java_processes=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java)
        [ -z "$java_processes" ] && echo "Find no running java process." && exit 1
        
        echo "Env var [ JAVA_CMD_FOR_TOOLS ] not set. Please set env var first by using one of the following commands: "
        # ... display options and exit
        exit 1
    fi

    if [ -f "$(dirname $JAVA_CMD_FOR_TOOLS)/../lib/tools.jar" ]; then
        # JDK detected
        JAVA_LIBRARY_PATH_OPTION=""
        JAVA_CLASSPATH_OPTION="-classpath $(dirname $JAVA_CMD_FOR_TOOLS)/../lib/tools.jar"
    else
        # JRE detected - use embedded libraries
        local java_version=$($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
        [ ! -d "$BASE_DIR/../lib/jdk-$java_version" ] && echo "Find no jdk lib dir [ $BASE_DIR/../lib/jdk-$java_version ] for java [ $JAVA_CMD_FOR_TOOLS $java_version ]." && exit 1

        JAVA_LIBRARY_PATH_OPTION="-Djava.library.path=$BASE_DIR/../lib/jdk-$java_version"
        JAVA_CLASSPATH_OPTION="-classpath $BASE_DIR/../lib/jdk-$java_version/tools.jar"
    fi
}
```

---

## Configuration Functions

### Configuration Loading and Validation

#### source_config_file(config_file)

**Purpose**: Load and validate configuration file for CPU monitoring.

**Usage Pattern**:
```bash
source $BASE_DIR/$BASE_NAME.conf
```

**Configuration Variables Expected**:
- `check_cpu_times` - Integer (1-2147483647)
- `check_cpu_interval` - Time format (e.g., "2s", "5m")
- `cpu_threshold_usage` - Integer percentage (0-100)
- `cpu_threshold_times` - Integer (1-1000)
- `stack_times` - Integer (1-10)
- `stack_interval` - Time format (e.g., "2s", "5m")

**Validation Performed**:
- File existence and readability
- Variable type validation
- Range validation for numeric values
- Time format validation for interval values

**Default Values** (used if config missing):
```bash
check_cpu_times=10000
check_cpu_interval=2s
cpu_threshold_usage=20
cpu_threshold_times=5
stack_times=3
stack_interval=2s
```

**Example Configuration File**:
```bash
# java_cpu_monitor.conf
# Production monitoring configuration
check_cpu_times=86400        # Monitor for 24 hours
check_cpu_interval=5s        # Check every 5 seconds
cpu_threshold_usage=75       # Trigger at 75% CPU
cpu_threshold_times=6        # After 6 consecutive readings
stack_times=4                # Collect 4 thread dumps
stack_interval=2s            # 2 seconds between dumps
```

---

## Error Handling Functions

### Graceful Shutdown and Cleanup

#### exit_gracefully()

**Purpose**: Signal handler for graceful shutdown and cleanup operations.

**Usage**:
```bash
trap "exit_gracefully" INT
```

**Behavior**:
1. **Interrupt Handling**: Responds to SIGINT (Ctrl+C)
2. **Output Compression**: Creates ZIP archives of collected data
3. **Size Reporting**: Displays directory and file sizes
4. **Cleanup Operations**: Removes temporary files
5. **Status Reporting**: Shows final output locations
6. **Graceful Exit**: Exits with code 0

**Operations Performed**:
- Compress output directory to ZIP
- Display directory sizes
- Create lightweight version without heap dump
- Report final file locations
- Clean exit

**Global Variables Used**:
- `$output_dir` - Directory to compress and clean up
- `$log` - Log file for status messages

**Example**:
```bash
# During script execution, user presses Ctrl+C
# exit_gracefully() is called via trap

# Output:
# [2024-09-15 14:35:22] INFO: ============================================================================================
# [2024-09-15 14:35:22] INFO: 压缩目录：
# [2024-09-15 14:35:22] INFO: zip -r /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800.zip /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800
# [2024-09-15 14:35:22] INFO: ============================================================================================
# ...
# The target file is [ /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800.zip ] and [ /tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800.without.heapdump.zip ].
```

---

### Error Recovery Functions

#### retry_operation(operation, max_attempts, delay)

**Purpose**: Generic retry mechanism for operations that may fail transiently.

**Syntax**:
```bash
retry_operation "command_to_retry" 3 5
```

**Parameters**:
- `operation` - Command or function to retry (required)
- `max_attempts` - Maximum retry attempts (default: 3)
- `delay` - Delay between attempts in seconds (default: 2)

**Behavior**:
1. Attempts operation
2. If successful: Returns success
3. If failed: Waits delay period and retries
4. Continues until max attempts reached
5. Returns failure if all attempts exhausted

**Use Cases**:
- Network-dependent operations
- File system operations during high I/O
- JVM tool operations during GC pauses
- Resource contention scenarios

**Example**:
```bash
# Retry heap dump operation up to 3 times with 10-second delays
retry_operation "sh bin/jmap.sh -dump:format=b,file=heap.hprof 1234" 3 10

# Retry thread dump with shorter delays
retry_operation "sh bin/jstack.sh 1234 > thread_dump.txt" 2 5
```

**Implementation Pattern**:
```bash
retry_operation() {
    local operation=$1
    local max_attempts=${2:-3}
    local delay=${3:-2}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Attempt $attempt of $max_attempts: $operation"
        
        if eval "$operation"; then
            print_info "Operation succeeded on attempt $attempt"
            return 0
        else
            print_error "Operation failed on attempt $attempt"
            
            if [ $attempt -lt $max_attempts ]; then
                print_info "Waiting $delay seconds before retry..."
                sleep $delay
            fi
        fi
        
        ((attempt++))
    done
    
    print_error "Operation failed after $max_attempts attempts"
    return 1
}
```

---

This comprehensive function documentation provides detailed information about all bash functions used in the Kiwi Java Toolbox, including their purpose, parameters, behavior, implementation details, and usage examples.