#!/usr/bin/env python3
"""Static/short tests for the source-side AXIS contract and APUG092 text.

Run: python3 test_axis_contract.py -v
No receiver/FIFO behaviour is asserted here; that is covered by the
netlist-derived control model and iverilog tests under astra_reuse/.
"""
import os
import re
import unittest

import axis_model as m

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "rca_ab_sources", "A", "work", "design", "user_source", "hdl_source")
APUG = "/Users/mac/Documents/ChatGPT/安路赛题一/reports/hardware_APUG092_HDMI1.4b_Transmitter_V1.0.txt"


class SourceAndTiming(unittest.TestCase):
    def test_axis_source_has_no_ready_port_and_640_last(self):
        with open(os.path.join(SRC, "video_rgb_to_axis_640x480.v"), encoding="utf-8") as f:
            text = f.read()
        mod = text[text.index("module video_rgb_to_axis_640x480"):text.index("endmodule")]
        self.assertNotIn("ready", mod.lower(), "source must not have a ready input")
        self.assertIn("O_video_valid <= I_de", text)
        self.assertIn("S_x_cnt == 11'd638", text)
        self.assertIn("S_vs_1d != I_vs", text)

    def test_line_space_and_frame_space_match_core(self):
        with open(os.path.join(SRC, "SD", "color_bar.v"), encoding="utf-8") as f:
            cb = f.read()
        block = cb[cb.index("`ifdef  VIDEO_640_480"):cb.index("`endif", cb.index("`ifdef  VIDEO_640_480"))]
        vals = {k: int(re.search(k + r"\s*=\s*16'd(\d+)", block).group(1))
                for k in ("H_ACTIVE", "H_FP", "H_SYNC", "H_BP",
                          "V_ACTIVE", "V_FP", "V_SYNC", "V_BP")}
        with open(os.path.join(SRC, "top_tf_hdmi_audio.v"), encoding="utf-8") as f:
            top = f.read()
        core = top[top.index("hdmi_1_4b_transmitter_core_wrapper #"):top.index("u_hdmi_1_4b_transmitter_core_wrapper(")]
        core_vals = {k: int(re.search(r"\." + k + r"\s*\(\s*(\d+)", core).group(1))
                     for k in ("HTOTAL", "HSA", "HFP", "HBP", "HACTIVE",
                               "VTOTAL", "VSA", "VFP", "VBP", "VACTIVE")}
        self.assertEqual(core_vals["HACTIVE"], vals["H_ACTIVE"])
        self.assertEqual(core_vals["HTOTAL"], vals["H_ACTIVE"] + vals["H_FP"] + vals["H_SYNC"] + vals["H_BP"])
        self.assertEqual(core_vals["VACTIVE"], vals["V_ACTIVE"])
        self.assertEqual(core_vals["VTOTAL"], vals["V_ACTIVE"] + vals["V_FP"] + vals["V_SYNC"] + vals["V_BP"])
        self.assertEqual((core_vals["HSA"], core_vals["HFP"], core_vals["HBP"]),
                         (vals["H_SYNC"], vals["H_FP"], vals["H_BP"]))
        self.assertEqual((core_vals["VSA"], core_vals["VFP"], core_vals["VBP"]),
                         (vals["V_SYNC"], vals["V_FP"], vals["V_BP"]))

    def test_apug092_contract_text_is_present(self):
        if not os.path.exists(APUG):
            self.skipTest("APUG092 text not present on this machine")
        with open(APUG, encoding="utf-8", errors="replace") as f:
            t = f.read()
        self.assertIn("I_axis_s_user信号是帧起始信号", t)
        self.assertIn("O_axis_s_ready只会在I_axis_s_last为高之后拉低", t)
        self.assertIn("一行数据输入必须连续", t)


if __name__ == "__main__":
    unittest.main(verbosity=2)
