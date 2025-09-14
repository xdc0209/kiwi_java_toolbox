# Kiwi Java Toolbox - API Documentation

## Overview

The Kiwi Java Toolbox is a comprehensive collection of scripts and utilities designed for Java application troubleshooting, performance monitoring, and problem diagnosis. This toolbox provides automated solutions for common Java issues including memory leaks, high CPU usage, and performance bottlenecks.

## Core Components

### Main Scripts

#### 1. java_info_collect.sh - Information Collection Tool

**Purpose**: One-click collection of comprehensive Java process diagnostic information.

**Usage**:
```bash
sh /path/to/java_info_collect.sh
```

**Interactive Mode**: The script will prompt you to select a Java process from the running processes list.

**Features**:
- Automatic Java process detection
- Thread stack dumps (multiple snapshots)
- Heap dumps and memory analysis
- GC information and statistics
- JVM system properties and command line parameters
- Operating system information collection
- Automatic compression of collected data

**Output**: Creates a timestamped directory with all diagnostic files, compressed into two ZIP archives:
- `*_full.zip` - Complete diagnostic package including heap dump
- `*_without_heapdump.zip` - Lightweight package without heap dump

**Key Functions**:

##### `init_env()`
Initializes the execution environment and creates output directories.
- **Parameters**: None
- **Returns**: Sets global variables `output_dir` and `log`
- **Side Effects**: Creates timestamped output directory with proper permissions

##### `input_java_pid()`
Interactive function to select target Java process.
- **Parameters**: None
- **Returns**: Sets global variable `java_pid`
- **Output**: Displays running Java processes and prompts for selection

##### `java_info_collect($java_pid)`
Main collection function that gathers all diagnostic information.
- **Parameters**: 
  - `java_pid` - Target Java process ID
- **Collections**:
  - Java version information
  - VM uptime and system properties
  - GC statistics (size and percentage views)
  - Thread dumps (3 snapshots with 2-second intervals)
  - Memory maps and object histograms
  - Heap dumps

##### `os_info_collect()`
Collects operating system diagnostic information.
- **Collections**:
  - System date and network configuration
  - Process lists and network connections
  - System resource usage (top, df)

**Example Output Structure**:
```
/tmp/java_info_collect_hostname_ip_timestamp/
├── java_info_collect.log
├── cpu_jstack-1.txt
├── cpu_jstack-2.txt  
├── cpu_jstack-3.txt
├── cpu_pstack-1.txt
├── cpu_top-1.txt
├── mem_pmap.txt
├── mem_objects_histogram.txt
├── mem_objects_histogram_live.txt
├── mem_heap_dump.hprof
├── os_date.txt
├── os_ifconfig.txt
├── os_netstat.txt
├── os_ps.txt
├── os_top.txt
└── os_df.txt
```

---

#### 2. java_cpu_monitor.sh - CPU Monitoring Tool

**Purpose**: Continuous monitoring of Java process CPU usage with automatic diagnostic collection when thresholds are exceeded.

**Usage**:
```bash
sh /path/to/java_cpu_monitor.sh
```

**Configuration**: Uses `java_cpu_monitor.conf` for threshold and timing parameters.

**Features**:
- Continuous CPU usage monitoring
- Configurable thresholds and collection triggers
- Automatic thread dump collection during high CPU periods
- Smart filtering to avoid false positives

**Configuration Parameters** (in `java_cpu_monitor.conf`):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `check_cpu_times` | 10000 | Maximum number of monitoring cycles |
| `check_cpu_interval` | 2s | Interval between CPU checks |
| `cpu_threshold_usage` | 20 | CPU usage percentage threshold |
| `cpu_threshold_times` | 5 | Consecutive high CPU occurrences required |
| `stack_times` | 3 | Number of thread dumps to collect |
| `stack_interval` | 2s | Interval between thread dumps |

**Key Functions**:

