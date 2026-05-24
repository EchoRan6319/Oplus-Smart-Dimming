# C++ Migration Plan

## Goals

- Replace the current shell polling loop with a native C++ daemon.
- Execute the migration in the same priority order we identified during review.
- Keep the module shippable during the migration by preserving a shell fallback path.

## Priority Order

1. Replace fixed-interval foreground-app polling with event-driven detection.
2. Reduce screen-on detection cost.
3. Remove unnecessary `settings get` calls through caching.
4. Keep any remaining fallback polling conservative and clearly isolated.

## Target Architecture

- `service.sh`
  - Waits for boot and shared storage.
  - Starts the native daemon when `bin/oplus_smart_dimmingd` exists.
  - Falls back to the legacy shell loop when the daemon is unavailable.
- `native/src/main.cpp`
  - Owns signal handling, PID file, config reload, and the main event loop.
- `AppMonitor`
  - Watches `cpuset`/`cgroup` files with `inotify`.
  - Schedules package resolution only when top-app changes are detected.
- `StateController`
  - Holds in-memory package/state cache.
  - Computes target eye-protection mode from the selected package list.
- `SystemUtils`
  - Wraps shell command execution, `dumpsys` parsing, `settings` reads/writes, and state/log file output.
- `ConfigManager`
  - Loads and reloads `packages.conf`.

## Delivery Phases

### Phase 1: Native Daemon Skeleton

- Add a C++ source tree and build metadata.
- Move service ownership from the shell loop toward the daemon.
- Keep the existing shell implementation as a fallback path.

### Phase 2: Priority 1 Implementation

- Implement `AppMonitor` using `inotify` on:
  - `/dev/cpuset/top-app/tasks`
  - `/dev/cpuset/top-app/cgroup.procs`
- Debounce changes, then resolve the package name with `dumpsys`.
- Recompute and apply the target state only when the resolved package changes.

### Phase 3: Priority 2 Implementation

- Introduce `ScreenMonitor` or a low-cost screen-state strategy.
- Replace multi-command screen checks with a single cached source.
- Skip unnecessary work while the screen is off.

### Phase 4: Priority 3 Implementation

- Cache the currently applied state in memory.
- Restrict `settings get` to startup, explicit refresh, or recovery paths.
- Write the state file only when key fields change.

### Phase 5: Priority 4 Implementation

- Keep a clearly separated fallback poll mode.
- Use long intervals and backoff rather than a constant 3-second loop.
- Expose the current runtime mode in logs and state output.

## Initial File Layout

```text
docs/
  cpp-migration-plan.md
native/
  CMakeLists.txt
  src/
    app_monitor.cpp
    app_monitor.h
    config_manager.cpp
    config_manager.h
    main.cpp
    state_controller.cpp
    state_controller.h
    system_utils.cpp
    system_utils.h
scripts/
  legacy_loop.sh
```

## Current Scope

This first implementation pass focuses on:

- adding the plan to the workspace,
- scaffolding the native daemon,
- wiring `service.sh` to prefer the native daemon,
- preserving the current shell loop as a fallback.

## Next Milestones

1. Compile the daemon for the target Android ABI and place it under `bin/`.
2. Test `cpuset` event delivery on the OnePlus 15 target device.
3. Add screen-state optimization once package switching is stable.

# C++迁移计划  
## 目标  
- 将当前的shell轮询循环替换为原生C++守护进程。  
- 按照审查期间确定的优先级顺序执行迁移。  
- 通过保留shell回退路径，确保迁移过程中模块可交付。  

## 优先级顺序  
1. 将固定间隔的前台应用轮询替换为事件驱动的检测。  
2. 降低屏幕亮屏检测成本。  
3. 通过缓存减少不必要的`settings get`调用。  
4. 保持任何剩余的回退轮询保守且清晰隔离。  

## 目标架构  
- `service.sh`  
  - 等待启动完成及共享存储就绪。  
  - 当`bin/oplus_smart_dimmingd`存在时启动原生守护进程。  
  - 当守护进程不可用时回退至传统shell循环。  
- `native/src/main.cpp`  
  - 负责信号处理、PID文件、配置重载及主事件循环。  
- `AppMonitor`  
  - 使用`inotify`监控`cpuset`/`cgroup`文件。  
  - 仅在检测到顶层应用变化时调度包解析。  
- `StateController`  
  - 维护内存中的包/状态缓存。  
  - 根据选定包列表计算目标护眼模式。  
- `SystemUtils`  
  - 封装shell命令执行、`dumpsys`解析、`settings`读写及状态/日志文件输出。  
- `ConfigManager`  
  - 加载并重载`packages.conf`。  

## 交付阶段  
### 阶段一：原生守护进程框架  
- 添加C++源代码树及构建元数据。  
- 将服务所有权从shell循环迁移至守护进程。  
- 保留现有shell实现作为回退路径。  

### 阶段二：优先级1实现  
- 使用`inotify`在以下路径实现`AppMonitor`：  
  - `/dev/cpuset/top-app/tasks`  
  - `/dev/cpuset/top-app/cgroup.procs`  
- 去抖动变化，然后通过`dumpsys`解析包名。  
- 仅在解析的包发生变化时重新计算并应用目标状态。  

### 阶段三：优先级2实现  
- 引入`ScreenMonitor`或低成本的屏幕状态策略。  
- 用单一缓存源替换多命令屏幕检测。  
- 屏幕关闭时跳过不必要的工作。  

### 阶段四：优先级3实现  
- 在内存中缓存当前应用状态。  
- 将`settings get`限制在启动、显式刷新或恢复路径中。  
- 仅在关键字段变化时写入状态文件。  

### 阶段五：优先级4实现  
- 保持清晰分离的回退轮询模式。  
- 使用长间隔和退避策略，而非固定的3秒循环。  
- 在日志和状态输出中暴露当前运行时模式。  

## 初始文件布局  
```text  
docs/  
   cpp-migration-plan.md  
native/  
   CMakeLists.txt  
   src/  
     app_monitor.cpp  
     app_monitor.h  
     config_manager.cpp  
     config_manager.h  
     main.cpp  
     state_controller.cpp  
     state_controller.h  
     system_utils.cpp  
     system_utils.h  
scripts/  
   legacy_loop.sh  
```  

## 当前范围  
首次实现重点在于：  
- 将计划添加到工作区，  
- 搭建原生守护进程框架，  
- 配置`service.sh`优先使用原生守护进程，  
- 保留当前shell循环作为回退。  

## 下阶段里程碑  
1. 为目标Android ABI编译守护进程并放置于`bin/`目录下。  
2. 在OnePlus 15目标设备上测试`cpuset`事件传递。  
3. 包切换稳定后添加屏幕状态优化。