#!/bin/python3
import time
import os
import builtins

from typing import Set
from qdrant_client import QdrantClient, models

pid = os.getpid()

PointId = int

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
QDRANT_REQUEST_TIMEOUT = 30

num_points_to_check = 200000
initial_point_ids = set(range(num_points_to_check))

qdrant_client = QdrantClient(
    url=QDRANT_CLUSTER_URL, api_key=QDRANT_API_KEY, timeout=100
)
IGNORED_ERRORS = ["does not have enough active replicas"]

class IgnoredError(Exception):
    pass

def get_inconsistent_points_ids(point_ids: Set[PointId]) -> Set[PointId]:
    """Returns (bool, set) where bool represents whether it passed successfully"""
    try:
        if len(point_ids) == num_points_to_check:
            # It's faster to use scroll
            points_ids = initial_point_ids
            points, _nxt = qdrant_client.scroll(
                COLLECTION_NAME,
                limit=num_points_to_check,
                with_payload=["timestamp"],
                with_vectors=False,
                consistency=models.ReadConsistencyType.ALL,
            )
        else:
            points = qdrant_client.retrieve(
                COLLECTION_NAME,
                point_ids,
                with_payload=["timestamp"],
                with_vectors=False,
                consistency=models.ReadConsistencyType.ALL,
            )
        found_points = set([int(point.id) for point in points])
        missing_points = points_ids - found_points

        return missing_points
    except Exception as e:
        e_str = str(e)

        if any(ignored_err in e_str for ignored_err in IGNORED_ERRORS):
            raise IgnoredError(e_str)

        raise e

# Assume all points are inconsistent
inconsistent_points = initial_point_ids
consistency_attempts_remaining = CONSISTENCY_ATTEMPTS_TOTAL

while True:
    consistency_attempts_remaining -= 1

    try:
        inconsistent_points = get_inconsistent_points_ids(inconsistent_points)
    except IgnoredError as e:
        e_str = str(e).replace("\n", " ")
        print(f'level=WARN msg="Failed to retrieve inconsistent points. But ignoring error and passing check" error="{e_str}"')
        exit(0)
    except Exception as e:
        e_str = str(e).replace("\n", " ")
        print(f'level=WARN msg="Failed to retrieve inconsistent points" error="{e_str}"')

    if len(inconsistent_points) == 0:
        print(
            f'level=INFO msg="Data consistency check succeeded" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count=0 inconsistent_points="[]"'
        )
        exit(0)
    else:
        sample_inconsistent_points = sorted(list(inconsistent_points))[:20]

        if consistency_attempts_remaining == 0:
            print(
                f'level=ERROR msg="Data consistency check failed" attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} inconsistent_count={len(inconsistent_points)} sample_inconsistent_points="{sample_inconsistent_points}"'
            )
            exit(1)
        else:
            print(
                f'level=WARN msg="Nodes might be inconsistent. Will retry" inconsistent_count={len(inconsistent_points)} sample_inconsistent_points="{sample_inconsistent_points}"'
            )
            print(
                f'level=WARN msg="Retrying data consistency check, inconsistent points only" inconsistent_count={len(inconsistent_points)} attempts={CONSISTENCY_ATTEMPTS_TOTAL - consistency_attempts_remaining} remaining_attempts={consistency_attempts_remaining}'
            )
            time.sleep(5)
