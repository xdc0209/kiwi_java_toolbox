# Kiwi Java Toolbox - Usage Examples and Tutorials

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Common Scenarios](#common-scenarios)
3. [Step-by-Step Tutorials](#step-by-step-tutorials)
4. [Advanced Usage Patterns](#advanced-usage-patterns)
5. [Integration Examples](#integration-examples)
6. [Best Practices](#best-practices)
7. [Real-World Case Studies](#real-world-case-studies)

---

## Quick Start Guide

### Installation and Setup

```bash
# 1. Extract the toolbox to a directory accessible by Java process users
unzip -o kiwi_java_toolbox-*.zip -d /home

# 2. Set proper permissions
chmod -R 755 /home/kiwi_java_toolbox

# 3. Verify installation
ls -la /home/kiwi_java_toolbox/
```

### First Diagnostic Collection

```bash
# Navigate to the toolbox directory
cd /home/kiwi_java_toolbox

# Run comprehensive information collection
sh java_info_collect.sh

# Example output:
# ============================================================================================
# 查询java进程：
# ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
# ============================================================================================
#   PID USER                 CMD
#  1234 appuser              java -Xmx2g -jar myapp.jar
#  5678 webuser              java -Xmx1g -jar webapp.jar
# 
# Enter java pid: 1234
```

### Quick CPU Monitoring

```bash
# Start CPU monitoring with default settings
sh java_cpu_monitor.sh

# Monitor will trigger collection when CPU > 20% for 5 consecutive checks
```

---

## Common Scenarios

### Scenario 1: Application Slowdown Investigation

**Situation**: Users report application slowness, need to identify the cause.

**Step-by-Step Approach**:

```bash
# Step 1: Get current system overview
sh java_info_collect.sh
# Select the problematic Java process when prompted

# Step 2: Check for high CPU usage patterns
sh java_cpu_monitor.sh
# Let it run for 10-15 minutes during peak usage

# Step 3: Start flight recording for detailed profiling
sh java_flight_recorder.sh start 1234
# Let it run for 30 minutes, then dump
sh java_flight_recorder.sh dump 1234
```

**Expected Output Structure**:
```
/tmp/java_info_collect_server01_192.168.1.100_20240915T143022+0800/
├── java_info_collect.log
├── cpu_jstack-1.txt          # Thread dumps
├── cpu_jstack-2.txt
├── cpu_jstack-3.txt
├── cpu_top-1.txt             # CPU usage snapshots
├── mem_objects_histogram.txt  # Memory usage
├── mem_heap_dump.hprof       # Full heap dump
└── os_*.txt                  # System information
```

**Analysis Approach**:
1. **Check GC logs** in the main log for excessive garbage collection
2. **Analyze thread dumps** for blocked threads or deadlocks
3. **Review CPU top files** for high CPU threads
4. **Examine object histogram** for memory leaks

---

### Scenario 2: Memory Leak Detection

**Situation**: Application memory usage continuously increases over time.

**Monitoring Setup**:

```bash
# Create monitoring script for memory leak detection
cat << 'EOF' > memory_leak_monitor.sh
#!/bin/bash
JAVA_PID=$1
INTERVAL=${2:-3600}  # Default 1 hour

while true; do
    echo "=== Memory snapshot at $(date) ==="
    
    # Quick memory histogram
    sh bin/jmap.sh -histo $JAVA_PID | head -20
    
    # GC statistics
    sh bin/jstat.sh -gc $JAVA_PID 1000 3
    
    # Sleep for specified interval
    sleep $INTERVAL
done
EOF

chmod +x memory_leak_monitor.sh

# Run memory monitoring
./memory_leak_monitor.sh 1234 1800  # Check every 30 minutes
```

**Detailed Analysis Collection**:

```bash
# Collect baseline heap dump
sh bin/jmap.sh -dump:live,format=b,file=heap_baseline.hprof 1234

# Wait for application to run (e.g., 2 hours)
sleep 7200

# Collect comparison heap dump
sh bin/jmap.sh -dump:live,format=b,file=heap_comparison.hprof 1234

# Generate object histograms for comparison
sh bin/jmap.sh -histo:live 1234 > histogram_current.txt
```

**Expected Indicators of Memory Leaks**:
```bash
# In GC statistics, look for:
# - Increasing Old Generation usage (OU column)
# - Frequent Full GC with minimal memory recovery
# - Increasing total GC time (GCT column)

# Example problematic GC output:
# S0C    S1C    S0U    S1U      EC       EU        OC         OU       PC     PU    YGC     YGCT    FGC    FGCT     GCT
# 8192.0 8192.0  0.0   8192.0 65536.0  32768.0  524288.0  512000.0  65536.0 45000.0  1250   12.5   45    67.8   80.3
#                                                          ^^^^^^^^^ High old gen usage
```

---

### Scenario 3: High CPU Usage Diagnosis

**Situation**: Java process consuming excessive CPU resources.

**Immediate Investigation**:

```bash
# Get immediate thread dump during high CPU
sh bin/jstack.sh -l 1234 > high_cpu_threads.txt

# Get top threads consuming CPU
top -H -p 1234 -n 1 > cpu_threads.txt

# Convert thread IDs to hex for correlation
# (This is done automatically by java_cpu_monitor.sh)
```

**Automated High CPU Monitoring**:

```bash
# Configure aggressive CPU monitoring
cat << 'EOF' > java_cpu_monitor.conf
check_cpu_times=1000
check_cpu_interval=1s
cpu_threshold_usage=50    # Trigger at 50% CPU
cpu_threshold_times=3     # After 3 consecutive readings
stack_times=5             # Collect 5 thread dumps
stack_interval=1s         # 1 second apart
EOF

# Start monitoring
sh java_cpu_monitor.sh
```

**Manual Thread Analysis**:

```bash
# Find high CPU threads
top -H -p 1234 -n 1 | grep -v "0.0" | head -10

# Example output:
#   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
#  1250 appuser   20   0 4194304 1048576  32768 R 85.0  5.2   0:45.67 java
#  1251 appuser   20   0 4194304 1048576  32768 R 75.0  5.2   0:38.45 java

# Convert PID to hex for thread dump correlation
printf "0x%x\n" 1250  # Output: 0x4e2
printf "0x%x\n" 1251  # Output: 0x4e3

# Search for these thread IDs in thread dump
grep -A 10 "nid=0x4e2" high_cpu_threads.txt
grep -A 10 "nid=0x4e3" high_cpu_threads.txt
```

---

### Scenario 4: Deadlock Detection

**Situation**: Application appears to hang intermittently.

**Deadlock Detection Script**:

```bash
# Create deadlock detection script
cat << 'EOF' > deadlock_detector.sh
#!/bin/bash
JAVA_PID=$1
INTERVAL=${2:-300}  # Check every 5 minutes

while true; do
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    THREAD_DUMP="thread_dump_${TIMESTAMP}.txt"
    
    # Collect thread dump
    sh bin/jstack.sh -l $JAVA_PID > $THREAD_DUMP
    
    # Check for deadlocks
    if grep -q "Found Java-level deadlock" $THREAD_DUMP; then
        echo "DEADLOCK DETECTED at $(date)"
        echo "Thread dump saved to: $THREAD_DUMP"
        
        # Extract deadlock information
        grep -A 50 "Found Java-level deadlock" $THREAD_DUMP > deadlock_${TIMESTAMP}.txt
        
        # Send alert (customize as needed)
        echo "Deadlock detected in Java process $JAVA_PID" | mail -s "Deadlock Alert" admin@company.com
    else
        echo "No deadlock detected at $(date)"
        # Remove clean thread dump to save space
        rm $THREAD_DUMP
    fi
    
    sleep $INTERVAL
done
EOF

chmod +x deadlock_detector.sh

# Run deadlock detection
./deadlock_detector.sh 1234 180  # Check every 3 minutes
```

**Manual Deadlock Analysis**:

```bash
# Collect thread dump
sh bin/jstack.sh -l 1234 > threads.txt

# Search for deadlock indicators
grep -i deadlock threads.txt
grep -i "waiting to lock" threads.txt
grep -i "locked by" threads.txt

# Example deadlock pattern:
# "Thread-1" #10 prio=5 os_prio=0 tid=0x... nid=0x... waiting for monitor entry
#    java.lang.Thread.State: BLOCKED (on object monitor)
#    at com.example.ClassA.methodA(ClassA.java:25)
#    - waiting to lock <0x000000076ab62208> (a java.lang.Object)
#    - locked <0x000000076ab62218> (a java.lang.Object)
```

---

## Step-by-Step Tutorials

### Tutorial 1: Complete Performance Analysis Workflow

**Objective**: Perform comprehensive performance analysis of a Java application.

#### Phase 1: Initial Assessment (5 minutes)

```bash
# Step 1: Identify Java processes
sh bin/jps.sh -l

# Step 2: Get basic process information
JAVA_PID=1234  # Replace with actual PID
ps -p $JAVA_PID -o pid,ppid,user,pcpu,pmem,etime,cmd

# Step 3: Check current resource usage
top -p $JAVA_PID -n 1

# Step 4: Quick GC status check
sh bin/jstat.sh -gc $JAVA_PID 1000 3
```

#### Phase 2: Baseline Collection (10 minutes)

```bash
# Step 5: Start flight recording for continuous profiling
sh java_flight_recorder.sh start $JAVA_PID

# Step 6: Collect comprehensive baseline information
sh java_info_collect.sh
# Enter the Java PID when prompted

# Step 7: Start CPU monitoring in background
nohup sh java_cpu_monitor.sh > cpu_monitor.log 2>&1 &
MONITOR_PID=$!
echo $MONITOR_PID > monitor.pid  # Save PID for later cleanup
```

#### Phase 3: Load Testing Period (30-60 minutes)

```bash
# Step 8: Let application run under normal/peak load
# Monitor the output directory for automatic collections
tail -f cpu_monitor.log

# Step 9: Periodic manual checks
while true; do
    echo "=== Status at $(date) ==="
    sh bin/jstat.sh -gccause $JAVA_PID 1000 1
    sleep 600  # Every 10 minutes
done
```

#### Phase 4: Final Collection and Cleanup (10 minutes)

```bash
# Step 10: Stop CPU monitoring
kill $(cat monitor.pid)

# Step 11: Dump flight recording
sh java_flight_recorder.sh dump $JAVA_PID

# Step 12: Stop flight recording
sh java_flight_recorder.sh stop $JAVA_PID

# Step 13: Final comprehensive collection
sh java_info_collect.sh

# Step 14: Organize results
mkdir performance_analysis_$(date +%Y%m%d)
mv /tmp/java_info_collect_* performance_analysis_$(date +%Y%m%d)/
mv /tmp/java_flight_recorder_* performance_analysis_$(date +%Y%m%d)/
mv cpu_monitor.log performance_analysis_$(date +%Y%m%d)/
```

---

### Tutorial 2: Setting Up Automated Monitoring

**Objective**: Configure automated monitoring for production Java applications.

#### Step 1: Create Monitoring Configuration

```bash
# Create configuration directory
mkdir -p /opt/java_monitoring/config

# Configure CPU monitoring thresholds
cat << 'EOF' > /opt/java_monitoring/config/production.conf
# Production monitoring configuration
check_cpu_times=86400        # Monitor for 24 hours
check_cpu_interval=5s        # Check every 5 seconds
cpu_threshold_usage=70       # Trigger at 70% CPU
cpu_threshold_times=6        # After 6 consecutive readings (30 seconds)
stack_times=3                # Collect 3 thread dumps
stack_interval=3s            # 3 seconds apart
EOF
```

#### Step 2: Create Monitoring Scripts

```bash
# Main monitoring script
cat << 'EOF' > /opt/java_monitoring/monitor_java_app.sh
#!/bin/bash

# Configuration
JAVA_APP_NAME="MyApplication"
JAVA_PID_FILE="/var/run/myapp.pid"
MONITOR_LOG="/var/log/java_monitoring.log"
TOOLBOX_PATH="/home/kiwi_java_toolbox"
CONFIG_FILE="/opt/java_monitoring/config/production.conf"

# Functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $MONITOR_LOG
}

get_java_pid() {
    if [ -f "$JAVA_PID_FILE" ]; then
        cat $JAVA_PID_FILE
    else
        # Fallback: search by process name
        pgrep -f "$JAVA_APP_NAME" | head -1
    fi
}

# Main monitoring loop
main() {
    JAVA_PID=$(get_java_pid)
    
    if [ -z "$JAVA_PID" ]; then
        log_message "ERROR: Could not find Java process for $JAVA_APP_NAME"
        exit 1
    fi
    
    log_message "Starting monitoring for Java PID: $JAVA_PID"
    
    # Copy configuration
    cp $CONFIG_FILE $TOOLBOX_PATH/java_cpu_monitor.conf
    
    # Start CPU monitoring
    cd $TOOLBOX_PATH
    echo $JAVA_PID | sh java_cpu_monitor.sh >> $MONITOR_LOG 2>&1
}

# Signal handlers
cleanup() {
    log_message "Monitoring stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start monitoring
main "$@"
EOF

chmod +x /opt/java_monitoring/monitor_java_app.sh
```

#### Step 3: Create Systemd Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/java-monitoring.service << 'EOF'
[Unit]
Description=Java Application Monitoring
After=network.target
Requires=network.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/java_monitoring/monitor_java_app.sh
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create monitoring user
sudo useradd -r -s /bin/bash -d /opt/java_monitoring monitoring

# Set permissions
sudo chown -R monitoring:monitoring /opt/java_monitoring
sudo chown -R monitoring:monitoring /home/kiwi_java_toolbox

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable java-monitoring.service
sudo systemctl start java-monitoring.service

# Check status
sudo systemctl status java-monitoring.service
```

#### Step 4: Log Rotation and Cleanup

```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/java-monitoring << 'EOF'
/var/log/java_monitoring.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Cleanup script for old diagnostic files
cat << 'EOF' > /opt/java_monitoring/cleanup_old_files.sh
#!/bin/bash

# Remove diagnostic files older than 7 days
find /tmp -name "java_info_collect_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
find /tmp -name "java_cpu_monitor_*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
find /tmp -name "java_flight_recorder_*" -type f -mtime +7 -delete 2>/dev/null

# Remove large heap dumps older than 3 days
find /tmp -name "*.hprof" -mtime +3 -delete 2>/dev/null

echo "Cleanup completed at $(date)"
EOF

chmod +x /opt/java_monitoring/cleanup_old_files.sh

# Add to crontab
echo "0 2 * * * /opt/java_monitoring/cleanup_old_files.sh" | sudo crontab -u monitoring -
```

---

## Advanced Usage Patterns

### Pattern 1: Multi-Application Monitoring

**Scenario**: Monitor multiple Java applications simultaneously.

```bash
# Create multi-app monitoring script
cat << 'EOF' > multi_app_monitor.sh
#!/bin/bash

# Application configurations
declare -A APPS=(
    ["WebApp"]="8080"
    ["APIService"]="8081" 
    ["BatchProcessor"]="8082"
)

monitor_app() {
    local app_name=$1
    local port=$2
    
    # Find PID by port
    local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
    
    if [ -z "$pid" ]; then
        echo "No process found listening on port $port for $app_name"
        return 1
    fi
    
    echo "Monitoring $app_name (PID: $pid, Port: $port)"
    
    # Create app-specific config
    cat << EOC > java_cpu_monitor_${app_name}.conf
check_cpu_times=10000
check_cpu_interval=3s
cpu_threshold_usage=60
cpu_threshold_times=5
stack_times=3
stack_interval=2s
EOC
    
    # Start monitoring in background
    (
        cp java_cpu_monitor_${app_name}.conf java_cpu_monitor.conf
        echo $pid | sh java_cpu_monitor.sh
    ) > monitor_${app_name}.log 2>&1 &
    
    echo $! > monitor_${app_name}.pid
}

# Start monitoring for all applications
for app in "${!APPS[@]}"; do
    monitor_app "$app" "${APPS[$app]}"
    sleep 2
done

echo "All monitors started. Check *.log files for output."
echo "Stop with: kill \$(cat monitor_*.pid)"
EOF

chmod +x multi_app_monitor.sh
```

### Pattern 2: Conditional Monitoring

**Scenario**: Start detailed monitoring only when specific conditions are met.

```bash
# Create condition-based monitoring
cat << 'EOF' > conditional_monitor.sh
#!/bin/bash

JAVA_PID=$1
CHECK_INTERVAL=30
DETAILED_MONITORING=false

# Monitoring conditions
check_conditions() {
    local pid=$1
    
    # Get current metrics
    local cpu_usage=$(top -b -n 1 -p $pid | tail -1 | awk '{print $9}' | cut -d'.' -f1)
    local memory_usage=$(ps -p $pid -o %mem --no-headers | cut -d'.' -f1)
    local gc_stats=$(sh bin/jstat.sh -gc $pid 1000 1 | tail -1)
    local old_gen_usage=$(echo $gc_stats | awk '{print int(($8/$7)*100)}')
    
    echo "CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Old Gen: ${old_gen_usage}%"
    
    # Check conditions for detailed monitoring
    if [ "$cpu_usage" -gt 70 ] || [ "$memory_usage" -gt 80 ] || [ "$old_gen_usage" -gt 85 ]; then
        return 0  # Start detailed monitoring
    else
        return 1  # Continue basic monitoring
    fi
}

# Main monitoring loop
while true; do
    if check_conditions $JAVA_PID; then
        if [ "$DETAILED_MONITORING" = "false" ]; then
            echo "Conditions met - starting detailed monitoring"
            
            # Start flight recording
            sh java_flight_recorder.sh start $JAVA_PID
            
            # Start CPU monitoring in background
            nohup sh java_cpu_monitor.sh > detailed_monitor.log 2>&1 &
            MONITOR_PID=$!
            
            DETAILED_MONITORING=true
        fi
    else
        if [ "$DETAILED_MONITORING" = "true" ]; then
            echo "Conditions normalized - stopping detailed monitoring"
            
            # Stop CPU monitoring
            kill $MONITOR_PID 2>/dev/null
            
            # Dump and stop flight recording
            sh java_flight_recorder.sh dump $JAVA_PID
            sh java_flight_recorder.sh stop $JAVA_PID
            
            DETAILED_MONITORING=false
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
EOF

chmod +x conditional_monitor.sh
```

### Pattern 3: Integration with Alerting Systems

**Scenario**: Integrate monitoring with external alerting systems.

```bash
# Create alerting integration
cat << 'EOF' > alerting_monitor.sh
#!/bin/bash

JAVA_PID=$1
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
EMAIL_RECIPIENTS="admin@company.com,oncall@company.com"

# Alert functions
send_slack_alert() {
    local message=$1
    local color=$2
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
        $WEBHOOK_URL
}

send_email_alert() {
    local subject=$1
    local message=$2
    
    echo "$message" | mail -s "$subject" $EMAIL_RECIPIENTS
}

# Enhanced monitoring with alerting
monitor_with_alerts() {
    local pid=$1
    
    # Start monitoring
    sh java_cpu_monitor.sh > monitor_output.log 2>&1 &
    local monitor_pid=$!
    
    # Monitor the output for issues
    tail -f monitor_output.log | while read line; do
        case "$line" in
            *"ERROR:"*)
                send_slack_alert "Java Monitor Error: $line" "danger"
                send_email_alert "Java Monitor Alert" "Error detected: $line"
                ;;
            *"CPU usage"*"high"*)
                send_slack_alert "High CPU detected on Java process $pid" "warning"
                ;;
            *"Get stack"*)
                send_slack_alert "Thread dumps collected for Java process $pid" "good"
                ;;
        esac
    done
}

# Start monitoring with alerts
monitor_with_alerts $JAVA_PID
EOF

chmod +x alerting_monitor.sh
```

---

## Integration Examples

### Integration with Docker

**Scenario**: Monitor Java applications running in Docker containers.

```bash
# Docker monitoring script
cat << 'EOF' > docker_java_monitor.sh
#!/bin/bash

CONTAINER_NAME=$1

# Get container PID
get_container_java_pid() {
    local container=$1
    
    # Get container's main process PID
    local container_pid=$(docker inspect -f '{{.State.Pid}}' $container)
    
    # Find Java process inside container
    local java_pid=$(docker exec $container ps aux | grep java | grep -v grep | awk '{print $2}' | head -1)
    
    echo $java_pid
}

# Copy toolbox into container
docker cp /home/kiwi_java_toolbox $CONTAINER_NAME:/tmp/

# Get Java PID inside container
JAVA_PID=$(get_container_java_pid $CONTAINER_NAME)

if [ -z "$JAVA_PID" ]; then
    echo "No Java process found in container $CONTAINER_NAME"
    exit 1
fi

echo "Found Java process $JAVA_PID in container $CONTAINER_NAME"

# Run monitoring inside container
docker exec -it $CONTAINER_NAME bash -c "
    cd /tmp/kiwi_java_toolbox
    echo $JAVA_PID | sh java_info_collect.sh
"

# Copy results back
docker cp $CONTAINER_NAME:/tmp/java_info_collect_* ./
EOF

chmod +x docker_java_monitor.sh

# Usage
./docker_java_monitor.sh my-java-app
```

### Integration with Kubernetes

```bash
# Kubernetes monitoring script
cat << 'EOF' > k8s_java_monitor.sh
#!/bin/bash

NAMESPACE=$1
POD_NAME=$2

# Copy toolbox to pod
kubectl cp /home/kiwi_java_toolbox $NAMESPACE/$POD_NAME:/tmp/

# Find Java PID in pod
JAVA_PID=$(kubectl exec -n $NAMESPACE $POD_NAME -- ps aux | grep java | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$JAVA_PID" ]; then
    echo "No Java process found in pod $POD_NAME"
    exit 1
fi

echo "Found Java process $JAVA_PID in pod $POD_NAME"

# Run monitoring
kubectl exec -n $NAMESPACE $POD_NAME -- bash -c "
    cd /tmp/kiwi_java_toolbox
    echo $JAVA_PID | sh java_info_collect.sh
"

# Copy results back
kubectl cp $NAMESPACE/$POD_NAME:/tmp/java_info_collect_* ./
EOF

chmod +x k8s_java_monitor.sh

# Usage
./k8s_java_monitor.sh default my-app-pod-12345
```

---

## Best Practices

### 1. Monitoring Strategy

**Layered Monitoring Approach**:

```bash
# Layer 1: Continuous lightweight monitoring
# - Basic metrics every 5 minutes
# - No heap dumps or intensive operations

# Layer 2: Triggered detailed monitoring  
# - Activated by Layer 1 alerts
# - Thread dumps and detailed GC analysis

# Layer 3: Deep diagnostic collection
# - Manual or scheduled comprehensive analysis
# - Heap dumps and flight recordings
```

### 2. Resource Management

**Disk Space Management**:

```bash
# Monitor available disk space before operations
check_disk_space() {
    local required_gb=$1
    local available_gb=$(df /tmp | tail -1 | awk '{print int($4/1024/1024)}')
    
    if [ $available_gb -lt $required_gb ]; then
        echo "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    return 0
}

# Use before heap dumps
if check_disk_space 5; then
    sh bin/jmap.sh -dump:live,format=b,file=heap.hprof $JAVA_PID
else
    echo "Skipping heap dump due to insufficient disk space"
fi
```

**Memory Impact Considerations**:

```bash
# Schedule memory-intensive operations during low usage
CURRENT_HOUR=$(date +%H)

if [ $CURRENT_HOUR -ge 2 ] && [ $CURRENT_HOUR -le 5 ]; then
    echo "Low usage period - performing heap dump"
    sh bin/jmap.sh -dump:live,format=b,file=heap_$(date +%Y%m%d_%H%M).hprof $JAVA_PID
else
    echo "Peak usage period - skipping heap dump"
fi
```

### 3. Security Considerations

**User Permission Management**:

```bash
# Create dedicated monitoring user
sudo useradd -r -s /bin/bash monitoring
sudo usermod -aG java_users monitoring

# Set proper ownership
sudo chown -R monitoring:monitoring /home/kiwi_java_toolbox
sudo chmod 750 /home/kiwi_java_toolbox

# Limit access to sensitive files
sudo chmod 640 /home/kiwi_java_toolbox/java_cpu_monitor.conf
```

**Data Protection**:

```bash
# Encrypt sensitive diagnostic data
encrypt_diagnostic_data() {
    local data_dir=$1
    local encrypted_file="${data_dir}.tar.gz.gpg"
    
    tar -czf - $data_dir | gpg --cipher-algo AES256 --compress-algo 1 \
        --symmetric --output $encrypted_file
    
    # Securely remove original
    rm -rf $data_dir
    echo "Encrypted data saved to: $encrypted_file"
}

# Usage after collection
encrypt_diagnostic_data /tmp/java_info_collect_*
```

### 4. Performance Optimization

**Efficient Collection Strategies**:

```bash
# Parallel collection for multiple metrics
collect_parallel_metrics() {
    local java_pid=$1
    
    # Start multiple collections in background
    sh bin/jstat.sh -gc $java_pid 1000 5 > gc_stats.txt &
    sh bin/jstack.sh -l $java_pid > thread_dump.txt &
    sh bin/jmap.sh -histo $java_pid > object_histogram.txt &
    
    # Wait for all to complete
    wait
    
    echo "Parallel collection completed"
}
```

**Optimized Monitoring Intervals**:

```bash
# Adaptive monitoring intervals based on system load
get_adaptive_interval() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count=$(nproc)
    local load_ratio=$(echo "$load_avg / $cpu_count" | bc -l)
    
    if (( $(echo "$load_ratio > 0.8" | bc -l) )); then
        echo 10s  # High load - less frequent monitoring
    elif (( $(echo "$load_ratio > 0.5" | bc -l) )); then
        echo 5s   # Medium load - normal monitoring
    else
        echo 2s   # Low load - more frequent monitoring
    fi
}

# Usage in monitoring script
MONITOR_INTERVAL=$(get_adaptive_interval)
echo "Using monitoring interval: $MONITOR_INTERVAL"
```

---

## Real-World Case Studies

### Case Study 1: E-commerce Application Memory Leak

**Background**: Online shopping platform experiencing gradual memory increase, leading to daily restarts.

**Investigation Process**:

```bash
# Day 1: Establish baseline
sh java_info_collect.sh  # Selected PID 2345 (main app server)

# Day 2-7: Continuous monitoring
cat << 'EOF' > ecommerce_monitor.sh
#!/bin/bash
JAVA_PID=2345
LOG_FILE="ecommerce_memory_trend.log"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Collect key memory metrics
    GC_STATS=$(sh bin/jstat.sh -gc $JAVA_PID 1000 1 | tail -1)
    OLD_GEN_USED=$(echo $GC_STATS | awk '{print $8}')
    OLD_GEN_CAPACITY=$(echo $GC_STATS | awk '{print $7}')
    OLD_GEN_PERCENT=$(echo "scale=2; $OLD_GEN_USED * 100 / $OLD_GEN_CAPACITY" | bc)
    
    # Log the metrics
    echo "$TIMESTAMP,$OLD_GEN_USED,$OLD_GEN_CAPACITY,$OLD_GEN_PERCENT" >> $LOG_FILE
    
    # Trigger detailed collection if memory usage high
    if (( $(echo "$OLD_GEN_PERCENT > 85" | bc -l) )); then
        echo "High memory usage detected: $OLD_GEN_PERCENT%"
        sh bin/jmap.sh -histo:live $JAVA_PID > histogram_$(date +%Y%m%d_%H%M).txt
        
        # If critical, take heap dump
        if (( $(echo "$OLD_GEN_PERCENT > 95" | bc -l) )); then
            sh bin/jmap.sh -dump:live,format=b,file=critical_heap_$(date +%Y%m%d_%H%M).hprof $JAVA_PID
        fi
    fi
    
    sleep 300  # Check every 5 minutes
done
EOF

nohup sh ecommerce_monitor.sh &
```

**Key Findings**:
1. **Memory Pattern**: Old generation usage increased 2-3% daily
2. **Object Analysis**: Shopping cart objects were not being cleared
3. **Root Cause**: Session timeout not properly cleaning cart data

**Resolution**:
```bash
# After code fix, verify the improvement
sh java_info_collect.sh

# Compare heap dumps before/after fix
# Before: 15,000,000 cart objects consuming 2.1GB
# After: 50,000 cart objects consuming 70MB
```

### Case Study 2: Microservice High CPU Usage

**Background**: API gateway service consuming 80%+ CPU during peak hours.

**Investigation Approach**:

```bash
# Configure aggressive CPU monitoring
cat << 'EOF' > api_gateway_cpu.conf
check_cpu_times=2000
check_cpu_interval=2s
cpu_threshold_usage=60
cpu_threshold_times=3
stack_times=7
stack_interval=1s
EOF

cp api_gateway_cpu.conf java_cpu_monitor.conf

# Start monitoring during peak hours (9 AM - 6 PM)
if [ $(date +%H) -ge 9 ] && [ $(date +%H) -le 18 ]; then
    echo "Peak hours - starting intensive monitoring"
    sh java_cpu_monitor.sh  # PID: 3456
fi
```

**Analysis Results**:

```bash
# Thread dump analysis revealed:
# 1. 85% of CPU time spent in JSON parsing
# 2. Large JSON payloads (>1MB) being parsed repeatedly
# 3. No caching of parsed objects

# Verification with flight recorder
sh java_flight_recorder.sh start 3456
# Let run for 30 minutes during peak
sh java_flight_recorder.sh dump 3456
```

**Performance Improvement Verification**:

```bash
# Before optimization:
# CPU Usage: 80-90%
# Response Time: 2.5 seconds average
# Thread count: 450+ active threads

# After optimization (JSON caching implemented):
# CPU Usage: 25-35%  
# Response Time: 0.8 seconds average
# Thread count: 150 active threads
```

### Case Study 3: Batch Processing Deadlock

**Background**: Nightly batch processing job hanging randomly, requiring manual intervention.

**Detection Setup**:

```bash
# Create batch job monitoring script
cat << 'EOF' > batch_deadlock_monitor.sh
#!/bin/bash
BATCH_PID=$(pgrep -f "BatchProcessor")
HANG_THRESHOLD=3600  # 1 hour without progress

get_thread_activity() {
    local pid=$1
    # Count threads not in WAITING state
    sh bin/jstack.sh $pid | grep -c "java.lang.Thread.State: RUNNABLE"
}

last_activity=$(get_thread_activity $BATCH_PID)
start_time=$(date +%s)

while kill -0 $BATCH_PID 2>/dev/null; do
    current_activity=$(get_thread_activity $BATCH_PID)
    current_time=$(date +%s)
    
    if [ $current_activity -eq $last_activity ]; then
        # No change in thread activity
        idle_time=$((current_time - start_time))
        
        if [ $idle_time -gt $HANG_THRESHOLD ]; then
            echo "DEADLOCK SUSPECTED: No thread activity for $idle_time seconds"
            
            # Collect evidence
            sh bin/jstack.sh -l $BATCH_PID > deadlock_evidence_$(date +%Y%m%d_%H%M).txt
            
            # Check for deadlock
            if grep -q "Found Java-level deadlock" deadlock_evidence_*.txt; then
                echo "DEADLOCK CONFIRMED"
                # Send alert and take action
                echo "Deadlock detected in batch job" | mail -s "URGENT: Batch Deadlock" admin@company.com
            fi
            
            break
        fi
    else
        # Activity detected, reset timer
        last_activity=$current_activity
        start_time=$current_time
    fi
    
    sleep 60  # Check every minute
done
EOF

# Run during batch processing window
nohup sh batch_deadlock_monitor.sh > batch_monitor.log 2>&1 &
```

**Root Cause Discovery**:

```bash
# Deadlock pattern found in thread dumps:
# Thread-1: Locked ResourceA, waiting for ResourceB
# Thread-2: Locked ResourceB, waiting for ResourceA

# Example from thread dump:
grep -A 20 "Found Java-level deadlock" deadlock_evidence_*.txt

# Output showed:
# "BatchWorker-1" waiting to lock <0x000000076ab62208> (ResourceB)
# - locked <0x000000076ab62218> (ResourceA)
# "BatchWorker-2" waiting to lock <0x000000076ab62218> (ResourceA)  
# - locked <0x000000076ab62208> (ResourceB)
```

**Resolution and Verification**:

```bash
# After implementing ordered locking (always acquire ResourceA before ResourceB):
# Run verification monitoring for 1 week
for day in {1..7}; do
    echo "Day $day monitoring..."
    sh batch_deadlock_monitor.sh
    sleep 86400  # 24 hours
done

# Results: No deadlocks detected in 7 days of monitoring
# Batch job completion time improved from 4+ hours to 2.5 hours
```

---

This comprehensive usage guide provides practical examples and real-world scenarios for effectively using the Kiwi Java Toolbox to diagnose and resolve Java application issues.