##### `java_cpu_monitor($java_pid)`
Main monitoring loop that checks CPU usage and triggers collection.
- **Parameters**: 
  - `java_pid` - Target Java process ID
- **Logic**:
  1. Monitors CPU usage at configured intervals
  2. Tracks consecutive high CPU occurrences
  3. Triggers diagnostic collection when thresholds met
  4. Resets counters after collection

**Monitoring Algorithm**:
```
for each monitoring cycle:
    current_cpu = get_cpu_usage(java_pid)
    if current_cpu >= threshold:
        consecutive_count++
        if consecutive_count >= threshold_times:
            collect_diagnostics()
            reset_consecutive_count()
    else:
        reset_consecutive_count()
```

**Example Usage Scenario**:
```bash
# Monitor Java process with PID 1234
# CPU threshold: 80%, trigger after 3 consecutive high readings
echo "cpu_threshold_usage=80" > java_cpu_monitor.conf
echo "cpu_threshold_times=3" >> java_cpu_monitor.conf
sh java_cpu_monitor.sh
# Enter PID: 1234
```

---

#### 3. java_flight_recorder.sh - Flight Recorder Management

**Purpose**: Management interface for Java Flight Recorder (JFR) operations.

**Usage**:
```bash
sh /path/to/java_flight_recorder.sh <operation> <java_pid>
```

**Operations**:
- `start` - Start flight recording
- `check` - Check recording status  
- `dump` - Export recording data
- `stop` - Stop recording

**Features**:
- Automatic commercial features unlocking
- Configurable recording parameters
- Compressed output generation
- Status validation and error handling

**Key Functions**:

##### `java_flight_recorder($java_pid, $operation)`
Main function handling all JFR operations.
- **Parameters**:
  - `java_pid` - Target Java process ID
  - `operation` - JFR operation (start|check|dump|stop)

**Operation Details**:

##### Start Recording
```bash
sh java_flight_recorder.sh start 1234
```
- Unlocks commercial features
- Checks for existing recordings
- Starts new recording with profile settings
- **Settings**: `maxsize=100m maxage=24h settings=profile`

##### Check Status
```bash
sh java_flight_recorder.sh check 1234
```
- Displays all active recordings
- Shows recording parameters and duration

##### Dump Recording
```bash
sh java_flight_recorder.sh dump 1234
```
- Validates recording exists
- Exports compressed JFR file
- **Output**: `/tmp/java_flight_recorder_hostname_ip_timestamp.jfr`

##### Stop Recording
```bash
sh java_flight_recorder.sh stop 1234
```
- Validates recording exists
- Stops active recording
- Preserves collected data

**JFR Requirements**:
- Available in JDK 7u4 and later
- Prior to JDK 8u40: Requires `-XX:+UnlockCommercialFeatures -XX:FlightRecorder`
- JDK 8u40+: Can be enabled at runtime

---

### Utility Scripts (bin/ directory)

#### JDK Tool Wrappers

All utility scripts in the `bin/` directory follow a common pattern for wrapping JDK tools with enhanced error handling and compatibility.

##### Common Functions

###### `get_target_java_pid($args)`
Extracts Java PID from command line arguments.
- **Parameters**: Command line arguments array
- **Returns**: First numeric argument (Java PID)
- **Logic**: Searches for first argument matching `^[0-9]+$`

###### `check_target_java_pid($target_java_pid)`
Validates Java process ID and user permissions.
- **Parameters**: 
  - `target_java_pid` - Process ID to validate
- **Validations**:
  - PID exists and is Java process
  - Current user matches Java process user
- **Error Handling**: Exits with descriptive error messages

###### `set_java_env_var($target_java_pid)`
Configures Java environment for tool execution.
- **Parameters**:
  - `target_java_pid` - Target process ID
- **Logic**:
  1. Determines Java executable path
  2. Checks for JDK vs JRE installation
  3. Sets appropriate classpath and library path
  4. Uses embedded JDK libraries if needed

