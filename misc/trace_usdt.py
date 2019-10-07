# Originated from
# https://github.com/brendangregg/bcc/blob/master/examples/tracing/nodejs_http_server.py
#
# Usage:
# $ sudo python misc/trace_usdt.py `which haconiwa`
# or
# $ sudo haconiwa run sample/hooks.haco #=> PID: 23346
# $ sudo python misc/trace_usdt.py 23346

from bcc import BPF, USDT
from bcc.utils import printb
import os, sys

haconiwa_path_or_pid = sys.argv[1]

bpf_text = """
#include <uapi/linux/ptrace.h>
int do_trace(struct pt_regs *ctx) {
    uint64_t addr1, addr2;
    long phase, hpid;
    bpf_usdt_readarg(1, ctx, &addr1);
    bpf_usdt_readarg(2, ctx, &addr2);

    bpf_probe_read(&phase, sizeof(phase), (void *)&addr1);
    bpf_probe_read(&hpid, sizeof(hpid), (void *)&addr2);

    bpf_trace_printk("phase:%ld,hpid:%ld\\n", phase, hpid);
    return 0;
};
"""

bpf_text_str = """
int do_trace_str(struct pt_regs *ctx) {
    char buf[256];
    bpf_usdt_readarg_p(2, ctx, &buf, sizeof(buf));
    bpf_trace_printk("%s\\n", buf);
    return 0;
};
"""

b = None

if os.path.exists(haconiwa_path_or_pid):
    print("tracing program %s" % haconiwa_path_or_pid)
    u = USDT(path=haconiwa_path_or_pid)
    u.enable_probe(probe="bootstrap-phase-pass", fn_name="do_trace")

    b = BPF(text=bpf_text, usdt_contexts=[u])
else:
    print("tracing PID = %s" % haconiwa_path_or_pid)
    u2 = USDT(pid=int(haconiwa_path_or_pid))
    # u2.enable_probe(probe="probe-misc", fn_name="do_trace")
    u2.enable_probe(probe="probe-misc-str", fn_name="do_trace_str")
    b = BPF(text=bpf_text_str, usdt_contexts=[u2])

print("%-18s %-16s %-6s %s" % ("TIME(s)", "COMM", "PID", "VALUE"))

# format output
while 1:
    try:
        (task, pid, cpu, flags, ts, msg) = b.trace_fields()
    except ValueError:
        print("value error")
        continue
    except KeyboardInterrupt:
        exit()
    printb(b"%-18.9f %-16s %-6d %s" % (ts, task, pid, msg))
