# Kiwi Java Toolbox - Bin Utilities Guide

## Table of Contents

1. [Utility Scripts Overview](#utility-scripts-overview)
2. [jcmd.sh - Java Command Tool](#jcmdsh---java-command-tool)
3. [jstack.sh - Thread Dump Tool](#jstacksh---thread-dump-tool)
4. [jmap.sh - Memory Analysis Tool](#jmapsh---memory-analysis-tool)
5. [jstat.sh - Statistics Tool](#jstatsh---statistics-tool)
6. [jps.sh - Process Status Tool](#jpssh---process-status-tool)
7. [Common Usage Patterns](#common-usage-patterns)
8. [Integration Examples](#integration-examples)
9. [Performance Considerations](#performance-considerations)
10. [Troubleshooting Utilities](#troubleshooting-utilities)

---

## Utility Scripts Overview

The `bin/` directory contains wrapper scripts for standard JDK diagnostic tools. These wrappers provide enhanced compatibility, error handling, and automatic environment configuration.

### Common Features

All utility scripts share these enhanced features:

- **Automatic JDK/JRE Detection**: Works with both JDK and JRE environments
- **Version Compatibility**: Handles multiple Java versions automatically  
- **User Permission Validation**: Ensures proper access permissions
- **Enhanced Error Messages**: Provides detailed error information
- **Environment Auto-Configuration**: Sets up classpath and library paths
- **Embedded JDK Support**: Falls back to embedded JDK libraries when needed

### Architecture

```
bin/
├── jcmd.sh      # Java command and diagnostic tool
├── jmap.sh      # Memory analysis and heap dumps
├── jps.sh       # Java process status
├── jstack.sh    # Thread dumps and stack traces
├── jstat.sh     # GC and runtime statistics
└── jtop.jar     # Enhanced thread monitoring (optional)
```

---

## jcmd.sh - Java Command Tool

### Overview

`jcmd.sh` is a wrapper for the `sun.tools.jcmd.JCmd` utility, providing a command-line interface to running Java processes for diagnostic and management operations.

### Syntax

```bash
sh bin/jcmd.sh <java_pid> <command> [arguments...]
sh bin/jcmd.sh <java_pid> help
```

### Parameters

- `java_pid` - Target Java process ID (required)
- `command` - JCmd command to execute (required)
- `arguments` - Command-specific arguments (optional)

### Core Commands

#### Virtual Machine Information

##### VM.uptime
Display JVM uptime information.

```bash
sh bin/jcmd.sh 1234 VM.uptime
# Output:
# 1234:
# 12345.678 s
```

**Use Cases**:
- Verify JVM restart times
- Calculate application runtime
- Correlate issues with uptime

##### VM.version
Display detailed JVM version information.

```bash
sh bin/jcmd.sh 1234 VM.version
# Output:
# 1234:
# Java HotSpot(TM) 64-Bit Server VM version 25.181-b13
# JDK 8.0_181
```

##### VM.system_properties
Display all JVM system properties.

```bash
sh bin/jcmd.sh 1234 VM.system_properties
# Output:
# 1234:
# java.runtime.name=Java(TM) SE Runtime Environment
# java.vm.version=25.181-b13
# java.vm.vendor=Oracle Corporation
# ...
```

**Analysis Uses**:
- Check configuration settings
- Verify system property values
- Debug classpath issues

##### VM.command_line
Display JVM startup command line and arguments.

```bash
sh bin/jcmd.sh 1234 VM.command_line
# Output:
# 1234:
# VM Arguments:
# jvm_args: -Xmx2g -Xms1g -XX:+UseG1GC
# java_command: com.example.MyApplication --config=prod.properties
# java_class_path (initial): /opt/myapp/lib/*:/opt/myapp/myapp.jar
# Launcher Type: SUN_STANDARD
```

**Analysis Uses**:
- Verify JVM tuning parameters
- Check application arguments
- Validate classpath configuration

#### Garbage Collection Commands

##### GC.run
Trigger a garbage collection cycle.

```bash
sh bin/jcmd.sh 1234 GC.run
# Output:
# 1234:
# Command executed successfully
```

**Use Cases**:
- Force GC before heap analysis
- Clear memory before performance testing
- Trigger GC for memory reclamation

**⚠️ Warning**: Can cause application pause, use carefully in production.

##### GC.run_finalization
Run finalization methods for pending objects.

```bash
sh bin/jcmd.sh 1234 GC.run_finalization
# Output:
# 1234:
# Command executed successfully
```

##### GC.class_histogram
Display class histogram (object count and memory usage).

```bash
sh bin/jcmd.sh 1234 GC.class_histogram
# Output:
# 1234:
#  num     #instances         #bytes  class name
# ----------------------------------------------
#    1:         98765       12345678  [C
#    2:         87654        9876543  java.lang.String
#    3:         65432        7654321  java.util.HashMap$Node
# ...
```

**Analysis Uses**:
- Identify memory-heavy classes
- Detect potential memory leaks
- Monitor object allocation patterns

#### Thread Management

##### Thread.print
Print thread stacks for all threads.

```bash
sh bin/jcmd.sh 1234 Thread.print
# Output:
# 1234:
# Full thread dump Java HotSpot(TM) 64-Bit Server VM (25.181-b13 mixed mode):
# 
# "main" #1 prio=5 os_prio=0 tid=0x... nid=0x... runnable [0x...]
#    java.lang.Thread.State: RUNNABLE
#    at java.io.FileInputStream.readBytes(Native Method)
# ...
```

**Equivalent**: Similar to `jstack` but via JCmd interface

#### Java Flight Recorder Commands

##### JFR.start
Start a Java Flight Recorder recording.

```bash
# Basic recording
sh bin/jcmd.sh 1234 JFR.start

# Named recording with settings
sh bin/jcmd.sh 1234 JFR.start name=myrecording settings=profile

# Recording with size and time limits
sh bin/jcmd.sh 1234 JFR.start name=myrecording maxsize=100m maxage=1h

# Custom settings file
sh bin/jcmd.sh 1234 JFR.start name=myrecording settings=/path/to/custom.jfc
```

**Parameters**:
- `name` - Recording name (default: auto-generated)
- `settings` - Settings profile (`default`, `profile`, or file path)
- `maxsize` - Maximum recording size (e.g., `100m`, `1g`)
- `maxage` - Maximum recording age (e.g., `30m`, `2h`, `1d`)
- `duration` - Recording duration (e.g., `5m`, `1h`)

**Example Output**:
```
1234:
Started recording 1. Name="myrecording" (running)
```

##### JFR.check
Check status of flight recordings.

```bash
sh bin/jcmd.sh 1234 JFR.check
# Output:
# 1234:
# Recording 1: name=myrecording duration=PT5M30S (running)
# Recording 2: name=background maxsize=100.0MB maxage=PT1H (running)
```

##### JFR.dump
Dump recording data to file.

```bash
# Dump specific recording
sh bin/jcmd.sh 1234 JFR.dump name=myrecording filename=/tmp/recording.jfr

# Dump with compression
sh bin/jcmd.sh 1234 JFR.dump name=myrecording filename=/tmp/recording.jfr compress=true
```

##### JFR.stop
Stop a flight recording.

```bash
sh bin/jcmd.sh 1234 JFR.stop name=myrecording
# Output:
# 1234:
# Stopped recording "myrecording".
```

### Advanced Commands

#### VM.unlock_commercial_features
Unlock commercial features (required for JFR in older JDK versions).

```bash
sh bin/jcmd.sh 1234 VM.unlock_commercial_features
# Output:
# 1234:
# Commercial Features already unlocked.
```

#### VM.classloader_stats
Display class loader statistics.

```bash
sh bin/jcmd.sh 1234 VM.classloader_stats
# Output:
# 1234:
# ClassLoader         Parent              CLD*               Classes   ChunkSz   BlockSz  Type
# 0x0000000000000000  0x0000000000000000  0x00007f8b44001000      1234    12345     67890  Bootstrap
# 0x00007f8b45001000  0x0000000000000000  0x00007f8b45002000       567     5678      8901  Platform
# ...
```

### Usage Examples

#### Comprehensive JVM Analysis

```bash
#!/bin/bash
# Comprehensive JVM analysis using jcmd

JAVA_PID=$1
OUTPUT_DIR="jcmd_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT_DIR

echo "Analyzing Java process $JAVA_PID..."

# Basic VM information
sh bin/jcmd.sh $JAVA_PID VM.uptime > $OUTPUT_DIR/vm_uptime.txt
sh bin/jcmd.sh $JAVA_PID VM.version > $OUTPUT_DIR/vm_version.txt
sh bin/jcmd.sh $JAVA_PID VM.system_properties > $OUTPUT_DIR/vm_properties.txt
sh bin/jcmd.sh $JAVA_PID VM.command_line > $OUTPUT_DIR/vm_commandline.txt

# Class and memory information
sh bin/jcmd.sh $JAVA_PID GC.class_histogram > $OUTPUT_DIR/class_histogram.txt
sh bin/jcmd.sh $JAVA_PID VM.classloader_stats > $OUTPUT_DIR/classloader_stats.txt

# Thread information
sh bin/jcmd.sh $JAVA_PID Thread.print > $OUTPUT_DIR/thread_dump.txt

echo "Analysis complete. Results in $OUTPUT_DIR/"
```

#### Flight Recorder Workflow

```bash
#!/bin/bash
# Complete flight recorder workflow

JAVA_PID=$1
RECORDING_NAME="performance_analysis"
DURATION="30m"

echo "Starting flight recorder analysis for PID $JAVA_PID"

# Unlock commercial features (if needed)
sh bin/jcmd.sh $JAVA_PID VM.unlock_commercial_features

# Start recording
echo "Starting recording: $RECORDING_NAME"
sh bin/jcmd.sh $JAVA_PID JFR.start name=$RECORDING_NAME duration=$DURATION settings=profile

# Monitor recording status
while true; do
    STATUS=$(sh bin/jcmd.sh $JAVA_PID JFR.check | grep $RECORDING_NAME)
    if echo "$STATUS" | grep -q "running"; then
        echo "Recording in progress: $STATUS"
        sleep 60
    else
        echo "Recording completed"
        break
    fi
done

# Dump recording
OUTPUT_FILE="/tmp/${RECORDING_NAME}_$(date +%Y%m%d_%H%M%S).jfr"
sh bin/jcmd.sh $JAVA_PID JFR.dump name=$RECORDING_NAME filename=$OUTPUT_FILE compress=true

echo "Flight recording saved to: $OUTPUT_FILE"
```

---

## jstack.sh - Thread Dump Tool

### Overview

`jstack.sh` wraps `sun.tools.jstack.JStack` to generate thread dumps showing the call stack of all threads in a Java process.

### Syntax

```bash
sh bin/jstack.sh [options] <java_pid>
```

### Options

| Option | Description | Impact |
|--------|-------------|--------|
| `-l` | Long listing with additional lock information | Larger output |
| `-m` | Mixed mode (Java and native C/C++ frames) | Much larger output |
| `-F` | Force thread dump when process is hung | May work when normal dump fails |

### Basic Usage

#### Standard Thread Dump

```bash
sh bin/jstack.sh 1234 > thread_dump.txt
```

**Output Format**:
```
Full thread dump Java HotSpot(TM) 64-Bit Server VM (25.181-b13 mixed mode):

"Thread-1" #10 prio=5 os_prio=0 tid=0x00007f8b4c001000 nid=0x4d2 waiting on condition [0x00007f8b3c7fe000]
   java.lang.Thread.State: WAITING (parking)
        at sun.misc.Unsafe.park(Native Method)
        - parking to wait for  <0x000000076ab62208> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
        at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
        at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
        ...
```

#### Thread Dump with Lock Information

```bash
sh bin/jstack.sh -l 1234 > detailed_thread_dump.txt
```

**Additional Information**:
- Locked synchronizers
- Lock ownership details
- Waiting thread information

**Example Output Addition**:
```
"Thread-1" #10 prio=5 os_prio=0 tid=0x00007f8b4c001000 nid=0x4d2 waiting on condition [0x00007f8b3c7fe000]
   java.lang.Thread.State: WAITING (parking)
        at sun.misc.Unsafe.park(Native Method)
        - parking to wait for  <0x000000076ab62208> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
        ...

   Locked ownable synchronizers:
        - None
```

#### Mixed Mode Thread Dump

```bash
sh bin/jstack.sh -m 1234 > mixed_thread_dump.txt
```

**Use Cases**:
- JNI debugging
- Native code analysis
- C/C++ library issues

**Additional Output**:
```
"Thread-1" #10 prio=5 os_prio=0 tid=0x00007f8b4c001000 nid=0x4d2 waiting on condition [0x00007f8b3c7fe000]
   java.lang.Thread.State: WAITING (parking)
        at sun.misc.Unsafe.park(Native Method)
        at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
        at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
        ...
        
Native frames: (J=compiled Java code, j=interpreted, Vv=VM code, C=native code)
C  [libzip.so+0x1234]  ZIP_GetEntry+0x12
C  [libjava.so+0x5678]  Java_java_util_zip_ZipFile_getEntry+0x34
j  java.util.zip.ZipFile.getEntry(Ljava/lang/String;Z)Ljava/util/zip/ZipEntry;+0
...
```

#### Force Thread Dump

```bash
sh bin/jstack.sh -F 1234 > forced_thread_dump.txt
```

**Use Cases**:
- Hung JVM processes
- Unresponsive applications
- Emergency diagnostics

**⚠️ Warning**: May be slower and more intrusive than normal thread dumps.

### Thread State Analysis

#### Thread States Reference

| State | Description | Typical Causes |
|-------|-------------|----------------|
| `NEW` | Thread created but not started | Programming logic |
| `RUNNABLE` | Thread executing or ready to execute | Normal execution, CPU-bound tasks |
| `BLOCKED` | Thread blocked waiting for monitor lock | Synchronization contention |
| `WAITING` | Thread waiting indefinitely | `wait()`, `join()`, `park()` calls |
| `TIMED_WAITING` | Thread waiting for specified time | `sleep()`, timed `wait()` |
| `TERMINATED` | Thread completed execution | Normal termination |

#### Identifying Common Issues

##### Deadlock Detection

```bash
# Look for deadlock information in thread dump
grep -A 10 -B 5 "Found Java-level deadlock" thread_dump.txt

# Example deadlock output:
# Found Java-level deadlock:
# =============================
# "Thread-1":
#   waiting to lock monitor 0x00007f8b4c002000 (object 0x000000076ab62208, a java.lang.Object),
#   which is held by "Thread-2"
# "Thread-2":
#   waiting to lock monitor 0x00007f8b4c003000 (object 0x000000076ab62218, a java.lang.Object),
#   which is held by "Thread-1"
```

##### High CPU Thread Identification

```bash
#!/bin/bash
# Correlate high CPU threads with thread dump

JAVA_PID=$1

# Get high CPU threads
echo "High CPU threads:"
top -H -p $JAVA_PID -n 1 | head -20

echo -e "\nThread dump analysis:"
sh bin/jstack.sh $JAVA_PID > thread_dump.txt

# Convert high CPU thread IDs to hex for correlation
echo "Convert thread IDs to hex for correlation:"
top -H -p $JAVA_PID -n 1 | awk 'NR>7 && $9>5.0 {printf "PID %s (0x%x) CPU: %s%%\n", $1, $1, $9}'

echo -e "\nSearch thread dump for high CPU threads:"
echo "Example: grep 'nid=0x4d2' thread_dump.txt"
```

##### Thread Pool Analysis

```bash
#!/bin/bash
# Analyze thread pool usage

analyze_thread_pools() {
    local thread_dump=$1
    
    echo "Thread Pool Analysis"
    echo "==================="
    
    # Count threads by pool type
    echo "Thread counts by pool:"
    grep -E "\".*pool.*\"" $thread_dump | sed 's/^"//' | sed 's/".*//' | sort | uniq -c | sort -nr
    
    echo -e "\nThread states in pools:"
    grep -A 1 -E "\".*pool.*\"" $thread_dump | grep "Thread.State" | sort | uniq -c | sort -nr
    
    echo -e "\nBlocked threads in pools:"
    grep -B 1 -A 5 "State: BLOCKED" $thread_dump | grep -E "(\".*pool.*\"|waiting to lock)"
}

analyze_thread_pools thread_dump.txt
```

### Advanced Usage Examples

#### Continuous Thread Monitoring

```bash
#!/bin/bash
# Continuous thread monitoring with analysis

JAVA_PID=$1
INTERVAL=${2:-30}  # Default 30 seconds
MAX_DUMPS=${3:-10}  # Default 10 dumps

echo "Monitoring Java process $JAVA_PID every $INTERVAL seconds"

for i in $(seq 1 $MAX_DUMPS); do
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    DUMP_FILE="thread_dump_${TIMESTAMP}.txt"
    
    echo "Collecting thread dump $i/$MAX_DUMPS at $(date)"
    sh bin/jstack.sh -l $JAVA_PID > $DUMP_FILE
    
    # Quick analysis
    THREAD_COUNT=$(grep -c "\".*\".*prio=" $DUMP_FILE)
    BLOCKED_COUNT=$(grep -c "State: BLOCKED" $DUMP_FILE)
    WAITING_COUNT=$(grep -c "State: WAITING" $DUMP_FILE)
    
    echo "  Threads: $THREAD_COUNT, Blocked: $BLOCKED_COUNT, Waiting: $WAITING_COUNT"
    
    # Check for deadlocks
    if grep -q "Found Java-level deadlock" $DUMP_FILE; then
        echo "  ⚠️  DEADLOCK DETECTED in $DUMP_FILE"
    fi
    
    [ $i -lt $MAX_DUMPS ] && sleep $INTERVAL
done

echo "Thread monitoring completed. Analyze dump files for trends."
```

#### Thread Dump Comparison

```bash
#!/bin/bash
# Compare thread dumps to identify changes

compare_thread_dumps() {
    local dump1=$1
    local dump2=$2
    
    echo "Comparing thread dumps:"
    echo "  Dump 1: $dump1"
    echo "  Dump 2: $dump2"
    echo
    
    # Extract thread names and states
    extract_thread_info() {
        grep -E "(\".*\".*prio=|Thread.State:)" $1 | \
        paste - - | \
        awk '{print $1 " " $NF}' | \
        sort
    }
    
    extract_thread_info $dump1 > /tmp/threads1.txt
    extract_thread_info $dump2 > /tmp/threads2.txt
    
    echo "New threads in dump 2:"
    comm -13 /tmp/threads1.txt /tmp/threads2.txt
    
    echo -e "\nThreads removed in dump 2:"
    comm -23 /tmp/threads1.txt /tmp/threads2.txt
    
    echo -e "\nThread state changes:"
    diff /tmp/threads1.txt /tmp/threads2.txt | grep -E "^[<>]"
    
    # Cleanup
    rm -f /tmp/threads1.txt /tmp/threads2.txt
}

# Usage
compare_thread_dumps thread_dump_1.txt thread_dump_2.txt
```

---

## jmap.sh - Memory Analysis Tool

### Overview

`jmap.sh` wraps `sun.tools.jmap.JMap` for memory analysis, heap dumps, and object statistics.

### Syntax

```bash
sh bin/jmap.sh [options] <java_pid>
```

### Core Operations

#### Object Histogram

##### Basic Histogram
```bash
sh bin/jmap.sh -histo <java_pid> > object_histogram.txt
```

**Output Format**:
```
 num     #instances         #bytes  class name
----------------------------------------------
   1:         98765       12345678  [C
   2:         87654        9876543  java.lang.String
   3:         65432        7654321  java.util.HashMap$Node
   4:         54321        6543210  [Ljava.lang.Object;
   5:         43210        5432109  java.lang.Integer
...
Total        1234567      123456789
```

**Column Descriptions**:
- `num`: Ranking by total memory usage
- `#instances`: Number of object instances
- `#bytes`: Total memory consumed by all instances
- `class name`: Java class name (see [Class Name Notation](#class-name-notation))

##### Live Objects Histogram
```bash
sh bin/jmap.sh -histo:live <java_pid> > live_objects_histogram.txt
```

**⚠️ Important**: This triggers a Full GC before analysis, causing application pause.

**Use Cases**:
- Accurate memory usage after GC
- Memory leak detection
- Clean memory baseline establishment

#### Heap Dumps

##### Basic Heap Dump
```bash
sh bin/jmap.sh -dump:format=b,file=heap.hprof <java_pid>
```

**Output**: Binary heap dump file in HPROF format

##### Live Heap Dump
```bash
sh bin/jmap.sh -dump:live,format=b,file=live_heap.hprof <java_pid>
```

**⚠️ Important**: Triggers Full GC, larger application pause than histogram.

##### Compressed Heap Dump (JDK 9+)
```bash
sh bin/jmap.sh -dump:live,format=b,gz=1,file=heap.hprof.gz <java_pid>
```

#### Advanced Options

##### Class Loader Statistics
```bash
sh bin/jmap.sh -clstats <java_pid> > classloader_stats.txt
```

**Output Example**:
```
Attaching to process ID 1234, please wait...
Debugger attached successfully.
Server compiler detected.
JVM version is 25.181-b13

class_loader    classes bytes   parent_loader   alive?  type
<bootstrap>     2345    12345678    null        live    <internal>
0x76ab62208     567     5678901     0x76ab62300 live    sun/misc/Launcher$AppClassLoader
0x76ab62300     234     2345678     0x76ab62400 live    sun/misc/Launcher$ExtClassLoader
```

### Class Name Notation

Understanding class name notation in jmap output:

| Notation | Meaning | Example |
|----------|---------|---------|
| `[C` | char array | `char[]` |
| `[B` | byte array | `byte[]` |
| `[I` | int array | `int[]` |
| `[L<classname>;` | Object array | `[Ljava.lang.String;` = `String[]` |
| `[[I` | 2D int array | `int[][]` |
| Regular class name | Regular Java class | `java.lang.String` |

### Memory Analysis Examples

#### Memory Leak Detection

```bash
#!/bin/bash
# Memory leak detection workflow

JAVA_PID=$1
ANALYSIS_DIR="memory_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p $ANALYSIS_DIR

echo "Starting memory leak analysis for PID $JAVA_PID"

# Baseline measurement
echo "Taking baseline measurement..."
sh bin/jmap.sh -histo:live $JAVA_PID > $ANALYSIS_DIR/baseline_histogram.txt

echo "Waiting for application to run (press Enter when ready for comparison)..."
read

# Comparison measurement
echo "Taking comparison measurement..."
sh bin/jmap.sh -histo:live $JAVA_PID > $ANALYSIS_DIR/comparison_histogram.txt

# Analysis
echo "Analyzing memory growth..."
analyze_memory_growth() {
    local baseline=$1
    local comparison=$2
    
    # Extract object counts and sizes
    awk 'NR>3 && NF>=4 {print $4, $2, $3}' $baseline | sort > /tmp/baseline.txt
    awk 'NR>3 && NF>=4 {print $4, $2, $3}' $comparison | sort > /tmp/comparison.txt
    
    # Find classes with significant growth
    join /tmp/baseline.txt /tmp/comparison.txt | \
    awk '{
        class=$1
        base_instances=$2
        base_bytes=$3
        comp_instances=$4
        comp_bytes=$5
        
        if (base_instances > 0) {
            instance_growth = (comp_instances - base_instances) / base_instances * 100
            byte_growth = (comp_bytes - base_bytes) / base_bytes * 100
            
            if (instance_growth > 50 || byte_growth > 50) {
                printf "%-50s %8d->%-8d (%+6.1f%%) %12d->%-12d (%+6.1f%%)\n", 
                       class, base_instances, comp_instances, instance_growth,
                       base_bytes, comp_bytes, byte_growth
            }
        }
    }' | sort -k6 -nr > $ANALYSIS_DIR/memory_growth_analysis.txt
    
    echo "Classes with significant memory growth:"
    head -20 $ANALYSIS_DIR/memory_growth_analysis.txt
    
    # Cleanup
    rm -f /tmp/baseline.txt /tmp/comparison.txt
}

analyze_memory_growth $ANALYSIS_DIR/baseline_histogram.txt $ANALYSIS_DIR/comparison_histogram.txt

echo "Full analysis available in: $ANALYSIS_DIR/"
```

#### Top Memory Consumers Analysis

```bash
#!/bin/bash
# Analyze top memory consuming classes

analyze_top_memory_consumers() {
    local histogram_file=$1
    local top_count=${2:-20}
    
    echo "Top $top_count Memory Consuming Classes"
    echo "======================================"
    
    # Extract and format top consumers
    awk -v count=$top_count '
    NR>3 && NF>=4 && NR<=count+3 {
        # Convert bytes to human readable
        bytes = $3
        if (bytes >= 1024*1024*1024) {
            size = sprintf("%.1f GB", bytes/(1024*1024*1024))
        } else if (bytes >= 1024*1024) {
            size = sprintf("%.1f MB", bytes/(1024*1024))
        } else if (bytes >= 1024) {
            size = sprintf("%.1f KB", bytes/1024)
        } else {
            size = sprintf("%d B", bytes)
        }
        
        printf "%2d. %-40s %8s instances %10s\n", NR-3, $4, $2, size
    }' $histogram_file
    
    echo
    echo "Memory Distribution Analysis:"
    
    # Calculate percentages
    total_bytes=$(awk 'END {print $3}' $histogram_file)
    
    awk -v total=$total_bytes '
    NR>3 && NF>=4 && NR<=13 {  # Top 10
        percentage = ($3 / total) * 100
        printf "%-40s %5.1f%%\n", $4, percentage
    }' $histogram_file
}

# Usage
analyze_top_memory_consumers object_histogram.txt 15
```

#### Heap Dump Analysis Preparation

```bash
#!/bin/bash
# Prepare heap dump for analysis with external tools

prepare_heap_analysis() {
    local java_pid=$1
    local analysis_name=${2:-"heap_analysis"}
    local output_dir="${analysis_name}_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p $output_dir
    
    echo "Preparing comprehensive heap analysis..."
    
    # 1. Pre-dump system information
    echo "Collecting system context..."
    ps -p $java_pid -o pid,ppid,user,pcpu,pmem,etime,cmd > $output_dir/process_info.txt
    free -h > $output_dir/system_memory.txt
    df -h > $output_dir/disk_space.txt
    
    # 2. JVM information
    echo "Collecting JVM information..."
    sh bin/jcmd.sh $java_pid VM.uptime > $output_dir/jvm_uptime.txt
    sh bin/jcmd.sh $java_pid VM.system_properties > $output_dir/jvm_properties.txt
    sh bin/jcmd.sh $java_pid VM.command_line > $output_dir/jvm_commandline.txt
    
    # 3. Pre-dump object histogram
    echo "Creating pre-dump object histogram..."
    sh bin/jmap.sh -histo $java_pid > $output_dir/pre_dump_histogram.txt
    
    # 4. GC statistics
    echo "Collecting GC statistics..."
    sh bin/jstat.sh -gc $java_pid 1000 3 > $output_dir/gc_stats.txt
    
    # 5. Create heap dump
    echo "Creating heap dump (this may take several minutes)..."
    local heap_file="$output_dir/heap_dump.hprof"
    sh bin/jmap.sh -dump:live,format=b,file=$heap_file $java_pid
    
    # 6. Post-dump information
    echo "Collecting post-dump information..."
    sh bin/jmap.sh -histo:live $java_pid > $output_dir/post_dump_histogram.txt
    ls -lh $heap_file > $output_dir/heap_dump_info.txt
    
    # 7. Create analysis script
    cat << 'EOF' > $output_dir/analyze_heap.sh
#!/bin/bash
# Heap dump analysis helper script

HEAP_FILE="heap_dump.hprof"

echo "Heap Dump Analysis Tools:"
echo "========================="
echo "1. Eclipse Memory Analyzer (MAT):"
echo "   Download: https://www.eclipse.org/mat/"
echo "   Open: $HEAP_FILE"
echo
echo "2. JVisualVM:"
echo "   Command: jvisualvm --jdkhome \$JAVA_HOME"
echo "   File -> Load -> $HEAP_FILE"
echo
echo "3. Online Analysis (for small dumps):"
echo "   Upload to: https://gceasy.io/"
echo
echo "4. Command line analysis:"
echo "   jhat -J-Xmx4g $HEAP_FILE"
echo "   Then browse: http://localhost:7000/"
echo
echo "Analysis Focus Areas:"
echo "- Dominator tree (largest object retainers)"
echo "- Leak suspects (objects consuming most memory)"
echo "- Duplicate classes (classloader leaks)"
echo "- Thread analysis (thread-local leaks)"
EOF
    
    chmod +x $output_dir/analyze_heap.sh
    
    echo "Heap analysis preparation completed!"
    echo "Output directory: $output_dir"
    echo "Heap dump size: $(ls -lh $heap_file | awk '{print $5}')"
    echo "Run: $output_dir/analyze_heap.sh for analysis instructions"
}

# Usage
prepare_heap_analysis 1234 "production_memory_issue"
```

---

## jstat.sh - Statistics Tool

### Overview

`jstat.sh` wraps `sun.tools.jstat.Jstat` for real-time monitoring of JVM statistics, particularly garbage collection and memory usage.

### Syntax

```bash
sh bin/jstat.sh [options] <java_pid> [interval] [count]
```

### Parameters

- `options` - Statistics option (required)
- `java_pid` - Target Java process ID (required)  
- `interval` - Update interval in milliseconds (optional)
- `count` - Number of updates (optional, default: continuous)

### Statistics Options

#### Garbage Collection Statistics

##### -gc (Garbage Collection)
Display garbage collection statistics with absolute values.

```bash
sh bin/jstat.sh -gc 1234 1000 5
```

**Output Format**:
```
 S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    YGC     YGCT    FGC    FGCT     GCT   
8192.0 8192.0  0.0   8192.0 65536.0  32768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3
8192.0 8192.0  0.0   8192.0 65536.0  35768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3
```

**Column Descriptions**:
| Column | Description | Unit |
|--------|-------------|------|
| `S0C`, `S1C` | Survivor space 0/1 capacity | KB |
| `S0U`, `S1U` | Survivor space 0/1 utilization | KB |
| `EC`, `EU` | Eden space capacity/utilization | KB |
| `OC`, `OU` | Old generation capacity/utilization | KB |
| `MC`, `MU` | Metaspace capacity/utilization | KB |
| `CCSC`, `CCSU` | Compressed class space capacity/utilization | KB |
| `YGC`, `YGCT` | Young GC count/total time | count/seconds |
| `FGC`, `FGCT` | Full GC count/total time | count/seconds |
| `GCT` | Total GC time | seconds |

##### -gccause (GC with Cause)
Display GC statistics with percentage utilization and GC causes.

```bash
sh bin/jstat.sh -gccause 1234 2000 10
```

**Output Format**:
```
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT    LGCC                 GCC                 
  0.00  50.00  75.50  50.12  68.75  92.45  1250   12.500    45   67.800   80.300 Allocation Failure   No GC               
  0.00  50.00  78.20  50.12  68.75  92.45  1250   12.500    45   67.800   80.300 Allocation Failure   No GC
```

**Additional Columns**:
| Column | Description |
|--------|-------------|
| `S0`, `S1`, `E`, `O` | Space utilization percentages |
| `M`, `CCS` | Metaspace and compressed class space percentages |
| `LGCC` | Last GC cause |
| `GCC` | Current GC cause |

**Common GC Causes**:
- `Allocation Failure` - Normal young generation GC
- `System.gc()` - Explicit GC call
- `CMS Initial Mark` - CMS collector phase
- `G1 Evacuation Pause` - G1 collector GC
- `Metadata GC Threshold` - Metaspace expansion

##### -gcutil (GC Utilization)
Compact view focusing on space utilization percentages.

```bash
sh bin/jstat.sh -gcutil 1234 5000
```

**Use Cases**:
- Quick memory utilization overview
- Continuous monitoring with minimal output
- Scripting and automated analysis

#### Memory Pool Statistics

##### -gccapacity (GC Capacity)
Display memory pool generation and space capacities.

```bash
sh bin/jstat.sh -gccapacity 1234
```

**Output Example**:
```
 NGCMN    NGCMX     NGC     S0C   S1C       EC      OGCMN      OGCMX       OGC         OC       MCMN     MCMX      MC     CCSMN    CCSMX     CCSC    YGC    FGC 
 87040.0 1398080.0  87040.0 8704.0 8704.0  69632.0   175104.0  2796160.0   175104.0   175104.0      0.0 1056768.0  65536.0      0.0 1048576.0   8192.0   1250    45
```

**Column Descriptions**:
| Column | Description |
|--------|-------------|
| `NGCMN`, `NGCMX`, `NGC` | New generation min/max/current capacity |
| `OGCMN`, `OGCMX`, `OGC` | Old generation min/max/current capacity |
| `MCMN`, `MCMX`, `MC` | Metaspace min/max/current capacity |

##### -gcnew (New Generation)
Detailed new generation statistics.

```bash
sh bin/jstat.sh -gcnew 1234 1000 5
```

##### -gcold (Old Generation)  
Detailed old generation statistics.

```bash
sh bin/jstat.sh -gcold 1234 1000 5
```

#### Class Loading Statistics

##### -class (Class Loader)
Display class loading and unloading statistics.

```bash
sh bin/jstat.sh -class 1234 2000
```

**Output Example**:
```
Loaded  Bytes  Unloaded  Bytes     Time   
 12345  23456.7      123    234.5    15.67
```

### Practical Monitoring Examples

#### GC Performance Analysis

```bash
#!/bin/bash
# Comprehensive GC performance analysis

analyze_gc_performance() {
    local java_pid=$1
    local duration_minutes=${2:-10}
    local interval_seconds=${3:-5}
    
    local samples=$((duration_minutes * 60 / interval_seconds))
    local interval_ms=$((interval_seconds * 1000))
    
    echo "Analyzing GC performance for PID $java_pid"
    echo "Duration: $duration_minutes minutes, Interval: $interval_seconds seconds"
    echo
    
    # Collect GC statistics
    local gc_file="gc_analysis_$(date +%Y%m%d_%H%M%S).txt"
    sh bin/jstat.sh -gccause $java_pid $interval_ms $samples > $gc_file
    
    echo "GC Analysis Results:"
    echo "==================="
    
    # Parse and analyze results
    awk '
    BEGIN {
        print "GC Performance Summary:"
        print "-----------------------"
    }
    NR==1 { 
        # Header line
        next 
    }
    NR==2 {
        # First data line - baseline
        initial_ygc = $7
        initial_ygct = $8
        initial_fgc = $9
        initial_fgct = $10
        initial_gct = $11
        next
    }
    END {
        # Last data line - final values
        final_ygc = $7
        final_ygct = $8
        final_fgc = $9
        final_fgct = $10
        final_gct = $11
        
        young_gcs = final_ygc - initial_ygc
        young_gc_time = final_ygct - initial_ygct
        full_gcs = final_fgc - initial_fgc
        full_gc_time = final_fgct - initial_fgct
        total_gc_time = final_gct - initial_gct
        
        if (young_gcs > 0) {
            avg_young_gc = young_gc_time / young_gcs * 1000
        } else {
            avg_young_gc = 0
        }
        
        if (full_gcs > 0) {
            avg_full_gc = full_gc_time / full_gcs * 1000
        } else {
            avg_full_gc = 0
        }
        
        printf "Young GCs: %d (%.1f ms average)\n", young_gcs, avg_young_gc
        printf "Full GCs: %d (%.1f ms average)\n", full_gcs, avg_full_gc
        printf "Total GC time: %.2f seconds\n", total_gc_time
        printf "GC overhead: %.2f%%\n", (total_gc_time / ('$duration_minutes' * 60)) * 100
        
        # Memory utilization analysis
        printf "\nMemory Utilization:\n"
        printf "Eden: %.1f%%, Old: %.1f%%, Metaspace: %.1f%%\n", $3, $4, $5
        
        # GC frequency analysis
        if (young_gcs > 0) {
            young_freq = ('$duration_minutes' * 60) / young_gcs
            printf "Young GC frequency: every %.1f seconds\n", young_freq
        }
        
        if (full_gcs > 0) {
            full_freq = ('$duration_minutes' * 60) / full_gcs
            printf "Full GC frequency: every %.1f seconds\n", full_freq
        }
        
        # Performance assessment
        printf "\nPerformance Assessment:\n"
        if (avg_young_gc > 100) {
            print "⚠️  Young GC pause times are high (>100ms)"
        } else {
            print "✅ Young GC pause times are acceptable"
        }
        
        if (full_gcs > 0 && avg_full_gc > 1000) {
            print "⚠️  Full GC pause times are high (>1s)"
        } else if (full_gcs == 0) {
            print "✅ No Full GCs occurred"
        } else {
            print "✅ Full GC pause times are acceptable"
        }
        
        if (total_gc_time / ('$duration_minutes' * 60) > 0.05) {
            print "⚠️  High GC overhead (>5%)"
        } else {
            print "✅ GC overhead is acceptable"
        }
    }' $gc_file
    
    echo
    echo "Detailed data saved to: $gc_file"
}

# Usage
analyze_gc_performance 1234 5 2  # 5 minutes, 2-second intervals
```

#### Memory Trend Monitoring

```bash
#!/bin/bash
# Monitor memory trends over time

monitor_memory_trends() {
    local java_pid=$1
    local duration_hours=${2:-1}
    local interval_minutes=${3:-1}
    
    local samples=$((duration_hours * 60 / interval_minutes))
    local interval_ms=$((interval_minutes * 60 * 1000))
    
    echo "Monitoring memory trends for $duration_hours hours"
    echo "Interval: $interval_minutes minutes"
    echo
    
    # Create output file with timestamp
    local trend_file="memory_trends_$(date +%Y%m%d_%H%M%S).csv"
    
    # CSV header
    echo "timestamp,eden_used_pct,old_used_pct,metaspace_used_pct,young_gcs,full_gcs,gc_time_total" > $trend_file
    
    # Collect data
    sh bin/jstat.sh -gccause $java_pid $interval_ms $samples | \
    awk '
    NR==1 { next }  # Skip header
    {
        timestamp = strftime("%Y-%m-%d %H:%M:%S")
        printf "%s,%.1f,%.1f,%.1f,%d,%d,%.2f\n", 
               timestamp, $3, $4, $5, $7, $9, $11
    }' >> $trend_file
    
    echo "Memory trend data collected in: $trend_file"
    echo
    echo "To analyze trends:"
    echo "1. Import CSV into spreadsheet application"
    echo "2. Create time-series charts for memory usage"
    echo "3. Look for memory leak patterns (steadily increasing old generation)"
    echo "4. Analyze GC frequency trends"
}

# Usage
monitor_memory_trends 1234 2 1  # 2 hours, 1-minute intervals
```

#### Real-time GC Monitoring Dashboard

```bash
#!/bin/bash
# Real-time GC monitoring dashboard

gc_dashboard() {
    local java_pid=$1
    local refresh_seconds=${2:-5}
    
    # Clear screen and hide cursor
    clear
    tput civis
    
    # Trap Ctrl+C to restore cursor
    trap 'tput cnorm; exit' INT
    
    while true; do
        # Move cursor to top
        tput cup 0 0
        
        echo "=== Java GC Monitoring Dashboard ==="
        echo "Process ID: $java_pid"
        echo "Refresh: ${refresh_seconds}s (Press Ctrl+C to exit)"
        echo "Last Update: $(date)"
        echo
        
        # Get current GC stats
        local gc_stats=$(sh bin/jstat.sh -gccause $java_pid 1000 1 | tail -1)
        
        if [ -n "$gc_stats" ]; then
            echo $gc_stats | awk '{
                printf "Memory Utilization:\n"
                printf "  Eden Space:     %6.1f%%\n", $3
                printf "  Survivor 0:     %6.1f%%\n", $1  
                printf "  Survivor 1:     %6.1f%%\n", $2
                printf "  Old Generation: %6.1f%%\n", $4
                printf "  Metaspace:      %6.1f%%\n", $5
                printf "  Compressed CS:  %6.1f%%\n", $6
                printf "\n"
                printf "Garbage Collection:\n"
                printf "  Young GCs:      %8d (%.2f sec total)\n", $7, $8
                printf "  Full GCs:       %8d (%.2f sec total)\n", $9, $10
                printf "  Total GC Time:  %8.2f seconds\n", $11
                printf "\n"
                printf "GC Causes:\n"
                printf "  Last GC:        %s\n", ($12 == "No" && $13 == "GC") ? "None" : $12 " " $13
                printf "  Current:        %s\n", ($14 == "No" && $15 == "GC") ? "None" : $14 " " $15
                printf "\n"
                
                # Calculate GC overhead (approximate)
                # This is a rough calculation based on total GC time
                if ($11 > 0) {
                    printf "Estimated GC Overhead: %.2f%%\n", ($11 / (systime() - start_time)) * 100
                }
            }
            BEGIN { start_time = systime() }'
            
            # Memory usage visualization
            echo "Memory Usage Visualization:"
            local eden_pct=$(echo $gc_stats | awk '{print int($3)}')
            local old_pct=$(echo $gc_stats | awk '{print int($4)}')
            
            printf "Eden:  ["
            for i in $(seq 1 50); do
                if [ $i -le $((eden_pct / 2)) ]; then
                    printf "█"
                else
                    printf " "
                fi
            done
            printf "] %d%%\n" $eden_pct
            
            printf "Old:   ["
            for i in $(seq 1 50); do
                if [ $i -le $((old_pct / 2)) ]; then
                    printf "█"
                else
                    printf " "
                fi
            done
            printf "] %d%%\n" $old_pct
            
        else
            echo "Unable to retrieve GC statistics"
        fi
        
        # Clear rest of screen
        tput ed
        
        sleep $refresh_seconds
    done
}

# Usage
gc_dashboard 1234 3  # Monitor PID 1234, refresh every 3 seconds
```

---

## jps.sh - Process Status Tool

### Overview

`jps.sh` wraps `sun.tools.jps.Jps` to list running Java processes with various levels of detail.

### Syntax

```bash
sh bin/jps.sh [options]
```

### Options

| Option | Description | Output Detail |
|--------|-------------|---------------|
| (none) | Basic listing | PID and main class name |
| `-l` | Long listing | PID and full class name/JAR path |
| `-v` | JVM arguments | PID, class name, and JVM flags |
| `-m` | Main arguments | PID, class name, and application arguments |
| `-V` | JVM flags file | PID, class name, and flags from file |

### Usage Examples

#### Basic Process Listing

```bash
sh bin/jps.sh
```

**Output Example**:
```
1234 MyApplication
5678 Bootstrap
9012 Jps
```

#### Long Listing with Full Class Names

```bash
sh bin/jps.sh -l
```

**Output Example**:
```
1234 com.example.MyApplication
5678 org.apache.catalina.startup.Bootstrap
9012 sun.tools.jps.Jps
```

#### JVM Arguments Display

```bash
sh bin/jps.sh -v
```

**Output Example**:
```
1234 MyApplication -Xmx2g -Xms1g -XX:+UseG1GC -Dfile.encoding=UTF-8
5678 Bootstrap -Xmx1g -XX:+UseConcMarkSweepGC -Djava.awt.headless=true
9012 Jps -Dapplication.home=/usr/lib/jvm/java-8-openjdk -Xms8m
```

#### Application Arguments Display

```bash
sh bin/jps.sh -m
```

**Output Example**:
```
1234 MyApplication --config=/opt/app/config.properties --port=8080 --env=production
5678 Bootstrap start
9012 Jps -m
```

### Advanced Usage Examples

#### Process Discovery and Analysis

```bash
#!/bin/bash
# Comprehensive Java process discovery

discover_java_processes() {
    echo "Java Process Discovery Report"
    echo "============================="
    echo "Generated: $(date)"
    echo
    
    # Basic process list
    echo "Running Java Processes:"
    echo "-----------------------"
    sh bin/jps.sh -l | while read pid class; do
        if [ "$pid" != "" ] && [ "$class" != "" ]; then
            # Get additional process information
            local user=$(ps -p $pid -o user --no-headers 2>/dev/null)
            local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null)
            local mem=$(ps -p $pid -o %mem --no-headers 2>/dev/null)
            local etime=$(ps -p $pid -o etime --no-headers 2>/dev/null)
            
            printf "PID: %5s | User: %10s | CPU: %5s%% | Mem: %5s%% | Runtime: %10s\n" \
                   "$pid" "$user" "$cpu" "$mem" "$etime"
            printf "Class: %s\n" "$class"
            echo
        fi
    done
    
    echo "JVM Configuration Summary:"
    echo "--------------------------"
    sh bin/jps.sh -v | while read pid class jvm_args; do
        if [ "$pid" != "" ]; then
            echo "PID $pid ($class):"
            
            # Parse JVM arguments
            echo "$jvm_args" | tr ' ' '\n' | while read arg; do
                case "$arg" in
                    -Xmx*) echo "  Max Heap: ${arg#-Xmx}" ;;
                    -Xms*) echo "  Initial Heap: ${arg#-Xms}" ;;
                    -XX:+Use*GC) echo "  GC Algorithm: ${arg#-XX:+Use}" ;;
                    -Dfile.encoding=*) echo "  Encoding: ${arg#-Dfile.encoding=}" ;;
                    -Djava.awt.headless=*) echo "  Headless: ${arg#-Djava.awt.headless=}" ;;
                esac
            done
            echo
        fi
    done
}

discover_java_processes > java_process_report.txt
echo "Report saved to: java_process_report.txt"
```

#### Process Monitoring Script

```bash
#!/bin/bash
# Monitor Java processes for changes

monitor_java_processes() {
    local check_interval=${1:-30}
    local log_file="java_process_monitor.log"
    
    echo "Starting Java process monitoring (interval: ${check_interval}s)"
    echo "Log file: $log_file"
    
    # Initial process snapshot
    sh bin/jps.sh -l > /tmp/java_processes_current.txt
    
    while true; do
        sleep $check_interval
        
        # Take new snapshot
        sh bin/jps.sh -l > /tmp/java_processes_new.txt
        
        # Compare with previous
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        
        # Find new processes
        local new_processes=$(comm -13 /tmp/java_processes_current.txt /tmp/java_processes_new.txt)
        if [ -n "$new_processes" ]; then
            echo "[$timestamp] NEW PROCESSES:" >> $log_file
            echo "$new_processes" >> $log_file
        fi
        
        # Find terminated processes  
        local terminated_processes=$(comm -23 /tmp/java_processes_current.txt /tmp/java_processes_new.txt)
        if [ -n "$terminated_processes" ]; then
            echo "[$timestamp] TERMINATED PROCESSES:" >> $log_file
            echo "$terminated_processes" >> $log_file
        fi
        
        # Update current snapshot
        mv /tmp/java_processes_new.txt /tmp/java_processes_current.txt
        
        # Display current status
        local process_count=$(wc -l < /tmp/java_processes_current.txt)
        echo "[$timestamp] Monitoring $process_count Java processes"
    done
}

# Usage
monitor_java_processes 60  # Check every 60 seconds
```

#### Process Selection Helper

```bash
#!/bin/bash
# Interactive Java process selection

select_java_process() {
    local purpose=${1:-"analysis"}
    
    echo "Select Java Process for $purpose"
    echo "================================"
    
    # Get process list
    local processes=$(sh bin/jps.sh -l)
    
    if [ -z "$processes" ]; then
        echo "No Java processes found."
        return 1
    fi
    
    # Display numbered list
    echo "$processes" | nl -w3 -s': '
    echo
    
    # Get user selection
    local max_num=$(echo "$processes" | wc -l)
    while true; do
        read -p "Select process (1-$max_num): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$max_num" ]; then
            local selected_line=$(echo "$processes" | sed -n "${selection}p")
            local selected_pid=$(echo "$selected_line" | awk '{print $1}')
            local selected_class=$(echo "$selected_line" | awk '{print $2}')
            
            echo
            echo "Selected Process:"
            echo "  PID: $selected_pid"
            echo "  Class: $selected_class"
            
            # Confirm selection
            read -p "Proceed with this selection? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                echo $selected_pid
                return 0
            fi
        else
            echo "Invalid selection. Please enter a number between 1 and $max_num."
        fi
    done
}

# Usage examples
SELECTED_PID=$(select_java_process "heap dump")
if [ $? -eq 0 ]; then
    echo "Creating heap dump for PID: $SELECTED_PID"
    sh bin/jmap.sh -dump:format=b,file=heap_$SELECTED_PID.hprof $SELECTED_PID
fi
```

---

## Common Usage Patterns

### Multi-Tool Analysis Workflows

#### Complete Diagnostic Workflow

```bash
#!/bin/bash
# Complete diagnostic analysis using multiple tools

comprehensive_analysis() {
    local java_pid=$1
    local analysis_name=${2:-"diagnostic"}
    local output_dir="${analysis_name}_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p $output_dir
    echo "Starting comprehensive analysis of PID $java_pid"
    echo "Output directory: $output_dir"
    
    # 1. Process identification and basic info
    echo "Step 1: Process identification..."
    sh bin/jps.sh -l | grep "^$java_pid " > $output_dir/process_info.txt
    sh bin/jcmd.sh $java_pid VM.uptime > $output_dir/vm_uptime.txt
    sh bin/jcmd.sh $java_pid VM.version > $output_dir/vm_version.txt
    sh bin/jcmd.sh $java_pid VM.command_line > $output_dir/vm_commandline.txt
    
    # 2. Memory analysis
    echo "Step 2: Memory analysis..."
    sh bin/jstat.sh -gc $java_pid 1000 5 > $output_dir/gc_stats.txt
    sh bin/jmap.sh -histo $java_pid > $output_dir/object_histogram.txt
    
    # 3. Thread analysis
    echo "Step 3: Thread analysis..."
    sh bin/jstack.sh -l $java_pid > $output_dir/thread_dump.txt
    
    # 4. System context
    echo "Step 4: System context..."
    ps -p $java_pid -o pid,ppid,user,pcpu,pmem,etime,cmd > $output_dir/process_details.txt
    top -p $java_pid -n 1 > $output_dir/resource_usage.txt
    
    # 5. Analysis summary
    echo "Step 5: Generating analysis summary..."
    cat << EOF > $output_dir/analysis_summary.txt
Comprehensive Java Process Analysis
===================================
Process ID: $java_pid
Analysis Date: $(date)
Output Directory: $output_dir

Files Generated:
- process_info.txt: Basic process identification
- vm_uptime.txt: JVM uptime information  
- vm_version.txt: JVM version details
- vm_commandline.txt: JVM startup parameters
- gc_stats.txt: Garbage collection statistics
- object_histogram.txt: Memory usage by object type
- thread_dump.txt: Thread stack traces
- process_details.txt: System process information
- resource_usage.txt: Current resource usage

Analysis Instructions:
1. Review vm_commandline.txt for configuration issues
2. Check gc_stats.txt for memory pressure signs
3. Analyze object_histogram.txt for memory leaks
4. Examine thread_dump.txt for deadlocks or blocking
5. Monitor resource_usage.txt for system impact

Recommended Tools:
- Eclipse MAT for heap dump analysis
- GCEasy.io for GC log analysis
- IBM TMDA for thread dump analysis
EOF
    
    echo "Comprehensive analysis completed!"
    echo "Review: $output_dir/analysis_summary.txt"
}

# Usage
comprehensive_analysis 1234 "production_issue"
```

#### Performance Baseline Collection

```bash
#!/bin/bash
# Collect performance baseline using multiple tools

collect_performance_baseline() {
    local java_pid=$1
    local duration_minutes=${2:-10}
    local baseline_name=${3:-"baseline"}
    
    local output_dir="${baseline_name}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $output_dir
    
    echo "Collecting performance baseline for $duration_minutes minutes"
    echo "Process: $java_pid, Output: $output_dir"
    
    # Start continuous monitoring
    local interval_seconds=30
    local samples=$((duration_minutes * 60 / interval_seconds))
    
    # GC monitoring
    echo "Starting GC monitoring..."
    sh bin/jstat.sh -gccause $java_pid $((interval_seconds * 1000)) $samples > $output_dir/gc_baseline.txt &
    local gc_monitor_pid=$!
    
    # Collect snapshots at intervals
    local snapshot_interval=$((duration_minutes * 60 / 5))  # 5 snapshots
    
    for snapshot in $(seq 1 5); do
        echo "Collecting snapshot $snapshot/5..."
        local snapshot_dir="$output_dir/snapshot_$snapshot"
        mkdir -p $snapshot_dir
        
        # Thread dump
        sh bin/jstack.sh -l $java_pid > $snapshot_dir/thread_dump.txt
        
        # Object histogram
        sh bin/jmap.sh -histo $java_pid > $snapshot_dir/object_histogram.txt
        
        # JVM information
        sh bin/jcmd.sh $java_pid VM.system_properties > $snapshot_dir/vm_properties.txt
        
        # System resources
        top -p $java_pid -n 1 > $snapshot_dir/resource_usage.txt
        
        [ $snapshot -lt 5 ] && sleep $snapshot_interval
    done
    
    # Wait for GC monitoring to complete
    wait $gc_monitor_pid
    
    # Generate baseline report
    cat << EOF > $output_dir/baseline_report.txt
Performance Baseline Report
===========================
Process ID: $java_pid
Collection Duration: $duration_minutes minutes
Collection Date: $(date)

Baseline Components:
- gc_baseline.txt: Continuous GC statistics
- snapshot_N/: Point-in-time snapshots (5 total)
  - thread_dump.txt: Thread state at snapshot time
  - object_histogram.txt: Memory usage snapshot
  - vm_properties.txt: JVM configuration
  - resource_usage.txt: System resource usage

Usage Instructions:
1. Use gc_baseline.txt to establish normal GC patterns
2. Compare future thread dumps with snapshot thread dumps
3. Monitor object histogram changes for memory leak detection
4. Use as comparison baseline for performance regression analysis

Baseline Established: $(date)
EOF
    
    echo "Performance baseline collection completed!"
    echo "Baseline report: $output_dir/baseline_report.txt"
}

# Usage
collect_performance_baseline 1234 15 "app_v2_baseline"
```

### Automated Problem Detection

#### Memory Leak Detection

```bash
#!/bin/bash
# Automated memory leak detection

detect_memory_leak() {
    local java_pid=$1
    local monitoring_hours=${2:-2}
    local check_interval_minutes=${3:-15}
    
    echo "Starting memory leak detection for PID $java_pid"
    echo "Duration: $monitoring_hours hours, Check interval: $check_interval_minutes minutes"
    
    local output_dir="memory_leak_detection_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $output_dir
    
    local checks=$((monitoring_hours * 60 / check_interval_minutes))
    local interval_seconds=$((check_interval_minutes * 60))
    
    # Collect baseline
    echo "Collecting baseline measurement..."
    sh bin/jmap.sh -histo:live $java_pid > $output_dir/baseline_histogram.txt
    sh bin/jstat.sh -gc $java_pid 1000 1 > $output_dir/baseline_gc.txt
    
    # Monitor over time
    for check in $(seq 1 $checks); do
        echo "Check $check/$checks at $(date)"
        
        local check_file="$output_dir/check_${check}_histogram.txt"
        local gc_file="$output_dir/check_${check}_gc.txt"
        
        sh bin/jmap.sh -histo:live $java_pid > $check_file
        sh bin/jstat.sh -gc $java_pid 1000 1 > $gc_file
        
        # Quick analysis
        local old_gen_usage=$(tail -1 $gc_file | awk '{print $8}')
        local old_gen_capacity=$(tail -1 $gc_file | awk '{print $7}')
        local old_gen_pct=$(echo "scale=1; $old_gen_usage * 100 / $old_gen_capacity" | bc)
        
        echo "  Old generation usage: $old_gen_pct%"
        
        # Alert if old generation usage is consistently high
        if (( $(echo "$old_gen_pct > 85" | bc -l) )); then
            echo "  ⚠️  High old generation usage detected!"
        fi
        
        [ $check -lt $checks ] && sleep $interval_seconds
    done
    
    # Generate leak analysis report
    echo "Generating memory leak analysis..."
    
    cat << 'EOF' > $output_dir/analyze_leak.sh
#!/bin/bash
# Memory leak analysis script

echo "Memory Leak Analysis Report"
echo "==========================="

# Analyze old generation growth
echo "Old Generation Usage Trend:"
echo "---------------------------"
for gc_file in check_*_gc.txt; do
    if [ -f "$gc_file" ]; then
        timestamp=$(echo $gc_file | sed 's/check_\([0-9]*\)_gc.txt/\1/')
        old_usage=$(tail -1 $gc_file | awk '{print $8}')
        old_capacity=$(tail -1 $gc_file | awk '{print $7}')
        old_pct=$(echo "scale=1; $old_usage * 100 / $old_capacity" | bc)
        printf "Check %2s: %s KB (%s%%)\n" $timestamp $old_usage $old_pct
    fi
done

echo
echo "Object Growth Analysis:"
echo "----------------------"

# Compare first and last histogram
if [ -f "baseline_histogram.txt" ] && [ -f "check_${checks}_histogram.txt" ]; then
    echo "Top growing object types:"
    
    # Extract object data and compare
    awk 'NR>3 && NF>=4 {print $4, $2, $3}' baseline_histogram.txt | sort > /tmp/baseline.txt
    awk 'NR>3 && NF>=4 {print $4, $2, $3}' check_${checks}_histogram.txt | sort > /tmp/final.txt
    
    join /tmp/baseline.txt /tmp/final.txt | \
    awk '{
        class=$1
        base_instances=$2
        base_bytes=$3
        final_instances=$4
        final_bytes=$5
        
        if (base_instances > 0) {
            instance_growth = (final_instances - base_instances) / base_instances * 100
            byte_growth = (final_bytes - base_bytes) / base_bytes * 100
            
            if (byte_growth > 25) {
                printf "%-40s: %+6.1f%% instances, %+6.1f%% memory\n", 
                       class, instance_growth, byte_growth
            }
        }
    }' | sort -k3 -nr | head -10
    
    rm -f /tmp/baseline.txt /tmp/final.txt
fi

echo
echo "Recommendations:"
echo "---------------"
echo "1. Review objects with >25% memory growth"
echo "2. Check for caching issues or collection leaks"
echo "3. Analyze thread dumps for potential retention causes"
echo "4. Consider heap dump analysis with Eclipse MAT"
EOF
    
    chmod +x $output_dir/analyze_leak.sh
    
    # Run analysis
    cd $output_dir
    ./analyze_leak.sh > leak_analysis_report.txt
    cd - > /dev/null
    
    echo "Memory leak detection completed!"
    echo "Results: $output_dir/leak_analysis_report.txt"
    echo "Run: $output_dir/analyze_leak.sh for detailed analysis"
}

# Usage
detect_memory_leak 1234 3 10  # 3 hours, 10-minute intervals
```

---

This comprehensive guide provides detailed documentation for all bin utility scripts, including practical examples, advanced usage patterns, and automated analysis workflows. The utilities work together to provide complete Java application diagnostics and monitoring capabilities.