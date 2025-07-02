import time, json, datetime, os, atexit
t0_wall = datetime.datetime.utcnow()
t0_mono = time.perf_counter()

def report():
    print("END   ", datetime.datetime.utcnow().isoformat(timespec='microseconds')+'Z')
    print(json.dumps({
        "wall_diff_s": (datetime.datetime.utcnow()-t0_wall).total_seconds(),
        "mono_diff_s": time.perf_counter()-t0_mono
    }, indent=2))

try:
  time.sleep(1000)
finally:
  atexit.register(report)