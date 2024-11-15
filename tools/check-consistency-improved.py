#!/bin/python3
import requests
import time

import os
import builtins

from qdrant_client import QdrantClient, models

pid = os.getpid()

def print(*args, **kwargs):
    new_args = args + (f"pid={pid}",)
    builtins.print(*new_args, **kwargs)

print('level=INFO msg="Starting data consistency check script"')

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
COLLECTION_NAME = "benchmark"


def check_response_from_cluster():
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


def get_inconsistent_points_ids_from_all():
    points, _nxt = qdrant_client.scroll(
        COLLECTION_NAME,
        limit=num_points_to_check,
        with_payload=['timestamp'],
        with_vectors=False,
        consistency=models.ReadConsistencyType.ALL
    )

    found_points = set([int(point.id) for point in points])
    missing_points = initial_point_ids_set - found_points

    return list(missing_points)


def get_inconsistent_points_ids_from_list(point_ids):
    points = qdrant_client.retrieve(
        COLLECTION_NAME,
        point_ids,
        with_payload=['timestamp'],
        with_vectors=False,
        consistency=models.ReadConsistencyType.ALL
    )

    expected_points = set(point_ids)
    found_points = set([int(point.id) for point in points])
    missing_points = list(expected_points - found_points)
    return missing_points


num_points_to_check = 200000
initial_point_ids = list(range(num_points_to_check))
initial_point_ids_set = set(range(num_points_to_check))
point_ids_for_node = list(range(num_points_to_check))
is_data_consistent = False
consistency_attempts_remaining = CONSISTENCY_ATTEMPTS_TOTAL
node_to_points_map = {}
consistent_points = {}
qdrant_client = QdrantClient(url=QDRANT_CLUSTER_URL, api_key=QDRANT_API_KEY, timeout=100)


try:
    inconsistent_points = get_inconsistent_points_ids_from_all()
except Exception as e:
    print(
        f'level=ERROR msg="Failed to retrieve all points" error="{str(e)}"'
    )
    exit(1)

retries = CONSISTENCY_ATTEMPTS_TOTAL
while retries > 0:
    retries -= 1
    consistency_attempts_remaining -= 1

    try:
        inconsistent_points = get_inconsistent_points_ids_from_list(inconsistent_points)
    except Exception as e:
        print(
            f'level=ERROR msg="Failed to retrieve inconsistent points" error="{str(e)}"'
        )
        exit(1)

    if not inconsistent_points:
        print(
            f'level=INFO msg="Data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count=0 inconsistent_points="[]"'
        )
        exit(0)
    else:
        if consistency_attempts_remaining == 0:
            print(
                f'level=ERROR msg="Data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count={len(inconsistent_points)} inconsistent_points="{sorted(inconsistent_points[:20])}"'
            )
            exit(1)
        else:
            print(
                f'level=WARN msg="Nodes might be inconsistent. Will retry" inconsistent_count={len(inconsistent_points)} inconsistent_points="{sorted(inconsistent_points[:20])}"'
            )
            print(
                f'level=WARN msg="Retrying data consistency check, inconsistent points only" inconsistent_count={len(inconsistent_points)} attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} remaining_attempts={consistency_attempts_remaining}'
            )
            time.sleep(5)


if inconsistent_points:
    print(
        f'level=ERROR msg="Data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count={len(inconsistent_points)} inconsistent_points="{sorted(inconsistent_points[:20])}"'
    )
    exit(1)
else:
    print(
        f'level=INFO msg="Data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count=0 inconsistent_points="[]"'
    )
    exit(0)