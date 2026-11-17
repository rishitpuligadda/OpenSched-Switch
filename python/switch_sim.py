import random

random.seed(67)

def hol_dest(N):
    entries = []
    for _ in range(N):
        entries.append(random.randrange(N))

    return entries

def req_collector(entries):
    dest = {} 
    for i in range(len(entries)):
        if entries[i] not in dest:
            dest[entries[i]] = [i]
            continue
        dest[entries[i]].append(i)

    return dest

def arbiter(dest):
    final_dest = {}
    for key in dest.keys():
        rand_input = random.choice(dest[key])
        final_dest[key] = rand_input

    return final_dest

def depart_refill(N, entries, dest):
    for out in dest.keys():
        entries[dest[out]] = random.randrange(N)
    return len(dest)

def slot_loop(N, slots):
    total = 0
    entries = hol_dest(N)
    for i in range(slots):
        collected = req_collector(entries)
        final_dest = arbiter(collected)
        total += depart_refill(N, entries, final_dest)

    return total / (N * slots)
        

if __name__ == "__main__":
    N = 16
    slots = 1000
    print(f"slots: {slots}, N = {N} and throughput = {slot_loop(N, slots)}")
