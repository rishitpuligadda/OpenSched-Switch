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
    for key in dest.keys():
        rand_input = random.choice(dest[key])
        dest[key] = rand_input

def depart_refill(N, entries, dest):
    for out in dest.keys():
        entries[dest[out]] = random.randrange(N)

if __name__ == "__main__":
    N = 4
    entries = hol_dest(N)
    collected = req_collector(entries)
    print(entries)
    print(collected)
    arbiter(collected)
    print(collected)
    depart_refill(N, entries, collected)
    print(entries)
