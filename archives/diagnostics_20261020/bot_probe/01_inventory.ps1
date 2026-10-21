Get-ChildItem D:\FPGA -Force | Select-Object Mode,Name | Format-Table -AutoSize
git -C D:\FPGA\EG4S20-NoBot log -35 --oneline
git -C D:\FPGA\EG4S20-NoBot branch -a
git -C D:\FPGA\EG4S20-NoBot worktree list
git -C D:\FPGA\EG4S20-NoBot status --short
