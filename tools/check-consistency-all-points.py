#!/bin/python3

import json
import requests
import time

import os
import builtins
pid = os.getpid()

def print(*args, **kwargs):
    new_args = args + (f"pid={pid}",)
    builtins.print(*new_args, **kwargs)

print('level=INFO msg="Starting all points data consistency check script"')

QC_NAME = os.getenv("QC_NAME", "qdrant-chaos-testing-three")

if QC_NAME == "qdrant-chaos-testing":
    POINTS_DIR = "data/points-dump"
elif QC_NAME == "qdrant-chaos-testing-debug":
    POINTS_DIR = "data/points-dump-debug"
elif QC_NAME == "qdrant-chaos-testing-three":
    POINTS_DIR = "data/points-dump-three"
else:
    raise NotImplementedError(f"Unknown cluster name {QC_NAME}")

print(f'level=DEBUG msg="Run all points data consistency check against {QC_NAME}"')

# Ensure the data/points-dump directory exists
os.makedirs(POINTS_DIR, exist_ok=True)

# Environment variables with default values if not set
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "r7y5t9wYUFtSVZSMQgtpGhjNRZ85vxwN-zQj-PKQ-ZXzJm4DXXsNNg")
QDRANT_CLUSTER_URL = os.getenv("QDRANT_CLUSTER_URL", "chaos-testing-three.eu-central.aws.staging-cloud.qdrant.io")
CONSISTENCY_ATTEMPTS_TOTAL = 10

is_data_consistent = False
first_node_points = []
consistency_attempts_remaining = CONSISTENCY_ATTEMPTS_TOTAL


def calculate_inconsistent_points(source_points, target_points, point_ids):
    source_point_idx_to_point = {
        point["id"]: (point["payload"]) for point in source_points
    }
    target_point_idx_to_point = {
        point["id"]: (point["payload"]) for point in target_points
    }

    # Mismatching or missing points
    inconsistent_point_ids_by_payload = []

    for point_id in point_ids:
        source_payload = source_point_idx_to_point.get(
            point_id, None
        )
        target_payload = target_point_idx_to_point.get(
            point_id, None
        )

        if source_payload != target_payload:
            inconsistent_point_ids_by_payload.append(point_id)

    return (
        inconsistent_point_ids_by_payload,
        (source_point_idx_to_point, target_point_idx_to_point)
    )


# Check all the points
num_points_to_check = 200_000
initial_point_ids = list(range(num_points_to_check + 1))
point_ids_for_node = [
    initial_point_ids for _ in range(4)
]  # point ids to check for node-0 to node-3

while True:
    try:
        cluster_response = requests.get(
            f"https://{QDRANT_CLUSTER_URL}:6333/cluster",
            headers={"api-key": QDRANT_API_KEY},
            timeout=10,
        )
    except requests.exceptions.Timeout as e:
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


    QDRANT_URIS = [
        f"https://node-{idx}-{QDRANT_CLUSTER_URL}:6333" for idx in range(num_peers)
    ]

    node_idx = 0
    first_node_points = []

    for uri in QDRANT_URIS:
        if node_idx >= len(point_ids_for_node):
            print(
                f'level=CRITICAL msg="Unexpected node index found. Breaking loop" node_idx={node_idx}'
            )
            break

        point_ids = point_ids_for_node[node_idx]

        if len(point_ids) == 0:
            is_data_consistent = True
            print(
                f'level=INFO msg="Skipping because no check required for node" node={node_idx}'
            )
            node_idx += 1
            continue

        try:
            response = requests.post(
                f"{uri}/collections/benchmark/points",
                headers={"api-key": QDRANT_API_KEY, "content-type": "application/json"},
                json={"ids": point_ids, "with_vector": False, "with_payload": True},
                timeout=10,
            )
        except requests.exceptions.Timeout as e:
            print(
                f'level=WARN msg="Request timed out after 10s, skipping all points consistency check for node" uri="{uri}" api="/collections/benchmark/points"'
            )
            node_idx += 1
            continue

        if response.status_code != 200:
            error_msg = response.text.strip()
            if error_msg in ("404 page not found", "Service Unavailable"):
                print(
                    f'level=WARN msg="Node unreachable, skipping all points consistency check" uri="{uri}" status_code={response.status_code} err="{error_msg}"'
                )
                # point_ids_for_node[node_idx] = []
                node_idx += 1
                continue
            else:
                # Some unknown error:
                print(
                    f'level=ERROR msg="Failed to fetch points" uri="{uri}" status_code={response.status_code} err="{error_msg}"'
                )
                is_data_consistent = False
                break

        fetched_points = sorted(response.json()["result"], key=lambda x: x["id"])
        fetched_points_count = len(fetched_points)

        print(
            f'level=INFO msg="Fetched points" num_points={fetched_points_count} uri="{uri}"'
        )

        attempt_number = CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining
        with open(
            f"{POINTS_DIR}/node-{node_idx}-attempt-{attempt_number}.json", "w"
        ) as f:
            json.dump(fetched_points, f)

        if len(first_node_points) == 0:
            first_node_points = fetched_points
        elif fetched_points == first_node_points:
            print(f'level=INFO msg="Node is consistent with node-0" uri="{uri}"')
            point_ids_for_node[node_idx] = []
            is_data_consistent = True
        else:
            print(f'level=INFO msg="Checking points of node" uri="{uri}"')
            inconsistent_ids_by_payload, (first_node_points_map, fetched_node_points_map)  = (
                calculate_inconsistent_points(
                    first_node_points, fetched_points, point_ids
                )
            )
            if len(inconsistent_ids_by_payload) == 0:
                print(f'level=INFO msg="Node is consistent" uri="{uri}"')
                point_ids_for_node[node_idx] = []
                is_data_consistent = True
                node_idx += 1
                continue
            inconsistent_point_ids = inconsistent_ids_by_payload
            print(
                f'level=WARN msg="Node might be inconsistent compared to node-0. Need to retry" uri="{uri}" inconsistent_count={len(inconsistent_point_ids)} inconsistent_by_payload="{inconsistent_ids_by_payload}" inconsistent_points="{inconsistent_point_ids}"'
            )

            point_ids_for_node[node_idx] = inconsistent_point_ids

            is_data_consistent = False
            break

        node_idx += 1

    consistency_attempts_remaining -= 1

    if is_data_consistent:
        print(
            f'level=INFO msg="All points Data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining}'
        )
        break
    else:
        if consistency_attempts_remaining == 0:
            try:
                print(
                    f'level=ERROR msg="All points Data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count={len(inconsistent_point_ids)} inconsistent_by_payload="{inconsistent_ids_by_payload}" inconsistent_points="{inconsistent_point_ids}"'
                )
                first_node_inconsistent_points = []
                last_fetched_node_inconsistent_points = []

                for point_id in inconsistent_point_ids:
                    first_node_inconsistent_points.append(first_node_points_map[point_id])
                    last_fetched_node_inconsistent_points.append(fetched_node_points_map[point_id])

                print(f'level=ERROR msg="Dumping inconsistent points compared to node-0" node="node-{node_idx}" expected_points="{first_node_inconsistent_points}" fetched_points={last_fetched_node_inconsistent_points}')

            except Exception as e:
                print(f'level=ERROR msg="Failed while printing inconsistent points" err={e}')

            break
        else:
            print(
                f'level=WARN msg="Retrying all points data consistency check" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} remaining_attempts={consistency_attempts_remaining}'
            )
            # Node might be unavailable which caused request to fail. Give some time to heal
            time.sleep(5)
            first_node_points = []
            continue

if not is_data_consistent:
    exit(1)
