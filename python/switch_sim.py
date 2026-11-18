import random
import sys
from collections import deque


class Arbiter:
    def __init__(self, rand_gen):
        self.rand_gen = rand_gen

    def schedule(self, requests):
        grants = {}
        for out_port in requests.keys():
            grants[out_port] = self.rand_gen.choice(requests[out_port])
        return grants


class Meter:
    def __init__(self, N, warmup):
        self.N = N
        self.warmup = warmup
        self.total = 0
        self.counted_slots = 0

    def record(self, count, current_slot):
        if current_slot >= self.warmup:
            self.total += count
            self.counted_slots += 1

    def report(self):
        if self.counted_slots <= 0:
            return 0.0
        return self.total / (self.N * self.counted_slots)


class HolSwitch:
    def __init__(self, N, slots, seed, warmup):
        self.N = N
        self.slots = slots
        self.rand_gen = random.Random(seed)
        self.arbiter = Arbiter(self.rand_gen)
        self.meter = Meter(N, warmup)
        self.hol = [self.rand_gen.randrange(N) for _ in range(N)]

    def _build_requests(self):
        requests = {}
        for in_port, out_dest in enumerate(self.hol):
            requests.setdefault(out_dest, []).append(in_port)
        return requests

    def step(self, current_slot):
        requests = self._build_requests()
        grants = self.arbiter.schedule(requests)
        for out_port, in_port in grants.items():
            self.hol[in_port] = self.rand_gen.randrange(self.N)
        self.meter.record(len(grants), current_slot)

    def run(self):
        for i in range(self.slots):
            self.step(i)
        return self.meter.report()


class Arrivals:

    def __init__(self, N, load, seed):
        self.N = N
        self.load = load
        self.rng = random.Random(seed)

    def generate(self):
        arrivals = {}
        for in_port in range(self.N):
            if self.rng.random() < self.load:
                arrivals[in_port] = self.rng.randrange(self.N)
        return arrivals


class PimMatcher:

    def __init__(self, rng, iterations):
        self.rng = rng
        self.iterations = iterations

    def schedule(self, requests):
        matching = {}
        matched_outputs = set()

        for _ in range(self.iterations):

            requesters = {}
            for in_port, outs in requests.items():
                if in_port in matching:
                    continue
                for out_port in outs:
                    if out_port not in matched_outputs:
                        requesters.setdefault(out_port, []).append(in_port)
            if not requesters:
                break


            grants = {}
            for out_port, ins in requesters.items():
                winner = self.rng.choice(ins)
                grants.setdefault(winner, []).append(out_port)


            for in_port, outs in grants.items():
                out_port = self.rng.choice(outs)
                matching[in_port] = out_port
                matched_outputs.add(out_port)

        return matching


class VoqMeter:

    def __init__(self, N, warmup):
        self.N = N
        self.warmup = warmup
        self.counted_slots = 0
        self.arrived = 0
        self.departed = 0
        self.delay_sum = 0
        self.delay_count = 0
        self.delay_max = 0

    def record_slot(self, slot, arrived, departed):
        if slot >= self.warmup:
            self.counted_slots += 1
            self.arrived += arrived
            self.departed += departed

    def record_delay(self, delay, arrival_slot):
        if arrival_slot >= self.warmup:
            self.delay_sum += delay
            self.delay_count += 1
            if delay > self.delay_max:
                self.delay_max = delay

    def report(self):
        if self.counted_slots <= 0:
            return {"offered": 0.0, "throughput": 0.0,
                    "mean_delay": 0.0, "max_delay": 0}
        capacity = self.N * self.counted_slots
        mean_delay = (self.delay_sum / self.delay_count
                      if self.delay_count else 0.0)
        return {"offered": self.arrived / capacity,
                "throughput": self.departed / capacity,
                "mean_delay": mean_delay,
                "max_delay": self.delay_max}


