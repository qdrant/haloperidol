#!/bin/python3

import os
import json
import requests
import random
import time

print('level=INFO msg="Starting data consistency check script"')

# Ensure the data/points-dump directory exists
os.makedirs("data/points-dump", exist_ok=True)

# Environment variables with default values if not set
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
QDRANT_CLUSTER_URL = os.getenv("QDRANT_CLUSTER_URL", "")
CONSISTENCY_ATTEMPTS_TOTAL = 5

is_data_consistent = False
first_node_points = []
consistency_attempts_remaining = CONSISTENCY_ATTEMPTS_TOTAL


def calculate_inconsistent_points(source_points, target_points, point_ids):
    source_point_idx_to_vector = {
        point["id"]: point["vector"] for point in source_points
    }
    target_point_idx_to_vector = {
        point["id"]: point["vector"] for point in target_points
    }

    inconsistent_point_ids = []
    for point_id in point_ids:
        if source_point_idx_to_vector.get(point_id) != target_point_idx_to_vector.get(
            point_id
        ):
            # Mismatching or missing points
            inconsistent_point_ids.append(point_id)

    return inconsistent_point_ids


# Generate 100 random numbers between 0 and 200K and convert into JSON array
num_points_to_check = 100
initial_point_ids = random.sample(range(200_001), num_points_to_check)
point_ids_for_node = [
    initial_point_ids for _ in range(4)
]  # point ids to check for node-0 to node-3

while True:
    try:
        cluster_response = requests.get(
            f"https://{QDRANT_CLUSTER_URL}:6333/cluster",
            headers={"api-key": QDRANT_API_KEY},
            timeout=10
        )
    except requests.exceptions.Timeout as e:
        print(f'level=ERROR msg="Request timed out after 10s" uri="{QDRANT_CLUSTER_URL}" api="/cluster"')
        exit(1)

    if cluster_response.status_code != 200:
        print(
            f'level=ERROR msg="Got error in response" status_code={cluster_response.status_code} api="/cluster" response="{cluster_response.text}"'
        )
        exit(1)

    num_peers = len(cluster_response.json()["result"]["peers"])
    print(f'level=INFO msg="Fetched cluster peers" num_peers={num_peers}')

    QDRANT_URIS = [
        f"https://node-{idx}-{QDRANT_CLUSTER_URL}:6333" for idx in range(num_peers)
    ]

    node_idx = 0
    first_node_points = []

    for uri in QDRANT_URIS:
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
                json={"ids": point_ids, "with_vector": True, "with_payload": True},
            )
        except requests.exceptions.Timeout as e:
            print(f'level=WARN msg="Request timed out after 10s, skipping consistency check for node" uri="{uri}" api="/collections/benchmark/points"')
            node_idx += 1
            continue

        if response.status_code != 200:
            error_msg = response.text.strip()
            if error_msg in ("404 page not found", "Service Unavailable"):
                print(
                    f'level=WARN msg="Node unreachable, skipping consistency check" uri="{uri}" status_code={response.status_code} err="{error_msg}"'
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
            f"data/points-dump/node-{node_idx}-attempt-{attempt_number}.json", "w"
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
            inconsistent_points = calculate_inconsistent_points(
                first_node_points, fetched_points, point_ids
            )
            if len(inconsistent_points) == 0:
                print(f'level=INFO msg="Node is consistent" uri="{uri}"')
                point_ids_for_node[node_idx] = []
                is_data_consistent = True
                continue
            print(
                f'level=WARN msg="Node might be inconsistent. Need to retry" compared_to="node-0" uri="{uri}" inconsistent_count={len(inconsistent_points)} inconsistent_point_ids="{inconsistent_points}"'
            )

            point_ids_for_node[node_idx] = inconsistent_points

            is_data_consistent = False
            break

        node_idx += 1

    consistency_attempts_remaining -= 1

    if is_data_consistent:
        print(
            f'level=INFO msg="Data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining}'
        )
        break
    else:
        if consistency_attempts_remaining == 0:
            print(
                f'level=ERROR msg="Data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining}'
            )
            break
        else:
            print(
                f'level=WARN msg="Retrying data consistency check" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} remaining_attempts={consistency_attempts_remaining}'
            )
            # Node might be unavailable which caused request to fail. Give some time to heal
            time.sleep(5)
            first_node_points = []
            continue

if not is_data_consistent:
    exit(1)
