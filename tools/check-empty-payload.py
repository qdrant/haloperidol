import os
import requests

QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
QDRANT_CLUSTER_URL = os.getenv("QDRANT_CLUSTER_URL", "")

try:
    cluster_response = requests.get(
        f"https://{QDRANT_CLUSTER_URL}:6333/cluster",
        headers={"api-key": QDRANT_API_KEY},
        timeout=10,
    )
except requests.RequestException as e:
    print(
        f'level=ERROR msg="Request failed" uri="{QDRANT_CLUSTER_URL}" api="/cluster" e={e}'
    )
    exit(1)


num_peers = len(cluster_response.json()["result"]["peers"])

QDRANT_URIS = [
    f"https://node-{idx}-{QDRANT_CLUSTER_URL}:6333" for idx in range(num_peers)
]

for uri in QDRANT_URIS:
    # Count empty payload points without affecting rest of the consistency check
    try:
        response = requests.post(
            f"{uri}/collections/benchmark/points/scroll",
            headers={"api-key": QDRANT_API_KEY, "content-type": "application/json"},
            json={
                "filter": {
                    "must": { "is_empty": {"key": "a"} }
                },
                "limit": 1000,
                "with_payload": False
            },
            timeout=10,
        )
        response.raise_for_status()
        empty_payload_point_ids = [p["id"] for p in response.json()["result"]["points"]]
        if len(empty_payload_point_ids) > 0:
            print(
                f'level=CRITICAL msg="Found empty payload points" empty_payload_num_points={len(empty_payload_point_ids)} uri="{uri}" empty_payload_point_ids="{empty_payload_point_ids}"'
            )
    except (requests.RequestException, requests.HTTPError) as e:
        print(
            f'level=WARN msg="Request failed" uri="{uri}" api="/collections/benchmark/points/count" e={e}'
        )
