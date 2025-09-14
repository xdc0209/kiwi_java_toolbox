# Kiwi Java Toolbox - Configuration Guide

## Table of Contents

1. [Configuration Overview](#configuration-overview)
2. [CPU Monitor Configuration](#cpu-monitor-configuration)
3. [Environment Variables](#environment-variables)
4. [JDK Library Configuration](#jdk-library-configuration)
5. [Output Directory Configuration](#output-directory-configuration)
6. [Logging Configuration](#logging-configuration)
7. [Performance Tuning](#performance-tuning)
8. [Security Configuration](#security-configuration)
9. [Advanced Configuration](#advanced-configuration)
10. [Configuration Examples](#configuration-examples)

---

## Configuration Overview

The Kiwi Java Toolbox uses several configuration mechanisms to customize its behavior:

### Configuration Types

| Type | File/Method | Purpose |
|------|-------------|---------|
| **Static Configuration** | `java_cpu_monitor.conf` | CPU monitoring thresholds and timing |
| **Environment Variables** | Shell environment | Runtime behavior control |
| **Runtime Parameters** | Command line arguments | Per-execution settings |
| **Auto-Detection** | System inspection | JDK/JRE compatibility |

### Configuration Precedence

1. **Command Line Arguments** (highest priority)
2. **Environment Variables**
3. **Configuration Files**
4. **Auto-Detection**
5. **Default Values** (lowest priority)

---

## CPU Monitor Configuration

### Configuration File: java_cpu_monitor.conf

**Location**: `./java_cpu_monitor.conf` (same directory as `java_cpu_monitor.sh`)

**Format**: Shell variable assignments (bash syntax)

### Core Parameters

#### check_cpu_times

**Purpose**: Maximum number of monitoring cycles before automatic termination.

**Type**: Positive integer  
**Default**: `10000`  
**Range**: `1` to `2147483647`  
**Unit**: Monitoring cycles

**Calculation**: Total monitoring time = `check_cpu_times × check_cpu_interval`

**Examples**:
```bash
# Monitor for 1000 cycles (default 2s interval = ~33 minutes)
check_cpu_times=1000

# Monitor for 24 hours (with 10s interval = 8640 cycles)
check_cpu_times=8640

# Continuous monitoring (very large number)
check_cpu_times=999999999
```

**Considerations**:
- Larger values enable longer monitoring periods
- Very large values may consume more memory for logging
- Consider disk space for extended monitoring logs

---

#### check_cpu_interval

**Purpose**: Time interval between CPU usage checks.

**Type**: Time duration string  
**Default**: `2s`  
**Format**: `<number><unit>` where unit is `s` (seconds), `m` (minutes), or `h` (hours)  
**Minimum**: `1s`  
**Recommended**: `2s` to `10s`

**Examples**:
```bash
# High-frequency monitoring (more responsive, higher overhead)
check_cpu_interval=1s

# Standard monitoring (balanced)
check_cpu_interval=5s

# Low-frequency monitoring (less overhead, slower response)
check_cpu_interval=30s

# Very low frequency (minimal overhead)
check_cpu_interval=2m
```

**Performance Impact**:
- **1s interval**: ~0.1% CPU overhead, very responsive
- **5s interval**: ~0.02% CPU overhead, good responsiveness
- **30s interval**: Minimal overhead, slower detection

**Tuning Guidelines**:
```bash
# Production systems (balance responsiveness and overhead)
check_cpu_interval=5s

# Development/testing (high responsiveness)
check_cpu_interval=2s

# Low-priority monitoring (minimal impact)
check_cpu_interval=30s
```

---

#### cpu_threshold_usage

**Purpose**: CPU usage percentage threshold that triggers monitoring alerts.

**Type**: Integer percentage  
**Default**: `20`  
**Range**: `0` to `100`  
**Unit**: Percentage (%)  
**Special Values**: `0` = always trigger (for testing)

**Examples**:
```bash
# Very sensitive (triggers on any significant CPU usage)
cpu_threshold_usage=10

# Moderate sensitivity (typical for most applications)
cpu_threshold_usage=50

# High threshold (only for severe CPU issues)
cpu_threshold_usage=80

# Testing mode (always trigger collection)
cpu_threshold_usage=0
```

**Application-Specific Recommendations**:
```bash
# Web applications (typically low baseline CPU)
cpu_threshold_usage=30

# Batch processing (higher baseline acceptable)
cpu_threshold_usage=70

# Real-time applications (very sensitive)
cpu_threshold_usage=15

# Background services (moderate sensitivity)
cpu_threshold_usage=50
```

---

#### cpu_threshold_times

**Purpose**: Number of consecutive high CPU readings required before triggering collection.

**Type**: Positive integer  
**Default**: `5`  
**Range**: `1` to `1000`  
**Unit**: Consecutive readings

**Purpose**: Prevents false positives from CPU spikes.

**Calculation**: Trigger delay = `cpu_threshold_times × check_cpu_interval`

**Examples**:
```bash
# Immediate trigger (no spike filtering)
cpu_threshold_times=1

# Quick trigger (10 seconds with 2s interval)
cpu_threshold_times=5

# Conservative trigger (30 seconds with 5s interval)
cpu_threshold_times=6

# Very conservative (2 minutes with 10s interval)
cpu_threshold_times=12
```

**Spike Filtering Analysis**:
```bash
# Configuration: check_cpu_interval=5s, cpu_threshold_times=4
# Result: Requires 20 seconds of sustained high CPU before triggering

# Scenario 1: Brief spike (5 seconds)
# CPU readings: 80%, 20%, 15%, 25% → No trigger (spike filtered)

# Scenario 2: Sustained high CPU (25+ seconds)  
# CPU readings: 80%, 85%, 82%, 78%, 81% → Trigger after 20 seconds
```

---

#### stack_times

**Purpose**: Number of thread dumps to collect when CPU threshold is exceeded.

**Type**: Positive integer  
**Default**: `3`  
**Range**: `1` to `10`  
**Unit**: Thread dump count

**Purpose**: Multiple snapshots help identify thread state changes and patterns.

**Examples**:
```bash
# Single snapshot (minimal overhead)
stack_times=1

# Standard analysis (good for most issues)
stack_times=3

# Detailed analysis (better trend identification)
stack_times=5

# Comprehensive analysis (for complex issues)
stack_times=7
```

**Analysis Benefits by Count**:
```bash
# 1 dump: Single point-in-time view
# 3 dumps: Can identify basic trends and state changes
# 5 dumps: Good for deadlock detection and thread progression
# 7+ dumps: Comprehensive view of thread behavior patterns
```

**Storage Impact**:
```bash
# Typical thread dump sizes (varies by application):
# Small app (50 threads): ~500KB per dump
# Medium app (200 threads): ~2MB per dump  
# Large app (500+ threads): ~5MB per dump

# With stack_times=5 and large app: ~25MB per trigger
```

---

#### stack_interval

**Purpose**: Time interval between consecutive thread dump collections.

**Type**: Time duration string  
**Default**: `2s`  
**Format**: `<number><unit>` (same as `check_cpu_interval`)  
**Minimum**: `1s`  
**Recommended**: `1s` to `5s`

**Examples**:
```bash
# Rapid succession (captures quick state changes)
stack_interval=1s

# Standard interval (balanced view)
stack_interval=2s

# Slower collection (reduces system impact)
stack_interval=5s
```

**Timing Considerations**:
```bash
# Total collection time = stack_times × stack_interval
# With stack_times=3, stack_interval=2s → 6 seconds total

# Fast collection (stack_times=5, stack_interval=1s → 5 seconds)
# Good for: Rapid state changes, deadlock detection

# Slow collection (stack_times=3, stack_interval=5s → 15 seconds)  
# Good for: Reducing system impact, stable issue analysis
```

---

### Complete Configuration Examples

#### High-Sensitivity Development Configuration
```bash
# java_cpu_monitor.conf - Development Environment
# High sensitivity for catching issues early

check_cpu_times=5000         # ~2.8 hours at 2s intervals
check_cpu_interval=2s        # Frequent checks
cpu_threshold_usage=25       # Low threshold
cpu_threshold_times=3        # Quick trigger (6 seconds)
stack_times=5                # Detailed analysis
stack_interval=1s            # Rapid collection
```

#### Balanced Production Configuration
```bash
# java_cpu_monitor.conf - Production Environment
# Balanced between sensitivity and system impact

check_cpu_times=17280        # 24 hours at 5s intervals
check_cpu_interval=5s        # Moderate frequency
cpu_threshold_usage=60       # Reasonable threshold
cpu_threshold_times=6        # 30-second confirmation
stack_times=3                # Standard analysis
stack_interval=2s            # Standard timing
```

#### Low-Impact Background Monitoring
```bash
# java_cpu_monitor.conf - Background Monitoring
# Minimal system impact for continuous monitoring

check_cpu_times=2880         # 24 hours at 30s intervals
check_cpu_interval=30s       # Low frequency
cpu_threshold_usage=80       # High threshold
cpu_threshold_times=4        # 2-minute confirmation
stack_times=2                # Minimal collection
stack_interval=3s            # Reduced impact
```

#### High-Performance Application Configuration
```bash
# java_cpu_monitor.conf - High-Performance Apps
# Optimized for applications with variable CPU patterns

check_cpu_times=43200        # 24 hours at 2s intervals
check_cpu_interval=2s        # Responsive monitoring
cpu_threshold_usage=40       # Moderate threshold
cpu_threshold_times=10       # 20-second confirmation (filters normal spikes)
stack_times=4                # Good analysis depth
stack_interval=2s            # Standard collection speed
```

---

## Environment Variables

### Tool Behavior Control

#### JAVA_CMD_FOR_TOOLS

**Purpose**: Override automatic Java executable detection.

**Type**: Absolute file path  
**Default**: Auto-detected from target process  
**Scope**: All utility scripts (`jcmd.sh`, `jstack.sh`, etc.)

**Usage Scenarios**:
- Multiple Java versions installed
- Custom Java installation paths
- Testing with specific JDK versions

**Examples**:
```bash
# Use specific OpenJDK 8 installation
export JAVA_CMD_FOR_TOOLS=/usr/lib/jvm/java-8-openjdk/bin/java

# Use Oracle JDK
export JAVA_CMD_FOR_TOOLS=/opt/jdk1.8.0_181/bin/java

# Use custom Java build
export JAVA_CMD_FOR_TOOLS=/opt/custom-jdk/bin/java
```

**Validation**:
The toolbox validates the specified Java executable:
```bash
# Test if specified Java works
$JAVA_CMD_FOR_TOOLS -version

# Test if JDK tools are available
ls $(dirname $JAVA_CMD_FOR_TOOLS)/../lib/tools.jar
```

---

#### DEBUG_SWITCH

**Purpose**: Control debug mode for subscript execution.

**Type**: Bash option string  
**Values**: `-x` (enable debug), empty (disable)  
**Default**: Auto-detected from parent shell  
**Scope**: All subscripts called via `bash $DEBUG_SWITCH script.sh`

**Automatic Detection**:
```bash
# If parent script runs with debug mode:
bash -x java_info_collect.sh

# DEBUG_SWITCH is automatically set to "-x"
# All subscripts inherit debug mode
```

**Manual Control**:
```bash
# Enable debug mode
export DEBUG_SWITCH=-x
sh java_info_collect.sh

# Disable debug mode
export DEBUG_SWITCH=
sh java_info_collect.sh
```

**Debug Output Example**:
```bash
# With DEBUG_SWITCH=-x
+[T: 143022, L: 185, S: java_info_collect.sh, F: java_info_collect]: exec_cmd_with_java_user 1234 'sh /home/kiwi_java_toolbox/bin/jcmd.sh 1234 VM.uptime'
+[T: 143023, L: 186, S: java_info_collect.sh, F: java_info_collect]: local java_user=appuser
+[T: 143023, L: 187, S: java_info_collect.sh, F: java_info_collect]: local cur_user=appuser
```

---

### System Integration Variables

#### JAVA_HOME

**Purpose**: Standard Java environment variable.

**Usage**: Used by JDK detection logic when `JAVA_CMD_FOR_TOOLS` is not set.

**Priority**: Lower than `JAVA_CMD_FOR_TOOLS` but higher than auto-detection.

**Example**:
```bash
# Set Java home for toolbox
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk
# Toolbox will use $JAVA_HOME/bin/java if JAVA_CMD_FOR_TOOLS not set
```

---

#### PATH

**Purpose**: System PATH for locating utilities.

**Required Tools**: `ps`, `top`, `netstat`, `ifconfig`/`ip`, `awk`, `sed`, `grep`

**Validation**:
```bash
# Check required tools availability
for tool in ps top netstat awk sed grep; do
    command -v $tool >/dev/null || echo "Missing: $tool"
done
```

---

## JDK Library Configuration

### Automatic JDK Detection

The toolbox automatically detects and configures JDK libraries based on the target Java process.

#### Detection Algorithm

```
1. Get Java executable path from target process
2. Check if installation is JDK or JRE:
   - JDK: Has tools.jar in ../lib/ directory
   - JRE: No tools.jar, runtime only
3. Configure library paths accordingly
```

#### JDK Configuration (Preferred)

When target process uses JDK:
```bash
# Automatic configuration
JAVA_CMD_FOR_TOOLS=/usr/lib/jvm/java-8-openjdk/bin/java
JAVA_LIBRARY_PATH_OPTION=""
JAVA_CLASSPATH_OPTION="-classpath /usr/lib/jvm/java-8-openjdk/lib/tools.jar"
```

**Benefits**:
- Perfect version compatibility
- No additional library management
- Uses system-provided tools

#### JRE Configuration (Fallback)

When target process uses JRE:
```bash
# Requires embedded JDK libraries
JAVA_CMD_FOR_TOOLS=/usr/bin/java
JAVA_LIBRARY_PATH_OPTION="-Djava.library.path=/home/kiwi_java_toolbox/lib/jdk-1.8.0"
JAVA_CLASSPATH_OPTION="-classpath /home/kiwi_java_toolbox/lib/jdk-1.8.0/tools.jar"
```

**Requirements**:
- Matching JDK library version in `lib/jdk-<version>/`
- Version compatibility validation

### Embedded JDK Library Structure

```
lib/
├── jdk-1.6.0/
│   ├── jdk-version.txt
│   ├── libattach.so
│   └── tools.jar
├── jdk-1.7.0/
│   ├── jdk-version.txt
│   ├── libattach.so
│   └── tools.jar
└── jdk-1.8.0/
    ├── jdk-version.txt
    ├── libattach.so
    └── tools.jar
```

### Version Compatibility Matrix

| Java Process Version | Required Library | Auto-Detection |
|---------------------|------------------|----------------|
| 1.6.x | `lib/jdk-1.6.0/` | ✓ |
| 1.7.x | `lib/jdk-1.7.0/` | ✓ |
| 1.8.x | `lib/jdk-1.8.0/` | ✓ |
| 9.x | `lib/jdk-9.0.0/` | ✓ |
| 11.x | `lib/jdk-11.0.0/` | ✓ |

### Adding New JDK Versions

#### Manual Library Extraction

```bash
# Extract libraries from JDK installation
extract_jdk_libraries() {
    local jdk_path=$1
    local version=$($jdk_path/bin/java -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
    
    mkdir -p lib/jdk-$version
    
    # Copy tools.jar
    cp $jdk_path/lib/tools.jar lib/jdk-$version/
    
    # Copy native library
    find $jdk_path -name "libattach.so" -exec cp {} lib/jdk-$version/ \;
    
    # Create version file
    echo $version > lib/jdk-$version/jdk-version.txt
    
    echo "JDK libraries extracted for version $version"
}

# Usage
extract_jdk_libraries /usr/lib/jvm/java-11-openjdk
```

#### Using Provided Extraction Script

```bash
# Use built-in extraction script
sh lib/jdk_lib_extract.sh /usr/lib/jvm/java-11-openjdk

# Verify extraction
ls -la lib/jdk-11.0.0/
```

---

## Output Directory Configuration

### Directory Naming Convention

**Format**: `/tmp/{script_name}_{hostname}_{ip_addresses}_{timestamp}/`

**Components**:
- `script_name`: Executing script basename (without .sh extension)
- `hostname`: System hostname
- `ip_addresses`: Non-loopback IP addresses (dash-separated)
- `timestamp`: ISO format (YYYYMMDDTHHMMSS±ZZZZ)

### Customizing Output Location

#### Environment Variable Override

```bash
# Custom output base directory
export KIWI_OUTPUT_BASE="/var/log/java_diagnostics"

# Custom temporary directory
export TMPDIR="/opt/diagnostics/tmp"
```

#### Script Modification

```bash
# Modify init_env() function in scripts
init_env() {
    # ... existing code ...
    
    # Custom output directory
    local custom_base="${KIWI_OUTPUT_BASE:-/tmp}"
    output_dir=$custom_base/${BASE_NAME}_${hostname}_${ips}_${date}
    
    # ... rest of function ...
}
```

### Directory Permissions

**Default Permissions**: `777` (world-writable)

**Rationale**: Allows access from different user contexts (root, Java process user, monitoring user)

**Security Considerations**:
```bash
# More restrictive permissions for sensitive environments
init_env() {
    # ... create directory ...
    chmod 750 $output_dir  # Owner and group only
    chown monitoring:java_users $output_dir
}
```

### Disk Space Management

#### Pre-Collection Space Check

```bash
check_available_space() {
    local required_gb=$1
    local target_dir=${2:-/tmp}
    
    local available_kb=$(df $target_dir | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ $available_gb -lt $required_gb ]; then
        echo "Insufficient space: ${available_gb}GB available, ${required_gb}GB required"
        return 1
    fi
    return 0
}

# Usage before heap dump
check_available_space 5 || { echo "Skipping heap dump"; exit 1; }
```

#### Automatic Cleanup Configuration

```bash
# Cleanup script for old diagnostics
cleanup_old_diagnostics() {
    local retention_days=${1:-7}
    local base_dir=${2:-/tmp}
    
    find $base_dir -name "java_*_*_*" -type d -mtime +$retention_days -exec rm -rf {} \; 2>/dev/null
    find $base_dir -name "*.hprof" -mtime +$retention_days -delete 2>/dev/null
}

# Add to cron for automatic cleanup
echo "0 2 * * * cleanup_old_diagnostics 7 /tmp" | crontab -
```

---

## Logging Configuration

### Log File Locations

**Main Scripts**:
- `java_info_collect.log` - In output directory
- `java_cpu_monitor.log` - In output directory  
- `java_flight_recorder.log` - In script directory

**Utility Scripts**:
- `jcmd.log`, `jstack.log`, etc. - In script directory (if logging enabled)

### Log Levels and Format

**Format**: `[YYYY-MM-DD HH:MM:SS] LEVEL: message`

**Levels**:
- `INFO`: Normal operation messages
- `ERROR`: Error conditions and failures

**Example Log Output**:
```
[2024-09-15 14:30:22] INFO: ============================================================================================
[2024-09-15 14:30:22] INFO: 查询java进程：
[2024-09-15 14:30:22] INFO: ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
[2024-09-15 14:30:25] ERROR: Pid [ 9999 ] is not a valid java pid.
[2024-09-15 14:30:30] INFO: Starting collection for Java PID: 1234
```

### Custom Logging Configuration

#### Redirect Logs to Syslog

```bash
# Modify logging functions to use syslog
print_info() {
    local message="$*"
    echo "[$(date "+%F %T")] INFO: $message" | tee -a $log
    logger -t kiwi_java_toolbox -p local0.info "$message"
}

print_error() {
    local message="$*"
    echo "[$(date "+%F %T")] ERROR: $message" | tee -a $log 1>&2
    logger -t kiwi_java_toolbox -p local0.error "$message"
}
```

#### Structured Logging (JSON)

```bash
# JSON logging function
log_json() {
    local level=$1
    local message=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"script\":\"$BASE_NAME\",\"pid\":\"$$\"}" >> $log
}

# Usage
log_json "INFO" "Starting Java process analysis"
log_json "ERROR" "Invalid PID specified"
```

### Log Rotation Configuration

#### Using logrotate

```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/kiwi-java-toolbox << 'EOF'
/tmp/java_*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    maxage 90
}
EOF
```

#### Manual Log Rotation

```bash
# Rotate log function
rotate_log() {
    local log_file=$1
    local max_size_mb=${2:-100}
    
    if [ -f "$log_file" ]; then
        local size_mb=$(du -m "$log_file" | cut -f1)
        if [ $size_mb -gt $max_size_mb ]; then
            mv "$log_file" "${log_file}.$(date +%Y%m%d_%H%M%S)"
            gzip "${log_file}.$(date +%Y%m%d_%H%M%S)"
            touch "$log_file"
        fi
    fi
}
```

---

## Performance Tuning

### CPU Monitoring Optimization

#### Adaptive Intervals

```bash
# Adjust monitoring frequency based on system load
get_adaptive_interval() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count=$(nproc)
    local load_ratio=$(echo "scale=2; $load_avg / $cpu_count" | bc -l)
    
    if (( $(echo "$load_ratio > 0.8" | bc -l) )); then
        echo "10s"  # High load - reduce monitoring frequency
    elif (( $(echo "$load_ratio > 0.5" | bc -l) )); then
        echo "5s"   # Medium load - normal frequency
    else
        echo "2s"   # Low load - high frequency
    fi
}

# Dynamic configuration
check_cpu_interval=$(get_adaptive_interval)
```

#### Resource-Limited Monitoring

```bash
# CPU and memory limits for monitoring process
limit_resources() {
    local cpu_limit=5      # Max 5% CPU
    local memory_limit=100 # Max 100MB memory
    
    # Set CPU limit (requires cgroups)
    echo $$ > /sys/fs/cgroup/cpu/kiwi_monitor/cgroup.procs
    echo 50000 > /sys/fs/cgroup/cpu/kiwi_monitor/cpu.cfs_quota_us  # 5% of 1 CPU
    
    # Set memory limit
    echo $$ > /sys/fs/cgroup/memory/kiwi_monitor/cgroup.procs
    echo 104857600 > /sys/fs/cgroup/memory/kiwi_monitor/memory.limit_in_bytes  # 100MB
}
```

### Collection Optimization

#### Parallel Operations

```bash
# Parallel collection configuration
enable_parallel_collection() {
    # Collect non-interfering metrics in parallel
    collect_vm_info &
    collect_gc_stats &
    collect_system_info &
    
    # Wait for parallel operations
    wait
    
    # Sequential operations that may interfere
    collect_thread_dumps
    collect_memory_analysis
}
```

#### Selective Collection Profiles

```bash
# Collection profiles for different scenarios
set_collection_profile() {
    local profile=$1
    
    case $profile in
        "minimal")
            skip_heap_dump=true
            stack_times=1
            skip_system_info=true
            ;;
        "standard")
            skip_heap_dump=false
            stack_times=3
            skip_system_info=false
            ;;
        "comprehensive")
            skip_heap_dump=false
            stack_times=5
            skip_system_info=false
            collect_flight_recorder=true
            ;;
    esac
}
```

---

## Security Configuration

### User Permission Management

#### Dedicated Monitoring User

```bash
# Create monitoring user setup
setup_monitoring_user() {
    local monitor_user="java_monitor"
    local java_group="java_apps"
    
    # Create monitoring user
    sudo useradd -r -s /bin/bash -d /opt/java_monitor $monitor_user
    
    # Create Java applications group
    sudo groupadd $java_group
    
    # Add monitoring user to Java group
    sudo usermod -aG $java_group $monitor_user
    
    # Add Java application users to group
    sudo usermod -aG $java_group app1_user
    sudo usermod -aG $java_group app2_user
    
    # Set toolbox permissions
    sudo chown -R $monitor_user:$java_group /home/kiwi_java_toolbox
    sudo chmod -R 750 /home/kiwi_java_toolbox
}
```

#### Sudo Configuration

```bash
# Sudo rules for monitoring user
sudo tee /etc/sudoers.d/java_monitor << 'EOF'
# Allow java_monitor to run toolbox as any Java application user
java_monitor ALL=(app1_user,app2_user,webuser) NOPASSWD: /home/kiwi_java_toolbox/*.sh
java_monitor ALL=(app1_user,app2_user,webuser) NOPASSWD: /home/kiwi_java_toolbox/bin/*.sh

# Allow reading process information
java_monitor ALL=(ALL) NOPASSWD: /bin/ps, /usr/bin/top, /bin/netstat
EOF
```

### Data Protection

#### Encryption Configuration

```bash
# Encrypt sensitive diagnostic data
encrypt_diagnostics() {
    local data_dir=$1
    local recipient=${2:-"admin@company.com"}
    
    # Create encrypted archive
    tar -czf - $data_dir | gpg --cipher-algo AES256 --compress-algo 1 \
        --recipient $recipient --encrypt --output ${data_dir}.tar.gz.gpg
    
    # Securely remove original
    shred -vfz -n 3 -r $data_dir
    
    echo "Encrypted diagnostics: ${data_dir}.tar.gz.gpg"
}
```

#### Access Control

```bash
# Restrict access to diagnostic files
secure_diagnostics() {
    local output_dir=$1
    local authorized_group="java_admins"
    
    # Set restrictive permissions
    chmod 750 $output_dir
    chgrp $authorized_group $output_dir
    
    # Secure individual files
    find $output_dir -type f -exec chmod 640 {} \;
    find $output_dir -type f -exec chgrp $authorized_group {} \;
}
```

### Network Security

#### Firewall Configuration

```bash
# If using remote monitoring, configure firewall
configure_monitoring_firewall() {
    # Allow monitoring connections from specific hosts
    sudo iptables -A INPUT -p tcp --dport 8080 -s 192.168.1.100 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
    
    # Log monitoring access attempts
    sudo iptables -A INPUT -p tcp --dport 8080 -j LOG --log-prefix "JAVA_MONITOR: "
}
```

---

## Advanced Configuration

### Custom Collection Scripts

#### Plugin Architecture

```bash
# Plugin configuration
PLUGIN_DIR="/opt/kiwi_java_toolbox/plugins"
ENABLED_PLUGINS="custom_metrics,security_scan,performance_baseline"

# Load plugins
load_plugins() {
    for plugin in $(echo $ENABLED_PLUGINS | tr ',' ' '); do
        if [ -f "$PLUGIN_DIR/${plugin}.sh" ]; then
            source "$PLUGIN_DIR/${plugin}.sh"
            echo "Loaded plugin: $plugin"
        fi
    done
}

# Plugin interface
run_plugin_hooks() {
    local hook_name=$1
    local java_pid=$2
    
    for plugin in $(echo $ENABLED_PLUGINS | tr ',' ' '); do
        if type "${plugin}_${hook_name}" >/dev/null 2>&1; then
            "${plugin}_${hook_name}" $java_pid
        fi
    done
}
```

#### Custom Metrics Collection

```bash
# Custom metrics plugin example
custom_metrics_pre_collection() {
    local java_pid=$1
    echo "Collecting custom metrics for PID $java_pid"
    
    # Application-specific metrics
    collect_app_metrics $java_pid > $output_dir/custom_app_metrics.txt
    
    # Database connection pool stats
    collect_db_pool_stats $java_pid > $output_dir/db_pool_stats.txt
    
    # Cache statistics
    collect_cache_stats $java_pid > $output_dir/cache_stats.txt
}
```

### Integration with Monitoring Systems

#### Prometheus Integration

```bash
# Export metrics to Prometheus format
export_prometheus_metrics() {
    local java_pid=$1
    local metrics_file="$output_dir/prometheus_metrics.txt"
    
    # GC metrics
    local gc_stats=$(sh bin/jstat.sh -gc $java_pid 1000 1 | tail -1)
    echo "# HELP java_gc_young_collections_total Young generation GC collections" > $metrics_file
    echo "# TYPE java_gc_young_collections_total counter" >> $metrics_file
    echo "java_gc_young_collections_total{pid=\"$java_pid\"} $(echo $gc_stats | awk '{print $11}')" >> $metrics_file
    
    # Memory metrics
    echo "# HELP java_memory_heap_used_bytes Used heap memory" >> $metrics_file
    echo "# TYPE java_memory_heap_used_bytes gauge" >> $metrics_file
    echo "java_memory_heap_used_bytes{pid=\"$java_pid\"} $(echo $gc_stats | awk '{print ($8*1024)}')" >> $metrics_file
}
```

#### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "Kiwi Java Toolbox Monitoring",
    "panels": [
      {
        "title": "CPU Usage Trend",
        "type": "graph",
        "targets": [
          {
            "expr": "java_cpu_usage{job=\"kiwi_monitor\"}",
            "legendFormat": "CPU Usage %"
          }
        ]
      },
      {
        "title": "GC Collections",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(java_gc_young_collections_total[5m])",
            "legendFormat": "Young GC Rate"
          }
        ]
      }
    ]
  }
}
```

---

## Configuration Examples

### Complete Production Setup

```bash
#!/bin/bash
# production_setup.sh - Complete production configuration

# 1. CPU Monitor Configuration
cat << 'EOF' > java_cpu_monitor.conf
# Production CPU monitoring configuration
check_cpu_times=17280        # 24 hours at 5s intervals
check_cpu_interval=5s        # Balanced monitoring frequency
cpu_threshold_usage=70       # Trigger on sustained high CPU
cpu_threshold_times=6        # 30-second confirmation period
stack_times=3                # Standard thread dump collection
stack_interval=2s            # Quick succession for state changes
EOF

# 2. Environment Variables
cat << 'EOF' > /etc/environment
# Kiwi Java Toolbox environment
JAVA_CMD_FOR_TOOLS=/usr/lib/jvm/java-8-openjdk/bin/java
KIWI_OUTPUT_BASE=/var/log/java_diagnostics
TMPDIR=/opt/diagnostics/tmp
EOF

# 3. User Setup
useradd -r -s /bin/bash -d /opt/java_monitor java_monitor
groupadd java_apps
usermod -aG java_apps java_monitor
usermod -aG java_apps app1_user
usermod -aG java_apps app2_user

# 4. Directory Setup
mkdir -p /var/log/java_diagnostics /opt/diagnostics/tmp
chown java_monitor:java_apps /var/log/java_diagnostics
chown java_monitor:java_apps /opt/diagnostics/tmp
chmod 750 /var/log/java_diagnostics /opt/diagnostics/tmp

# 5. Toolbox Permissions
chown -R java_monitor:java_apps /home/kiwi_java_toolbox
chmod -R 750 /home/kiwi_java_toolbox

# 6. Sudo Configuration
tee /etc/sudoers.d/java_monitor << 'SUDO_EOF'
java_monitor ALL=(app1_user,app2_user) NOPASSWD: /home/kiwi_java_toolbox/*.sh
java_monitor ALL=(app1_user,app2_user) NOPASSWD: /home/kiwi_java_toolbox/bin/*.sh
SUDO_EOF

# 7. Log Rotation
tee /etc/logrotate.d/kiwi-java-toolbox << 'LOGROTATE_EOF'
/var/log/java_diagnostics/*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    maxage 90
}
LOGROTATE_EOF

# 8. Cleanup Cron Job
echo "0 2 * * * /home/kiwi_java_toolbox/cleanup_old_diagnostics.sh 7" | crontab -u java_monitor -

echo "Production setup completed"
```

### Development Environment Setup

```bash
#!/bin/bash
# development_setup.sh - Development environment configuration

# 1. High-sensitivity monitoring
cat << 'EOF' > java_cpu_monitor.conf
# Development monitoring - high sensitivity
check_cpu_times=7200         # 4 hours at 2s intervals
check_cpu_interval=2s        # Frequent monitoring
cpu_threshold_usage=30       # Low threshold for early detection
cpu_threshold_times=3        # Quick trigger (6 seconds)
stack_times=5                # Detailed analysis
stack_interval=1s            # Rapid collection
EOF

# 2. Debug mode enabled
echo 'export DEBUG_SWITCH=-x' >> ~/.bashrc

# 3. Custom output location
mkdir -p ~/java_diagnostics
echo 'export KIWI_OUTPUT_BASE=~/java_diagnostics' >> ~/.bashrc

# 4. Development aliases
cat << 'EOF' >> ~/.bashrc
# Kiwi Java Toolbox aliases
alias jinfo='sh ~/kiwi_java_toolbox/java_info_collect.sh'
alias jmonitor='sh ~/kiwi_java_toolbox/java_cpu_monitor.sh'
alias jfr='sh ~/kiwi_java_toolbox/java_flight_recorder.sh'
alias jps='sh ~/kiwi_java_toolbox/bin/jps.sh'
alias jstack='sh ~/kiwi_java_toolbox/bin/jstack.sh'
alias jmap='sh ~/kiwi_java_toolbox/bin/jmap.sh'
alias jstat='sh ~/kiwi_java_toolbox/bin/jstat.sh'
EOF

echo "Development setup completed"
echo "Please run: source ~/.bashrc"
```

### Container Environment Setup

```bash
#!/bin/bash
# container_setup.sh - Configuration for containerized environments

# 1. Container-optimized monitoring
cat << 'EOF' > java_cpu_monitor.conf
# Container monitoring configuration
check_cpu_times=86400        # Long-running containers
check_cpu_interval=10s       # Reduced frequency for container overhead
cpu_threshold_usage=80       # Higher threshold (containers often CPU-limited)
cpu_threshold_times=3        # Quick response for container issues
stack_times=2                # Minimal collection (storage constraints)
stack_interval=3s            # Reduced I/O impact
EOF

# 2. Minimal tool dependencies
export MINIMAL_DEPS=true

# 3. Container-specific output handling
export KIWI_OUTPUT_BASE="/shared/diagnostics"
mkdir -p /shared/diagnostics

# 4. Container health check integration
cat << 'EOF' > /usr/local/bin/java_health_check.sh
#!/bin/bash
# Health check with Kiwi integration

JAVA_PID=$(pgrep java | head -1)
if [ -z "$JAVA_PID" ]; then
    echo "No Java process found"
    exit 1
fi

# Quick health check
CPU_USAGE=$(top -b -n 1 -p $JAVA_PID | tail -1 | awk '{print $9}' | cut -d'.' -f1)
if [ $CPU_USAGE -gt 90 ]; then
    echo "High CPU detected: $CPU_USAGE%"
    # Trigger emergency collection
    sh /kiwi_java_toolbox/java_info_collect.sh <<< "$JAVA_PID" &
fi

echo "Java process healthy: PID=$JAVA_PID, CPU=$CPU_USAGE%"
exit 0
EOF

chmod +x /usr/local/bin/java_health_check.sh

echo "Container setup completed"
```

---

This comprehensive configuration guide provides detailed information about all configuration options, performance tuning, security considerations, and practical setup examples for the Kiwi Java Toolbox.