**Environment Configuration Logic**:
```bash
if JDK_installation:
    use_jdk_tools_jar()
else:
    use_embedded_jdk_libraries()
    validate_version_compatibility()
```

---

#### 1. jcmd.sh - Java Command Tool Wrapper

**Purpose**: Wrapper for `sun.tools.jcmd.JCmd` with enhanced compatibility.

**Usage**:
```bash
sh bin/jcmd.sh <java_pid> <command> [options]
```

**Common Commands**:
```bash
# VM information
sh bin/jcmd.sh 1234 VM.uptime
sh bin/jcmd.sh 1234 VM.system_properties
sh bin/jcmd.sh 1234 VM.command_line

# Flight Recorder
sh bin/jcmd.sh 1234 JFR.start name=myrecording
sh bin/jcmd.sh 1234 JFR.check
sh bin/jcmd.sh 1234 JFR.dump name=myrecording filename=output.jfr

# GC operations
sh bin/jcmd.sh 1234 GC.run
sh bin/jcmd.sh 1234 GC.class_histogram
```

---

#### 2. jstack.sh - Thread Dump Tool Wrapper

**Purpose**: Wrapper for `sun.tools.jstack.JStack` with enhanced output formatting.

**Usage**:
```bash
sh bin/jstack.sh [options] <java_pid>
```

**Options**:
- `-l` - Long listing (locks information)
- `-m` - Mixed mode (Java and native frames)
- `-F` - Force thread dump (when process is hung)

**Example**:
```bash
# Standard thread dump
sh bin/jstack.sh 1234

# Thread dump with lock information
sh bin/jstack.sh -l 1234

# Force thread dump for hung process
sh bin/jstack.sh -F 1234
```

**Output Enhancement**:
- Automatic PID validation
- User permission checking
- Enhanced error messages
- Compatible with both JDK and JRE environments

---

#### 3. jmap.sh - Memory Map Tool Wrapper

**Purpose**: Wrapper for `sun.tools.jmap.JMap` for memory analysis.

**Usage**:
```bash
sh bin/jmap.sh [options] <java_pid>
```

**Common Operations**:
```bash
# Object histogram
sh bin/jmap.sh -histo 1234

# Live object histogram (triggers GC)
sh bin/jmap.sh -histo:live 1234

# Heap dump
sh bin/jmap.sh -dump:format=b,file=heap.hprof 1234

# Live heap dump (triggers GC)
sh bin/jmap.sh -dump:live,format=b,file=heap.hprof 1234

# Memory map
sh bin/jmap.sh -dump:format=b,file=heap.hprof 1234
```

**Important Notes**:
- `:live` options trigger Full GC (application pause)
- Heap dumps can be large and time-consuming
- Requires sufficient disk space for heap dump files

---

#### 4. jstat.sh - Statistics Monitoring Tool Wrapper

**Purpose**: Wrapper for `sun.tools.jstat.Jstat` for GC and memory statistics.

**Usage**:
```bash
sh bin/jstat.sh [options] <java_pid> [interval] [count]
```

**Statistics Options**:
- `-gc` - Garbage collection statistics
- `-gccause` - GC statistics with cause information  
- `-gcutil` - GC utilization summary
- `-gccapacity` - Memory pool generation and space capacities

**Examples**:
```bash
# GC statistics every 1 second, 10 times
sh bin/jstat.sh -gc 1234 1000 10

# GC cause information every 5 seconds, continuously  
sh bin/jstat.sh -gccause 1234 5000

# Memory utilization summary
sh bin/jstat.sh -gcutil 1234
```

**Output Interpretation**:

**GC Statistics (`-gc`)**:
| Column | Description |
|--------|-------------|
| S0C, S1C | Survivor space 0/1 capacity (KB) |
| S0U, S1U | Survivor space 0/1 utilization (KB) |
| EC, EU | Eden space capacity/utilization (KB) |
| OC, OU | Old space capacity/utilization (KB) |
| YGC, YGCT | Young GC count/time |
| FGC, FGCT | Full GC count/time |
| GCT | Total GC time |

