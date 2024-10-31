#!/bin/python3
import json
from concurrent.futures import as_completed, ProcessPoolExecutor

import requests
import time

import os
import builtins
pid = os.getpid()

def print(*args, **kwargs):
    new_args = args + (f"pid={pid}",)
    builtins.print(*new_args, **kwargs)

print('level=INFO msg="Starting all points all peers data consistency check script"')

QC_NAME = os.getenv("QC_NAME", "qdrant-chaos-testing")

if QC_NAME == "qdrant-chaos-testing":
    POINTS_DIR = "data/points-dump"
elif QC_NAME == "qdrant-chaos-testing-debug":
    POINTS_DIR = "data/points-dump-debug"
elif QC_NAME == "qdrant-chaos-testing-three":
    POINTS_DIR = "data/points-dump-three"
else:
    raise NotImplementedError(f"Unknown cluster name {QC_NAME}")

# Ensure the data/points-dump directory exists
os.makedirs(POINTS_DIR, exist_ok=True)

# Environment variables with default values if not set
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
QDRANT_CLUSTER_URL = os.getenv("QDRANT_CLUSTER_URL", "")
CONSISTENCY_ATTEMPTS_TOTAL = 10


def get_points_ids_from_peer(uri, point_ids):
    if len(point_ids) == 0:
        print(
            f'level=INFO msg="Skipping because no check required for node" node={node_idx}'
        )
        return None

    try:
        response = requests.post(
            f"{uri}/collections/benchmark/points",
            headers={"api-key": QDRANT_API_KEY, "content-type": "application/json"},
            json={"ids": point_ids, "with_vector": False, "with_payload": True},
            timeout=10,
        )
    except requests.exceptions.Timeout:
        print(
            f'level=WARN msg="Request timed out after 10s, skipping all points all peers consistency check for node" uri="{uri}" api="/collections/benchmark/points"'
        )
        return None

    if response.status_code != 200:
        error_msg = response.text.strip()
        if error_msg in ("404 page not found", "Service Unavailable"):
            print(
                f'level=WARN msg="Node unreachable, skipping all points all peers consistency check" uri="{uri}" status_code={response.status_code} err="{error_msg}"'
            )
            return None
        else:
            # Some unknown error:
            print(
                f'level=ERROR msg="Failed to fetch points" uri="{uri}" status_code={response.status_code} err="{error_msg}"'
            )
            return None

    return {item["id"]: item["payload"] for item in response.json()["result"]}


def get_points_from_all_peers_parallel(qdrant_peers, attempt_number, node_points_map):
    for node_idx, uri in enumerate(qdrant_peers):
        if not node_points_map.get(node_idx):
            node_points_map[node_idx] = {}

    with ProcessPoolExecutor() as executor:
        future_to_uri = {executor.submit(get_points_ids_from_peer, uri, point_ids_for_node): (node_idx, uri) for node_idx, uri in enumerate(qdrant_peers)}
        for future in as_completed(future_to_uri):
            node_idx, uri = future_to_uri[future]
            fetched_points = future.result()

            if fetched_points:
                fetched_points_count = len(fetched_points)
                node_points_map[node_idx][attempt_number] = fetched_points
            else:
                fetched_points_count = 0
                fetched_points = {}

            print(
                f'level=INFO msg="Fetched points" num_points={fetched_points_count} uri="{uri}"'
            )
            with open(
                    f"{POINTS_DIR}/node-{node_idx}-attempt-{attempt_number}.json", "w"
            ) as f:
                json.dump(fetched_points, f)

    return node_points_map


def check_for_consistency(node_to_points_map, attempt_number, consistent_points):
    print(
        f'level=INFO msg="Start checking points, attempt_number={attempt_number}"'
    )
    for point in initial_point_ids:
        if consistent_points[point]:
            # if point is already consistent, no need to check again
            continue

        # get point's payload from all nodes
        point_attempt_versions_list = []
        for node_idx, node in node_to_points_map.items():
            if not node or not node.get(attempt_number):
                # print(f"level=INFO msg='No points for node, skip' node_idx={node_idx} attempt_number={attempt_number}")
                continue
            try:
                version = node[attempt_number][point]
            except KeyError:
                print(f"level=WARN msg='Missing point for node' node_idx={node_idx} attempt_number={attempt_number} point={point}")
                version = None
            point_attempt_versions_list.append(version)

        first_obj = point_attempt_versions_list[0]
        is_point_consistent = all(obj == first_obj for obj in point_attempt_versions_list)

        if is_point_consistent:
            consistent_points[point] = True
            continue

        point_history_nodes = [] # point history over different attempts for each node
        for node_idx, node in node_to_points_map.items():
            point_history = set()

            for attempt in range(attempt_number + 1):
                if node.get(attempt):
                    payload = node.get(attempt).get(point, None)
                    if payload:
                        point_history.add(tuple(sorted(payload.items())))
                    else:
                        point_history.add(())

            if point_history:
                # if node has no data for this point (was unreachable all this time), skip it
                point_history_nodes.append(point_history)

        common_objects = set.intersection(*point_history_nodes)
        common_objects = [dict(obj) for obj in common_objects]
        if len(common_objects) > 0:
            consistent_points[point] = True

    is_consistent = all(consistent_points.values())
    return is_consistent

