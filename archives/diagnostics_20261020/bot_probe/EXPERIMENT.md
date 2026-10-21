# Old Bot + proven HDMI Probe controlled experiment

Authorized scope: only transplant the proven probe; serial Windows TD build and, when available, hardware validation. Preserve all original projects, card data and unrelated uncommitted work. No SDRAM fixes, retiming or functional redesign.

Baseline: 20871da98664b2b674fbcfe94a713359ff9614a1, the final full Bot delivery before bcbc083 removed Bot. Its build inputs are sealed in timing_fix_20261016_02_source.zip (SHA256 2923dfe9667f1cb1472c87ae52e47fae743dda64054cb1978578decc2a4d84c3), built from aba266bf4ca2bdb347ed947493786cb9b6c00475. Later delivery changes are tests/documentation, not synthesis inputs. Original hardware record: black/white rapid flashing, no music; do not treat the offline timing acceptance as hardware success.

Probe donor: delivered 42de1dbe4a20ca78f28be54c4bf41bd0dd814481, build source 72e5c80e223f53953f6bb7b53dbb704e41d7c2d6, hdmi_probe_001_source.zip SHA256 5b204edb0b30a16c2256b0e08075b07aba99c4d228059892d52205e5bdb9c29f. Only its hdmi_probe.v, top-level observation connections and seven-segment probe display are imported. No NoBot datapath or constraints are imported.

Reproduction: `python -X utf8 scripts/bot_probe_build.py prepare`, then `python -X utf8 scripts/bot_probe_build.py run`. Requires original private ZIP dependencies on Windows. Preparation checks every sealed input and emits probe_only.diff and bot_probe_audit.json. It retains the complete old Bot design and inherited build.tcl, with only absolute project/ROM paths relocated. No ROM regeneration. No signal renaming is needed. Bitstreams/private derived vendor HDL remain excluded from Git.

Logical differences: top_tf_hdmi_audio.v connects HDMI locked output and adds probe/display; ext/hdmi_probe.v is copied byte-for-byte; project .al adds the source. Existing seven-segment status display is replaced as in the successful donor. This changes observation/implementation load, not HDMI pixel/audio data or media controls. All probe preservation attributes are retained as authored.

Hardware results remain PENDING until explicitly recorded against the new bitstream SHA256. SRAM download alone does not survive power removal; a persistent boot test needs separately tracked Flash programming or an explicit re-download distinction. Never overwrite the successful TF card without compatibility confirmation.
