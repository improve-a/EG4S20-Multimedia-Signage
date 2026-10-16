#!/usr/bin/env python3
"""Apply authored HTML memory-controller interface deltas to restored originals.

Only changed lines are included. Restore the local dependency manifest first;
this command verifies each complete baseline and is idempotent on its own result.
The SDRAM IP, clocks, pins and underlying FIFO implementation are not modified.
"""
import argparse,hashlib,json,pathlib
FILES={'rtl/SD/frame_fifo_read.v': {'baseline_sha256': '0f186d8460d613ba010cefaa2e1625b115b1feff96bf28d3bb2a57d02f9eb69d',
                              'baseline_text_sha256': '0f186d8460d613ba010cefaa2e1625b115b1feff96bf28d3bb2a57d02f9eb69d',
                              'result_text_sha256': '895ee6738e99df103ebe3144f9509430c398b2de1e1fa887fbf43ee419b281d6',
                              'edits': [{'start': 0,
                                         'end': 0,
                                         'old': [],
                                         'new': ['// HTML_FIDELITY_INTEGRATED\n']},
                                        {'start': 8,
                                         'end': 8,
                                         'old': [],
                                         'new': ['\tparameter READ_DRAIN_CYCLES=10,\n',
                                                 '    parameter ENABLE_SOURCE_READY=0,\n']},
                                        {'start': 11,
                                         'end': 11,
                                         'old': [],
                                         'new': ['\tinput source_ready,source_busy,\n']},
                                        {'start': 79,
                                         'end': 80,
                                         'old': ["assign rd_burst_finish = (rd_vld && rd_delay == 4'd10);\n"],
                                         'new': ['assign rd_burst_finish = (rd_vld && rd_delay == '
                                                 'READ_DRAIN_CYCLES);\n']},
                                        {'start': 83,
                                         'end': 84,
                                         'old': ['assign App_rd_en = App_rd_en_d0 && ((burst_cnt != 0) || '
                                                 '!Sdr_init_ref_vld);\n'],
                                         'new': ['assign App_rd_en = App_rd_en_d0 && (!ENABLE_SOURCE_READY '
                                                 '|| source_ready) && ((burst_cnt != 0) || '
                                                 '!Sdr_init_ref_vld);\n']},
                                        {'start': 114,
                                         'end': 115,
                                         'old': ["    else if(rd_delay < 4'd10)begin\n"],
                                         'new': ['    else if(rd_delay < READ_DRAIN_CYCLES)begin\n']},
                                        {'start': 179,
                                         'end': 180,
                                         'old': ["\t\t\t\tif(read_req_d2 == 1'b1 && Sdr_init_done)\n"],
                                         'new': ["\t\t\t\tif(read_req_d2 == 1'b1 && Sdr_init_done && "
                                                 '(!ENABLE_SOURCE_READY || !source_busy))\n']},
                                        {'start': 222,
                                         'end': 223,
                                         'old': ['\t\t\t\t\tstate <= S_ACK;\n'],
                                         'new': ['                    if(!ENABLE_SOURCE_READY || '
                                                 '!source_busy)state <= S_ACK;\n']},
                                        {'start': 252,
                                         'end': 253,
                                         'old': ['\t\t\t\t\tstate <= S_ACK;\n'],
                                         'new': ['                    if(!ENABLE_SOURCE_READY || '
                                                 '!source_busy)state <= S_ACK;\n']}]},
 'rtl/SD/frame_read_write.v': {'baseline_sha256': '733257c43b1f2ecac52c659c8d02e6e894d3abe18d35e71baf5a8ca65fd75eb1',
                               'baseline_text_sha256': '733257c43b1f2ecac52c659c8d02e6e894d3abe18d35e71baf5a8ca65fd75eb1',
                               'result_text_sha256': '7c9eceabec73f990904ea3e08fa0eaf1caca394cc3ba269364597baafb8201da',
                               'edits': [{'start': 0,
                                          'end': 0,
                                          'old': [],
                                          'new': ['// HTML_FIDELITY_INTEGRATED\n']},
                                         {'start': 10,
                                          'end': 10,
                                          'old': [],
                                          'new': ['\tparameter READ_BURST_SIZE        = BURST_SIZE, // '
                                                  'display reserve independent of write burst\n',
                                                  '\tparameter READ_DRAIN_CYCLES=10, ENABLE_LINEAR_CONFIG=0, '
                                                  'ENABLE_READ_SOURCE=0,\n']},
                                         {'start': 15,
                                          'end': 15,
                                          'old': [],
                                          'new': ['\toutput read_accept_mem,\n',
                                                  '\tinput write_linear,\n',
                                                  '    input read_source_ready,read_source_busy,\n',
                                                  '    output write_busy_mem,\n']},
                                         {'start': 87,
                                          'end': 87,
                                          'old': [],
                                          'new': ['assign read_accept_mem=rd_ack_mem;\n']},
                                         {'start': 116,
                                          'end': 117,
                                          'old': ['assign App_rd_busy = '
                                                  'O_rd_busy;//读指令还没有过去十个时钟;因为写指令优先，不需要在意下个时钟是否是读指令\n'],
                                          'new': ['assign write_busy_mem=O_wr_busy;\n',
                                                  'assign App_rd_busy = O_rd_busy | (ENABLE_READ_SOURCE && '
                                                  'read_source_busy);//读指令还没有过去十个时钟;因为写指令优先，不需要在意下个时钟是否是读指令\n']},
                                         {'start': 142,
                                          'end': 142,
                                          'old': [],
                                          'new': ['\t.ENABLE_LINEAR_CONFIG(ENABLE_LINEAR_CONFIG),\n']},
                                         {'start': 148,
                                          'end': 148,
                                          'old': [],
                                          'new': ['\t.write_linear(write_linear),\n']},
                                         {'start': 190,
                                          'end': 190,
                                          'old': [],
                                          'new': ['\t'
                                                  '.READ_DRAIN_CYCLES(READ_DRAIN_CYCLES),.ENABLE_SOURCE_READY(ENABLE_READ_SOURCE),\n']},
                                         {'start': 193,
                                          'end': 194,
                                          'old': ['\t.BURST_SIZE                 (BURST_SIZE               '
                                                  ')\n'],
                                          'new': ['\t.BURST_SIZE                 (READ_BURST_SIZE          '
                                                  ')\n']},
                                         {'start': 197,
                                          'end': 197,
                                          'old': [],
                                          'new': ['    '
                                                  '.source_ready(read_source_ready),.source_busy(read_source_busy),\n']}]}}