num_points_to_check = 200000
initial_point_ids = list(range(num_points_to_check))
point_ids_for_node = list(range(num_points_to_check))
is_data_consistent = False
consistency_attempts_remaining = CONSISTENCY_ATTEMPTS_TOTAL
node_to_points_map = {}
consistent_points = {}

while True:
    attempt_number = CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining

    try:
        cluster_response = requests.get(
            f"https://{QDRANT_CLUSTER_URL}:6333/cluster",
            headers={"api-key": QDRANT_API_KEY},
            timeout=10,
        )
    except requests.exceptions.Timeout:
        print(
            f'level=ERROR msg="Request timed out after 10s" uri="{QDRANT_CLUSTER_URL}" api="/cluster"'
        )
        exit(1)

    if cluster_response.status_code != 200:
        print(
            f'level=ERROR msg="Got error in response" status_code={cluster_response.status_code} api="/cluster" response="{cluster_response.text}"'
        )
        exit(1)

    result = cluster_response.json()['result']
    num_peers = len(result["peers"])
    pending_operations = result["raft_info"]["pending_operations"]
    peer_id = result['peer_id']

    if num_peers >= 5 and pending_operations == 0:
        print(f'level=CRITICAL msg="Fetched cluster peers. Found too many peers" num_peers={num_peers} peer_id={peer_id} response={result}')
    else:
        print(f'level=INFO msg="Fetched cluster peers" peer_id={peer_id} num_peers={num_peers}')

    qdrant_peers = [
        f"https://node-{idx}-{QDRANT_CLUSTER_URL}:6333" for idx in range(num_peers)
    ]

    # node_to_points_map = get_points_from_all_peers(qdrant_peers, attempt_number, node_to_points_map)
    node_to_points_map = get_points_from_all_peers_parallel(qdrant_peers, attempt_number, node_to_points_map)
    # track consistency of each point
    if attempt_number == 0:
        # initialize all points on the 1st attempt
        for point in initial_point_ids:
            consistent_points[point] = False

    is_data_consistent = check_for_consistency(node_to_points_map, attempt_number, consistent_points)

    consistency_attempts_remaining -= 1

    if is_data_consistent:
        print(
            f'level=INFO msg="All points all peers data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining}'
        )
        break
    else:
        inconsistent_point_ids = [i for i, val in consistent_points.items() if not val]

        if consistency_attempts_remaining == 0:
            print(
                f'level=ERROR msg="All points all peers data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count={len(inconsistent_point_ids)} inconsistent_points="{inconsistent_point_ids[:20]}"'
            )

            last_fetched_node_inconsistent_points = []
            for point_id in inconsistent_point_ids:
                point_data = {point_id : {}}
                for node_idx, node_data in node_to_points_map.items():
                    point_data[point_id][f"node-{node_idx}"] = node_data[attempt_number][point_id] if node_data.get(attempt_number) else None
                last_fetched_node_inconsistent_points.append(point_data)

            print(
                    f'level=ERROR msg="Dumping inconsistent points (max 5)" last_fetched_points={last_fetched_node_inconsistent_points[:5]}')
            break
        else:
            print(
                f'level=WARN msg="Nodes might be inconsistent. Will retry" inconsistent_count={len(inconsistent_point_ids)} inconsistent_points="{inconsistent_point_ids[:20]}"'
            )
            print(
                f'level=WARN msg="Retrying all points all peers data consistency check, inconsistent points only" inconsistent_count={len(inconsistent_point_ids)} attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} remaining_attempts={consistency_attempts_remaining}'
            )
            point_ids_for_node = [ x for x in inconsistent_point_ids]
            # Node might be unavailable which caused request to fail. Give some time to heal
            time.sleep(5)
            continue

if not is_data_consistent:
    exit(1)