---

#### 5. jps.sh - Process Status Tool Wrapper

**Purpose**: Wrapper for `sun.tools.jps.Jps` to list Java processes.

**Usage**:
```bash
sh bin/jps.sh [options]
```

**Options**:
- `-l` - Long listing with full class names
- `-v` - JVM arguments
- `-m` - Application arguments

**Examples**:
```bash
# List Java processes
sh bin/jps.sh

# List with full class names
sh bin/jps.sh -l

# List with JVM arguments
sh bin/jps.sh -v

# List with application arguments  
sh bin/jps.sh -m
```

---

## Common Functions Library

### Kiwi Bash Library Functions

All scripts include a common library of utility functions for consistent behavior and error handling.

#### Logging Functions

##### `print_error($message)`
Prints error message to stderr and log file.
- **Parameters**: Error message string
- **Output**: `[TIMESTAMP] ERROR: message` to stderr and log file

##### `print_info($message)`  
Prints informational message to stdout and log file.
- **Parameters**: Info message string
- **Output**: `[TIMESTAMP] INFO: message` to stdout and log file

##### `log_error($message)`, `log_info($message)`
Silent logging functions (log file only).

##### `die($message)`
Prints error message and exits with error code.
- **Parameters**: Error message string
- **Behavior**: Calls `print_error()` and `exit 1`

#### Process Management Functions

##### `exec_cmd_with_java_user($java_pid, $command)`
Executes command as the Java process owner.
- **Parameters**:
  - `java_pid` - Target Java process ID
  - `command` - Command to execute
- **Logic**:
  - If current user == Java process user: Execute directly
  - If current user == root: Execute via `su`
  - Otherwise: Exit with error

##### `add_pid16_to_top_file($top_file)`
Adds hexadecimal PID column to top command output.
- **Purpose**: Correlates decimal PIDs from top with hexadecimal thread IDs in Java stack dumps
- **Parameters**: Path to top output file
- **Modification**: Prepends hex PID column to each numeric PID line

#### Validation Functions

##### `check_java_pid($java_pid)`
Validates Java process ID.
- **Validations**:
  - PID is not empty
  - PID corresponds to running Java process
- **Error Handling**: Exits on validation failure

##### `check_java_lib($java_pid)`
Validates JDK library availability.
- **Logic**:
  - If Java process uses JDK: No action needed
  - If Java process uses JRE: Validates embedded JDK libraries
- **Version Matching**: Ensures JDK library version compatibility

##### `check_cur_user($java_pid)`
Validates user permissions for Java process access.
- **Validations**:
  - Current user == Java process user, OR
  - Current user == root with access to tool directory
- **Error Handling**: Exits if permissions insufficient

---

## Configuration

### java_cpu_monitor.conf

Configuration file for CPU monitoring thresholds and timing parameters.

```bash
# Maximum monitoring cycles (default: 10000)
check_cpu_times=10000

# CPU check interval (default: 2s)  
check_cpu_interval=2s

# CPU usage threshold percentage (default: 20%)
cpu_threshold_usage=20

# Consecutive high CPU readings required (default: 5)
cpu_threshold_times=5

# Number of thread dumps to collect (default: 3)
stack_times=3

# Interval between thread dumps (default: 2s)
stack_interval=2s
```

**Tuning Guidelines**:
- **Lower `cpu_threshold_usage`**: More sensitive detection
- **Higher `cpu_threshold_times`**: Reduces false positives
- **Shorter `check_cpu_interval`**: More responsive monitoring (higher overhead)
- **More `stack_times`**: Better trend analysis (larger output)

---

## Error Handling and Troubleshooting

### Common Error Scenarios

#### 1. Permission Issues
**Error**: `java.io.IOException: well-known file is not secure`
**Cause**: Current user != Java process user
**Solution**: 
```bash
# Switch to Java process user
su - java_user
# Or ensure tool directory has proper permissions
chown -R java_user:java_group /path/to/kiwi_java_toolbox
```

