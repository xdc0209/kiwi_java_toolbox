# Kiwi Java Toolbox - API Reference

## Table of Contents

1. [Script Reference](#script-reference)
2. [Function Reference](#function-reference)
3. [Configuration Reference](#configuration-reference)
4. [File Format Reference](#file-format-reference)
5. [Environment Variables](#environment-variables)
6. [Exit Codes](#exit-codes)
7. [Output Specifications](#output-specifications)

---

## Script Reference

### Main Scripts

#### java_info_collect.sh

**Synopsis**:
```bash
sh java_info_collect.sh
```

**Description**: 
One-click comprehensive Java process diagnostic information collection tool.

**Parameters**: None (interactive mode)

**Interactive Prompts**:
- Java PID selection from running processes

**Exit Codes**:
- `0` - Successful collection
- `1` - Invalid PID or permission error
- `2` - JDK library not found
- `3` - Insufficient disk space

**Output Files**:
| File Pattern | Description |
|--------------|-------------|
| `java_info_collect.log` | Main execution log |
| `cpu_jstack-[1-3].txt` | Thread stack dumps |
| `cpu_pstack-[1-3].txt` | Native stack traces |
| `cpu_top-[1-3].txt` | CPU usage snapshots |
| `mem_pmap.txt` | Memory mapping |
| `mem_objects_histogram.txt` | Object statistics |
| `mem_objects_histogram_live.txt` | Live object statistics |
| `mem_heap_dump.hprof` | Binary heap dump |
| `os_*.txt` | Operating system information |

**Example**:
```bash
$ sh java_info_collect.sh
[2024-09-15 14:30:22] INFO: ============================================================================================
[2024-09-15 14:30:22] INFO: 查询java进程：
[2024-09-15 14:30:22] INFO: ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
[2024-09-15 14:30:22] INFO: ============================================================================================
  PID USER                 CMD
 1234 appuser              java -Xmx2g -jar myapp.jar
Enter java pid: 1234
```

---

#### java_cpu_monitor.sh

**Synopsis**:
```bash
sh java_cpu_monitor.sh
```

**Description**: 
Continuous CPU monitoring with automatic diagnostic collection on threshold breach.

**Parameters**: None (interactive mode)

**Configuration File**: `java_cpu_monitor.conf`

**Interactive Prompts**:
- Java PID selection from running processes

**Monitoring Logic**:
```
1. Check CPU usage at configured intervals
2. Track consecutive high CPU readings
3. Trigger collection when threshold exceeded
4. Reset counter after collection
```

**Exit Codes**:
- `0` - Monitoring completed normally
- `1` - Invalid PID or permission error
- `2` - Configuration file error

**Output Files**:
| File Pattern | Description |
|--------------|-------------|
| `java_cpu_monitor.log` | Monitoring execution log |
| `[NNNNN]-cpu_jstack-[1-N].txt` | Timestamped thread dumps |
| `[NNNNN]-cpu_pstack-[1-N].txt` | Timestamped native stacks |
| `[NNNNN]-cpu_top-[1-N].txt` | Timestamped CPU snapshots |

**Example**:
```bash
$ sh java_cpu_monitor.sh
Enter java pid: 1234
[2024-09-15 14:30:22] INFO: Check cpu time 00001 of 10000.
[2024-09-15 14:30:22] INFO: Because {cpu_usage} [85.2%] >= {cpu_threshold_usage} [20%], increase {cpu_high_continuous_times} to [1].
```

---

#### java_flight_recorder.sh

**Synopsis**:
```bash
sh java_flight_recorder.sh <operation> <java_pid>
```

**Description**: 
Java Flight Recorder management interface.

**Parameters**:
- `operation` - Required. One of: `start`, `check`, `dump`, `stop`
- `java_pid` - Required. Target Java process ID

**Operations**:

##### start
Starts a new flight recording session.
```bash
sh java_flight_recorder.sh start 1234
```
- **Recording Name**: `java_flight_recorder`
- **Settings**: `profile`
- **Max Size**: `100m`
- **Max Age**: `24h`

##### check
Displays status of active recordings.
```bash
sh java_flight_recorder.sh check 1234
```

##### dump
Exports recording data to file.
```bash
sh java_flight_recorder.sh dump 1234
```
- **Output**: `/tmp/java_flight_recorder_[hostname]_[ip]_[timestamp].jfr`
- **Compression**: Enabled

##### stop
Stops active recording.
```bash
sh java_flight_recorder.sh stop 1234
```

**Exit Codes**:
- `0` - Operation successful
- `1` - Invalid parameters or help requested
- `2` - Java process not found
- `3` - JDK library compatibility error
- `4` - Operation-specific error (recording not found, etc.)

**Example**:
```bash
$ sh java_flight_recorder.sh start 1234
Exec cmd [ sh /home/kiwi_java_toolbox/bin/jcmd.sh 1234 JFR.start name=java_flight_recorder settings=profile maxsize=100m maxage=24h ].
1234:
Started recording 1. Name="java_flight_recorder" (running)
```

---

### Utility Scripts (bin/)

#### jcmd.sh

**Synopsis**:
```bash
sh bin/jcmd.sh <java_pid> <command> [arguments...]
```

**Description**: 
Wrapper for `sun.tools.jcmd.JCmd` with enhanced compatibility.

**Parameters**:
- `java_pid` - Required. Target Java process ID
- `command` - Required. JCmd command to execute
- `arguments` - Optional. Command-specific arguments

**Common Commands**:
| Command | Description |
|---------|-------------|
| `VM.uptime` | JVM uptime information |
| `VM.system_properties` | System properties |
| `VM.command_line` | JVM command line |
| `VM.version` | JVM version information |
| `GC.run` | Trigger garbage collection |
| `GC.run_finalization` | Run finalization |
| `Thread.print` | Print thread stacks |
| `JFR.start` | Start flight recording |
| `JFR.stop` | Stop flight recording |
| `JFR.dump` | Dump flight recording |
| `JFR.check` | Check recording status |

**Exit Codes**:
- `0` - Command executed successfully
- `1` - Invalid Java PID
- `2` - User permission mismatch
- `3` - JDK library not found

**Example**:
```bash
$ sh bin/jcmd.sh 1234 VM.uptime
1234:
12345.678 s

$ sh bin/jcmd.sh 1234 JFR.start name=myrecording settings=profile
1234:
Started recording 1. Name="myrecording" (running)
```

---

#### jstack.sh

**Synopsis**:
```bash
sh bin/jstack.sh [options] <java_pid>
```

**Description**: 
Wrapper for `sun.tools.jstack.JStack` for thread dump generation.

**Parameters**:
- `options` - Optional. JStack options
- `java_pid` - Required. Target Java process ID

**Options**:
| Option | Description |
|--------|-------------|
| `-l` | Long listing with lock information |
| `-m` | Mixed mode (Java and native frames) |
| `-F` | Force thread dump (for hung processes) |

**Exit Codes**:
- `0` - Thread dump generated successfully
- `1` - Invalid Java PID
- `2` - User permission mismatch
- `3` - JDK library not found
- `4` - Process hung or unresponsive

**Output Format**:
```
Full thread dump Java HotSpot(TM) 64-Bit Server VM (25.181-b13 mixed mode):

"Thread-1" #10 prio=5 os_prio=0 tid=0x... nid=0x... waiting on condition
   java.lang.Thread.State: WAITING (parking)
	at sun.misc.Unsafe.park(Native Method)
	at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
	...
```

**Example**:
```bash
$ sh bin/jstack.sh -l 1234 > thread_dump.txt
$ head -10 thread_dump.txt
Full thread dump Java HotSpot(TM) 64-Bit Server VM (25.181-b13 mixed mode):
```

---

#### jmap.sh

**Synopsis**:
```bash
sh bin/jmap.sh [options] <java_pid>
```

**Description**: 
Wrapper for `sun.tools.jmap.JMap` for memory analysis.

**Parameters**:
- `options` - Optional. JMap options
- `java_pid` - Required. Target Java process ID

**Options**:
| Option | Description | GC Impact |
|--------|-------------|-----------|
| `-histo` | Object histogram | None |
| `-histo:live` | Live object histogram | Triggers Full GC |
| `-dump:format=b,file=<file>` | Binary heap dump | None |
| `-dump:live,format=b,file=<file>` | Live binary heap dump | Triggers Full GC |
| `-clstats` | Class loader statistics | None |

**Exit Codes**:
- `0` - Operation completed successfully
- `1` - Invalid Java PID
- `2` - User permission mismatch
- `3` - JDK library not found
- `4` - Insufficient disk space
- `5` - Process hung during operation

**Histogram Output Format**:
```
 num     #instances         #bytes  class name
----------------------------------------------
   1:         12345        1234567  [C
   2:          5678         567890  java.lang.String
   3:          2345         234567  java.util.HashMap$Node
```

**Example**:
```bash
$ sh bin/jmap.sh -histo 1234 | head -10
 num     #instances         #bytes  class name
----------------------------------------------
   1:         98765       12345678  [C
   2:         87654        9876543  java.lang.String

$ sh bin/jmap.sh -dump:live,format=b,file=heap.hprof 1234
Dumping heap to heap.hprof ...
Heap dump file created
```

---

#### jstat.sh

**Synopsis**:
```bash
sh bin/jstat.sh [options] <java_pid> [interval] [count]
```

**Description**: 
Wrapper for `sun.tools.jstat.Jstat` for GC and memory statistics.

**Parameters**:
- `options` - Required. Statistics option
- `java_pid` - Required. Target Java process ID  
- `interval` - Optional. Update interval in milliseconds
- `count` - Optional. Number of updates (default: continuous)

**Statistics Options**:
| Option | Description |
|--------|-------------|
| `-gc` | Garbage collection statistics |
| `-gccause` | GC statistics with cause information |
| `-gcutil` | GC utilization summary |
| `-gccapacity` | Memory pool capacities |
| `-gcnew` | New generation statistics |
| `-gcold` | Old generation statistics |
| `-class` | Class loader statistics |

**GC Statistics Columns**:
| Column | Description | Unit |
|--------|-------------|------|
| `S0C`, `S1C` | Survivor space 0/1 capacity | KB |
| `S0U`, `S1U` | Survivor space 0/1 utilization | KB |
| `EC`, `EU` | Eden space capacity/utilization | KB |
| `OC`, `OU` | Old space capacity/utilization | KB |
| `MC`, `MU` | Metaspace capacity/utilization | KB |
| `YGC`, `YGCT` | Young GC count/time | count/seconds |
| `FGC`, `FGCT` | Full GC count/time | count/seconds |
| `GCT` | Total GC time | seconds |

**Exit Codes**:
- `0` - Statistics collected successfully
- `1` - Invalid Java PID
- `2` - Invalid statistics option
- `3` - JDK library not found

**Example**:
```bash
$ sh bin/jstat.sh -gc 1234 1000 3
 S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    YGC     YGCT    FGC    FGCT     GCT   
8192.0 8192.0  0.0   8192.0 65536.0  32768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3
8192.0 8192.0  0.0   8192.0 65536.0  35768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3
8192.0 8192.0  0.0   8192.0 65536.0  38768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3

$ sh bin/jstat.sh -gccause 1234
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT    LGCC                 GCC                 
  0.00  50.00  75.50  50.12  68.75  92.45  1250   12.500    45   67.800   80.300 Allocation Failure   No GC
```

---

#### jps.sh

**Synopsis**:
```bash
sh bin/jps.sh [options]
```

**Description**: 
Wrapper for `sun.tools.jps.Jps` to list Java processes.

**Parameters**:
- `options` - Optional. Output format options

**Options**:
| Option | Description |
|--------|-------------|
| `-l` | Long listing with full class names |
| `-v` | JVM arguments |
| `-m` | Application arguments |
| `-V` | JVM flags passed through flags file |

**Exit Codes**:
- `0` - Process list generated successfully
- `1` - No Java processes found
- `2` - JDK library not found

**Output Format**:
```
# Default output
1234 MyApplication
5678 org.apache.catalina.startup.Bootstrap

# With -l option
1234 com.example.MyApplication
5678 org.apache.catalina.startup.Bootstrap

# With -v option
1234 MyApplication -Xmx2g -Xms1g -server
5678 Bootstrap -Xmx1g -XX:+UseG1GC
```

**Example**:
```bash
$ sh bin/jps.sh
1234 MyApplication
5678 Bootstrap
9012 Jps

$ sh bin/jps.sh -l
1234 com.example.MyApplication
5678 org.apache.catalina.startup.Bootstrap
9012 sun.tools.jps.Jps
```

---

## Function Reference

### Common Library Functions

#### Logging Functions

##### print_error(message)
**Purpose**: Print error message to stderr and log file.
**Parameters**:
- `message` - Error message string
**Output**: `[TIMESTAMP] ERROR: message`
**Side Effects**: Writes to log file and stderr

##### print_info(message)
**Purpose**: Print informational message to stdout and log file.
**Parameters**:
- `message` - Information message string
**Output**: `[TIMESTAMP] INFO: message`
**Side Effects**: Writes to log file and stdout

##### log_error(message)
**Purpose**: Write error message to log file only.
**Parameters**:
- `message` - Error message string
**Side Effects**: Appends to log file

##### log_info(message)
**Purpose**: Write informational message to log file only.
**Parameters**:
- `message` - Information message string
**Side Effects**: Appends to log file

##### die(message)
**Purpose**: Print error message and exit with error code.
**Parameters**:
- `message` - Error message string
**Exit Code**: 1
**Side Effects**: Calls `print_error()` and terminates script

**Example**:
```bash
print_info "Starting collection process"
# Output: [2024-09-15 14:30:22] INFO: Starting collection process

print_error "Invalid PID specified"
# Output to stderr: [2024-09-15 14:30:22] ERROR: Invalid PID specified

die "Critical error occurred"
# Output to stderr: [2024-09-15 14:30:22] ERROR: Critical error occurred
# Script exits with code 1
```

---

#### Process Management Functions

##### exec_cmd_with_java_user(java_pid, command)
**Purpose**: Execute command as Java process owner.
**Parameters**:
- `java_pid` - Target Java process ID
- `command` - Command string to execute
**Return Value**: Command exit code
**Logic**:
1. Determine Java process owner
2. If current user == Java user: Execute directly
3. If current user == root: Execute via `su`
4. Otherwise: Exit with error

**Example**:
```bash
exec_cmd_with_java_user 1234 "sh bin/jstack.sh 1234"
# Executes as the owner of process 1234
```

##### add_pid16_to_top_file(top_file)
**Purpose**: Add hexadecimal PID column to top output.
**Parameters**:
- `top_file` - Path to top command output file
**Side Effects**: Modifies file in-place
**Logic**: Prepends hex PID to each line with numeric PID

**Example**:
```bash
# Before:
#   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
#  1234 appuser   20   0 4194304 1048576  32768 R 85.0  5.2   0:45.67 java

add_pid16_to_top_file cpu_top.txt

# After:
# PID-16   PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
# 0x4d2   1234 appuser   20   0 4194304 1048576  32768 R 85.0  5.2   0:45.67 java
```

---

#### Validation Functions

##### check_java_pid(java_pid)
**Purpose**: Validate Java process ID.
**Parameters**:
- `java_pid` - Process ID to validate
**Exit Code**: 1 if validation fails
**Validations**:
- PID is not empty
- PID corresponds to running Java process

##### check_java_lib(java_pid)
**Purpose**: Validate JDK library availability.
**Parameters**:
- `java_pid` - Java process ID for version detection
**Exit Code**: 1 if libraries not found
**Logic**:
1. Determine if Java process uses JDK or JRE
2. For JDK: Use system libraries
3. For JRE: Check embedded library compatibility

##### check_cur_user(java_pid)
**Purpose**: Validate user permissions.
**Parameters**:
- `java_pid` - Java process ID for user detection
**Exit Code**: 1 if permissions insufficient
**Validations**:
- Current user == Java process user, OR
- Current user == root with directory access

**Example**:
```bash
check_java_pid 1234
# Validates that 1234 is a running Java process

check_java_lib 1234
# Ensures JDK tools are available for process 1234

check_cur_user 1234
# Verifies current user can access process 1234
```

---

#### Environment Setup Functions

##### init_env()
**Purpose**: Initialize execution environment.
**Global Variables Set**:
- `output_dir` - Timestamped output directory
- `log` - Log file path
**Side Effects**:
- Creates output directory with 777 permissions
- Sets directory permissions

##### get_target_java_pid(args...)
**Purpose**: Extract Java PID from arguments.
**Parameters**:
- `args` - Command line arguments array
**Return Value**: First numeric argument
**Logic**: Searches for first argument matching `^[0-9]+$`

##### set_java_env_var(target_java_pid)
**Purpose**: Configure Java environment for tools.
**Parameters**:
- `target_java_pid` - Target process ID (optional)
**Global Variables Set**:
- `JAVA_CMD_FOR_TOOLS` - Java executable path
- `JAVA_LIBRARY_PATH_OPTION` - Library path option
- `JAVA_CLASSPATH_OPTION` - Classpath option
**Logic**:
1. Determine Java executable from PID or environment
2. Check JDK vs JRE installation
3. Set appropriate library and classpath options

**Example**:
```bash
init_env
# Sets up output directory: /tmp/java_info_collect_hostname_192.168.1.100_20240915T143022+0800

get_target_java_pid 1234 -l
# Returns: 1234

set_java_env_var 1234
# Configures Java environment for process 1234
```

---

## Configuration Reference

### java_cpu_monitor.conf

**File Location**: `./java_cpu_monitor.conf`

**Format**: Shell variable assignments

**Parameters**:

#### check_cpu_times
- **Type**: Integer
- **Default**: 10000
- **Description**: Maximum number of monitoring cycles
- **Range**: 1 - 2147483647
- **Example**: `check_cpu_times=5000`

#### check_cpu_interval
- **Type**: Time duration
- **Default**: 2s
- **Description**: Interval between CPU usage checks
- **Format**: `[0-9]+[smh]` (seconds, minutes, hours)
- **Minimum**: 1s
- **Example**: `check_cpu_interval=5s`

#### cpu_threshold_usage
- **Type**: Integer (percentage)
- **Default**: 20
- **Description**: CPU usage threshold for triggering collection
- **Range**: 0 - 100
- **Special**: 0 means always collect
- **Example**: `cpu_threshold_usage=75`

#### cpu_threshold_times
- **Type**: Integer
- **Default**: 5
- **Description**: Consecutive high CPU readings required
- **Range**: 1 - 1000
- **Purpose**: Reduce false positives
- **Example**: `cpu_threshold_times=3`

#### stack_times
- **Type**: Integer
- **Default**: 3
- **Description**: Number of thread dumps to collect per trigger
- **Range**: 1 - 10
- **Purpose**: Capture thread state changes
- **Example**: `stack_times=5`

#### stack_interval
- **Type**: Time duration
- **Default**: 2s
- **Description**: Interval between thread dump collections
- **Format**: `[0-9]+[smh]`
- **Minimum**: 1s
- **Example**: `stack_interval=1s`

**Complete Example**:
```bash
# High-sensitivity monitoring configuration
check_cpu_times=86400        # 24 hours of monitoring
check_cpu_interval=3s        # Check every 3 seconds  
cpu_threshold_usage=60       # Trigger at 60% CPU
cpu_threshold_times=4        # After 4 consecutive readings (12 seconds)
stack_times=4                # Collect 4 thread dumps
stack_interval=2s            # 2 seconds between dumps
```

---

## File Format Reference

### Thread Dump Format (.txt)

**File Pattern**: `cpu_jstack-[N].txt`, `[NNNNN]-cpu_jstack-[N].txt`

**Format**: Plain text Java thread dump

**Structure**:
```
Full thread dump Java HotSpot(TM) 64-Bit Server VM (build-info):

"thread-name" #thread-number prio=priority os_prio=os-priority tid=thread-id nid=native-id thread-state
   java.lang.Thread.State: THREAD_STATE
	at class.method(source:line)
	- waiting on <object-id> (a class.name)
	- locked <object-id> (a class.name)
	...

"Another Thread" #N prio=P os_prio=OP tid=TID nid=NID state
   java.lang.Thread.State: STATE
	at class.method(source:line)
	...
```

**Key Fields**:
- `thread-name` - Thread identifier
- `thread-number` - Sequential thread number
- `priority` - Java thread priority (1-10)
- `os_priority` - OS thread priority
- `thread-id` - JVM internal thread ID
- `native-id` - OS native thread ID (hexadecimal)
- `thread-state` - Current thread state

**Thread States**:
- `NEW` - Thread created but not started
- `RUNNABLE` - Thread executing or ready to execute
- `BLOCKED` - Thread blocked waiting for monitor
- `WAITING` - Thread waiting indefinitely
- `TIMED_WAITING` - Thread waiting for specified time
- `TERMINATED` - Thread completed execution

---

### Heap Dump Format (.hprof)

**File Pattern**: `mem_heap_dump.hprof`

**Format**: Binary heap dump (HPROF format)

**Header Structure**:
```
JAVA PROFILE 1.0.2
u4: identifier size (4)
u8: high word of timestamp
u8: low word of timestamp
[records]*
```

**Record Types**:
- `HEAP_DUMP` - Heap snapshot
- `HEAP_DUMP_SEGMENT` - Partial heap snapshot
- `LOAD_CLASS` - Class loading record
- `UNLOAD_CLASS` - Class unloading record
- `STACK_FRAME` - Stack frame definition
- `STACK_TRACE` - Stack trace definition

**Analysis Tools**:
- Eclipse Memory Analyzer (MAT)
- JVisualVM
- JProfiler
- IBM HeapAnalyzer

---

### Object Histogram Format (.txt)

**File Pattern**: `mem_objects_histogram.txt`, `mem_objects_histogram_live.txt`

**Format**: Plain text object statistics

**Structure**:
```
 num     #instances         #bytes  class name
----------------------------------------------
   1:         12345        1234567  [C
   2:          5678         567890  java.lang.String
   3:          2345         234567  java.util.HashMap$Node
   4:          1234         123456  [Ljava.lang.Object;
   ...
Total        123456       12345678
```

**Columns**:
- `num` - Ranking by total bytes
- `#instances` - Number of object instances
- `#bytes` - Total bytes consumed
- `class name` - Java class name

**Class Name Notation**:
- `[C` - char array
- `[B` - byte array  
- `[I` - int array
- `[L<classname>;` - Object array
- `[` prefix indicates array type

---

### GC Statistics Format (.txt)

**File Pattern**: Various `*gc*.txt` files

**Format**: Tabular GC statistics

**GC Statistics (`-gc`)**:
```
 S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    YGC     YGCT    FGC    FGCT     GCT   
8192.0 8192.0  0.0   8192.0 65536.0  32768.0  524288.0  262144.0  65536.0 45000.0  1250   12.5    45    67.8   80.3
```

**GC Cause Statistics (`-gccause`)**:
```
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT    LGCC                 GCC                 
  0.00  50.00  75.50  50.12  68.75  92.45  1250   12.500    45   67.800   80.300 Allocation Failure   No GC
```

---

### Log File Format (.log)

**File Pattern**: `java_info_collect.log`, `java_cpu_monitor.log`

**Format**: Timestamped log entries

**Entry Structure**:
```
[YYYY-MM-DD HH:MM:SS] LEVEL: message
```

**Log Levels**:
- `INFO` - Informational messages
- `ERROR` - Error messages

**Example**:
```
[2024-09-15 14:30:22] INFO: ============================================================================================
[2024-09-15 14:30:22] INFO: 查询java进程：
[2024-09-15 14:30:22] INFO: ps -eww -o pid,user:20,cmd | grep -v grep | grep -w java
[2024-09-15 14:30:25] ERROR: Pid [ 9999 ] is not a valid java pid.
```

---

## Environment Variables

### Tool-Specific Variables

#### JAVA_CMD_FOR_TOOLS
- **Purpose**: Override Java executable for tools
- **Type**: File path
- **Default**: Auto-detected from target process
- **Example**: `export JAVA_CMD_FOR_TOOLS=/usr/lib/jvm/java-8-openjdk/bin/java`

#### DEBUG_SWITCH
- **Purpose**: Enable debug mode for subscripts
- **Type**: Bash option
- **Values**: `-x` (enable), empty (disable)
- **Auto-set**: When parent script runs with `bash -x`

### System Variables Used

#### PS4
- **Purpose**: Bash debug prompt format
- **Set by**: Kiwi bash library
- **Format**: Colored timestamp and location information

#### BASH
- **Purpose**: Bash shell detection
- **Required**: Must be set (scripts verify bash usage)

#### SHELLOPTS
- **Purpose**: Shell option detection
- **Used for**: Debug mode propagation

---

## Exit Codes

### Standard Exit Codes

| Code | Meaning | Context |
|------|---------|---------|
| 0 | Success | Operation completed successfully |
| 1 | General error | Invalid parameters, permission denied |
| 2 | System error | Missing dependencies, system limitations |
| 3 | Configuration error | Invalid configuration, missing files |
| 4 | Runtime error | Process hung, operation timeout |
| 5 | Resource error | Insufficient disk space, memory |

### Script-Specific Exit Codes

#### java_info_collect.sh
- `0` - Collection completed successfully
- `1` - Invalid Java PID or permission error
- `2` - JDK library compatibility error
- `3` - Insufficient disk space for output

#### java_cpu_monitor.sh  
- `0` - Monitoring completed normally
- `1` - Invalid Java PID or permission error
- `2` - Configuration file error or invalid parameters

#### java_flight_recorder.sh
- `0` - Operation successful
- `1` - Invalid parameters or help requested
- `2` - Java process not found
- `3` - JDK library compatibility error
- `4` - Operation-specific error (recording not found, etc.)

#### Utility Scripts (bin/)
- `0` - Tool executed successfully
- `1` - Invalid Java PID
- `2` - User permission mismatch
- `3` - JDK library not found
- `4` - Tool-specific error (process hung, etc.)

---

## Output Specifications

### Directory Structure

**Pattern**: `/tmp/{script_name}_{hostname}_{ip_addresses}_{timestamp}/`

**Components**:
- `script_name` - Executing script name (without .sh)
- `hostname` - System hostname
- `ip_addresses` - Non-loopback IP addresses (dash-separated)
- `timestamp` - ISO format: YYYYMMDDTHHMMSS±ZZZZ

**Example**: `/tmp/java_info_collect_server01_192.168.1.100-10.0.0.5_20240915T143022+0800/`

### File Naming Conventions

#### Timestamped Files
**Pattern**: `{prefix}_{timestamp}.{extension}`
- Used for: Flight recorder dumps, manual collections
- Example: `java_flight_recorder_server01_192.168.1.100_20240915T143022+0800.jfr`

#### Sequence Files  
**Pattern**: `{prefix}-{sequence}.{extension}`
- Used for: Multiple thread dumps, CPU snapshots
- Example: `cpu_jstack-1.txt`, `cpu_jstack-2.txt`, `cpu_jstack-3.txt`

#### Prefixed Sequence Files
**Pattern**: `{cycle}-{prefix}-{sequence}.{extension}`
- Used for: CPU monitoring output
- Example: `00001-cpu_jstack-1.txt`, `00001-cpu_top-1.txt`

### Compression Formats

#### ZIP Archives
**Files**: `{output_dir}.zip`, `{output_dir}.without.heapdump.zip`
- **Format**: ZIP compression
- **Contents**: Complete diagnostic collection
- **Variants**: With and without heap dump

#### TAR Archives (Alternative)
**Pattern**: `{name}_{timestamp}.tar.gz`
- **Format**: Gzip-compressed tar
- **Usage**: Manual compression, space-constrained environments

### File Size Expectations

| File Type | Typical Size | Notes |
|-----------|--------------|-------|
| Thread dumps | 1-10 MB | Depends on thread count |
| Heap dumps | 100MB - 10GB | Approximately heap size |
| Object histograms | 10-100 KB | Text format, compressed well |
| GC statistics | 1-10 KB | Small tabular data |
| Log files | 10-100 KB | Depends on verbosity |
| System info | 10-50 KB | OS command outputs |

---

This API reference provides complete technical specifications for all public APIs, functions, and components in the Kiwi Java Toolbox.