class VoqSwitch:

    def __init__(self, N, slots, warmup, load, iterations,
                 traffic_seed=1, sched_seed=2, check=False):
        self.N = N
        self.slots = slots
        self.arrivals = Arrivals(N, load, traffic_seed)
        self.matcher = PimMatcher(random.Random(sched_seed), iterations)
        self.meter = VoqMeter(N, warmup)
        self.voqs = [[deque() for _ in range(N)] for _ in range(N)]


        self.nonempty = [set() for _ in range(N)]
        self.total_arrived = 0
        self.total_departed = 0
        self.check = check

    def _build_requests(self):
        return {i: sorted(outs)
                for i, outs in enumerate(self.nonempty) if outs}

    def _check_matching(self, requests, matching):
        outs = list(matching.values())
        assert len(outs) == len(set(outs)), "an output was matched twice"
        for in_port, out_port in matching.items():
            assert out_port in requests.get(in_port, []), \
                "matched a VOQ that was empty"

    def _depart(self, matching, slot):
        for in_port, out_port in matching.items():
            q = self.voqs[in_port][out_port]
            arrival_slot = q.popleft()
            if not q:
                self.nonempty[in_port].discard(out_port)
            self.meter.record_delay(slot - arrival_slot, arrival_slot)
        return len(matching)

    def _enqueue(self, arrivals, slot):
        for in_port, out_port in arrivals.items():
            self.voqs[in_port][out_port].append(slot)
            self.nonempty[in_port].add(out_port)

    def step(self, slot):
        requests = self._build_requests()
        matching = self.matcher.schedule(requests)
        if self.check:
            self._check_matching(requests, matching)
        departed = self._depart(matching, slot)

        arrivals = self.arrivals.generate()
        self._enqueue(arrivals, slot)

        self.total_arrived += len(arrivals)
        self.total_departed += departed
        self.meter.record_slot(slot, len(arrivals), departed)

    def backlog(self):
        return sum(len(q) for row in self.voqs for q in row)

    def run(self):
        for slot in range(self.slots):
            self.step(slot)
        return self.meter.report()


MILESTONE1_BASELINE = {
    2: 0.750930, 4: 0.655203, 8: 0.618244, 16: 0.601780, 32: 0.593657,
}


def check_regression():
    print("== Regression: milestone 1 (single FIFO, HOL blocking) ==")
    ok = True
    for N, expected in MILESTONE1_BASELINE.items():
        got = HolSwitch(N, 100000, 67, 50).run()
        match = abs(got - expected) < 5e-7
        ok = ok and match
        print(f"N={N:2d}  got {got:.6f}  expected {expected:.6f}  "
              f"{'OK' if match else 'MISMATCH'}")
    return ok


def check_arrivals():
    print("== Arrivals: average per input per slot should equal load ==")
    N, slots = 8, 100000
    for load in (0.0, 0.25, 0.5, 0.75, 1.0):
        arr = Arrivals(N, load, seed=1)
        count = 0
        dest = [0] * N
        for _ in range(slots):
            for out_port in arr.generate().values():
                count += 1
                dest[out_port] += 1
        avg = count / (N * slots)
        spread = (max(dest) - min(dest)) / count if count else 0.0
        print(f"load {load:4.2f}  measured {avg:.4f}  "
              f"dest spread (max-min)/total {spread:.4f}")


def check_conservation():
    print("== Conservation and matching validity ==")
    for N, load, iters in ((4, 0.5, 1), (8, 0.8, 2), (16, 1.0, 4)):
        sw = VoqSwitch(N, 20000, 100, load, iters, check=True)
        sw.run()
        lhs = sw.total_arrived
        rhs = sw.total_departed + sw.backlog()
        status = "OK" if lhs == rhs else "MISMATCH"
        print(f"N={N:2d} load={load:.1f} iters={iters}  arrived {lhs} = "
              f"departed {sw.total_departed} + backlog {sw.backlog()}  "
              f"{status}")
        assert lhs == rhs


def sweep(N=8, slots=50000, warmup=2000):
    print(f"== Sweep: N={N}, {slots} slots, warmup {warmup} ==")
    print("PIM = random matching baseline. Delay is in slots.")
    print(f"{'load':>5} {'iters':>5} {'offered':>8} {'thruput':>8} "
          f"{'mean_delay':>11} {'max_delay':>10}")
    for load in (0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 1.0):
        for iters in (1, 2, 4):
            r = VoqSwitch(N, slots, warmup, load, iters).run()
            print(f"{load:5.2f} {iters:5d} {r['offered']:8.4f} "
                  f"{r['throughput']:8.4f} {r['mean_delay']:11.2f} "
                  f"{r['max_delay']:10d}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "checks"
    if which == "checks":
        check_regression()
        print()
        check_arrivals()
        print()
        check_conservation()
    elif which == "sweep":
        sweep()
    else:
        print("usage: python3 switch_sim.py [checks|sweep]")