#### 2. Version Mismatch
**Error**: `Unable to open socket file: target process not responding`
**Cause**: JDK tool version != Java process version
**Solution**:
```bash
# Update embedded JDK libraries
sh lib/jdk_lib_extract.sh /path/to/matching/jdk
```

#### 3. Missing Libraries
**Error**: `java.lang.UnsatisfiedLinkError: no attach in java.library.path`
**Cause**: Missing libattach.so in library path
**Solution**: Ensure proper `-Djava.library.path` setting (handled automatically by scripts)

### Debug Mode

Enable debug output for troubleshooting:
```bash
# Enable bash debug mode
bash -x java_info_collect.sh

# Or set debug environment
export DEBUG_SWITCH=-x
sh java_info_collect.sh
```

---

## Performance Considerations

### Resource Impact

#### CPU Monitoring
- **Overhead**: ~0.5 seconds per check cycle
- **Recommendation**: `check_cpu_interval >= 2s`
- **Impact**: Minimal on monitored process

#### Thread Dumps
- **Impact**: Brief application pause (typically <100ms)
- **Frequency**: Configurable via `stack_times` and `stack_interval`
- **Storage**: ~1-10MB per dump depending on thread count

#### Heap Dumps
- **Impact**: Full GC + application pause during dump
- **Duration**: Proportional to heap size (GB heap = minutes)
- **Storage**: Approximately heap size (compressed)
- **Recommendation**: Schedule during maintenance windows

#### GC-Triggering Operations
Operations that trigger garbage collection:
- `jmap -histo:live`
- `jmap -dump:live`
- JFR operations (minimal impact)

---

## Integration Examples

### Automated Monitoring Setup

```bash
#!/bin/bash
# Automated Java monitoring script

# Start CPU monitoring in background
nohup sh java_cpu_monitor.sh > monitor.log 2>&1 &
MONITOR_PID=$!

# Start flight recording
sh java_flight_recorder.sh start $JAVA_PID

# Schedule periodic collections
while true; do
    sleep 3600  # Every hour
    sh java_info_collect.sh
done
```

### Cron Integration

```bash
# Hourly light monitoring
0 * * * * /path/to/kiwi_java_toolbox/java_info_collect.sh

# Daily comprehensive analysis with heap dump
0 2 * * * /path/to/kiwi_java_toolbox/java_info_collect.sh

# Weekly flight recorder dump
0 0 * * 0 /path/to/kiwi_java_toolbox/java_flight_recorder.sh dump $JAVA_PID
```

---

## Output Analysis

### Thread Dump Analysis
- **Tools**: [Eclipse MAT](http://www.eclipse.org/mat), [IBM TMDA](https://www.ibm.com/developerworks/community/groups/service/html/communitystart?communityUuid=2245aa39-fa5c-4475-b891-14c205f7333c)
- **Online**: [GCEasy.io](http://gceasy.io)
- **Focus Areas**: Deadlocks, high CPU threads, blocking operations

### Heap Dump Analysis  
- **Tools**: Eclipse MAT, JVisualVM, JProfiler
- **Key Metrics**: Object retention, memory leaks, large object graphs
- **Heap Histogram**: Object count and size distribution

### GC Analysis
- **Tools**: GCViewer, GCEasy.io, Java Mission Control
- **Key Metrics**: GC frequency, pause times, throughput impact
- **Optimization**: Heap sizing, GC algorithm selection

### Flight Recorder Analysis
- **Tool**: Java Mission Control (JMC)
- **Comprehensive**: CPU usage, memory allocation, I/O operations
- **Low Overhead**: Production-safe continuous profiling

---

This API documentation provides comprehensive coverage of all public APIs, functions, and components in the Kiwi Java Toolbox, with detailed usage examples and troubleshooting guidance.