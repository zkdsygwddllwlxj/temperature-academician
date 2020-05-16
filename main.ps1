function getcputmp  # 获取CPU温度的函数
{
    $cputmp=Get-Counter "\Thermal Zone Information(*)\Temperature"
    $cputmp=$cputmp.CounterSamples.CookedValue[1]-273
    return $cputmp  # 函数返回值：cpu温度
}
function getgputmp  # 获取显卡温度的函数
{
    do
    {
        $gpuinfo = nvidia-smi
        $gputmp = $gpuinfo[8].Split()[4]
        $gputmp = $gputmp.Substring(0, $gputmp.Length - 1)
        $gputmp = [convert]::ToInt32($gputmp, 10)
    }
    until($gputmp)
    return $gputmp  # 函数返回值：显卡温度
}
function file_modification_date ($filepath)  # 获取文件最后一次修改日期的函数
{
    $fileinfo=dir $filepath
    $modificationdate=$fileinfo.LastWriteTime|Out-String
    $modificationdate=$modificationdate.Trim("`n`r").Split("")[0]
    return $modificationdate  # 函数返回值：文件最后一次修改日期
}
function produce_results($date,$cpu_max,$cpu_min,$gpu_max,$gpu_min)  #生成每日输出结果
{
    $cpu_diff=$cpu_max-$cpu_min
    $gpu_diff=$gpu_max-$gpu_min
    $result=$date+" "*(33-$date.Length)+$cpu_max+" "*33+$cpu_min+" "*16+$cpu_diff+" "*15+$gpu_max+" "*33+$gpu_min+" "*16+$gpu_diff
    return $result
}
function reset  # 重置文件的值
{
    0 > $PSScriptRoot\cpumax
    100 > $PSScriptRoot\cpumin
    0 > $PSScriptRoot\gpumax
    100 > $PSScriptRoot\gpumin
}
$cpu_max_path=$PSScriptRoot+"\cpumax"
$cpu_max_exist=Test-path $cpu_max_path  # 检测文件cpumax是否存在
$cpu_min_path=$PSScriptRoot+"\cpumin"
$cpu_min_exist=Test-path $cpu_min_path  # 检测文件cpumin是否存在
$gpu_max_path=$PSScriptRoot+"\gpumax"
$gpu_max_exist=Test-path $gpu_max_path  # 检测文件gpumax是否存在
$gpu_min_path=$PSScriptRoot+"\gpumin"
$gpu_min_exist=Test-path $gpu_min_path  # 检测文件gpumin是否存在
$cpu_tmp=getcputmp  # 获取cpu温度
$gpu_tmp=getgputmp  # 获取显卡温度
if (!$cpu_max_exist){   # 文件cpumax不存在，就创建该文件并把当前温度写入该文件
    New-Item cpumax
    $cpu_tmp > $PSScriptRoot\cpumax
}
if (!$cpu_min_exist){    # 文件cpumin不存在，就创建该文件并把当前温度写入该文件
    New-Item cpumin
    $cpu_tmp > $PSScriptRoot\cpumin
}
if (!$gpu_max_exist){   # 文件gpumax不存在，就创建该文件并把当前温度写入该文件
    New-Item gpumax
    $gpu_tmp > $PSScriptRoot\gpumax
}
if (!$gpu_min_exist){    # 文件gpumin不存在，就创建该文件并把当前温度写入该文件
    New-Item gpumin
    $gpu_tmp > $PSScriptRoot\gpumin
}
$last_time=Get-Date
$last_day=$last_time.Day    # 获取当前日
$now_date=$last_time|Out-String
$now_date=$now_date.Trim("`n`r").Split("")[0]   # 获取当前日期
$gpumin_modified_date=file_modification_date($gpu_min_path)  # 获取文件gpumin的修改日期
if ($gpumin_modified_date -ne$now_date)  #  文件gpumin修改日期不是当前日期的话
{
    $cpu_max=Get-Content $PSScriptRoot\cpumax   # 读取文件cpumax的值
    $cpu_min=Get-Content $PSScriptRoot\cpumin   # 读取文件cpumin的值
    $gpu_max=Get-Content $PSScriptRoot\gpumax   # 读取文件gpumax的值
    $gpu_min=Get-Content $PSScriptRoot\gpumin   # 读取文件gpumin的值
    $result=produce_results $gpumin_modified_date $cpu_max $cpu_min $gpu_max $gpu_min
    reset
    $result >> $PSScriptRoot\result.txt  # 上一次关机当天的结果写入文件
}
do{
    $cpu_tmp=getcputmp  # 获取当前CPU温度
    $gpu_tmp=getgputmp  # 获取当前显卡温度
    $HTML=$PSScriptRoot+"\index.html"
    [xml]$xml=Get-Content $HTML -Encoding UTF8
    $xml.html.body.h1="CPU温度：$cpu_tmp"
    $xml.html.body.h2="显卡温度：$gpu_tmp"
    [xml]$xml.save($HTML)
    $now_time=Get-Date
    $now_day=$now_time.Day
    $cpu_max=Get-Content $PSScriptRoot\cpumax   # 读取文件cpumax的值
    $cpu_min=Get-Content $PSScriptRoot\cpumin   # 读取文件cpumin的值
    $gpu_max=Get-Content $PSScriptRoot\gpumax   # 读取文件gpumax的值
    $gpu_min=Get-Content $PSScriptRoot\gpumin   # 读取文件gpumin的值
    if ($now_day -eq$last_day){  # 如果还在当天
        if($cpu_tmp -gt$cpu_max){
            $cpu_tmp > $PSScriptRoot\cpumax  # 更新CPU温度的最大值
        }
        if($cpu_tmp -lt$cpu_min){
            $cpu_tmp > $PSScriptRoot\cpumin  # 更新CPU温度的最小值
        }
        if($gpu_tmp -gt$gpu_max){
            $gpu_tmp > $PSScriptRoot\gpumax  # 更新显卡温度的最大值
        }
        if($gpu_tmp -lt$gpu_min){
            $gpu_tmp > $PSScriptRoot\gpumin  # 更新显卡温度的最小值
        }
    }else{
        $last_time_str=$last_time|Out-String
        $date=$last_time_str.Trim("`n`r").Split("")[0]  # 获取昨天的日期
        $result=produce_results $date $cpu_max $cpu_min $gpu_max $gpu_min
        reset
        $result >> $PSScriptRoot\result.txt  # 昨天的记录结果写入文件
        $last_day=$now_day
        $last_time=$now_time
    }
    sleep 1
}
while(1)