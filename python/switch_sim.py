import random

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

class Switch:
    def __init__(self, N, slots, seed, warmup):
        self.N = N
        self.slots = slots

        self.rand_gen = random.Random(seed)

        self.arbiter = Arbiter(self.rand_gen)
        # Meter no longer needs total slots passed to it
        self.meter = Meter(N, warmup)

        self.hol = [self.rand_gen.randrange(N) for _ in range(N)]

    def _build_requests(self):
        requests = {}
        for in_port, out_dest in enumerate(self.hol):       
            requests.setdefault(out_dest, []).append(in_port)
        return requests

    def step(self, current_slot):
        # 1. Collect Requests
        requests = self._build_requests()

        # 2. Grant (Arbitration)
        grants = self.arbiter.schedule(requests)

        # 3. Depart and Refill
        for out_port, in_port in grants.items():
            self.hol[in_port] = self.rand_gen.randrange(self.N)

        # 4. Record throughput
        self.meter.record(len(grants), current_slot)

    def run(self):
        for i in range(self.slots):
            self.step(i)
        return self.meter.report()

def arrivals(N, load):
    arr_vals = {}
    for i in range(N):
        if random.random() < load:
            arr_vals[i] = random.randrange(N)
    return arr_vals

if __name__ == "__main__":
    test_cases = [2, 4, 8, 16, 32]
    slots = 100000
    seed = 67
    warmup = 50

    #for N in test_cases:
     #   sim = Switch(N, slots, seed, warmup)
      #  throughput = sim.run()
       # print(f"slots: {slots}, N = {N:2d} and throughput = {throughput:.6f}")

    print(arrivals(4, 1.0))
    print(arrivals(4, 0.5))
    print(arrivals(4, 0.75))
