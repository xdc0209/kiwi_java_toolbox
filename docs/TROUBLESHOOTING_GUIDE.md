# Kiwi Java Toolbox - Troubleshooting Guide

## Table of Contents

1. [Common Installation Issues](#common-installation-issues)
2. [Permission and Security Problems](#permission-and-security-problems)
3. [JDK Version Compatibility Issues](#jdk-version-compatibility-issues)
4. [Runtime Errors and Solutions](#runtime-errors-and-solutions)
5. [Performance Issues](#performance-issues)
6. [Environment-Specific Problems](#environment-specific-problems)
7. [Data Collection Issues](#data-collection-issues)
8. [Monitoring and Alerting Problems](#monitoring-and-alerting-problems)
9. [Advanced Debugging Techniques](#advanced-debugging-techniques)
10. [FAQ and Quick Solutions](#faq-and-quick-solutions)

---

## Common Installation Issues

### Issue 1: Extraction and Permission Problems

**Problem**: Toolbox files cannot be extracted or accessed after installation.

**Symptoms**:
```bash
$ unzip kiwi_java_toolbox-*.zip
unzip: cannot find or open kiwi_java_toolbox-*.zip

$ sh java_info_collect.sh
bash: java_info_collect.sh: Permission denied
```

**Solutions**:

```bash
# Solution 1: Check file existence and permissions
ls -la kiwi_java_toolbox*
# If file doesn't exist, verify download location

# Solution 2: Extract with proper permissions
unzip -o kiwi_java_toolbox-*.zip -d /home
chmod -R 755 /home/kiwi_java_toolbox

# Solution 3: Verify directory structure
find /home/kiwi_java_toolbox -type f -name "*.sh" -exec chmod +x {} \;

# Solution 4: Check filesystem permissions
df -h /home
# Ensure filesystem is not mounted read-only
```

**Prevention**:
```bash
# Always verify installation
cd /home/kiwi_java_toolbox
ls -la *.sh
./java_info_collect.sh --help 2>/dev/null && echo "Installation OK" || echo "Installation failed"
```

### Issue 2: Missing Dependencies

**Problem**: Required system tools or libraries are missing.

**Symptoms**:
```bash
$ sh java_info_collect.sh
./java_info_collect.sh: line 186: top: command not found
./java_info_collect.sh: line 313: gstack: command not found
```

**Solutions**:

```bash
# Check for required tools
check_dependencies() {
    local missing_tools=()
    
    for tool in bash ps top netstat ifconfig awk sed grep; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    return 0
}

# Install missing tools (Red Hat/CentOS)
sudo yum install -y procps-ng net-tools gdb

# Install missing tools (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y procps net-tools gdb

# Install missing tools (SUSE)
sudo zypper install -y procps net-tools gdb
```

**Alternative Solutions**:
```bash
# If gstack is not available, create alternative
if ! command -v gstack >/dev/null 2>&1; then
    gstack() {
        gdb -batch -ex "thread apply all bt" -p $1 2>/dev/null
    }
    export -f gstack
fi

# If ifconfig is not available, use ip command
get_ip_addresses() {
    if command -v ifconfig >/dev/null 2>&1; then
        ifconfig -a | grep -w 'inet' | awk '{print $2}' | grep -v '127.0.0.1'
    else
        ip addr show | grep -w 'inet' | awk '{print $2}' | cut -d'/' -f1 | grep -v '127.0.0.1'
    fi
}
```

---

## Permission and Security Problems

### Issue 1: Java Process User Mismatch

**Problem**: Current user cannot access Java process due to permission restrictions.

**Symptoms**:
```bash
$ sh java_info_collect.sh
Enter java pid: 1234
Current os user [ monitoring ] must be [ root ] or java process user [ appuser ].

$ sh bin/jstack.sh 1234
java.io.IOException: well-known file is not secure
    at sun.tools.attach.LinuxVirtualMachine.checkPermissions(Native Method)
```

**Diagnosis**:
```bash
# Check current user vs Java process user
JAVA_PID=1234
CURRENT_USER=$(whoami)
JAVA_USER=$(ps -p $JAVA_PID -o user --no-headers)

echo "Current user: $CURRENT_USER"
echo "Java process user: $JAVA_USER"

# Check process details
ps -p $JAVA_PID -o pid,user,cmd
```

**Solutions**:

```bash
# Solution 1: Switch to Java process user
su - $JAVA_USER
cd /home/kiwi_java_toolbox
sh java_info_collect.sh

# Solution 2: Run as root (if available)
sudo sh java_info_collect.sh

# Solution 3: Grant temporary access (as root)
# Add monitoring user to Java user's group
sudo usermod -aG $(id -gn $JAVA_USER) monitoring

# Solution 4: Use sudo with specific user
sudo -u $JAVA_USER sh java_info_collect.sh
```

**Advanced Permission Setup**:
```bash
# Create monitoring-friendly setup
create_monitoring_setup() {
    local java_user=$1
    local monitoring_user=${2:-monitoring}
    
    # Create monitoring user if doesn't exist
    if ! id $monitoring_user >/dev/null 2>&1; then
        sudo useradd -r -s /bin/bash -d /opt/monitoring $monitoring_user
    fi
    
    # Create shared group
    sudo groupadd -f java_monitoring
    sudo usermod -aG java_monitoring $java_user
    sudo usermod -aG java_monitoring $monitoring_user
    
    # Set toolbox permissions
    sudo chown -R $monitoring_user:java_monitoring /home/kiwi_java_toolbox
    sudo chmod -R 750 /home/kiwi_java_toolbox
    
    echo "Monitoring setup completed for user: $monitoring_user"
}

# Usage
create_monitoring_setup appuser monitoring
```

### Issue 2: SELinux/AppArmor Restrictions

**Problem**: Security frameworks preventing tool execution.

**Symptoms**:
```bash
$ sh java_info_collect.sh
Permission denied (SELinux policy violation)

$ dmesg | tail
SELinux: denied { execute } for pid=1234 comm="java_info_collect" path="/home/kiwi_java_toolbox/bin/jstack.sh"
```

**Diagnosis**:
```bash
# Check SELinux status
sestatus
getenforce

# Check recent denials
ausearch -m avc -ts recent | grep java

# Check AppArmor status (Ubuntu)
sudo apparmor_status
```

**Solutions**:

```bash
# SELinux Solutions

# Solution 1: Temporary disable (not recommended for production)
sudo setenforce 0

# Solution 2: Create custom policy
sudo setsebool -P allow_execstack 1
sudo setsebool -P allow_execmem 1

# Solution 3: Set proper context
sudo restorecon -Rv /home/kiwi_java_toolbox
sudo chcon -R -t bin_t /home/kiwi_java_toolbox/bin/

# AppArmor Solutions

# Solution 1: Create profile exception
sudo tee /etc/apparmor.d/local/kiwi_java_toolbox << 'EOF'
# Kiwi Java Toolbox profile
/home/kiwi_java_toolbox/** mr,
/home/kiwi_java_toolbox/bin/** rix,
/tmp/java_info_collect_*/** rw,
/proc/*/exe r,
/proc/*/stat r,
EOF

sudo apparmor_parser -r /etc/apparmor.d/local/kiwi_java_toolbox
```

---

## JDK Version Compatibility Issues

### Issue 1: Version Mismatch Between Tool and Target JVM

**Problem**: JDK tools version doesn't match target Java process version.

**Symptoms**:
```bash
$ sh bin/jstack.sh 1234
com.sun.tools.attach.AttachNotSupportedException: Unable to open socket file: target process not responding or HotSpot VM not loaded

$ sh java_info_collect.sh
Find no jdk lib dir [ /home/kiwi_java_toolbox/lib/jdk-11.0.0 ] for java [ /usr/bin/java 11.0.0 ]
```

**Diagnosis**:
```bash
# Check Java process version
JAVA_PID=1234
JAVA_CMD=$(readlink -m /proc/$JAVA_PID/exe)
$JAVA_CMD -version

# Check available JDK libraries
ls -la /home/kiwi_java_toolbox/lib/

# Check version parsing
$JAVA_CMD -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}'
```

**Solutions**:

```bash
# Solution 1: Extract JDK libraries from target Java installation
extract_jdk_libraries() {
    local java_cmd=$1
    local java_version=$($java_cmd -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
    local jdk_path=$(dirname $java_cmd)/..
    
    echo "Extracting JDK libraries for version: $java_version"
    
    # Create version-specific directory
    mkdir -p /home/kiwi_java_toolbox/lib/jdk-$java_version
    
    # Copy required files
    if [ -f "$jdk_path/lib/tools.jar" ]; then
        cp "$jdk_path/lib/tools.jar" /home/kiwi_java_toolbox/lib/jdk-$java_version/
    fi
    
    # Copy native library
    find "$jdk_path" -name "libattach.so" -exec cp {} /home/kiwi_java_toolbox/lib/jdk-$java_version/ \;
    
    # Create version file
    echo "$java_version" > /home/kiwi_java_toolbox/lib/jdk-$java_version/jdk-version.txt
    
    echo "JDK libraries extracted for version $java_version"
}

# Usage
JAVA_CMD=$(readlink -m /proc/1234/exe)
extract_jdk_libraries $JAVA_CMD

# Solution 2: Use system JDK tools directly
use_system_jdk() {
    local java_pid=$1
    local java_cmd=$(readlink -m /proc/$java_pid/exe)
    local jdk_path=$(dirname $java_cmd)/..
    
    if [ -f "$jdk_path/lib/tools.jar" ]; then
        echo "Using system JDK tools"
        export JAVA_CMD_FOR_TOOLS=$java_cmd
        export JAVA_HOME=$jdk_path
    else
        echo "System Java is JRE, not JDK"
        return 1
    fi
}

# Solution 3: Install matching JDK version
install_matching_jdk() {
    local target_version=$1
    
    case $target_version in
        1.8.*)
            # Red Hat/CentOS
            sudo yum install -y java-1.8.0-openjdk-devel
            # Ubuntu/Debian  
            sudo apt-get install -y openjdk-8-jdk
            ;;
        11.*)
            sudo yum install -y java-11-openjdk-devel
            sudo apt-get install -y openjdk-11-jdk
            ;;
        17.*)
            sudo yum install -y java-17-openjdk-devel
            sudo apt-get install -y openjdk-17-jdk
            ;;
    esac
}
```

### Issue 2: JDK vs JRE Detection Problems

**Problem**: Tool incorrectly identifies JDK vs JRE installations.

**Symptoms**:
```bash
$ sh bin/jcmd.sh 1234 VM.uptime
Find no jdk lib dir [ /home/kiwi_java_toolbox/lib/jdk-1.8.0 ] for java [ /usr/bin/java 1.8.0 ]
```

**Diagnosis and Solution**:
```bash
# Enhanced JDK/JRE detection function
detect_java_environment() {
    local java_pid=$1
    local java_cmd=$(readlink -m /proc/$java_pid/exe)
    local java_home=$(dirname $java_cmd)/..
    
    echo "Java executable: $java_cmd"
    echo "Java home: $java_home"
    
    # Check for JDK indicators
    if [ -f "$java_home/lib/tools.jar" ]; then
        echo "Environment: JDK (Full Development Kit)"
        echo "Tools.jar: Available"
        return 0
    elif [ -f "$java_home/bin/javac" ]; then
        echo "Environment: JDK (Missing tools.jar)"
        echo "Tools.jar: Missing"
        return 1
    else
        echo "Environment: JRE (Runtime Environment Only)"
        
        # Check for embedded JDK libraries
        local java_version=$($java_cmd -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
        if [ -d "/home/kiwi_java_toolbox/lib/jdk-$java_version" ]; then
            echo "Embedded JDK libs: Available for version $java_version"
            return 0
        else
            echo "Embedded JDK libs: Missing for version $java_version"
            return 1
        fi
    fi
}

# Usage
detect_java_environment 1234
```

---

## Runtime Errors and Solutions

### Issue 1: Out of Memory During Heap Dump

**Problem**: Tool runs out of memory when creating heap dumps.

**Symptoms**:
```bash
$ sh bin/jmap.sh -dump:format=b,file=heap.hprof 1234
java.lang.OutOfMemoryError: Java heap space
```

**Solutions**:

```bash
# Solution 1: Increase tool JVM memory
create_high_memory_jmap() {
    cat << 'EOF' > bin/jmap_large.sh
#!/bin/bash
# High-memory version of jmap

# Set large heap for the tool itself
export JAVA_OPTS="-Xmx4g -Xms1g"

# Source original jmap.sh logic but with modified JVM options
JAVA_CMD_FOR_TOOLS="$JAVA_CMD_FOR_TOOLS $JAVA_OPTS"

# Execute original jmap logic
source bin/jmap.sh
EOF
    chmod +x bin/jmap_large.sh
}

# Solution 2: Use streaming heap dump (if available)
streaming_heap_dump() {
    local java_pid=$1
    local output_file=$2
    
    # Try using jcmd for heap dump (more memory efficient)
    sh bin/jcmd.sh $java_pid GC.run_finalization
    sleep 2
    sh bin/jcmd.sh $java_pid GC.run
    sleep 2
    sh bin/jcmd.sh $java_pid VM.classloader_stats > classloader_stats.txt
    
    # Alternative: Use gcore for native dump
    gcore -o native_dump $java_pid
}

# Solution 3: Split heap analysis
analyze_heap_without_dump() {
    local java_pid=$1
    
    echo "Analyzing heap without full dump..."
    
    # Get object histogram (much smaller)
    sh bin/jmap.sh -histo $java_pid > object_histogram.txt
    
    # Get class histogram with counts
    sh bin/jmap.sh -histo:live $java_pid > live_object_histogram.txt
    
    # Get memory usage summary
    sh bin/jstat.sh -gccapacity $java_pid > gc_capacity.txt
    sh bin/jstat.sh -gcutil $java_pid 1000 5 > gc_utilization.txt
    
    echo "Lightweight heap analysis completed"
}
```

### Issue 2: Process Hangs During Data Collection

**Problem**: Target Java process becomes unresponsive during diagnostic collection.

**Symptoms**:
```bash
$ sh java_info_collect.sh
# Process hangs at "获取java虚拟机堆转储" step
# Java application becomes unresponsive
```

**Solutions**:

```bash
# Solution 1: Non-blocking collection with timeouts
collect_with_timeout() {
    local java_pid=$1
    local timeout_seconds=${2:-300}  # 5 minute default
    
    echo "Starting collection with $timeout_seconds second timeout"
    
    # Use timeout command for each operation
    timeout $timeout_seconds sh bin/jstack.sh -l $java_pid > thread_dump.txt &
    JSTACK_PID=$!
    
    timeout $timeout_seconds sh bin/jmap.sh -histo $java_pid > histogram.txt &
    JMAP_PID=$!
    
    # Monitor processes
    while kill -0 $JSTACK_PID 2>/dev/null || kill -0 $JMAP_PID 2>/dev/null; do
        echo "Collection in progress..."
        sleep 10
    done
    
    echo "Collection completed or timed out"
}

# Solution 2: Force collection for hung processes
force_collect_hung_process() {
    local java_pid=$1
    
    echo "Attempting forced collection for potentially hung process"
    
    # Force thread dump
    sh bin/jstack.sh -F $java_pid > forced_thread_dump.txt 2>&1
    
    # Get native stack trace
    if command -v gstack >/dev/null 2>&1; then
        gstack $java_pid > native_stack.txt 2>&1
    fi
    
    # Get process status
    cat /proc/$java_pid/status > process_status.txt
    cat /proc/$java_pid/stat > process_stat.txt
    
    # Get file descriptors
    ls -la /proc/$java_pid/fd > file_descriptors.txt 2>&1
    
    echo "Forced collection completed"
}

# Solution 3: Minimal impact collection
minimal_impact_collection() {
    local java_pid=$1
    
    echo "Performing minimal impact collection"
    
    # Only collect non-intrusive information
    ps -p $java_pid -o pid,ppid,user,pcpu,pmem,etime,cmd > process_info.txt
    
    # Get JVM info without forcing GC
    sh bin/jcmd.sh $java_pid VM.uptime > vm_uptime.txt
    sh bin/jcmd.sh $java_pid VM.command_line > vm_command_line.txt
    sh bin/jcmd.sh $java_pid VM.system_properties > vm_properties.txt
    
    # Get basic GC stats (non-intrusive)
    sh bin/jstat.sh -gc $java_pid 1000 1 > gc_stats.txt
    
    echo "Minimal collection completed"
}
```

### Issue 3: Disk Space Issues During Collection

**Problem**: Insufficient disk space for diagnostic files.

**Symptoms**:
```bash
$ sh java_info_collect.sh
No space left on device
zip: can't create /tmp/java_info_collect_*.zip
```

**Solutions**:

```bash
# Solution 1: Pre-flight disk space check
check_available_space() {
    local required_gb=$1
    local target_dir=${2:-/tmp}
    
    local available_kb=$(df $target_dir | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    echo "Available space: ${available_gb}GB, Required: ${required_gb}GB"
    
    if [ $available_gb -lt $required_gb ]; then
        echo "Insufficient disk space in $target_dir"
        
        # Suggest alternative locations
        echo "Checking alternative locations:"
        for dir in /var/tmp /opt/tmp $HOME/tmp; do
            if [ -d $dir ] && [ -w $dir ]; then
                local alt_available_kb=$(df $dir | tail -1 | awk '{print $4}')
                local alt_available_gb=$((alt_available_kb / 1024 / 1024))
                echo "  $dir: ${alt_available_gb}GB available"
                
                if [ $alt_available_gb -ge $required_gb ]; then
                    echo "Recommendation: Use $dir as output directory"
                    return 0
                fi
            fi
        done
        
        return 1
    fi
    
    return 0
}

# Solution 2: Selective collection based on available space
selective_collection() {
    local java_pid=$1
    local available_gb=$(df /tmp | tail -1 | awk '{print int($4/1024/1024)}')
    
    echo "Available space: ${available_gb}GB"
    
    if [ $available_gb -ge 10 ]; then
        echo "Sufficient space - performing full collection"
        sh java_info_collect.sh
    elif [ $available_gb -ge 5 ]; then
        echo "Limited space - skipping heap dump"
        collect_without_heap_dump $java_pid
    elif [ $available_gb -ge 1 ]; then
        echo "Very limited space - basic collection only"
        basic_collection $java_pid
    else
        echo "Critical space shortage - emergency collection only"
        emergency_collection $java_pid
    fi
}

collect_without_heap_dump() {
    local java_pid=$1
    
    # Collect everything except heap dump
    sh bin/jstack.sh -l $java_pid > thread_dump.txt
    sh bin/jmap.sh -histo $java_pid > object_histogram.txt
    sh bin/jstat.sh -gc $java_pid 1000 3 > gc_stats.txt
    
    # Compress immediately
    tar -czf diagnostic_no_heap_$(date +%Y%m%d_%H%M).tar.gz *.txt
    rm *.txt
}

basic_collection() {
    local java_pid=$1
    
    # Only essential information
    sh bin/jcmd.sh $java_pid VM.uptime > basic_info.txt
    sh bin/jstat.sh -gc $java_pid 1000 1 >> basic_info.txt
    ps -p $java_pid -o pid,pcpu,pmem,etime,cmd >> basic_info.txt
    
    gzip basic_info.txt
}

emergency_collection() {
    local java_pid=$1
    
    # Minimal information to stdout only
    echo "=== Emergency Collection $(date) ==="
    echo "Java PID: $java_pid"
    ps -p $java_pid -o pid,pcpu,pmem,etime,cmd
    sh bin/jstat.sh -gc $java_pid 1000 1
}

# Solution 3: Automatic cleanup of old files
cleanup_old_diagnostics() {
    local retention_days=${1:-7}
    
    echo "Cleaning up diagnostic files older than $retention_days days"
    
    # Remove old diagnostic directories
    find /tmp -name "java_info_collect_*" -type d -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null
    find /tmp -name "java_cpu_monitor_*" -type d -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null
    
    # Remove old heap dumps
    find /tmp -name "*.hprof" -mtime +$retention_days -delete 2>/dev/null
    
    # Remove old compressed files
    find /tmp -name "java_*_*.zip" -mtime +$retention_days -delete 2>/dev/null
    
    echo "Cleanup completed"
}
```

---

## Performance Issues

### Issue 1: Tool Execution Too Slow

**Problem**: Diagnostic collection takes excessively long time.

**Symptoms**:
```bash
$ time sh java_info_collect.sh
# Takes 30+ minutes to complete
real    32m15.432s
```

**Solutions**:

```bash
# Solution 1: Parallel collection optimization
optimize_collection_performance() {
    local java_pid=$1
    
    echo "Starting optimized parallel collection"
    
    # Run non-interfering collections in parallel
    {
        sh bin/jcmd.sh $java_pid VM.uptime > vm_uptime.txt
        sh bin/jcmd.sh $java_pid VM.system_properties > vm_properties.txt
        sh bin/jcmd.sh $java_pid VM.command_line > vm_command_line.txt
    } &
    
    {
        sh bin/jstat.sh -gc $java_pid 1000 3 > gc_stats.txt
        sh bin/jstat.sh -gccause $java_pid 1000 3 > gc_cause.txt
    } &
    
    {
        ps -eww -o pid,user:20,cmd > process_list.txt
        top -bc -n 1 > system_top.txt
        df -h > disk_usage.txt
    } &
    
    # Wait for parallel operations
    wait
    
    # Sequential operations that may interfere with each other
    sh bin/jstack.sh -l $java_pid > thread_dump.txt
    sh bin/jmap.sh -histo $java_pid > object_histogram.txt
    
    echo "Optimized collection completed"
}

# Solution 2: Skip expensive operations during high load
adaptive_collection() {
    local java_pid=$1
    local load_threshold=${2:-2.0}
    
    local current_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    echo "Current system load: $current_load"
    
    if (( $(echo "$current_load > $load_threshold" | bc -l) )); then
        echo "High system load detected - using lightweight collection"
        
        # Skip expensive operations
        sh bin/jcmd.sh $java_pid VM.uptime > basic_info.txt
        sh bin/jstat.sh -gc $java_pid 1000 1 >> basic_info.txt
        sh bin/jstack.sh $java_pid > quick_thread_dump.txt  # Without -l flag
        
    else
        echo "Normal system load - performing full collection"
        sh java_info_collect.sh
    fi
}

# Solution 3: Configurable collection depth
configurable_collection() {
    local java_pid=$1
    local collection_level=${2:-full}  # basic, standard, full
    
    case $collection_level in
        basic)
            echo "Basic collection mode"
            sh bin/jcmd.sh $java_pid VM.uptime > basic.txt
            sh bin/jstat.sh -gc $java_pid 1000 1 >> basic.txt
            ;;
        standard)
            echo "Standard collection mode"
            sh bin/jstack.sh $java_pid > thread_dump.txt
            sh bin/jmap.sh -histo $java_pid > histogram.txt
            sh bin/jstat.sh -gc $java_pid 1000 3 > gc_stats.txt
            ;;
        full)
            echo "Full collection mode"
            sh java_info_collect.sh
            ;;
    esac
}
```

### Issue 2: High Resource Usage by Monitoring

**Problem**: Monitoring tools consume too much system resources.

**Symptoms**:
```bash
$ top -p $(pgrep -f java_cpu_monitor)
  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
 5678 monitor   20   0  145236  45678  12345 S 15.0  2.3   5:45.67 bash
```

**Solutions**:

```bash
# Solution 1: Optimize monitoring intervals
optimize_monitoring_intervals() {
    cat << 'EOF' > optimized_monitor.conf
# Optimized configuration for minimal resource usage
check_cpu_times=86400        # 24 hour monitoring
check_cpu_interval=10s       # Check every 10 seconds (reduced frequency)
cpu_threshold_usage=80       # Higher threshold to reduce false triggers
cpu_threshold_times=6        # Require 6 consecutive readings (1 minute)
stack_times=2                # Fewer thread dumps
stack_interval=5s            # Longer interval between dumps
EOF
    
    echo "Optimized configuration created"
}

# Solution 2: Implement smart monitoring
smart_monitoring() {
    local java_pid=$1
    local base_interval=10
    local current_interval=$base_interval
    local max_interval=60
    
    while true; do
        # Get current system load
        local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        local cpu_count=$(nproc)
        local load_ratio=$(echo "scale=2; $load / $cpu_count" | bc)
        
        # Adjust monitoring interval based on system load
        if (( $(echo "$load_ratio > 1.0" | bc -l) )); then
            # High load - reduce monitoring frequency
            current_interval=$((current_interval * 2))
            if [ $current_interval -gt $max_interval ]; then
                current_interval=$max_interval
            fi
        else
            # Normal load - reset to base interval
            current_interval=$base_interval
        fi
        
        echo "Monitoring interval: ${current_interval}s (load ratio: $load_ratio)"
        
        # Perform monitoring check
        local cpu_usage=$(top -b -n 1 -p $java_pid | tail -1 | awk '{print $9}' | cut -d'.' -f1)
        echo "Java process CPU: ${cpu_usage}%"
        
        sleep $current_interval
    done
}

# Solution 3: Resource-limited collection
resource_limited_collection() {
    local java_pid=$1
    local cpu_limit=${2:-5}    # Max 5% CPU usage
    local memory_limit=${3:-100} # Max 100MB memory usage
    
    # Use nice and ionice to limit resource usage
    nice -n 19 ionice -c 3 sh java_info_collect.sh &
    local collection_pid=$!
    
    # Monitor resource usage
    while kill -0 $collection_pid 2>/dev/null; do
        local cpu_usage=$(ps -p $collection_pid -o %cpu --no-headers | cut -d'.' -f1)
        local mem_usage=$(ps -p $collection_pid -o rss --no-headers)
        local mem_mb=$((mem_usage / 1024))
        
        if [ $cpu_usage -gt $cpu_limit ] || [ $mem_mb -gt $memory_limit ]; then
            echo "Resource limit exceeded - pausing collection"
            kill -STOP $collection_pid
            sleep 10
            kill -CONT $collection_pid
        fi
        
        sleep 5
    done
}
```

---

## Environment-Specific Problems

### Issue 1: Docker Container Issues

**Problem**: Tool doesn't work properly inside Docker containers.

**Symptoms**:
```bash
# Inside container
$ sh java_info_collect.sh
ps: can't access /proc filesystem
top: can't open /proc/stat
```

**Solutions**:

```bash
# Solution 1: Docker-aware process detection
docker_aware_process_detection() {
    local container_id=$1
    
    # Check if running inside container
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup; then
        echo "Running inside Docker container"
        
        # Use container-specific process detection
        ps aux | grep java | grep -v grep
        
    else
        echo "Running on host system"
        
        # Use standard process detection
        ps -eww -o pid,user:20,cmd | grep java | grep -v grep
    fi
}

# Solution 2: Container monitoring from host
monitor_container_java() {
    local container_name=$1
    
    echo "Monitoring Java process in container: $container_name"
    
    # Get container PID namespace
    local container_pid=$(docker inspect -f '{{.State.Pid}}' $container_name)
    
    # Find Java process in container
    local java_pid=$(docker exec $container_name ps aux | grep java | grep -v grep | awk '{print $2}' | head -1)
    
    if [ -z "$java_pid" ]; then
        echo "No Java process found in container"
        return 1
    fi
    
    # Copy toolbox into container
    docker cp /home/kiwi_java_toolbox $container_name:/tmp/
    
    # Run collection inside container
    docker exec $container_name bash -c "
        cd /tmp/kiwi_java_toolbox
        echo $java_pid | sh java_info_collect.sh
    "
    
    # Copy results back to host
    docker cp $container_name:/tmp/java_info_collect_* ./
}

# Solution 3: Host-based container monitoring
host_based_container_monitoring() {
    local container_name=$1
    
    # Get container process tree from host perspective
    local container_pid=$(docker inspect -f '{{.State.Pid}}' $container_name)
    
    # Find Java processes in container namespace
    local java_pids=$(pgrep -P $container_pid java)
    
    for java_pid in $java_pids; do
        echo "Monitoring Java PID $java_pid in container $container_name"
        
        # Use host-based tools to monitor container processes
        sh bin/jstack.sh $java_pid > container_${container_name}_thread_dump.txt
        sh bin/jstat.sh -gc $java_pid 1000 3 > container_${container_name}_gc_stats.txt
    done
}
```

### Issue 2: Kubernetes Pod Issues

**Problem**: Monitoring Java applications in Kubernetes pods.

**Solutions**:

```bash
# Solution 1: Pod-based monitoring
k8s_pod_monitoring() {
    local namespace=$1
    local pod_name=$2
    
    echo "Monitoring Java in pod: $namespace/$pod_name"
    
    # Copy toolbox to pod
    kubectl cp /home/kiwi_java_toolbox $namespace/$pod_name:/tmp/
    
    # Find Java process in pod
    local java_pid=$(kubectl exec -n $namespace $pod_name -- ps aux | grep java | grep -v grep | awk '{print $2}' | head -1)
    
    if [ -z "$java_pid" ]; then
        echo "No Java process found in pod"
        return 1
    fi
    
    # Run collection
    kubectl exec -n $namespace $pod_name -- bash -c "
        cd /tmp/kiwi_java_toolbox
        echo $java_pid | sh java_info_collect.sh
    "
    
    # Copy results back
    kubectl cp $namespace/$pod_name:/tmp/java_info_collect_* ./
}

# Solution 2: Sidecar monitoring container
create_monitoring_sidecar() {
    cat << 'EOF' > monitoring-sidecar.yaml
apiVersion: v1
kind: Pod
metadata:
  name: java-app-with-monitoring
spec:
  containers:
  - name: java-app
    image: my-java-app:latest
    # Main application container
    
  - name: monitoring-sidecar
    image: openjdk:8-jdk-alpine
    command: ["/bin/sh"]
    args: ["-c", "while true; do sleep 3600; done"]
    volumeMounts:
    - name: shared-tmp
      mountPath: /shared
    - name: kiwi-toolbox
      mountPath: /opt/kiwi_java_toolbox
      
  volumes:
  - name: shared-tmp
    emptyDir: {}
  - name: kiwi-toolbox
    configMap:
      name: kiwi-toolbox-config
EOF
    
    echo "Sidecar configuration created"
}
```

### Issue 3: Cloud Environment Restrictions

**Problem**: Cloud security policies blocking diagnostic operations.

**Solutions**:

```bash
# Solution 1: Cloud-compliant collection
cloud_compliant_collection() {
    local java_pid=$1
    
    echo "Performing cloud-compliant diagnostic collection"
    
    # Use only non-intrusive operations
    collect_safe_metrics() {
        # JVM information (safe)
        sh bin/jcmd.sh $java_pid VM.uptime > safe_vm_info.txt
        sh bin/jcmd.sh $java_pid VM.version >> safe_vm_info.txt
        
        # GC statistics (safe)
        sh bin/jstat.sh -gc $java_pid 1000 1 > safe_gc_stats.txt
        
        # Process information (safe)
        ps -p $java_pid -o pid,ppid,user,pcpu,pmem,etime,cmd > safe_process_info.txt
        
        # Avoid potentially restricted operations:
        # - No heap dumps (may be blocked by security policies)
        # - No thread dumps (may expose sensitive stack traces)
        # - No system-level information collection
    }
    
    collect_safe_metrics
    
    # Compress and encrypt if required
    tar -czf safe_diagnostics_$(date +%Y%m%d_%H%M).tar.gz safe_*.txt
    rm safe_*.txt
    
    echo "Cloud-compliant collection completed"
}

# Solution 2: Policy-aware monitoring
policy_aware_monitoring() {
    local java_pid=$1
    
    # Check available capabilities
    check_capabilities() {
        local capabilities=()
        
        # Test thread dump capability
        if timeout 10 sh bin/jstack.sh $java_pid >/dev/null 2>&1; then
            capabilities+=("thread_dump")
        fi
        
        # Test heap dump capability
        if timeout 10 sh bin/jmap.sh -histo $java_pid | head -5 >/dev/null 2>&1; then
            capabilities+=("heap_analysis")
        fi
        
        # Test system information capability
        if ps aux >/dev/null 2>&1; then
            capabilities+=("system_info")
        fi
        
        echo "Available capabilities: ${capabilities[*]}"
        return 0
    }
    
    check_capabilities
    
    # Perform collection based on available capabilities
    # Implementation based on capability check results
}
```

---

## Data Collection Issues

### Issue 1: Incomplete or Corrupted Output Files

**Problem**: Diagnostic files are empty, truncated, or corrupted.

**Symptoms**:
```bash
$ ls -la /tmp/java_info_collect_*/
-rw-r--r-- 1 user user    0 Oct 15 14:30 cpu_jstack-1.txt
-rw-r--r-- 1 user user  156 Oct 15 14:30 mem_heap_dump.hprof  # Should be much larger
```

**Solutions**:

```bash
# Solution 1: Validate output files
validate_collection_output() {
    local output_dir=$1
    local issues=()
    
    echo "Validating collection output in: $output_dir"
    
    # Check thread dump files
    for thread_dump in $output_dir/cpu_jstack-*.txt; do
        if [ -f "$thread_dump" ]; then
            if [ ! -s "$thread_dump" ]; then
                issues+=("Empty thread dump: $(basename $thread_dump)")
            elif ! grep -q "Full thread dump" "$thread_dump"; then
                issues+=("Invalid thread dump format: $(basename $thread_dump)")
            fi
        fi
    done
    
    # Check heap dump file
    local heap_dump="$output_dir/mem_heap_dump.hprof"
    if [ -f "$heap_dump" ]; then
        local heap_size=$(stat -f%z "$heap_dump" 2>/dev/null || stat -c%s "$heap_dump")
        if [ $heap_size -lt 1048576 ]; then  # Less than 1MB is suspicious
            issues+=("Suspiciously small heap dump: ${heap_size} bytes")
        fi
        
        # Check heap dump header
        if ! head -c 20 "$heap_dump" | grep -q "JAVA PROFILE"; then
            issues+=("Invalid heap dump format")
        fi
    fi
    
    # Check GC statistics
    local gc_stats="$output_dir"/*gc*.txt
    for gc_file in $gc_stats; do
        if [ -f "$gc_file" ] && [ -s "$gc_file" ]; then
            if ! grep -q -E "(S0C|S1C|EC|OC)" "$gc_file"; then
                issues+=("Invalid GC statistics format: $(basename $gc_file)")
            fi
        fi
    done
    
    # Report issues
    if [ ${#issues[@]} -gt 0 ]; then
        echo "VALIDATION ISSUES FOUND:"
        printf '%s\n' "${issues[@]}"
        return 1
    else
        echo "All output files validated successfully"
        return 0
    fi
}

# Solution 2: Retry mechanism for failed collections
retry_failed_collections() {
    local java_pid=$1
    local max_retries=${2:-3}
    local retry_delay=${3:-30}
    
    for attempt in $(seq 1 $max_retries); do
        echo "Collection attempt $attempt of $max_retries"
        
        # Try collection
        if sh java_info_collect.sh; then
            # Validate the output
            local latest_output=$(ls -td /tmp/java_info_collect_* | head -1)
            if validate_collection_output "$latest_output"; then
                echo "Collection successful on attempt $attempt"
                return 0
            else
                echo "Collection validation failed on attempt $attempt"
            fi
        else
            echo "Collection failed on attempt $attempt"
        fi
        
        if [ $attempt -lt $max_retries ]; then
            echo "Waiting $retry_delay seconds before retry..."
            sleep $retry_delay
        fi
    done
    
    echo "All collection attempts failed"
    return 1
}

# Solution 3: Incremental collection with checkpoints
incremental_collection() {
    local java_pid=$1
    local checkpoint_file="/tmp/collection_checkpoint_${java_pid}.txt"
    
    # Define collection steps
    local steps=(
        "vm_info:sh bin/jcmd.sh $java_pid VM.uptime"
        "gc_stats:sh bin/jstat.sh -gc $java_pid 1000 3"
        "thread_dump:sh bin/jstack.sh -l $java_pid"
        "object_histogram:sh bin/jmap.sh -histo $java_pid"
        "heap_dump:sh bin/jmap.sh -dump:live,format=b,file=heap.hprof $java_pid"
    )
    
    # Load checkpoint if exists
    local completed_steps=()
    if [ -f "$checkpoint_file" ]; then
        mapfile -t completed_steps < "$checkpoint_file"
    fi
    
    for step in "${steps[@]}"; do
        local step_name=$(echo $step | cut -d':' -f1)
        local step_command=$(echo $step | cut -d':' -f2-)
        
        # Check if step already completed
        if printf '%s\n' "${completed_steps[@]}" | grep -q "^$step_name$"; then
            echo "Skipping completed step: $step_name"
            continue
        fi
        
        echo "Executing step: $step_name"
        if eval "$step_command > ${step_name}.txt 2>&1"; then
            echo "Step completed: $step_name"
            echo "$step_name" >> "$checkpoint_file"
        else
            echo "Step failed: $step_name"
            echo "Check ${step_name}.txt for error details"
        fi
    done
    
    # Cleanup checkpoint file on successful completion
    rm -f "$checkpoint_file"
}
```

---

## FAQ and Quick Solutions

### Q1: How do I quickly check if the toolbox is working?

**Quick Test**:
```bash
# Basic functionality test
cd /home/kiwi_java_toolbox

# Test 1: Check if scripts are executable
ls -la *.sh | grep -E '^-rwxr'

# Test 2: Test Java process detection
sh bin/jps.sh

# Test 3: Test basic JVM tool
JAVA_PID=$(sh bin/jps.sh | tail -1 | awk '{print $1}')
if [ -n "$JAVA_PID" ]; then
    sh bin/jcmd.sh $JAVA_PID VM.uptime
    echo "Toolbox is working correctly"
else
    echo "No Java processes found for testing"
fi
```

### Q2: What should I do if I get "Permission denied" errors?

**Quick Fix**:
```bash
# Fix 1: Check and fix permissions
chmod -R 755 /home/kiwi_java_toolbox
chmod +x /home/kiwi_java_toolbox/*.sh
chmod +x /home/kiwi_java_toolbox/bin/*.sh

# Fix 2: Check user context
whoami
ps aux | grep java | head -3

# Fix 3: Switch to appropriate user
sudo su - $(ps aux | grep java | head -1 | awk '{print $1}')
```

### Q3: How do I reduce the size of diagnostic output?

**Quick Solutions**:
```bash
# Option 1: Skip heap dump
# Edit java_info_collect.sh and comment out the heap dump section
# Lines 366-375

# Option 2: Use histogram only
sh bin/jmap.sh -histo $JAVA_PID > memory_analysis.txt

# Option 3: Compress immediately
sh java_info_collect.sh
gzip /tmp/java_info_collect_*/*.hprof
```

### Q4: Can I run monitoring in the background?

**Background Monitoring Setup**:
```bash
# Start CPU monitoring in background
nohup sh java_cpu_monitor.sh > monitor.log 2>&1 &
echo $! > monitor.pid

# Check monitoring status
ps -p $(cat monitor.pid)

# Stop monitoring
kill $(cat monitor.pid)
```

### Q5: How do I analyze the collected data?

**Analysis Tools and Steps**:
```bash
# 1. Thread dump analysis
# Upload cpu_jstack-*.txt to: http://gceasy.io
# Or use IBM Thread and Monitor Dump Analyzer

# 2. Heap dump analysis  
# Use Eclipse Memory Analyzer (MAT)
# Open mem_heap_dump.hprof in MAT

# 3. GC analysis
# Look for patterns in GC statistics:
grep "Full GC" /tmp/java_info_collect_*/java_info_collect.log

# 4. CPU analysis
# Correlate high CPU threads from top files with thread dumps
# Look for thread IDs in hexadecimal format
```

### Q6: What are the most important files to analyze first?

**Priority Analysis Order**:
```bash
# 1. First check the main log
less /tmp/java_info_collect_*/java_info_collect.log

# 2. Look at GC statistics for memory issues
less /tmp/java_info_collect_*/gc_stats.txt

# 3. Check thread dumps for deadlocks or high CPU threads
grep -i deadlock /tmp/java_info_collect_*/cpu_jstack-*.txt

# 4. Review object histogram for memory leaks
head -20 /tmp/java_info_collect_*/mem_objects_histogram.txt

# 5. Check system resources
less /tmp/java_info_collect_*/os_top.txt
```

---

This troubleshooting guide covers the most common issues encountered when using the Kiwi Java Toolbox, with practical solutions and preventive measures for each scenario.