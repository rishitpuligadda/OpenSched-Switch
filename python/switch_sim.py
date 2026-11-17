import random

random.seed(62)

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

if __name__ == "__main__":
    entries = hol_dest(4)
    collected = req_collector(entries)
    print(entries)
    print(collected)
