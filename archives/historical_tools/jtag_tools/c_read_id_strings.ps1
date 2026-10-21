[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$ProgressPreference='SilentlyContinue'
$p='G:\anlu\bin\bw_commands_prompt.exe'
$s=[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($p))
$patterns=@('read_device_id','get_name_from_id','read_idcode','list_cable')
foreach($patt in $patterns){
  $index=0
  while(($index=$s.IndexOf($patt,$index,[StringComparison]::Ordinal)) -ge 0){
    $start=[Math]::Max(0,$index-750); $length=[Math]::Min(2000,$s.Length-$start)
    [pscustomobject]@{Pattern=$patt;Offset=$index;SurroundingStrings=@([regex]::Matches($s.Substring($start,$length),'[ -~]{4,}') | ForEach-Object {$_.Value})} | ConvertTo-Json -Depth 4
    $index += $patt.Length
  }
}
