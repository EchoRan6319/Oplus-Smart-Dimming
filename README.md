# 欧加真智能调光

一加 / 欧加系 ColorOS 设备的应用级低频闪自动切换模块。

默认保持 `全亮度低频闪`；当前台进入你手动加入名单的应用时，临时切换到 `经典低频闪`；退出后自动恢复。

## 适用范围

只有系统设置中同时存在以下两个选项的机型，才可以使用本模块：

- `经典低频闪`
- `全亮度低频闪`

如果你的手机设置里没有这两个选项，或名称 / 行为完全不同，则本模块无效。

## 当前状态

- 已在 OnePlus 15 / PLK110 / ColorOS `16.0.3.503` 上验证通过
- 默认使用原生守护进程 `oplus_smart_dimmingd`
- 前台应用检测优先使用 `cpuset + inotify` 事件驱动
- 仅在长时间无事件时，才启用低频 fallback 轮询

## 工作方式

模块会维护两种状态：

- 默认状态：`全亮度低频闪`
- 兼容状态：`经典低频闪`

行为规则：

1. 日常停留在默认状态
2. 当前台进入名单应用时，切到兼容状态
3. 退出名单应用时，恢复默认状态
4. 熄屏时恢复默认状态
5. 亮屏后重新识别当前前台应用并刷新状态

## 检测逻辑来源

本模块当前的前台应用检测思路，**明确参考并模仿了 YC9559 大佬的开源项目 [`yc9559/dfps`](https://github.com/yc9559/dfps)**。

参考点主要包括：

- 使用 `cpuset` / `cgroup` 变化作为前台应用切换信号
- 使用 `inotify` 监听相关节点，而不是高频 shell 轮询
- 在事件触发后，再解析一次当前前台包名

本模块**没有照搬 `dfps` 的触摸事件 / 动态刷新率逻辑**。  
`dfps` 解决的是“操作时高刷、空闲时低刷”；本模块只关心：

- 当前是不是进入了目标应用
- 当前是不是退出了目标应用
- 屏幕是不是熄灭 / 点亮

这里借鉴的是它的**事件驱动检测思路**，不是它的完整业务逻辑。

## 为什么不用纯轮询

旧版 shell 方案会周期性执行：

- `dumpsys`
- `settings get`
- 前台应用查询

这类轮询实现虽然简单，但更容易带来额外耗电。

当前版本已经改成：

- 事件驱动为主
- 低频 fallback 为辅

这样可以在保留兼容性的前提下，尽量减少无意义查询。

## WebUI 说明

WebUI 可以完成这些操作：

- 查看当前服务状态
- 查看当前模式 / 屏幕状态 / 前台应用
- 维护应用名单
- 开启或关闭调试日志
- 重启后台服务
- 查看运行诊断

模块页可同时保留两个入口：

- `打开 WebUI`
- `执行`

其中 `执行` 主要用于手动触发配置重载；日常配置仍建议优先在 WebUI 内完成。

WebUI 状态每 5 秒刷新一次；后台调光由原生守护进程事件驱动处理。  
屏幕状态检测间隔为 3 秒，用于熄屏恢复默认状态和亮屏后刷新当前应用。

`运行诊断` 默认收起，需要手动展开。  
展开后可以看到：

- 是否处于事件驱动
- 是否被迫进入 fallback
- 监听数量
- 事件次数
- 回退轮询次数
- 解析失败次数
- 最近来源 / 最近包名 / 最近失败
- 监听路径

## 哪些应用建议加入名单

建议只加入**确实需要兼容**的应用，例如：

- 游戏
- 高刷竞技类应用
- 你肉眼觉得显示观感不舒服的应用

不建议盲目全选。  
只有“确实需要单独兼容”的应用才值得加入，这样切换更少、日常观感也更稳定。

## 真机验证结果

在当前测试设备上，已验证通过：

- 普通应用保持默认状态 `2`
- 名单应用 `com.tencent.tmgp.sgame` 自动切换到兼容状态 `0`
- 返回桌面后恢复默认状态 `2`
- 熄屏时进入 `screen_off` 流程并恢复默认状态
- 亮屏后重新识别当前前台应用并恢复 `event` 模式
- 重启后自动拉起原生守护进程

事件监听已命中：

- `/dev/cpuset/top-app/tasks`
- `/dev/cpuset/top-app/cgroup.procs`
- `/dev/cpuset/foreground/tasks`
- `/dev/cpuset/foreground/cgroup.procs`

## 构建

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_native.ps1
```

### WSL

```bash
./scripts/build_native_wsl.sh
```

生成的 Android 原生守护进程产物位于：

```text
bin/oplus_smart_dimmingd
```

## 打包

正式发布包可通过以下脚本生成：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_release.ps1
```

当前 release 包名：

```text
build/oplus_smart_dimming_v425_release.zip
```

## 调试

如果要排查异常，优先看：

- WebUI 的 `运行诊断`
- `/data/local/tmp/oplus_smart_dimming.state`
- `/data/local/tmp/oplus_smart_dimming.boot.log`
- `/storage/emulated/0/Documents/Oplus_Smart_Dimming/smart_dimming.log`

重点观察这些字段：

- `runtime_mode`
- `screen_on`
- `app_monitor`
- `fallback_forced`
- `resolve_failures`
- `fallback_polls`

## V4.2.5 实机验证清单

安装新包后建议逐项确认：

- KernelSU 模块页同时显示 `执行` 和 `WebUI` 两个入口
- 点击 `执行` 后能看到模块目录、重载结果和服务 PID
- WebUI 可以正常打开并读取服务状态
- WebUI 点击 `重启服务` 后服务 PID 更新，状态重新读取成功
- 勾选当前前台应用并保存后，能立即切到经典低频闪
- 退出名单应用或熄屏后，能恢复全亮度低频闪
- `/data/local/tmp/oplus_smart_dimming.boot.log` 没有持续报错

## 致谢

- [YC9559 / dfps](https://github.com/yc9559/dfps)  
  前台应用检测与事件驱动思路的重要参考来源

- 二词元Token（酷安：戶晨風_Official）  
  本模块原始项目与场景需求来源
