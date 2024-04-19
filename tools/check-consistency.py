#!/bin/python3

import os
import json
import requests
import random
import time

print("Checking data consistency")

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
point_ids_for_node = [initial_point_ids for _ in range(4)]  # node-0 to node-3

while True:
    cluster_response = requests.get(
        f"https://{QDRANT_CLUSTER_URL}:6333/cluster",
        headers={"api-key": QDRANT_API_KEY},
    )

    if cluster_response.status_code != 200:
        print(f"Non-200 response from /cluster API")
        print("Error response:", cluster_response.text)
        exit(1)

    num_nodes = len(cluster_response.json()["result"]["peers"])
    print(f"Number of nodes: {num_nodes}")

    QDRANT_URIS = [
        f"https://node-{idx}-{QDRANT_CLUSTER_URL}:6333" for idx in range(num_nodes)
    ]

    node_idx = 0
    first_node_points = []

    for uri in QDRANT_URIS:
        point_ids = point_ids_for_node[node_idx]

        if len(point_ids) == 0:
            is_data_consistent = True
            print(f"Skipping node-{node_idx}")
            node_idx += 1
            continue

        response = requests.post(
            f"{uri}/collections/benchmark/points",
            headers={"api-key": QDRANT_API_KEY, "content-type": "application/json"},
            json={"ids": point_ids, "with_vector": True, "with_payload": True},
        )

        if response.status_code != 200:
            if response.text == "Service Unavailable":
                print(f"{uri} seems unavailable, skipping consistency check for this node")
                continue

            print(f"Failed to fetch points from {uri}")
            print("Error response:", response.text)
            is_data_consistent = False
            break

        fetched_points = sorted(response.json()["result"], key=lambda x: x["id"])
        fetched_points_count = len(fetched_points)

        print(f"Got {fetched_points_count} points from {uri}")

        attempt_number = CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining
        with open(
            f"data/points-dump/node-{node_idx}-attempt-{attempt_number}.json", "w"
        ) as f:
            json.dump(fetched_points, f)

        if len(first_node_points) == 0:
            first_node_points = fetched_points
        elif fetched_points == first_node_points:
            print(f"{uri} data is consistent with node-0")
            point_ids_for_node[node_idx] = []
            is_data_consistent = True
        else:
            print(f"Checking {uri}")
            inconsistent_points = calculate_inconsistent_points(
                first_node_points, fetched_points, point_ids
            )
            if len(inconsistent_points) == 0:
                print(f"{uri} is consistent")
                point_ids_for_node[node_idx] = []
                is_data_consistent = True
                continue
            print(
                f"{uri} data is inconsistent with node-0 by {len(inconsistent_points)} points"
            )
            print("Inconsistent point IDs to be retried in next attempt:", inconsistent_points)

            point_ids_for_node[node_idx] = inconsistent_points

            is_data_consistent = False
            break

        node_idx += 1

    consistency_attempts_remaining -= 1

    if is_data_consistent:
        print(
            f"Data consistency check succeeded with {CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} attempt(s)"
        )
        break
    else:
        if consistency_attempts_remaining == 0:
            print(
                f"Data consistency check failed despite {CONSISTENCY_ATTEMPTS_TOTAL} attempts"
            )
            break
        else:
            print(
                f"Retrying data consistency check. Attempts remaining: {consistency_attempts_remaining} / {CONSISTENCY_ATTEMPTS_TOTAL}"
            )
            # Node might be unavailable which caused request to fail. Give some time to heal
            time.sleep(5)
            first_node_points = []
            continue

if not is_data_consistent:
    exit(1)
