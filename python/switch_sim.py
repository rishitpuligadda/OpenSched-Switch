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

if __name__ == "__main__":
    N = 4
    entries = hol_dest(N)
    collected = req_collector(entries)
    final_dest = arbiter(collected)
    print(entries)
    print(collected)
    print(final_dest)
    depart_refill(N, entries, final_dest)
    print(entries)