def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def apply_text(relative,text):
    text=text.replace("\r\n","\n")
    spec=FILES[relative]
    if digest(text)==spec["result_text_sha256"]:
        return text,False
    if digest(text)!=spec["baseline_text_sha256"]:
        raise ValueError(relative+": source differs from both the verified baseline and the integration result; preserve and inspect it. SHA256="+digest(text))
    lines=text.splitlines(keepends=True)
    for edit in reversed(spec["edits"]):
        if lines[edit["start"]:edit["end"]]!=edit["old"]:
            raise ValueError(relative+": baseline context mismatch")
        lines[edit["start"]:edit["end"]]=edit["new"]
    result="".join(lines)
    if digest(result)!=spec["result_text_sha256"]:
        raise ValueError(relative+": internal patch result hash mismatch")
    return result,True

def apply(root,check=False):
    planned=[]
    # Validate every file before writing any of them.
    for relative,spec in FILES.items():
        path=pathlib.Path(root)/relative
        raw=path.read_bytes()
        result,changed=apply_text(relative,raw.decode("utf-8"))
        planned.append((path,raw,result,changed,relative))
    report=[]
    for path,raw,result,changed,relative in planned:
        if changed and not check:
            path.write_bytes(result.encode("utf-8"))
        report.append({"path":str(path),"state":"APPLICABLE" if changed and check else "APPLIED" if changed else "UNCHANGED","before_sha256":hashlib.sha256(raw).hexdigest(),"result_text_sha256":digest(result),"baseline_manifest_sha256":FILES[relative]["baseline_sha256"]})
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    print(json.dumps(apply(args.root,args.check)))

if __name__=="__main__":
    main()
